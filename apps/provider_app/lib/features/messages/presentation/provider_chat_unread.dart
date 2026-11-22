import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/provider_chat_auth.dart';
import '../application/provider_chat_controller.dart';

class ProviderChatUnread extends ConsumerWidget {
  const ProviderChatUnread({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(providerChatBootstrapProvider).asData?.value;
    if (auth == null || auth.user == null) return child;
    return ProviderScope(
      overrides: [providerChatAuthProvider.overrideWithValue(auth)],
      child: _Unread(child: child),
    );
  }
}

class _Unread extends ConsumerStatefulWidget {
  const _Unread({required this.child});
  final Widget child;
  @override
  ConsumerState<_Unread> createState() => _UnreadState();
}

class _UnreadState extends ConsumerState<_Unread> with WidgetsBindingObserver {
  Timer? timer;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (foreground) ref.read(providerChatInboxProvider)?.refresh();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      ref.read(providerChatInboxProvider)?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(providerChatInboxProvider);
    if (inbox == null) return widget.child;
    return ListenableBuilder(
      listenable: inbox,
      builder: (_, _) => Badge(
        isLabelVisible: inbox.unread > 0,
        label: Text(inbox.unread > 99 ? '99+' : '${inbox.unread}'),
        child: widget.child,
      ),
    );
  }
}
