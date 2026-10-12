import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/services/documents/documents_controller.dart';

import 'support/fake_documents_repository.dart';

void main() {
  test(
    'initial repository resolution failure releases loading and retries',
    () async {
      var fail = true;
      final repo = FakeDocuments();
      final container = ProviderContainer(
        overrides: [
          documentsRepositoryProvider.overrideWith((_) {
            if (fail) throw StateError('private setup failure');
            return repo;
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        documentsControllerProvider(3),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);
      final c = container.read(documentsControllerProvider(3).notifier);
      expect(c.state.requirementsLoading, isFalse);
      expect(c.state.documentsLoading, isFalse);
      expect(c.state.requirementsError, isNotNull);
      fail = false;
      container.invalidate(documentsRepositoryProvider);
      await c.load();
      expect(c.state.requirementsError, isNull);
      expect(c.state.requirements, isNotEmpty);
    },
  );

  test(
    'repository resolution failure during submit is visible and releases busy',
    () async {
      var fail = false;
      final repo = FakeDocuments();
      final container = ProviderContainer(
        overrides: [
          documentsRepositoryProvider.overrideWith((_) {
            if (fail) throw StateError('private configuration details');
            return repo;
          }),
          documentPickerProvider.overrideWithValue(FakePicker()),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        documentsControllerProvider(3),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);
      final c = container.read(documentsControllerProvider(3).notifier);
      c.edit(requirement);
      await c.pick();
      c.state.draft!.issued = '2020-01-01';
      fail = true;
      container.invalidate(documentsRepositoryProvider);
      await c.submit();
      expect(
        c.state.operationError,
        'Unable to submit the document. Please retry.',
      );
      expect(c.state.busy, isFalse);
      expect(c.state.phase, isNull);
      expect(c.state.draft, isNotNull);
    },
  );
  test('submit without draft explains its early return', () async {
    final container = ProviderContainer(
      overrides: [
        documentsRepositoryProvider.overrideWithValue(FakeDocuments()),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      documentsControllerProvider(3),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    final c = container.read(documentsControllerProvider(3).notifier);
    await c.submit();
    expect(c.state.operationError, 'Open a document editor before submitting.');
    expect(c.state.busy, isFalse);
  });
}
