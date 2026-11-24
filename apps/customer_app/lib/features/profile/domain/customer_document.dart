import '../../booking/domain/booking_models.dart';

/// One reusable requirement; its targets never create separate submissions.
CustomerRequirement documentRequirement(Map<String, dynamic> item) {
  final upload = Map<String, dynamic>.from(item['upload'] as Map);
  if (item['actionRequired'] is! bool ||
      item['fileKeys'] is! List ||
      !{
        'IMAGE_UPLOAD',
        'DOCUMENT_UPLOAD',
        'FILE_UPLOAD',
      }.contains(item['fieldType'])) {
    throw const FormatException('Invalid document');
  }
  final keys = List<String>.from(item['fileKeys'] as List);
  if (keys.any((key) => key.isEmpty) || keys.toSet().length != keys.length) {
    throw const FormatException('Invalid document files');
  }
  return CustomerRequirement.parse({
    'requirement': {
      'requirementId': item['requirementId'],
      'definition': {
        ...upload,
        'code': item['code'],
        'label': item['name'],
        'fieldType': item['fieldType'],
        'description': item['description'],
        'required': item['required'],
        'blocksBooking': item['blocksBooking'],
        'maximumFileSizeMb': (upload['maximumFileSizeMb'] as int? ?? 10).clamp(
          1,
          10,
        ),
      },
    },
    'submission': {
      'status': item['status'],
      'value': {
        'files': [
          for (final key in keys) {'key': key},
        ],
      },
      'expiresOn': item['expiresOn'],
      'rejectionReason': item['rejectionReason'],
    },
  });
}

String? documentReason(Map<String, dynamic> item) =>
    switch (item['statusReason']) {
      'DEFINITION_CHANGED' => 'Requirements changed. Please upload again.',
      'SUPPORTING_EVIDENCE_CHANGED' =>
        'Under review again after supporting evidence changed.',
      'REJECTED' =>
        item['rejectionReason'] as String? ?? 'Rejected. Please upload again.',
      'EXPIRED' =>
        item['expiresOn'] == null
            ? 'Expired. Upload a new document.'
            : 'Expired on ${item['expiresOn']}.',
      _ => null,
    };
