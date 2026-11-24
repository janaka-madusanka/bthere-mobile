import 'package:customer_app/features/profile/domain/customer_document.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> document() => {
  'requirementId': 7,
  'code': 'CERTIFICATE',
  'name': 'Certificate',
  'fieldType': 'DOCUMENT_UPLOAD',
  'required': true,
  'blocksBooking': true,
  'status': 'MISSING',
  'actionRequired': true,
  'statusReason': 'DEFINITION_CHANGED',
  'services': [
    {'optionId': 2},
    {'optionId': 3},
  ],
  'fileKeys': ['customers/12/documents/old.pdf'],
  'upload': {
    'minimumFiles': 1,
    'maximumFiles': 2,
    'maximumFileSizeMb': 20,
    'allowedFileTypes': ['PDF', 'PNG'],
  },
};

void main() {
  test('shared requirement keeps one identity and old evidence after definition change', () {
    final item = document();
    final result = documentRequirement(item);
    expect(result.field.id, 7);
    expect(result.field.uploadExtensions, ['pdf', 'png']);
    expect(result.value, {
      'files': [
        {'key': 'customers/12/documents/old.pdf'},
      ],
    });
    expect(documentReason(item), contains('upload again'));
  });
  test('rejects duplicate file keys and missing authoritative action flag', () {
    final item = document()..['fileKeys'] = ['same', 'same'];
    expect(() => documentRequirement(item), throwsFormatException);
    final missing = document()..remove('actionRequired');
    expect(() => documentRequirement(missing), throwsFormatException);
  });
  test('supporting evidence and expiry explain review state', () {
    expect(
      documentReason({'statusReason': 'SUPPORTING_EVIDENCE_CHANGED'}),
      contains('Under review again'),
    );
    expect(
      documentReason({'statusReason': 'EXPIRED', 'expiresOn': '2026-11-23'}),
      contains('2026-11-23'),
    );
  });
}
