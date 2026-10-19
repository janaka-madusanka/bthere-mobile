import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';
import 'package:provider_app/features/onboarding/services/domain/provider_service_type.dart';
import 'package:provider_app/features/services/application/service_detail_controller.dart';
import 'package:provider_app/features/services/application/registration_draft.dart';
import 'package:provider_app/features/services/presentation/service_registration_screen.dart';
import 'package:provider_app/features/services/presentation/registration_widgets.dart';
import 'package:provider_app/features/services/presentation/registration_details.dart';
import 'package:provider_app/features/services/presentation/registration_documents.dart';
import 'package:provider_app/features/services/presentation/registration_option_editor.dart';
import 'package:provider_app/features/services/presentation/registration_review.dart';
import 'package:provider_app/features/services/documents/documents_controller.dart';
import 'package:provider_app/features/services/documents/document_models.dart';

import 'service_first_test.dart' show ServiceFixture, pump, completeServiceJson;

import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/services/data/registration_repository.dart';

import 'provider_options_test.dart' show optionsSchema;
import 'support/fake_schema_repository.dart';
import 'support/fake_registration_repository.dart';
import 'support/fake_service_repository.dart';
import 'support/fake_documents_repository.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('HomeInter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await inter.load();
    final nunito = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito.ttf'));
    await nunito.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  Map<String, dynamic> schema({bool subservice = false}) {
    final j = optionsSchema();
    j['serviceName'] = 'Caregiving';
    j['serviceSetup']['skills'] = [
      for (final (i, name) in [
        'Personal Care',
        'Mobility Assistance',
        'Dementia Care',
        'Meal Preparation',
        'Household Support',
        'Medication Support',
      ].indexed)
        {
          'skillId': i + 10,
          'name': name,
          'required': i < 2,
          'requiresApproval': true,
        },
    ];
    j['options'] = [
      for (final (i, name) in [
        'Elderly Care',
        'Childcare',
        'Special Needs Care',
        'Post-Hospital Care',
      ].indexed)
        {
          'optionId': i + 12,
          'name': name,
          'code': 'CARE_$i',
          if (subservice) 'description': 'Support for older adults',
          if (subservice) 'deliveryModes': ['PROVIDER_TO_CUSTOMER'],
          'fields': i == 0
              ? [
                  fieldJson(optionId: 12)
                    ..['fieldId'] = 20
                    ..['label'] = 'Years of Experience'
                    ..['fieldType'] = 'SELECT'
                    ..['options'] = ['1 – 2 years', '3 – 5 years'],
                  fieldJson(optionId: 12)
                    ..['fieldId'] = 21
                    ..['label'] = 'Describe your experience'
                    ..['fieldType'] = 'TEXTAREA',
                  fieldJson(optionId: 12)
                    ..['fieldId'] = 22
                    ..['label'] = 'Care for which age group?'
                    ..['fieldType'] = 'SELECT'
                    ..['options'] = ['Children', 'Adults', '60+ years'],
                  if (subservice)
                    fieldJson(optionId: 12)
                      ..['fieldId'] = 23
                      ..['label'] = 'Can you assist with medical needs?'
                      ..['fieldType'] = 'BOOLEAN',
                  if (subservice)
                    fieldJson(optionId: 12)
                      ..['fieldId'] = 24
                      ..['label'] = 'Any special conditions you can support?'
                      ..['fieldType'] = 'MULTI_SELECT'
                      ..['options'] = ['Dementia', 'Mobility Issues'],
                ]
              : [],
        },
    ];
    return j;
  }

  Map<String, dynamic> draft() => {
    ...readyRegistrationDraft(),
    'languages': ['ENGLISH', 'SINHALA'],
    'skills': ['Personal Care', 'Mobility Assistance', 'Meal Preparation'],
    'options': {
      '12': {
        'saved': true,
        'deliveryMode': 'PROVIDER_TO_CUSTOMER',
        'areas': [
          {
            'locationName': 'Colombo',
            'city': 'Colombo',
            'country': 'Sri Lanka',
            'latitude': 6.9271,
            'longitude': 79.8612,
            'radiusKm': 15,
            'capacity': 1,
          },
        ],
        'fields': {
          '20': '1 – 2 years',
          '21': 'I have experience providing daily care, mobility support and companionship for elderly clients.',
          '22': '60+ years',
        },
      },
      '15': {'saved': true, 'deliveryMode': 'ONLINE', 'areas': <Object>[]},
    },
  };
  ServiceDetailState state() => ServiceDetailState(
    service: parseActiveProviderServices([serviceJson(name: 'Caregiving')])
        .single,
    schema: parseProviderSchema(schema(), 3),
    selected: {12, 15},
    experience: '4.5',
  );
  Future<void> frame(
    WidgetTester tester,
    ServiceFixture f,
    Widget child,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: f.container,
        child: MaterialApp(home: child),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final name in [
    'selection',
    'details',
    'option',
    'documents',
    'review',
    'complete',
  ]) {
    testWidgets('registration $name matches Figma layout', (tester) async {
      final f = ServiceFixture();
      final v = state();
      final child = switch (name) {
        'selection' => RegistrationPage(
          step: 1,
          onBack: () {},
          child: RegistrationSelection(
            services: [
              for (final (i, label) in [
                'Caregiving',
                'Home Services',
                'Handyman',
                'Vehicle Services',
                'Wellness & Lifestyle',
                'Errands & Delivery',
                'Pet Care',
                'Childcare',
              ].indexed)
                ProviderServiceType(id: i + 1, name: label, status: 'ACTIVE'),
            ],
            registeredIds: {7, 8},
            selected: 1,
            onSelect: (_) {},
            onContinue: () {},
          ),
        ),
        'details' => RegistrationPage(
          step: 2,
          onBack: () {},
          child: RegistrationDetails(
            value: v,
            draft: draft(),
            onChange: () {},
            onSaveDraft: (_) async => true,
            onContinue: (_) async {},
          ),
        ),
        'option' => RegistrationOptionEditor(
          option: parseProviderSchema(
            schema(subservice: true),
            3,
          ).options.first,
          service: v.service,
          setup: v.schema.serviceSetup,
          initial: {
            ...(draft()['options'] as Map)['12'] as Map<String, dynamic>,
            'fields': {
              ...((draft()['options'] as Map)['12']['fields']
                  as Map<String, dynamic>),
              '23': true,
              '24': ['Dementia', 'Mobility Issues'],
            },
            'areas': [
              ...((draft()['options'] as Map)['12']['areas'] as List),
              {
                'locationName': 'Galle',
                'city': 'Galle',
                'country': 'Sri Lanka',
                'latitude': 6.0535,
                'longitude': 80.2210,
                'radiusKm': 8,
                'capacity': 1,
              },
            ],
            'availability': {
              'availableAnyDay': false,
              'availableAnyTime': true,
              'weeklySlots': [
                for (final day in [
                  'MONDAY',
                  'TUESDAY',
                  'WEDNESDAY',
                  'THURSDAY',
                  'FRIDAY',
                  'SUNDAY',
                ])
                  {'dayOfWeek': day, 'startTime': null, 'endTime': null},
              ],
            },
          },
        ),
        'documents' => RegistrationPage(
          step: 3,
          onBack: () {},
          child: RegistrationDocuments(
            serviceTypeId: 3,
            selectedOptionIds: const {12},
            onContinue: () {},
          ),
        ),
        'review' => RegistrationPage(
          step: 4,
          onBack: () {},
          child: RegistrationReview(
            value: v,
            draft: draft(),
            onEdit: (_) {},
            onSubmit: () {},
          ),
        ),
        _ => const RegistrationCompleteScreen(),
      };
      if (name == 'documents') {
        final repo =
            f.container.read(documentsRepositoryProvider) as FakeDocuments;
        repo.requirementsResult = const Success([
          DocumentRequirement(
            1,
            'Selfie',
            'A clear photo of your face.',
            false,
            true,
            true,
          ),
          DocumentRequirement(
            2,
            'Birth Certificate',
            'Upload a clear copy of your birth certificate.',
            false,
            false,
            true,
          ),
          DocumentRequirement(
            3,
            'Caregiver Certificate',
            'Upload your caregiver certificate.',
            false,
            true,
            true,
            optionId: 12,
          ),
        ]);
      }
      final size = Size(430, switch (name) {
        'selection' => 985,
        'details' => 1757,
        'option' => 1371,
        'documents' => 1120,
        _ => 932,
      });
      await frame(tester, f, child, size);
      if (name == 'documents') {
        final common = find.byWidgetPredicate(
          (widget) =>
              widget is RegistrationSection &&
              widget.title == 'Common Documents',
        );
        final specific = find.byWidgetPredicate(
          (widget) =>
              widget is RegistrationSection &&
              widget.title == 'Service Specific Documents',
        );
        expect(
          find.descendant(of: common, matching: find.text('Selfie')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: common,
            matching: find.text('Caregiver Certificate'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: specific,
            matching: find.text('Caregiver Certificate'),
          ),
          findsOneWidget,
        );
      }
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('goldens/registration_$name.png'),
      );
    });
  }
  testWidgets(
    'newly selected option on an existing assignment skips saved-location reads',
    (tester) async {
      final f = ServiceFixture();
      final repository = f.container.read(
        registrationRepositoryProvider,
      ) as FakeRegistrationRepository;
      repository.areasResult = const Failure(
        AppFailure(message: 'Option not registered'),
      );
      final data = draft();
      (data['options'] as Map)['15']['deliveryMode'] = 'PROVIDER_TO_CUSTOMER';
      await frame(
        tester,
        f,
        RegistrationPage(
          step: 2,
          onBack: () {},
          child: RegistrationDetails(
            value: state().copy(
              assignment: parseProviderServiceAssignment(assignmentJson()),
            ),
            draft: data,
            onChange: () {},
            onSaveDraft: (_) async => true,
            onContinue: (_) async {},
          ),
        ),
        const Size(430, 932),
      );
      final location = find.byKey(const ValueKey('option-15-Location & Area'));
      await tester.ensureVisible(location);
      await tester.tap(location);
      await tester.pumpAndSettle();
      final editor = tester.widget<RegistrationOptionEditor>(
        find.byType(RegistrationOptionEditor),
      );
      expect(editor.assignmentId, 14);
      expect(editor.asSheet, isTrue);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(RegistrationPage), findsOneWidget);
      expect(editor.loadSavedLocations, isFalse);
      expect(repository.areaLoads, isEmpty);
      expect(find.text('Retry loading locations'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('new registration starts with service selection', (tester) async {
    final f = ServiceFixture();
    await pump(tester, f, route: '/services/register');
    expect(find.text('What service do you offer?'), findsOneWidget);
  });
  testWidgets(
    'saved languages preselect the picker despite an old empty draft',
    (tester) async {
      final f = ServiceFixture(existing: true);
      final repository = f.container.read(
        registrationRepositoryProvider,
      ) as FakeRegistrationRepository;
      repository.server['languages'] = ['ENGLISH', 'SINHALA'];
      (f.container.read(
        registrationDraftStoreProvider,
      ) as MemoryRegistrationDrafts).drafts[3] = {
        'languages': [],
        '_step': 2,
      };
      await pump(tester, f, route: '/services/3/register?details=1');
      await tester.ensureVisible(find.text('English, Sinhala'));
      await tester.tap(find.text('English, Sinhala'));
      await tester.pumpAndSettle();
      CheckboxListTile language(String label) =>
          tester.widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, label),
          );
      expect(language('English').value, isTrue);
      expect(language('Sinhala').value, isTrue);
      expect(language('Tamil').value, isFalse);
      expect(repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'language selection follows newly loaded parent data and persists edits',
    (tester) async {
      final f = ServiceFixture();
      var incoming = <String, dynamic>{'languages': <String>[]};
      late StateSetter update;
      Map<String, dynamic>? saved;
      await frame(
        tester,
        f,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return RegistrationPage(
              step: 2,
              onBack: () {},
              child: RegistrationDetails(
                value: state(),
                draft: incoming,
                onChange: () {},
                onSaveDraft: (value) async {
                  saved = value;
                  return true;
                },
                onContinue: (_) async {},
              ),
            );
          },
        ),
        const Size(430, 932),
      );
      update(
        () => incoming = {
          'languages': [' english ', 'sinhala'],
        },
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('English, Sinhala'));
      await tester.tap(find.text('English, Sinhala'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'English'),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Tamil'));
      await tester.tap(find.text('Save Languages'));
      await tester.pumpAndSettle();
      expect(saved?['languages'], ['ENGLISH', 'SINHALA', 'TAMIL']);
      expect(saved?['_languagesEdited'], isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unsaved valid step 2 draft stays on details after reopening', (
    tester,
  ) async {
    final f = ServiceFixture(existing: true);
    final data = optionsSchema();
    data['serviceSetup']['certificates']['level'] = 'DISABLED';
    data['serviceSetup']['education']['level'] = 'DISABLED';
    f.schema.result = Success(parseProviderSchema(data, 3));
    (f.container.read(
      registrationDraftStoreProvider,
    ) as MemoryRegistrationDrafts).drafts[3] = {
      ...readyRegistrationDraft(),
      '_step': 2,
    };
    await pump(tester, f, route: '/services/3/register');
    expect(find.text('Service Details'), findsOneWidget);
    expect(find.text('Upload Required Documents'), findsNothing);
    expect(find.text('Review Your Service'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing subservice resumes incomplete details', (tester) async {
    final f = ServiceFixture(existing: true);
    await pump(tester, f, route: '/services/3/register?optionId=12');
    expect(find.text('Service Details'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('What service do you offer?'), findsNothing);
  });

  testWidgets('adding a subservice opens details despite saved progress', (
    tester,
  ) async {
    final f = ServiceFixture(existing: true);
    (f.container.read(
      registrationDraftStoreProvider,
    ) as MemoryRegistrationDrafts).drafts[3] = {
      ...readyRegistrationDraft(),
      '_step': 4,
    };
    await pump(tester, f, route: '/services/3/register?optionId=12&details=1');
    expect(find.text('Service Details'), findsOneWidget);
  });

  testWidgets(
    'unregistered subservice opens its editor and back returns to overview',
    (tester) async {
      final f = ServiceFixture(existing: true);
      await pump(tester, f, route: '/services/3');
      await tester.ensureVisible(find.text('Work type 13'));
      await tester.tap(find.text('Work type 13'));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrationOptionEditor), findsOneWidget);
      expect(find.text('Save Work type 13 Details'), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.byType(RegistrationDetails), findsNothing);
      expect(
        f.container.read(serviceDetailControllerProvider(3)).asData!.value
            is Success<ServiceDetailState>,
        isTrue,
      );
      final editor = tester.widget<RegistrationOptionEditor>(
        find.byType(RegistrationOptionEditor),
      );
      expect(editor.option.optionId, 13);
      expect(editor.loadSavedLocations, isFalse);
      editor.onBack!();
      await tester.pumpAndSettle();
      expect(find.byType(RegistrationOptionEditor), findsNothing);
      expect(find.text('Your Registered Sub-services'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'direct subservice save preserves shared details and advances to documents',
    (tester) async {
      final f = ServiceFixture(existing: true);
      final data = optionsSchema();
      data['serviceSetup']['certificates']['level'] = 'DISABLED';
      data['serviceSetup']['education']['level'] = 'DISABLED';
      f.schema.result = Success(parseProviderSchema(data, 3));
      final original = readyRegistrationDraft();
      final store = f.container.read(
        registrationDraftStoreProvider,
      ) as MemoryRegistrationDrafts;
      store.drafts[3] = original;
      await pump(
        tester,
        f,
        route: '/services/3/register?optionId=13&details=1',
      );
      final editor = tester.widget<RegistrationOptionEditor>(
        find.byType(RegistrationOptionEditor),
      );
      await editor.onSave!({
        'saved': true,
        'fields': <String, dynamic>{},
        'deliveryMode': 'ONLINE',
        'areas': <Object>[],
        'availability': original['availability'],
      });
      await tester.pumpAndSettle();
      expect(find.text('Upload Required Documents'), findsOneWidget);
      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(find.byType(RegistrationDetails), findsNothing);
      expect(store.drafts[3]!['languages'], original['languages']);
      expect(
        (store.drafts[3]!['options'] as Map)['12'],
        (original['options'] as Map)['12'],
      );
      expect((store.drafts[3]!['options'] as Map)['13']['saved'], isTrue);
      expect(f.options.saves.last.ids, containsAll([12, 13]));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registration saves supported sections, advances only after success, and retains retry state',
    (tester) async {
      final f = ServiceFixture();
      (f.container.read(
        registrationDraftStoreProvider,
      ) as MemoryRegistrationDrafts).drafts[3] = readyRegistrationDraft();
      final j = optionsSchema();
      j['serviceSetup']['certificates']['level'] = 'DISABLED';
      j['serviceSetup']['education']['level'] = 'DISABLED';
      f.schema.result = Success(parseProviderSchema(j, 3));
      await pump(tester, f, route: '/services/3/register');
      expect(find.text('Service Details'), findsOneWidget);
      f.container.read(serviceDetailControllerProvider(3).notifier).toggle(12);
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '4.5');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Upload Required Documents'), findsOneWidget);
      expect(
        (f.container.read(
          registrationDraftStoreProvider,
        ) as MemoryRegistrationDrafts).drafts[3]?['_step'],
        3,
      );
      expect(f.services.submissions, 1);
      expect(f.options.saves.length, 1);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Review Your Service'), findsOneWidget);
      final repository = f.container.read(
        registrationRepositoryProvider,
      ) as FakeRegistrationRepository;
      final savedWrites = List<String>.of(repository.writes);
      repository.loadFailure = const AppFailure(
        message: 'Safe retryable failure',
      );
      // A final review must not replay the already successful Step 2 writes.
      repository.result = const Failure(
        AppFailure(message: 'Duplicate replacement failed'),
      );
      await tester.ensureVisible(find.text('Submit for Review'));
      await tester.tap(find.text('Submit for Review'));
      await tester.pumpAndSettle();
      expect(find.text('Review Your Service'), findsOneWidget);
      expect(find.text('Safe retryable failure'), findsOneWidget);
      repository.loadFailure = null;
      f.completion.result = Success(
        parseProviderCompletion(completeServiceJson()),
      );
      await tester.ensureVisible(find.text('Submit for Review'));
      await tester.tap(find.text('Submit for Review'));
      await tester.pumpAndSettle();
      expect(find.text('All Set!'), findsOneWidget);
      expect(find.text('Under Review'), findsOneWidget);
      expect(f.services.submissions, 1);
      expect(repository.writes, savedWrites);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('step 2 derives progress from answers rather than saved flags', (
    tester,
  ) async {
    final f = ServiceFixture();
    final data = draft();
    (data['options'] as Map)['12'] = {
      'saved': true,
      'deliveryMode': 'PROVIDER_TO_CUSTOMER',
      'areas': <Object>[],
      'fields': <String, dynamic>{},
    };
    await frame(
      tester,
      f,
      RegistrationPage(
        step: 2,
        onBack: () {},
        child: RegistrationDetails(
          value: state(),
          draft: data,
          onChange: () {},
          onSaveDraft: (_) async => true,
          onContinue: (_) async {},
        ),
      ),
      const Size(430, 1757),
    );
    expect(find.text('2 selected'), findsOneWidget);
    final experience = find.byKey(const ValueKey('option-12-Experience'));
    final location = find.byKey(const ValueKey('option-12-Location & Area'));
    expect(
      find.descendant(of: experience, matching: find.text('Not added')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: location, matching: find.text('Not added')),
      findsOneWidget,
    );
    expect(find.text('Incomplete'), findsOneWidget);
    expect(find.text('3 of 6 selected'), findsNWidgets(2));
    await tester.ensureVisible(find.byTooltip('Collapse Elderly Care'));
    await tester.tap(find.byTooltip('Collapse Elderly Care'));
    await tester.pumpAndSettle();
    expect(experience, findsNothing);
    expect(find.byTooltip('Expand Elderly Care'), findsOneWidget);
  });

  testWidgets(
    'step 2 renders API skill IDs independently for duplicate names',
    (tester) async {
      final f = ServiceFixture();
      final data = schema();
      data['serviceSetup']['skills'] = [
        {'skillId': 501, 'name': 'Shared label', 'required': false},
        {'skillId': 502, 'name': 'Shared label', 'required': false},
      ];
      Map<String, dynamic>? saved;
      final v = state();
      await frame(
        tester,
        f,
        RegistrationPage(
          step: 2,
          onBack: () {},
          child: RegistrationDetails(
            value: ServiceDetailState(
              service: v.service,
              schema: parseProviderSchema(data, 3),
              selected: {12},
              experience: '4.5',
            ),
            draft: {...draft(), 'skillIds': <int>[], 'skills': <String>[]},
            onChange: () {},
            onSaveDraft: (value) async {
              saved = value;
              return true;
            },
            onContinue: (_) async {},
          ),
        ),
        const Size(430, 1757),
      );
      final first = find.byKey(const ValueKey('skill-501'));
      final second = find.byKey(const ValueKey('skill-502'));
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(first).value, isTrue);
      expect(tester.widget<CheckboxListTile>(second).value, isFalse);
      expect(saved?['skillIds'], [501]);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'registration remains scrollable at 320px and text scale $scale',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final f = ServiceFixture();
        await frame(
          tester,
          f,
          RegistrationPage(
            step: 2,
            onBack: () {},
            child: RegistrationDetails(
              value: state(),
              draft: draft(),
              onChange: () {},
              onSaveDraft: (_) async => true,
              onContinue: (_) async {},
            ),
          ),
          const Size(320, 568),
        );
        await tester.ensureVisible(find.text('Continue'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
