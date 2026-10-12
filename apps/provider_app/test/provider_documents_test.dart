import 'support/fake_documents_repository.dart';
import 'support/completed_entry_gate.dart';

import 'package:provider_app/features/onboarding/application/provider_entry_gate.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/app.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/app/router/app_router.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/services/application/service_setup_controller.dart';
import 'package:provider_app/features/services/documents/document_models.dart';
import 'package:provider_app/features/services/documents/documents_controller.dart';
import 'package:provider_app/features/services/documents/documents_repository.dart';
import 'package:provider_app/features/services/documents/documents_screen.dart';

import 'service_first_test.dart' show ServiceFixture;
import 'support/fake_session_storage.dart';

class DocumentAdapter implements HttpClientAdapter {
  Object? body;
  int status = 200;
  bool failure = false;
  RequestOptions? request;
  String? multipart;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    request = options;
    if (failure) throw StateError('private transport details');
    if (stream != null) {
      multipart = utf8.decode(
        await stream.expand((bytes) => bytes).toList(),
        allowMalformed: true,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class DocumentsFixture {
  final service = ServiceFixture(existing: true);
  final repo = FakeDocuments();
  final picker = FakePicker();
  late final ProviderContainer container = ProviderContainer(
    overrides: [
      providerEntryGateProvider.overrideWith(CompletedEntryGate.new),
      appConfigProvider.overrideWithValue(
        service.container.read(appConfigProvider),
      ),
      clockProvider.overrideWithValue(() => testNow),
      sessionStorageProvider.overrideWithValue(service.storage),
      providerServiceRepositoryProvider.overrideWithValue(service.services),
      providerSchemaRepositoryProvider.overrideWithValue(service.schema),
      providerOptionsRepositoryProvider.overrideWithValue(service.options),
      providerCompletionRepositoryProvider.overrideWithValue(
        service.completion,
      ),
      apiClientProvider.overrideWith(
        (_) => throw StateError('No live backend'),
      ),
      documentsRepositoryProvider.overrideWithValue(repo),
      documentPickerProvider.overrideWithValue(picker),
    ],
  );
  DocumentsFixture() {
    addTearDown(() => container.dispose());
  }
  Future<DocumentsController> controller() async {
    final sub = container.listen(documentsControllerProvider(3), (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    return container.read(documentsControllerProvider(3).notifier);
  }

  Future<void> pump(WidgetTester tester, {bool route = false}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: route
            ? const BThereProviderApp()
            : const MaterialApp(
                home: DocumentsContent(
                  serviceTypeId: 3,
                  serviceName: 'Caregiver',
                ),
              ),
      ),
    );
    await tester.pumpAndSettle();
    if (route) {
      container.read(appRouterProvider).go('/services/3/setup/documents');
      await tester.pumpAndSettle();
    }
  }
}

Future<void> draft(DocumentsController c, {DocumentRequirement? type}) async {
  c.edit(type ?? requirement);
  await c.pick();
  c.state.draft!.number = '123';
  c.state.draft!.issued = '2020-01-01';
  c.state.draft!.expiry = '2031-01-01';
}

void main() {
  test('requirements parse required optional expiry approval and empty', () {
    final items = parseRequirements([
      requirementJson(),
      requirementJson(id: 2, required: false, expiry: true, approval: false),
    ]);
    expect(items[0].required, isTrue);
    expect(items[1].required, isFalse);
    expect(items[1].hasExpiry, isTrue);
    expect(items[1].requiresApproval, isFalse);
    expect(parseRequirements([]), isEmpty);
  });
  for (final bad in [
    null,
    {},
    [requirementJson()..['required'] = 'true'],
    [requirementJson()..['documentTypeId'] = 0],
    [requirementJson(), requirementJson()],
  ]) {
    test(
      'malformed requirements safely rejected $bad',
      () => expect(() => parseRequirements(bad), throwsFormatException),
    );
  }
  test('confirmed document fields and null review metadata parse', () {
    final d = parseDocuments([documentJson()]).single;
    expect(d.id, 70);
    expect(d.typeId, 1);
    expect(d.name, 'National Identity Card');
    expect(d.number, '200012345678');
    expect(d.issuedDate, '2020-01-01');
    expect(d.createdAt, DateTime(2026, 10, 9, 10));
    expect(d.rejectionReason, isNull);
    expect(d.expiryDate, isNull);
  });
  for (final status in ['PENDING', 'APPROVED', 'REJECTED']) {
    test('shared document state $status matches type not service', () {
      final state = DocumentsState()
        ..documents = parseDocuments([documentJson(status: status)]);
      final d = state.match(1, testNow)!;
      expect(
        d.status(testNow),
        {
          'PENDING': 'Pending approval',
          'APPROVED': 'Approved',
          'REJECTED': 'Rejected',
        }[status],
      );
      expect(state.match(9, testNow), isNull);
      if (status == 'REJECTED') expect(d.rejectionReason, 'Unreadable scan');
    });
  }
  test('expiry day remains valid then expires, approved preferred across duplicates', () {
    final expired = parseDocuments([
      documentJson(status: 'APPROVED', expiry: '2029-01-01'),
    ]).single;
    expect(expired.status(testNow), 'Expired');
    final today = parseDocuments([
      documentJson(status: 'APPROVED', expiry: '2030-01-02'),
    ]).single;
    expect(today.status(testNow), 'Approved');
    final state = DocumentsState()..documents = [expired, today];
    expect(state.match(1, testNow), same(today));
  });
  for (final extension in documentExtensions) {
    test(
      'allowed $extension file',
      () => expect(
        file(name: 'scan.${extension.toUpperCase()}').validation,
        isNull,
      ),
    );
  }
  for (final value in [
    file(name: 'scan.exe'),
    file(size: maximumDocumentBytes + 1),
    file(size: 0),
  ]) {
    test(
      'invalid file ${value.name} ${value.size}',
      () => expect(value.validation, isNotNull),
    );
  }
  test(
    '100 MB boundary accepted',
    () => expect(file(size: maximumDocumentBytes).validation, isNull),
  );
  late DocumentAdapter adapter;
  late ApiDocumentsRepository api;
  setUp(() {
    adapter = DocumentAdapter();
    final client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      tokenProvider: SessionAccessTokenProvider(
        FakeSessionStorage()..session = testSession(),
        now: () => testNow,
      ),
      adapter: adapter,
    );
    api = ApiDocumentsRepository(client);
    addTearDown(() => client.close());
  });
  void authenticated(String method, String path) {
    expect(adapter.request!.method, method);
    expect(adapter.request!.path, path);
    expect(adapter.request!.extra['bthere.network.requires_auth'], isTrue);
    expect(adapter.request!.headers['Authorization'], startsWith('Bearer '));
  }

  test('requirements exact selected-service path and authentication', () async {
    adapter.body = [requirementJson()];
    expect(
      await api.requirements(9),
      isA<Success<List<DocumentRequirement>>>(),
    );
    authenticated('GET', '/provider-types/9/document-requirements');
  });
  test(
    'existing documents exact provider-level path and authentication',
    () async {
      adapter.body = [documentJson()];
      expect(await api.documents(), isA<Success<List<ProviderDocument>>>());
      authenticated('GET', '/providers/me/documents');
    },
  );
  test('network and malformed errors are safe failures', () async {
    adapter.failure = true;
    expect(
      await api.requirements(3),
      isA<Failure<List<DocumentRequirement>>>(),
    );
    adapter.failure = false;
    adapter.body = {};
    expect(await api.documents(), isA<Failure<List<ProviderDocument>>>());
  });
  test('multipart file field exact endpoint progress and upload key', () async {
    adapter.body = {
      'key': 'storage-key',
      'url': 'https://example.invalid/file',
      'contentType': 'application/pdf',
      'size': 3,
    };
    final progress = <int>[];
    final result = await api.upload(
      file(),
      (sent, total) => progress.add(sent),
    );
    authenticated('POST', '/uploads/documents');
    expect(adapter.request!.contentType, startsWith('multipart/form-data'));
    expect(adapter.multipart, contains('name="file"'));
    expect(adapter.multipart, contains('filename="scan.pdf"'));
    expect((result as Success<DocumentUpload>).value.key, 'storage-key');
    expect(progress, isNotEmpty);
  });
  test(
    'registration exact six keys uses key not URL and accepts 201',
    () async {
      adapter.status = 201;
      adapter.body = documentJson();
      final input = DocumentRegistration(
        typeId: 1,
        name: 'National ID',
        number: '123',
        key: 'upload-key',
        issuedDate: '2020-01-01',
        expiryDate: null,
      );
      expect(await api.register(input), isA<Success<void>>());
      authenticated('POST', '/providers/me/documents');
      expect(adapter.request!.data, {
        'documentTypeId': 1,
        'documentName': 'National ID',
        'documentNumber': '123',
        'documentKey': 'upload-key',
        'issuedDate': '2020-01-01',
        'expiryDate': null,
      });
    },
  );
  test('delete exact path and approved guard before network', () async {
    adapter.status = 204;
    expect(
      await api.delete(parseDocuments([documentJson()]).single),
      isA<Success<void>>(),
    );
    authenticated('DELETE', '/providers/me/documents/70');
    adapter.request = null;
    expect(
      await api.delete(
        parseDocuments([documentJson(status: 'APPROVED')]).single,
      ),
      isA<Failure<void>>(),
    );
    expect(adapter.request, isNull);
  });
  test(
    'registration retry retains key metadata and does not re-upload',
    () async {
      final f = DocumentsFixture();
      final c = await f.controller();
      await draft(c);
      f.repo.registerResult = const Failure(
        AppFailure(message: 'private error'),
      );
      await c.submit();
      expect(c.state.draft!.upload!.key, 'upload-key');
      expect(c.state.draft!.number, '123');
      f.repo.registerResult = const Success(null);
      await c.submit();
      expect(f.repo.uploads, 1);
      expect(f.repo.registrations.length, 2);
      expect(f.repo.registrations.map((r) => r.key), [
        'upload-key',
        'upload-key',
      ]);
      expect(c.state.draft, isNull);
      expect(f.repo.documentCalls, 2);
      expect(f.service.storage.writes, 0);
    },
  );
  for (final expiry in [false, true]) {
    test('registration expiry contract $expiry', () async {
      final f = DocumentsFixture();
      final c = await f.controller();
      await draft(
        c,
        type: parseRequirements([requirementJson(expiry: expiry)]).single,
      );
      await c.submit();
      expect(
        f.repo.registrations.single.expiryDate,
        expiry ? '2031-01-01' : null,
      );
    });
  }
  test('duplicate submit blocked during pending registration', () async {
    final f = DocumentsFixture();
    final c = await f.controller();
    await draft(c);
    f.repo.pending = Completer();
    final first = c.submit();
    await Future<void>.delayed(Duration.zero);
    await c.submit();
    expect(f.repo.uploads, 1);
    expect(f.repo.registrations.length, 1);
    f.repo.pending!.complete(const Success(null));
    await first;
  });
  test(
    'upload failure leaves draft and no registration, retry uploads',
    () async {
      final f = DocumentsFixture();
      final c = await f.controller();
      await draft(c);
      f.repo.uploadResult = const Failure(AppFailure(message: 'secret'));
      await c.submit();
      expect(f.repo.registrations, isEmpty);
      expect(c.state.draft!.number, '123');
      expect(c.state.operationError, isNot(contains('secret')));
      f.repo.uploadResult = const Success(
        DocumentUpload('new-key', 'url', 'application/pdf', 3),
      );
      await c.submit();
      expect(f.repo.uploads, 2);
    },
  );
  test(
    'picker cancellation and invalid files preserve selected upload key',
    () async {
      final f = DocumentsFixture();
      final c = await f.controller();
      await draft(c);
      c.state.draft!.upload = const DocumentUpload(
        'old-key',
        'url',
        'application/pdf',
        3,
      );
      f.picker.selected = null;
      await c.pick();
      expect(c.state.draft!.upload!.key, 'old-key');
      f.picker.selected = file(name: 'bad.exe');
      await c.pick();
      expect(c.state.draft!.upload!.key, 'old-key');
      f.picker.selected = file(name: 'new.png');
      await c.pick();
      expect(c.state.draft!.upload, isNull);
    },
  );
  test('approved cannot be edited or deleted; rejected replacement needs no delete', () async {
    final f = DocumentsFixture();
    f.repo.documentsResult = Success(
      parseDocuments([documentJson(status: 'APPROVED')]),
    );
    final c = await f.controller();
    c.edit(requirement);
    expect(c.state.draft, isNull);
    await c.delete(c.state.documents!.single);
    expect(f.repo.deletes, 0);
    f.repo.documentsResult = Success(
      parseDocuments([documentJson(status: 'REJECTED')]),
    );
    await c.load();
    c.edit(requirement);
    expect(c.state.draft!.number, '200012345678');
    await c.pick();
    await c.submit();
    expect(f.repo.deletes, 0);
  });
  test('delete failure safe, retry reloads documents and completion', () async {
    final f = DocumentsFixture();
    f.repo.documentsResult = Success(parseDocuments([documentJson()]));
    final c = await f.controller();
    f.repo.deleteResult = const Failure(AppFailure(message: 'secret'));
    await c.delete(c.state.documents!.single);
    expect(c.state.operationError, isNotNull);
    expect(f.repo.documentCalls, 1);
    f.repo.deleteResult = const Success(null);
    await c.delete(c.state.documents!.single);
    expect(f.repo.documentCalls, 2);
  });
  for (final status in ['PENDING', 'APPROVED', 'REJECTED']) {
    testWidgets('document cards present $status and shared labels', (
      tester,
    ) async {
      final f = DocumentsFixture();
      f.repo.documentsResult = Success(
        parseDocuments([documentJson(status: status)]),
      );
      f.repo.requirementsResult = Success(
        parseRequirements([
          requirementJson(),
          requirementJson(id: 2, required: false),
        ]),
      );
      await f.pump(tester);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Optional'), findsOneWidget);
      expect(
        find.text(
          'Status: ${{'PENDING': 'Pending approval', 'APPROVED': 'Approved', 'REJECTED': 'Rejected'}[status]}',
        ),
        findsOneWidget,
      );
      if (status == 'APPROVED') {
        expect(find.text('Delete document'), findsNothing);
        expect(find.text('Replace document'), findsNothing);
      }
      if (status == 'REJECTED') {
        expect(find.text('Unreadable scan'), findsOneWidget);
      }
      expect(find.text('Caregiver Documents'), findsOneWidget);
    });
  }
  testWidgets('separate loading states', (tester) async {
    final f = DocumentsFixture();
    f.repo.pendingRequirements = Completer();
    f.repo.pendingDocuments = Completer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: f.container,
        child: const MaterialApp(
          home: DocumentsContent(serviceTypeId: 3, serviceName: 'Caregiver'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Loading document requirements'), findsOneWidget);
    expect(find.text('Loading your documents'), findsOneWidget);
    f.repo.pendingRequirements!.complete(const Success([]));
    f.repo.pendingDocuments!.complete(const Success([]));
    await tester.pumpAndSettle();
    expect(
      find.text('No documents are required for this service.'),
      findsOneWidget,
    );
  });
  testWidgets('error retry and metadata form no expiry when not required', (
    tester,
  ) async {
    final f = DocumentsFixture();
    f.repo.requirementsResult = const Failure(AppFailure(message: 'secret'));
    await f.pump(tester);
    expect(find.text('Retry refresh'), findsOneWidget);
    f.repo.requirementsResult = Success([requirement]);
    await tester.ensureVisible(find.text('Retry refresh'));
    await tester.tap(find.text('Retry refresh'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Upload document'));
    await tester.tap(find.text('Upload document'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Document name'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Expiry date (YYYY-MM-DD)'),
      findsNothing,
    );
  });
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('responsive scrollable documents ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = DocumentsFixture();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: f.container,
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const DocumentsContent(
                serviceTypeId: 3,
                serviceName: 'Caregiver',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'invalid document dates and malformed upload do not produce success',
    () async {
      expect(
        () => parseDocuments([documentJson(expiry: '2030-02-30')]),
        throwsFormatException,
      );
      expect(
        () => parseDocuments([documentJson()..['documentId'] = null]),
        throwsFormatException,
      );
      expect(
        () => parseUpload({
          'url': 'https://example.invalid/file',
          'contentType': 'application/pdf',
          'size': 3,
        }),
        throwsFormatException,
      );
      adapter.body = {};
      expect(
        await api.upload(file(), (_, _) {}),
        isA<Failure<DocumentUpload>>(),
      );
    },
  );
  test(
    'empty requirements and transport failure preserve repository contract',
    () async {
      adapter.body = [];
      expect(
        (await api.requirements(3) as Success<List<DocumentRequirement>>).value,
        isEmpty,
      );
      adapter.failure = true;
      expect(await api.documents(), isA<Failure<List<ProviderDocument>>>());
      expect(
        await api.upload(file(), (_, _) {}),
        isA<Failure<DocumentUpload>>(),
      );
    },
  );
  test('unsupported and oversized uploads rejected before transport', () async {
    for (final f in [
      file(name: 'bad.exe'),
      file(size: maximumDocumentBytes + 1),
    ]) {
      expect(await api.upload(f, (_, _) {}), isA<Failure<DocumentUpload>>());
      expect(adapter.request, isNull);
    }
  });
  test(
    'rejected delete and supplied expiry exact transport requests',
    () async {
      adapter.status = 204;
      await api.delete(
        parseDocuments([documentJson(status: 'REJECTED')]).single,
      );
      authenticated('DELETE', '/providers/me/documents/70');
      adapter.status = 201;
      await api.register(
        const DocumentRegistration(
          typeId: 9,
          name: 'Licence',
          number: '',
          key: 'key',
          issuedDate: '2020-01-01',
          expiryDate: '2031-01-01',
        ),
      );
      expect((adapter.request!.data as Map)['expiryDate'], '2031-01-01');
      expect((adapter.request!.data as Map)['documentTypeId'], 9);
    },
  );
  test(
    'successful registration refresh failure cannot resubmit same draft',
    () async {
      final f = DocumentsFixture();
      final c = await f.controller();
      await draft(c);
      f.repo.documentsResult = const Failure(AppFailure(message: 'secret'));
      await c.submit();
      await c.submit();
      expect(f.repo.registrations.length, 1);
      expect(c.state.draft, isNull);
      expect(c.state.documentsError, contains('saved'));
      expect(c.state.busy, isFalse);
    },
  );
  test('picker exceptions safe and missing dates do not upload', () async {
    final f = DocumentsFixture();
    final c = await f.controller();
    c.edit(requirement);
    f.picker.throws = true;
    await c.pick();
    expect(c.state.operationError, isNot(contains('private')));
    expect(c.state.busy, isFalse);
    f.picker.throws = false;
    await c.pick();
    c.state.draft!.issued = '2020-02-30';
    await c.submit();
    expect(f.repo.uploads, 0);
  });
  testWidgets(
    'registration failure preserves visible form metadata and retained key',
    (tester) async {
      final f = DocumentsFixture();
      await f.pump(tester);
      final c = f.container.read(documentsControllerProvider(3).notifier);
      await tester.ensureVisible(find.text('Upload document'));
      await tester.tap(find.text('Upload document'));
      await tester.pumpAndSettle();
      await c.pick();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Document number'),
        'My number',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Issued date (YYYY-MM-DD)'),
        '2020-01-01',
      );
      f.repo.registerResult = const Failure(AppFailure(message: 'secret'));
      await c.submit();
      await tester.pumpAndSettle();
      expect(
        tester
                .widget<TextFormField>(
                  find.widgetWithText(TextFormField, 'Document number'),
                )
                .controller
                ?.text ??
            c.state.draft!.number,
        'My number',
      );
      expect(find.text('Retry registration'), findsOneWidget);
      expect(c.state.draft!.upload!.key, 'upload-key');
      f.repo.registerResult = const Success(null);
      await c.submit();
      await tester.pumpAndSettle();
      expect(f.repo.uploads, 1);
    },
  );
  testWidgets('expiry input follows backend requirement', (tester) async {
    final f = DocumentsFixture();
    f.repo.requirementsResult = Success(
      parseRequirements([requirementJson(expiry: true)]),
    );
    await f.pump(tester);
    await tester.ensureVisible(find.text('Upload document'));
    await tester.tap(find.text('Upload document'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextFormField, 'Expiry date (YYYY-MM-DD)'),
      findsOneWidget,
    );
  });
  testWidgets('delete confirmation cancellation then success refresh', (
    tester,
  ) async {
    final f = DocumentsFixture();
    f.repo.documentsResult = Success(parseDocuments([documentJson()]));
    await f.pump(tester);
    await tester.ensureVisible(find.text('Delete document'));
    await tester.tap(find.text('Delete document'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(f.repo.deletes, 0);
    await tester.tap(find.text('Delete document'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(f.repo.deletes, 1);
    expect(f.repo.documentCalls, 2);
  });
  testWidgets(
    'service-scoped route back and backend completion refresh preserves selections',
    (tester) async {
      final f = DocumentsFixture();
      await f.pump(tester, route: true);
      expect(find.text('Home Nurse Documents'), findsOneWidget);
      final c = f.container.read(documentsControllerProvider(3).notifier);
      await draft(c);
      await c.submit();
      await tester.pumpAndSettle();
      expect(f.service.completion.calls, greaterThanOrEqualTo(2));
      final setup = await f.container.read(
        serviceSetupControllerProvider(3).future,
      ) as Success<ServiceSetupData>;
      expect(setup.value.selected, {12});
      expect(setup.value.serviceCompletion.documentsCompleted, isFalse);
      expect(f.repo.documentCalls, 2);
      expect(f.repo.uploads, 1);
      expect(find.text('Home Nurse Documents'), findsOneWidget);
      await tester.ensureVisible(find.text('Back to service setup'));
      await tester.tap(find.text('Back to service setup'));
      await tester.pumpAndSettle();
      expect(
        f.container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/services/3/setup',
      );
      expect(f.service.services.submissions, 0);
      expect(f.service.options.saves, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
