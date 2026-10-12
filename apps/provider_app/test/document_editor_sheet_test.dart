import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/services/documents/documents_controller.dart';
import 'package:provider_app/features/services/documents/documents_repository.dart';
import 'package:provider_app/features/services/documents/documents_screen.dart';

import 'provider_documents_test.dart' show DocumentsFixture;
import 'support/fake_documents_repository.dart';

Future<void> open(
  WidgetTester tester, {
  String label = 'Upload document',
}) async {
  final button = find.widgetWithText(BThereButton, label).first;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Choose file'));
  await tester.tap(find.text('Choose file'));
  await tester.pumpAndSettle();
}

Future<void> metadata(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Document number'),
    '123',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Issued date (YYYY-MM-DD)'),
    '2020-01-01',
  );
  tester.testTextInput.hide();
  await tester.pump();
}

Future<void> submit(
  WidgetTester tester, {
  String label = 'Upload and submit',
  bool settle = true,
}) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'completion removes its own sheet without popping a covering dialog',
    (tester) async {
      final f = DocumentsFixture();
      f.repo.pending = Completer();
      await f.pump(tester);
      await open(tester);
      await choose(tester);
      await metadata(tester);
      await submit(tester, settle: false);
      final sheetContext = tester.element(find.byType(DocumentEditorSheet));
      unawaited(
        showDialog<void>(
          context: sheetContext,
          builder: (_) => const AlertDialog(content: Text('Covering dialog')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      f.repo.pending!.complete(const Success(null));
      await tester.pumpAndSettle();
      expect(find.text('Covering dialog'), findsOneWidget);
      Navigator.of(tester.element(find.text('Covering dialog'))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(DocumentEditorSheet), findsNothing);
      expect(find.text('Caregiver Documents'), findsOneWidget);
    },
  );

  testWidgets('missing file submit explains blocker inside visible modal', (
    tester,
  ) async {
    final f = DocumentsFixture();
    await f.pump(tester);
    await open(tester);
    await submit(tester);
    expect(
      find.textContaining('Please choose a document file.').hitTestable(),
      findsOneWidget,
    );
    expect(find.byType(DocumentEditorSheet), findsOneWidget);
    expect(f.repo.uploads, 0);
    expect(f.container.read(documentsControllerProvider(3)).busy, isFalse);
  });
  testWidgets('issued and expiry errors are inline and do not upload', (
    tester,
  ) async {
    final f = DocumentsFixture();
    f.repo.requirementsResult = Success(
      parseRequirements([requirementJson(expiry: true)]),
    );
    await f.pump(tester);
    await open(tester);
    await choose(tester);
    await submit(tester);
    final issued = tester.widget<TextField>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Issued date (YYYY-MM-DD)'),
        matching: find.byType(TextField),
      ),
    );
    final expiry = tester.widget<TextField>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Expiry date (YYYY-MM-DD)'),
        matching: find.byType(TextField),
      ),
    );
    expect(
      issued.decoration!.errorText,
      'Enter a valid issued date (YYYY-MM-DD).',
    );
    expect(
      expiry.decoration!.errorText,
      'Enter a valid expiry date (YYYY-MM-DD).',
    );
    expect(f.repo.uploads, 0);
  });
  testWidgets(
    'focused metadata relinquishes focus before a pending native picker',
    (tester) async {
      final f = DocumentsFixture();
      await f.pump(tester);
      await open(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Document number'),
        '123',
      );
      final editing = tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Document number'),
          matching: find.byType(EditableText),
        ),
      );
      expect(editing.focusNode.hasFocus, isTrue);
      f.picker.pending = Completer();
      await tester.ensureVisible(find.text('Choose file'));
      await tester.tap(find.text('Choose file'));
      await tester.pump();
      expect(f.picker.calls, 1);
      expect(find.text('Selecting file'), findsOneWidget);
      expect(editing.focusNode.hasFocus, isFalse);
      f.picker.pending!.complete(null);
      await tester.pumpAndSettle();
      expect(f.container.read(documentsControllerProvider(3)).busy, isFalse);
      expect(
        f.container.read(documentsControllerProvider(3)).draft!.number,
        '123',
      );
    },
  );
  testWidgets(
    'picker exception recovers actions and exposes safe visible error',
    (tester) async {
      final f = DocumentsFixture();
      await f.pump(tester);
      await open(tester);
      f.picker.throws = true;
      await choose(tester);
      expect(
        find.text('Unable to select the file. Please retry.').hitTestable(),
        findsOneWidget,
      );
      expect(f.container.read(documentsControllerProvider(3)).busy, isFalse);
      f.picker.throws = false;
      await choose(tester);
      expect(f.picker.calls, 2);
      expect(find.text('scan.pdf'), findsOneWidget);
    },
  );
  testWidgets('pending picker cannot launch twice and success selects file', (
    tester,
  ) async {
    final f = DocumentsFixture();
    await f.pump(tester);
    await open(tester);
    f.picker.pending = Completer();
    final chooseButton = tester
        .widget<BThereButton>(find.widgetWithText(BThereButton, 'Choose file'))
        .onPressed!;
    chooseButton();
    chooseButton();
    await tester.pump();
    expect(f.picker.calls, 1);
    f.picker.pending!.complete(file());
    await tester.pumpAndSettle();
    expect(find.text('scan.pdf'), findsOneWidget);
    expect(f.container.read(documentsControllerProvider(3)).busy, isFalse);
  });
  testWidgets(
    'validation with keyboard and long metadata scrolls error into view',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final f = DocumentsFixture();
      await f.pump(tester);
      await open(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await submit(tester);
      expect(
        find.textContaining('Please choose a document file.').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'top card immediately presents selected editor without scrolling the whole page',
    (tester) async {
      final f = DocumentsFixture();
      f.repo.requirementsResult = Success(
        parseRequirements([
          requirementJson(),
          for (var id = 2; id <= 10; id++) requirementJson(id: id),
        ]),
      );
      await f.pump(tester);
      expect(find.byType(DocumentMetadataForm), findsNothing);
      await tester.tap(
        find.widgetWithText(BThereButton, 'Upload document').first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(DocumentEditorSheet), findsOneWidget);
      expect(find.text('Submit National ID').hitTestable(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DocumentsContent),
          matching: find.byType(DocumentMetadataForm),
        ),
        findsNothing,
      );
      expect(find.byType(DocumentMetadataForm), findsOneWidget);
    },
  );
  testWidgets('replace opens immediately with existing metadata and expiry', (
    tester,
  ) async {
    final f = DocumentsFixture();
    f.repo.requirementsResult = Success(
      parseRequirements([requirementJson(expiry: true)]),
    );
    f.repo.documentsResult = Success(
      parseDocuments([documentJson(status: 'REJECTED', expiry: '2031-01-01')]),
    );
    await f.pump(tester);
    await open(tester, label: 'Replace document');
    expect(find.byType(DocumentEditorSheet), findsOneWidget);
    expect(find.text('National Identity Card'), findsWidgets);
    final draft = f.container.read(documentsControllerProvider(3)).draft!;
    expect(draft.name, 'National Identity Card');
    expect(draft.number, '200012345678');
    expect(draft.issued, '2020-01-01');
    expect(draft.expiry, '2031-01-01');
    expect(
      find.widgetWithText(TextFormField, 'Expiry date (YYYY-MM-DD)'),
      findsOneWidget,
    );
  });
  testWidgets('choose calls picker and renders selected filename in sheet', (
    tester,
  ) async {
    final f = DocumentsFixture();
    await f.pump(tester);
    await open(tester);
    await choose(tester);
    expect(f.picker.calls, 1);
    expect(
      find.descendant(
        of: find.byType(DocumentEditorSheet),
        matching: find.text('scan.pdf'),
      ),
      findsOneWidget,
    );
    expect(
      f.container.read(documentsControllerProvider(3)).draft!.file!.name,
      'scan.pdf',
    );
  });
  testWidgets('cancelled picker keeps sheet and typed metadata without error', (
    tester,
  ) async {
    final f = DocumentsFixture();
    await f.pump(tester);
    await open(tester);
    await metadata(tester);
    f.picker.selected = null;
    await choose(tester);
    expect(find.byType(DocumentEditorSheet), findsOneWidget);
    expect(
      f.container.read(documentsControllerProvider(3)).draft!.number,
      '123',
    );
    expect(
      f.container.read(documentsControllerProvider(3)).operationError,
      isNull,
    );
  });
  testWidgets('Cancel closes sheet discards draft and can reopen', (
    tester,
  ) async {
    final f = DocumentsFixture();
    await f.pump(tester);
    await open(tester);
    await metadata(tester);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentEditorSheet), findsNothing);
    expect(f.container.read(documentsControllerProvider(3)).draft, isNull);
    await open(tester);
    expect(
      f.container.read(documentsControllerProvider(3)).draft!.number,
      isEmpty,
    );
    expect(f.repo.registrations, isEmpty);
  });
  testWidgets('system back closes idle sheet and cancels draft', (
    tester,
  ) async {
    final f = DocumentsFixture();
    await f.pump(tester);
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DocumentEditorSheet), findsNothing);
    expect(f.container.read(documentsControllerProvider(3)).draft, isNull);
    expect(find.text('Caregiver Documents'), findsOneWidget);
  });
  testWidgets(
    'repeated upload callbacks do not stack sheets or switch requirement',
    (tester) async {
      final f = DocumentsFixture();
      f.repo.requirementsResult = Success(
        parseRequirements([requirementJson(), requirementJson(id: 2)]),
      );
      await f.pump(tester);
      final callbacks = tester
          .widgetList<BThereButton>(
            find.widgetWithText(BThereButton, 'Upload document'),
          )
          .map((b) => b.onPressed!)
          .toList();
      callbacks[0]();
      callbacks[0]();
      callbacks[1]();
      await tester.pumpAndSettle();
      expect(find.byType(DocumentEditorSheet), findsOneWidget);
      expect(
        f.container.read(documentsControllerProvider(3)).draft!.requirement.id,
        1,
      );
    },
  );
  testWidgets('upload failure keeps sheet metadata and safe error visible', (
    tester,
  ) async {
    final f = DocumentsFixture();
    f.repo.uploadResult = const Failure(AppFailure(message: 'secret headers'));
    await f.pump(tester);
    await open(tester);
    await choose(tester);
    await metadata(tester);
    await submit(tester);
    expect(find.byType(DocumentEditorSheet), findsOneWidget);
    expect(find.text('Upload failed. Please retry.'), findsOneWidget);
    expect(
      f.container.read(documentsControllerProvider(3)).draft!.number,
      '123',
    );
    expect(f.repo.registrations, isEmpty);
  });
  testWidgets(
    'registration retry stays in sheet and reuses key without upload',
    (tester) async {
      final f = DocumentsFixture();
      f.repo.registerResult = const Failure(AppFailure(message: 'secret'));
      await f.pump(tester);
      await open(tester);
      await choose(tester);
      await metadata(tester);
      await submit(tester);
      expect(find.byType(DocumentEditorSheet), findsOneWidget);
      expect(find.text('Retry registration'), findsOneWidget);
      f.repo.registerResult = const Success(null);
      f.repo.documentsResult = Success(parseDocuments([documentJson()]));
      await submit(tester, label: 'Retry registration');
      expect(find.byType(DocumentEditorSheet), findsNothing);
      expect(f.repo.uploads, 1);
      expect(f.repo.registrations.map((r) => r.key), [
        'upload-key',
        'upload-key',
      ]);
      expect(find.text('Status: Pending approval'), findsOneWidget);
    },
  );
  testWidgets(
    'busy registration blocks back Cancel picker submit and barrier dismissal',
    (tester) async {
      final f = DocumentsFixture();
      f.repo.pending = Completer();
      await f.pump(tester);
      await open(tester);
      await choose(tester);
      await metadata(tester);
      await submit(tester, settle: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<BThereButton>(
              find.widgetWithText(BThereButton, 'Choose file'),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(DocumentEditorSheet), findsOneWidget);
      expect(f.container.read(documentsControllerProvider(3)).draft, isNotNull);
      await tester.tapAt(const Offset(2, 2));
      await tester.pump();
      expect(find.byType(DocumentEditorSheet), findsOneWidget);
      await f.container.read(documentsControllerProvider(3).notifier).submit();
      expect(f.repo.registrations.length, 1);
      f.repo.pending!.complete(const Success(null));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentEditorSheet), findsNothing);
    },
  );
  testWidgets('successful registration waits for refresh before closing', (
    tester,
  ) async {
    final f = DocumentsFixture();
    await f.pump(tester);
    await open(tester);
    await choose(tester);
    await metadata(tester);
    f.repo.pendingDocuments = Completer();
    await submit(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DocumentEditorSheet), findsOneWidget);
    expect(find.text('Refreshing documents'), findsOneWidget);
    f.repo.pendingDocuments!.complete(
      Success(parseDocuments([documentJson()])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DocumentEditorSheet), findsNothing);
    expect(find.text('Status: Pending approval'), findsOneWidget);
  });
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'keyboard narrow large-text sheet does not overflow ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final f = DocumentsFixture();
        await f.pump(tester, route: true);
        await open(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        final button = find.text('Upload and submit');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(button.hitTestable(), findsOneWidget);
        expect(Theme.of(tester.element(button)).brightness, brightness);
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      },
    );
  }
}
