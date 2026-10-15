import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/onboarding/requirements/options/data/provider_options_response.dart';
import 'package:provider_app/features/services/application/service_detail_controller.dart';

import 'service_first_test.dart' show ServiceFixture, pump;
import 'provider_options_test.dart' show optionsSchema;
import 'support/fake_service_repository.dart';
import 'support/fake_options_repository.dart';

void main() {
  for (final registered in [false, true]) {
    testWidgets('caregiving overview ${registered ? 'registered' : 'new'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = ServiceFixture(existing: registered);
      f.services.catalog = Success(
        parseActiveProviderServices([serviceJson(name: 'Caregiving')]),
      );
      final schema = optionsSchema();
      schema['options'] = [
        for (final (i, name) in [
          'Elderly Care',
          'Childcare',
          'Special Needs Care',
          'Post-Hospital Care',
        ].indexed)
          {'optionId': i + 12, 'code': 'CARE_$i', 'name': name, 'fields': []},
      ];
      f.schema.result = Success(parseProviderSchema(schema, 3));
      if (registered) {
        f.options.selections = Success(
          parseProviderOptions([
            selectedOptionJson(id: 12)
              ..['name'] = 'Elderly Care'
              ..['verificationStatus'] = 'APPROVED',
            selectedOptionJson(id: 15)
              ..['providerOptionId'] = 30
              ..['name'] = 'Post-Hospital Care',
          ]),
        );
      }
      await pump(tester, f, route: '/services/3');
      if (registered) {
        f.container
            .read(serviceDetailControllerProvider(3).notifier)
            .toggle(13);
      }
      await tester.runAsync(() async {
        final context = tester.element(find.text('Caregiving'));
        await precacheImage(
          const AssetImage('assets/service_detail/imgSupportiveHands.png'),
          context,
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Key Responsibilities'), findsOneWidget);
      expect(find.text('Childcare'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile(
          'goldens/service_detail_${registered ? 'registered' : 'new'}.png',
        ),
      );
      if (registered) {
        expect(find.text('Your Registered Sub-services'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Pending review'), findsOneWidget);
        expect(find.text('Incomplete'), findsOneWidget);
      } else {
        await tester.ensureVisible(find.text('Register for this Service'));
        await tester.tap(find.text('Register for this Service'));
        await tester.pumpAndSettle();
        expect(find.text('What service do you offer?'), findsOneWidget);
      }
      expect(f.services.submissions, 0);
      expect(f.options.saves, isEmpty);
    });
  }
}
