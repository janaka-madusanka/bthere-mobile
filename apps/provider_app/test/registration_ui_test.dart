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
  Map<String, dynamic> schema() {
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
          option: v.schema.options.first,
          service: v.service,
          setup: v.schema.serviceSetup,
          initial: {
            ...(draft()['options'] as Map)['12'] as Map<String, dynamic>,
            'availability': draft()['availability'],
          },
        ),
        'documents' => RegistrationPage(
          step: 3,
          onBack: () {},
          child: RegistrationDocuments(serviceTypeId: 3, onContinue: () {}),
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
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('goldens/registration_$name.png'),
      );
    });
  }
  testWidgets('new registration starts with service selection', (tester) async {
    final f = ServiceFixture();
    await pump(tester, f, route: '/services/register');
    expect(find.text('What service do you offer?'), findsOneWidget);
  });

  testWidgets('existing subservice resumes incomplete details', (tester) async {
    final f = ServiceFixture(existing: true);
    await pump(tester, f, route: '/services/3/register?optionId=12');
    expect(find.text('Service Details'), findsOneWidget);
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
      expect(f.services.submissions, 1);
      expect(f.options.saves.length, 1);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Review Your Service'), findsOneWidget);
      final repository = f.container.read(
        registrationRepositoryProvider,
      ) as FakeRegistrationRepository;
      repository.result = const Failure(
        AppFailure(message: 'Safe retryable failure'),
      );
      await tester.ensureVisible(find.text('Submit for Review'));
      await tester.tap(find.text('Submit for Review'));
      await tester.pumpAndSettle();
      expect(find.text('Review Your Service'), findsOneWidget);
      expect(find.text('Safe retryable failure'), findsOneWidget);
      repository.result = const Success(null);
      f.completion.result = Success(
        parseProviderCompletion(completeServiceJson()),
      );
      await tester.ensureVisible(find.text('Submit for Review'));
      await tester.tap(find.text('Submit for Review'));
      await tester.pumpAndSettle();
      expect(find.text('All Set!'), findsOneWidget);
      expect(find.text('Under Review'), findsOneWidget);
      expect(f.services.submissions, 1);
      expect(tester.takeException(), isNull);
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
