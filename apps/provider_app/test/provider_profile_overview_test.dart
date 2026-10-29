import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/account/application/provider_profile_overview.dart';
import 'package:provider_app/features/services/documents/document_models.dart';
import 'package:provider_app/features/services/documents/documents_controller.dart';

import 'service_first_test.dart';
import 'support/fake_documents_repository.dart';

void main() {
  test('shared document rows deduplicate types and exclude unselected option requirements', () async {
    final fixture = ServiceFixture(existing: true);
    final documents =
        fixture.container.read(documentsRepositoryProvider) as FakeDocuments;
    documents.requirementsResult = const Success([
      DocumentRequirement(1, 'ID', null, false, false, true),
      DocumentRequirement(1, 'ID', null, false, true, true, optionId: 12),
      DocumentRequirement(
        2,
        'Unused option document',
        null,
        false,
        true,
        true,
        optionId: 99,
      ),
      DocumentRequirement(
        3,
        'Selected option document',
        null,
        false,
        true,
        true,
        optionId: 12,
      ),
    ]);
    final result = await fixture.container.read(
      profileDocumentRequirementsProvider.future,
    );
    expect(result, isA<Success<List<ProfileDocumentRequirement>>>());
    final rows = (result as Success<List<ProfileDocumentRequirement>>).value;
    expect(rows.map((r) => r.requirement.id), [1, 3]);
    expect(rows.first.requirement.required, isTrue);
    expect(rows.first.serviceTypeId, 3);
  });
  test('failed document requirements remain an error rather than an empty requirement list', () async {
    final fixture = ServiceFixture(existing: true);
    final documents =
        fixture.container.read(documentsRepositoryProvider) as FakeDocuments;
    documents.requirementsResult = const Failure(
      AppFailure(message: 'Synthetic private response'),
    );
    final result = await fixture.container.read(
      profileDocumentRequirementsProvider.future,
    );
    expect(result, isA<Failure<List<ProfileDocumentRequirement>>>());
    expect(
      (result as Failure).failure.message,
      'Unable to load document requirements. Please retry.',
    );
  });
}
