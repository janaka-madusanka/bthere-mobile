/// Carries only a fixed schema field name, never a backend value.
class DiscoveryContractException extends FormatException {
  const DiscoveryContractException(this.field)
    : super('Invalid discovery response');
  final String field;
}

class CustomerMarket {
  const CustomerMarket({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.currencyCode,
    required this.timezone,
  });
  final int id;
  final String name, countryCode, currencyCode, timezone;
  factory CustomerMarket.fromJson(Object? value) {
    final json = object(value);
    return CustomerMarket(
      id: positiveId(json['id']),
      name: text(json['name']),
      countryCode: text(json['countryCode']),
      currencyCode: text(json['currencyCode']),
      timezone: text(json['timezone']),
    );
  }
}

class CustomerService {
  const CustomerService({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.coverImage,
    required this.accessStatus,
    required this.action,
    required this.reasons,
    this.iconUrl,
  });
  final int id;
  final String name, accessStatus, action;
  final String? description, imageUrl, iconUrl;
  final bool coverImage;
  final List<String> reasons;
  factory CustomerService.fromJson(Object? value) {
    final row = object(value),
        service = object(row['service'], field: 'service'),
        access = object(row['access'], field: 'access');
    final eligibility = object(
      access['eligibility'],
      field: 'access.eligibility',
    );
    final reasons = eligibility['reasons'];
    if (reasons is! List || eligibility['eligible'] is! bool) {
      throw DiscoveryContractException(
        reasons is! List
            ? 'access.eligibility.reasons'
            : 'access.eligibility.eligible',
      );
    }
    String? media(Object? value) => value == null
        ? null
        : safeImageUrl(object(value, field: 'service.media')['url']);
    final cover = media(service['coverImage']);
    return CustomerService(
      id: positiveId(service['id'], field: 'service.id'),
      name: text(service['name'], field: 'service.name'),
      description: optionalText(service['description']),
      imageUrl:
          cover ?? media(service['icon']) ?? safeImageUrl(service['iconUrl']),
      iconUrl: media(service['icon']) ?? safeImageUrl(service['iconUrl']),
      coverImage: cover != null,
      accessStatus: text(access['status'], field: 'access.status'),
      action: text(access['action'], field: 'access.action'),
      reasons: List.unmodifiable(
        reasons.map(
          (item) => text(
            object(item, field: 'access.eligibility.reason')['message'],
            field: 'access.eligibility.reason.message',
          ),
        ),
      ),
    );
  }
  String get badge => switch (accessStatus) {
    'ELIGIBLE' => 'Available',
    'CHECK_OPTION' => 'Check options',
    'NEEDS_DETAILS' => 'Details required',
    'PENDING_REVIEW' => 'Pending review',
    'REJECTED' => 'Requirements rejected',
    'RESTRICTED' => 'Restricted',
    _ => 'Check availability',
  };
}

/// The customer OptionCard projection used by the expandable service catalog.
/// Provider qualification fields are deliberately not customer form fields.
class CustomerServiceOption {
  const CustomerServiceOption({
    required this.id,
    required this.serviceId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.displayOrder,
    required this.access,
  });
  final int id, serviceId, displayOrder;
  final String name;
  final String? description, imageUrl;
  final CustomerService access;
  String? get iconUrl => access.iconUrl;

  factory CustomerServiceOption.fromJson(Object? value) {
    final row = object(value), option = object(row['option'], field: 'option');
    final order = option['displayOrder'];
    if (order is! int) {
      throw const DiscoveryContractException('option.displayOrder');
    }
    final access = CustomerService.fromJson({
      'service': {...option, 'id': option['optionId']},
      'access': row['access'],
    });
    return CustomerServiceOption(
      id: positiveId(option['optionId'], field: 'option.optionId'),
      serviceId: positiveId(
        option['serviceTypeId'],
        field: 'option.serviceTypeId',
      ),
      name: access.name,
      description: access.description,
      imageUrl: access.imageUrl,
      displayOrder: order,
      access: access,
    );
  }
}

Map<String, dynamic> object(Object? value, {String field = 'object'}) {
  if (value is! Map<String, dynamic>) {
    throw DiscoveryContractException(field);
  }
  return value;
}

String text(Object? value, {String field = 'text'}) {
  if (value is! String || value.trim().isEmpty) {
    throw DiscoveryContractException(field);
  }
  return value;
}

String? optionalText(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const DiscoveryContractException('service.description');
  }
  return value.trim().isEmpty ? null : value;
}

int positiveId(Object? value, {String field = 'id'}) {
  if (value is! int || value <= 0) {
    throw DiscoveryContractException(field);
  }
  return value;
}

String? safeImageUrl(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const DiscoveryContractException('service.media.url');
  }
  final uri = Uri.tryParse(value);
  return uri != null &&
          ['http', 'https'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? value
      : null;
}
