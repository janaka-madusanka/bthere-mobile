import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/services/presentation/service_registration_screen.dart';
import 'package:provider_app/features/onboarding/requirements/options/data/provider_options_response.dart';
import 'package:provider_app/features/services/application/service_detail_controller.dart';
import 'package:provider_app/features/services/documents/documents_controller.dart';
import 'package:provider_app/features/services/documents/documents_repository.dart';

import 'service_first_test.dart' show ServiceFixture, pump, detail;
import 'support/fake_documents_repository.dart';
import 'support/fake_options_repository.dart';

FakeDocuments documents(ServiceFixture fixture) =>
    fixture.container.read(documentsRepositoryProvider) as FakeDocuments;

void main() {
  testWidgets(
    'saved pending subservice without required documents remains incomplete and resumes',
    (tester) async {
      final f = ServiceFixture(existing: true);
      documents(f).requirementsResult = Success(
        parseRequirements([requirementJson()]),
      );
      await pump(tester, f, route: '/services/3');
      expect(find.text('Incomplete'), findsOneWidget);
      expect(find.text('Pending review'), findsNothing);
      expect(find.text('Your Registered Sub-services'), findsNothing);
      expect(find.text('Sub Services'), findsOneWidget);
      final row = find.byKey(const ValueKey('registered-option-12'));
      expect(
        find.descendant(of: row, matching: find.text('Incomplete')),
        findsOneWidget,
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      final registration = tester.widget<ServiceRegistrationScreen>(
        find.byType(ServiceRegistrationScreen),
      );
      expect(registration.serviceTypeId, 3);
      expect(registration.optionId, 12);
      expect(f.services.submissions, 0);
      expect(f.options.saves, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in ['PENDING', 'APPROVED']) {
    test(
      'uploaded $status documents keep pending subservice in review',
      () async {
        final f = ServiceFixture(existing: true);
        documents(f).requirementsResult = Success(
          parseRequirements([requirementJson()]),
        );
        documents(f).documentsResult = Success(
          parseDocuments([documentJson(status: status)]),
        );
        expect((await detail(f)).incompleteRegistrationIds, isEmpty);
      },
    );
  }
  for (final status in ['APPROVED', 'REJECTED']) {
    test('$status subservice is unchanged when documents are absent', () async {
      final f = ServiceFixture(existing: true);
      f.options.selections = Success(
        parseProviderOptions([
          selectedOptionJson()..['verificationStatus'] = status,
        ]),
      );
      documents(f).requirementsResult = Success(
        parseRequirements([requirementJson()]),
      );
      expect((await detail(f)).incompleteRegistrationIds, isEmpty);
      expect(documents(f).requirementCalls, 0);
    });
  }
  test(
    'option-specific missing document does not relabel another subservice',
    () async {
      final f = ServiceFixture(existing: true);
      f.options.selections = Success(
        parseProviderOptions([
          selectedOptionJson(),
          selectedOptionJson(id: 13),
        ]),
      );
      documents(f).requirementsResult = Success(
        parseRequirements([requirementJson()..['optionId'] = 13]),
      );
      expect((await detail(f)).incompleteRegistrationIds, {13});
    },
  );
  test(
    'optional documents and failed refresh do not relabel pending subservice',
    () async {
      final f = ServiceFixture(existing: true);
      documents(f).requirementsResult = Success(
        parseRequirements([requirementJson(required: false)]),
      );
      expect((await detail(f)).incompleteRegistrationIds, isEmpty);
      documents(f).requirementsResult = const Failure(
        AppFailure(message: 'Unavailable'),
      );
      f.container.invalidate(serviceDetailControllerProvider(3));
      expect((await detail(f)).incompleteRegistrationIds, isEmpty);
    },
  );
}
