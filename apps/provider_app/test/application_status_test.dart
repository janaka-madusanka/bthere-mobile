import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/router/app_routes.dart';
import 'package:provider_app/features/home/presentation/provider_home_widgets.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';
import 'package:provider_app/features/onboarding/requirements/options/domain/provider_selected_option.dart';
import 'package:provider_app/features/services/application/application_status_controller.dart';
import 'package:provider_app/features/services/application/registration_draft.dart';
import 'package:provider_app/features/services/documents/document_models.dart';
import 'package:provider_app/features/services/documents/documents_controller.dart';
import 'package:provider_app/features/services/presentation/application_status_screen.dart';
import 'package:provider_app/features/services/presentation/registration_widgets.dart';

import 'service_first_test.dart'
    show ServiceFixture, pump, path, detail, completeServiceJson;
import 'support/fake_documents_repository.dart';
import 'support/fake_registration_repository.dart';
import 'support/fake_service_repository.dart';

void main() {
  setUpAll(() async {
    for (final (name, path) in [
      ('Nunito', 'Nunito.ttf'),
      ('HomeInter', 'Inter.ttf'),
      ('HomeLato', 'Lato-Regular.ttf'),
    ]) {
      await (FontLoader(
        name,
      )..addFont(rootBundle.load('assets/fonts/$path'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  void configure(ServiceFixture fixture, {bool rejected = false}) {
    fixture.completion.result = Success(
      parseProviderCompletion(
        completeServiceJson(verification: rejected ? 'REJECTED' : 'PENDING'),
      ),
    );
    fixture.services.assignments = Success([
      parseProviderServiceAssignment(
        assignmentJson()
          ..['verificationStatus'] = rejected ? 'REJECTED' : 'PENDING',
      ),
    ]);
    final documents =
        fixture.container.read(documentsRepositoryProvider) as FakeDocuments;
    documents.requirementsResult = const Success([
      DocumentRequirement(1, 'National ID card', null, false, true, true),
      DocumentRequirement(
        2,
        'Grama Niladhari Certificate',
        null,
        false,
        true,
        true,
      ),
      DocumentRequirement(3, 'Driving License', null, false, true, true),
      DocumentRequirement(
        9,
        'Unselected service document',
        null,
        false,
        true,
        true,
        optionId: 999,
      ),
    ]);
    documents.documentsResult = Success([
      ProviderDocument(
        71,
        1,
        rejected ? 'REJECTED' : 'PENDING',
        rejected ? 'Document is unclear. Upload clean images.' : null,
        null,
        key: 'providers/25/id.pdf',
      ),
      const ProviderDocument(
        72,
        2,
        'APPROVED',
        null,
        null,
        key: 'providers/25/certificate.pdf',
      ),
      ProviderDocument(
        73,
        3,
        rejected ? 'PENDING' : 'APPROVED',
        null,
        null,
        key: 'providers/25/licence.pdf',
      ),
    ]);
  }

  test('review items use server states, scope, reasons and confirmed reupload history', () async {
    final fixture = ServiceFixture(existing: true);
    configure(fixture, rejected: true);
    final uploads = fixture.container.read(
      registrationDraftStoreProvider,
    ) as MemoryRegistrationDrafts;
    await uploads.recordReviewUpload(3, 3, 'providers/25/licence.pdf');
    final result = await fixture.container.read(
      applicationStatusProvider(3).future,
    );
    expect(result, isA<Success<ApplicationStatusData>>());
    final data = (result as Success<ApplicationStatusData>).value;
    expect(data.rejected, isTrue);
    expect(
      data.items.any((item) => item.label == 'Unselected service document'),
      isFalse,
    );
    expect(
      data.items.first.reason,
      'Document is unclear. Upload clean images.',
    );
    expect(data.items.first.state, ApplicationItemState.rejected);
    expect(
      data.items.singleWhere((item) => item.id == 'document-3').state,
      ApplicationItemState.reuploaded,
    );
    expect(fixture.services.submissions, 0);
    expect(fixture.options.saves, isEmpty);
  });
  test(
    'unknown item states remain unavailable rather than appearing approved',
    () {
      expect(
        applicationItemState('UNRECOGNIZED'),
        ApplicationItemState.unknown,
      );
      expect(applicationItemState(null), ApplicationItemState.missing);
    },
  );
  test(
    'replacing a rejected document records the actual uploaded key',
    () async {
      final fixture = ServiceFixture(existing: true);
      configure(fixture, rejected: true);
      final provider = documentsControllerProvider(3);
      final keepAlive = fixture.container.listen(provider, (_, _) {});
      addTearDown(keepAlive.close);
      final controller = fixture.container.read(provider.notifier);
      await controller.load();
      controller.edit(
        const DocumentRequirement(
          1,
          'National ID card',
          null,
          false,
          true,
          true,
        ),
      );
      final draft = fixture.container.read(provider).draft!;
      draft.file = file();
      draft.issued = '2020-01-01';
      final repository =
          fixture.container.read(documentsRepositoryProvider) as FakeDocuments;
      repository.documentsResult = const Success([
        ProviderDocument(71, 1, 'PENDING', null, null, key: 'upload-key'),
      ]);
      await controller.submit();
      final history = await fixture.container
          .read(registrationDraftStoreProvider)
          .reviewUploads(3);
      expect(repository.uploads, 1);
      expect(repository.registrations.single.key, 'upload-key');
      expect(history['1'], 'upload-key');
      expect(fixture.services.submissions, 0);
    },
  );
  for (final aggregate in ['PENDING', 'APPROVED']) {
    for (final rejected in [false, true]) {
      testWidgets(
        'registered subservice ${rejected ? 'rejected' : 'pending'} badge opens its status page with $aggregate aggregate',
        (tester) async {
          tester.view.physicalSize = const Size(430, 932);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final fixture = ServiceFixture(existing: true);
          configure(fixture);
          fixture.completion.result = Success(
            parseProviderCompletion(
              completeServiceJson(verification: aggregate),
            ),
          );
          fixture.services.assignments = Success([
            parseProviderServiceAssignment(
              assignmentJson()..['verificationStatus'] = aggregate,
            ),
          ]);
          fixture.options.selections = Success([
            ProviderSelectedOption(
              providerOptionId: 112,
              optionId: 12,
              code: 'CARE',
              name: 'Home care',
              providerStatus: 'ACTIVE',
              adminStatus: 'ACTIVE',
              verificationStatus: rejected ? 'REJECTED' : 'PENDING',
            ),
          ]);
          await pump(tester, fixture, route: AppRoutes.serviceDetail(3));
          final row = find.byKey(const ValueKey('registered-option-12'));
          await tester.ensureVisible(row);
          await tester.tap(
            find.descendant(
              of: row,
              matching: find.text(rejected ? 'Rejected' : 'Pending review'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Application Status'), findsOneWidget);
          expect(
            find.text(
              rejected
                  ? 'Your application was not approved'
                  : 'Your application is Under Review',
            ),
            findsOneWidget,
          );
          expect(find.text('Service Details'), findsNothing);
          expect(find.text('View setup information'), findsNothing);
          expect(fixture.services.submissions, 0);
          expect(fixture.options.saves, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final rejected in [false, true]) {
    testWidgets(
      'home routes ${rejected ? 'rejected' : 'pending'} applications to status',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = ServiceFixture(existing: true);
        configure(fixture, rejected: rejected);
        await pump(tester, fixture, route: AppRoutes.home);
        final card = find.byType(HomeRegisteredService).first;
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.text('Application Status'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'catalog routes ${rejected ? 'rejected' : 'pending'} applications to the new page',
      (tester) async {
        final fixture = ServiceFixture(existing: true);
        configure(fixture, rejected: rejected);
        await pump(tester, fixture);
        await tester.ensureVisible(
          find.byKey(const ValueKey('main-service-3')),
        );
        await tester.tap(find.byKey(const ValueKey('main-service-3')));
        await tester.pumpAndSettle();
        expect(path(fixture), AppRoutes.serviceStatus(3));
        expect(find.text('Application Status'), findsOneWidget);
        expect(
          find.text(
            rejected
                ? 'Your application was not approved'
                : 'Your application is Under Review',
          ),
          findsOneWidget,
        );
        if (rejected) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('review-item-document-1')),
          );
          await tester.tap(
            find.byKey(const ValueKey('review-item-document-1')),
          );
          await tester.pumpAndSettle();
          expect(
            fixture.container
                .read(documentsControllerProvider(3))
                .draft
                ?.requirement
                .id,
            1,
          );
        } else {
          await tester.ensureVisible(find.text('Go to Home'));
          await tester.tap(find.text('Go to Home'));
          await tester.pumpAndSettle();
          expect(path(fixture), AppRoutes.home);
        }
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${rejected ? 'rejected' : 'pending'} application matches the status design',
      (tester) async {
        final fixture = ServiceFixture(existing: true);
        configure(fixture, rejected: rejected);
        final service = await detail(fixture);
        final completion =
            (fixture.completion.result as Success).value.services.single;
        final data = ApplicationStatusData(
          service: service,
          completion: completion,
          items: [
            ApplicationReviewItem(
              id: 'document-1',
              label: 'National ID card',
              kind: ApplicationItemKind.document,
              state: rejected
                  ? ApplicationItemState.rejected
                  : ApplicationItemState.pending,
              reason: rejected
                  ? 'Document is unclear. Upload clean images.'
                  : null,
            ),
            ApplicationReviewItem(
              id: 'document-2',
              label: 'Grama Niladhari Certificate',
              kind: ApplicationItemKind.certificate,
              state: rejected
                  ? ApplicationItemState.approved
                  : ApplicationItemState.pending,
            ),
            ApplicationReviewItem(
              id: 'document-3',
              label: 'Driving License',
              kind: ApplicationItemKind.document,
              state: rejected
                  ? ApplicationItemState.reuploaded
                  : ApplicationItemState.approved,
            ),
          ],
        );
        tester.view.physicalSize = Size(430, rejected ? 901 : 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: RegistrationPage(
              step: 1,
              title: 'Application Status',
              showProgress: false,
              contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
              onBack: () {},
              child: ApplicationStatusView(
                data: data,
                onItem: (_) {},
                onUpdate: () {},
                onHome: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile(
            'goldens/application_${rejected ? 'rejected' : 'review'}.png',
          ),
        );
        tester.view.physicalSize = const Size(320, 568);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text(rejected ? 'Update and Resubmit' : 'Go to Home').first,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'review load failure gives retry and never substitutes an empty successful list',
    (tester) async {
      final fixture = ServiceFixture(existing: true);
      configure(fixture);
      final documents =
          fixture.container.read(documentsRepositoryProvider) as FakeDocuments;
      documents.documentsResult = const Failure(
        AppFailure(message: 'Unavailable'),
      );
      await pump(tester, fixture, route: AppRoutes.serviceStatus(3));
      expect(find.text('Unable to load application status'), findsOneWidget);
      expect(find.text('Review in progress'), findsNothing);
      documents.documentsResult = const Success([]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Review in progress'), findsOneWidget);
    },
  );
}
