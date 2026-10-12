import '../../data/provider_schema_response.dart';
import '../domain/provider_selected_option.dart';

List<ProviderSelectedOption> parseProviderOptions(Object? raw) {
  final values = array(raw).map((v) {
    final m = object(v);
    final timestamp = m['reviewedAt'];
    DateTime? date;
    if (timestamp != null) {
      if (timestamp is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(timestamp)) {
        throw const FormatException('Invalid review date');
      }
      date = DateTime.tryParse(timestamp)?.toUtc();
      if (date == null) throw const FormatException('Invalid review date');
    }
    return ProviderSelectedOption(
      providerOptionId: integer(m['providerOptionId'], positive: true),
      optionId: integer(m['optionId'], positive: true),
      code: string(m['code']),
      name: string(m['name']),
      providerStatus: string(m['providerStatus']),
      adminStatus: string(m['adminStatus']),
      verificationStatus: string(m['verificationStatus']),
      reviewedBy: optionalInt(m['reviewedBy'], positive: true),
      reviewedAt: date,
      reviewNote: m['reviewNote'] == null
          ? null
          : m['reviewNote'] is String
          ? m['reviewNote'] as String
          : throw const FormatException('Invalid review note'),
    );
  }).toList();
  if (values.map((v) => v.optionId).toSet().length != values.length ||
      values.map((v) => v.providerOptionId).toSet().length != values.length) {
    throw const FormatException('Duplicate selected options');
  }
  return List.unmodifiable(values);
}
