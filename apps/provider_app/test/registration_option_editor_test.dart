import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/onboarding/requirements/domain/provider_onboarding_schema.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_type.dart';
import 'package:provider_app/features/services/presentation/registration_option_editor.dart';

import 'support/fake_schema_repository.dart';

void main() {
  testWidgets(
    'changing a weekday preserves the saved times of other weekdays',
    (tester) async {
      Map<String, dynamic>? saved;
      final data = schemaJson();
      data['serviceSetup']['serviceAreasEnabled'] = false;
      final setup = parseProviderSchema(data, 3).serviceSetup;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Edit option'),
                  onPressed: () async {
                    saved = await Navigator.of(context)
                        .push<Map<String, dynamic>>(
                          MaterialPageRoute(
                            builder: (_) => RegistrationOptionEditor(
                              option: ProviderSchemaOption(
                                optionId: 12,
                                code: 'CARE',
                                name: 'Care',
                                fields: [],
                              ),
                              service: const ProviderServiceType(
                                id: 3,
                                name: 'Care',
                                status: 'ACTIVE',
                              ),
                              setup: setup,
                              initial: {
                                'availability': {
                                  'availableAnyDay': false,
                                  'availableAnyTime': false,
                                  'weeklySlots': [
                                    {
                                      'dayOfWeek': 'MONDAY',
                                      'startTime': '08:00:00',
                                      'endTime': '12:00:00',
                                    },
                                    {
                                      'dayOfWeek': 'TUESDAY',
                                      'startTime': '14:00:00',
                                      'endTime': '18:00:00',
                                    },
                                  ],
                                },
                              },
                            ),
                          ),
                        );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit option'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wed'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Care Details'));
      await tester.tap(find.text('Save Care Details'));
      await tester.pumpAndSettle();
      final slots = saved?['availability']['weeklySlots'] as List;
      expect(slots.where((slot) => slot['dayOfWeek'] == 'MONDAY').single, {
        'dayOfWeek': 'MONDAY',
        'startTime': '08:00:00',
        'endTime': '12:00:00',
      });
      expect(slots.where((slot) => slot['dayOfWeek'] == 'TUESDAY').single, {
        'dayOfWeek': 'TUESDAY',
        'startTime': '14:00:00',
        'endTime': '18:00:00',
      });
      expect(slots.map((slot) => slot['dayOfWeek']), [
        'MONDAY',
        'TUESDAY',
        'WEDNESDAY',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}
