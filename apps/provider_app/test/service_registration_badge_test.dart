import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/onboarding/requirements/options/data/provider_options_response.dart';
import 'package:provider_app/features/services/application/service_detail_controller.dart';
import 'package:provider_app/features/services/application/service_providers.dart';
import 'package:provider_app/features/services/documents/documents_controller.dart';
import 'package:provider_app/features/services/documents/documents_repository.dart';

import 'service_first_test.dart' show ServiceFixture, pump;
import 'support/fake_documents_repository.dart';
import 'support/fake_options_repository.dart';
import 'support/fake_schema_repository.dart';

ServiceFixture registeredFixture() {
  final f = ServiceFixture(existing: true);
  final schema = schemaJson();
  schema['options'] = [
    for (var id = 12; id < 17; id++)
      {'optionId': id, 'code': 'CARE_$id', 'name': 'Care $id', 'fields': []},
  ];
  f.schema.result = Success(parseProviderSchema(schema, 3));
  return f;
}

void main() {
  testWidgets(
    'card shows unique saved sub-services out of the available schema and refreshes',
    (tester) async {
      final f = registeredFixture();
      f.options.selections = Success(
        parseProviderOptions([
          selectedOptionJson(),
          selectedOptionJson(id: 13),
          selectedOptionJson(id: 99),
        ]),
      );
      await pump(tester, f);
      expect(find.text('2/5 Registered'), findsOneWidget);
      f.options.selections = Success(
        parseProviderOptions([
          selectedOptionJson(),
          selectedOptionJson(id: 13),
        ]),
      );
      f.container.invalidate(providerAssignmentsProvider);
      await tester.pumpAndSettle();
      // A local selection is a draft, not a registered sub-service.
      f.container.read(serviceDetailControllerProvider(3).notifier).toggle(14);
      await tester.pumpAndSettle();
      expect(find.text('2/5 Registered'), findsOneWidget);
      f.options.selections = Success(
        parseProviderOptions([
          selectedOptionJson(),
          selectedOptionJson(id: 13),
          selectedOptionJson(id: 14),
        ]),
      );
      f.container.invalidate(providerAssignmentsProvider);
      await tester.pumpAndSettle();
      expect(find.text('3/5 Registered'), findsOneWidget);
      expect(f.services.submissions, 0);
      expect(f.options.saves, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('known incomplete registration is excluded from the numerator', (
    tester,
  ) async {
    final f = registeredFixture();
    f.options.selections = Success(
      parseProviderOptions([selectedOptionJson(), selectedOptionJson(id: 13)]),
    );
    (f.container.read(
      documentsRepositoryProvider,
    ) as FakeDocuments).requirementsResult = Success(
      parseRequirements([requirementJson()..['optionId'] = 13]),
    );
    await pump(tester, f);
    expect(find.text('1/5 Registered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unavailable count keeps the registered badge without inventing a ratio',
    (tester) async {
      final f = registeredFixture();
      f.options.selections = const Failure(AppFailure(message: 'Unavailable'));
      await pump(tester, f);
      final badge = find.byKey(const ValueKey('service-registration-count-3'));
      expect(
        find.descendant(of: badge, matching: find.text('Registered')),
        findsOneWidget,
      );
      expect(find.text('0/5 Registered'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
