import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/provider_chat_auth.dart';
import '../../../app/providers/app_providers.dart';
import 'provider_chat_views.dart';

/// Real provider inbox, scoped to the signed-in account.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(appConfigProvider) == null
      ? const Center(child: Text('Messages require API configuration.'))
      : ref
            .watch(providerChatBootstrapProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () =>
                      ref.invalidate(providerChatBootstrapProvider),
                  child: const Text('Retry messages'),
                ),
              ),
              data: (auth) => auth.user == null
                  ? const Center(
                      child: Text('Please sign in to view messages.'),
                    )
                  : ProviderScope(
                      key: ValueKey('provider-inbox-${auth.user!.id}'),
                      overrides: [
                        providerChatAuthProvider.overrideWithValue(auth),
                      ],
                      child: const ProviderMessagesInbox(),
                    ),
            );
}

Future<void> openProviderBookingChat(
  BuildContext context,
  WidgetRef ref,
  int jobId,
) async {
  try {
    final auth = await ref.read(providerChatBootstrapProvider.future);
    if (!context.mounted || auth.user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF7F9FE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheet) => ProviderScope(
        overrides: [providerChatAuthProvider.overrideWithValue(auth)],
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          child: SizedBox(
            height:
                (MediaQuery.sizeOf(sheet).height -
                    MediaQuery.viewInsetsOf(sheet).bottom) *
                .82,
            child: ProviderChatScreen(jobId: jobId, embedded: true),
          ),
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Messages could not be opened. Please retry.'),
        ),
      );
    }
  }
}
