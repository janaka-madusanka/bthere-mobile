import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'provider_chat_theme.dart';
import '../../../app/providers/app_providers.dart';
import '../application/provider_chat_auth.dart';

import '../application/provider_chat_controller.dart';
import '../data/provider_chat_repository.dart';

Future<void> showProviderBookingChatSheet(
  BuildContext context,
  int jobId, {
  Map<String, dynamic>? participant,
  VoidCallback? onCall,
}) => showModalBottomSheet<void>(
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
    overrides: [
      providerChatAuthProvider.overrideWithValue(
        ProviderScope.containerOf(context).read(providerChatAuthProvider),
      ),
    ],
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(sheet).height -
                MediaQuery.viewInsetsOf(sheet).bottom) *
            .82,
        child: ProviderChatScreen(
          jobId: jobId,
          embedded: true,
          participant: participant,
          onCall: onCall,
        ),
      ),
    ),
  ),
);

/// Stop polling/receipts when another route covers chat or the app backgrounds.
mixin ChatVisibility<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  GoRouter? _router;
  void onVisibility(bool visible);
  void _changed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        onVisibility(
          (ModalRoute.of(context)?.isCurrent ?? false) &&
              (WidgetsBinding.instance.lifecycleState == null ||
                  WidgetsBinding.instance.lifecycleState ==
                      AppLifecycleState.resumed),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_changed);
      _router = router;
      router.routerDelegate.addListener(_changed);
    }
    _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      onVisibility(false);
    } else {
      _changed();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_changed);
    super.dispose();
  }
}

class ProviderMessagesInbox extends ConsumerStatefulWidget {
  const ProviderMessagesInbox({super.key});
  @override
  ConsumerState<ProviderMessagesInbox> createState() => _InboxState();
}

class _InboxState extends ConsumerState<ProviderMessagesInbox>
    with WidgetsBindingObserver, ChatVisibility {
  bool visible = false;
  Timer? inboxTimer;
  @override
  void initState() {
    super.initState();
    inboxTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (visible) ref.read(providerChatInboxProvider)?.refresh();
    });
  }

  @override
  void dispose() {
    inboxTimer?.cancel();
    super.dispose();
  }

  @override
  void onVisibility(bool value) {
    if (value && !visible) ref.read(providerChatInboxProvider)?.refresh();
    visible = value;
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(providerChatInboxProvider);
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (_, _) => Scaffold(
        backgroundColor: ProviderChatColors.background,
        appBar: chatAppBar('Messages'),
        body: RefreshIndicator(
          onRefresh: c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Your booking conversations',
                style: ProviderChatTypography.section,
              ),
              const SizedBox(height: 6),
              const Text(
                'Stay in touch with your customers.',
                style: ProviderChatTypography.body,
              ),
              const SizedBox(height: 20),
              if (c.busy && c.rows.isEmpty)
                const Center(child: CircularProgressIndicator()),
              if (c.error != null) _ChatError(c.error!, c.refresh),
              if (!c.busy && c.error == null && c.rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 70),
                  child: Column(
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 44,
                        color: ProviderChatColors.action,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: ProviderChatTypography.section,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Chat becomes available after your booking is confirmed.',
                        textAlign: TextAlign.center,
                        style: ProviderChatTypography.body,
                      ),
                    ],
                  ),
                ),
              for (final row in c.rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: ProviderChatColors.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: ChatAvatar(
                        participant: (row['participants'] as List).firstOrNull,
                      ),
                      title: Text(
                        participantNames(row['participants']),
                        style: ProviderChatTypography.card,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Booking #${row['jobId']}',
                            style: ProviderChatTypography.compact,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            row['lastMessage'] is Map
                                ? '${row['lastMessage']['preview'] ?? 'Message unavailable'}'
                                : 'Start a conversation',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ProviderChatTypography.body.copyWith(
                              color: ProviderChatColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      trailing: (row['unreadCount'] as int) > 0
                          ? Badge(label: Text('${row['unreadCount']}'))
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => showProviderBookingChatSheet(
                        context,
                        row['jobId'] as int,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String participantNames(Object? raw) {
  final people = (raw is List ? raw : const [])
      .whereType<Map>()
      .where((p) => p['you'] != true)
      .map((p) => p['displayName'])
      .whereType<String>()
      .where((s) => s.trim().isNotEmpty)
      .toList();
  return people.isEmpty ? 'Booking chat' : people.join(', ');
}

AppBar chatAppBar(String title, {Widget? leading}) => AppBar(
  title: Text(
    title,
    style: ProviderChatTypography.section.copyWith(color: Colors.white),
  ),
  centerTitle: true,
  backgroundColor: ProviderChatColors.action,
  foregroundColor: Colors.white,
  surfaceTintColor: Colors.transparent,
  leading: leading,
);

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, this.participant});
  final Object? participant;
  @override
  Widget build(BuildContext context) {
    final raw = participant is Map
        ? (participant as Map)['profilePhoto']
        : null;
    final url = raw is String ? Uri.tryParse(raw) : null;
    const fallback = Icon(
      Icons.person_outline_rounded,
      color: ProviderChatColors.action,
    );
    return CircleAvatar(
      radius: 24,
      backgroundColor: ProviderChatColors.selection,
      child: url != null && url.scheme == 'https' && url.host.isNotEmpty
          ? ClipOval(
              child: Image.network(
                url.toString(),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
            )
          : fallback,
    );
  }
}

class ProviderChatScreen extends ConsumerStatefulWidget {
  const ProviderChatScreen({
    super.key,
    required this.jobId,
    this.embedded = false,
    this.participant,
    this.onCall,
  });
  final int jobId;
  final bool embedded;
  final Map<String, dynamic>? participant;
  final VoidCallback? onCall;
  @override
  ConsumerState<ProviderChatScreen> createState() => _ChatState();
}

class _ChatState extends ConsumerState<ProviderChatScreen>
    with WidgetsBindingObserver, ChatVisibility {
  late final ProviderChatController c;
  final draft = TextEditingController(), scroll = ScrollController();
  final viewport = GlobalKey();
  final bubbleKeys = <int, GlobalKey>{};
  bool compactHeader(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) > 19 ||
      MediaQuery.sizeOf(context).height -
              MediaQuery.viewInsetsOf(context).bottom <
          450;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    c = ProviderChatController(
      widget.jobId,
      ref.read(providerChatRepositoryProvider),
      ref.read(providerChatAuthProvider),
      onRead: () => ref.read(providerChatAuthProvider).refreshInboxes(),
    );
    c.addListener(changed);
    scroll.addListener(receipts);
  }

  void changed() {
    if (!mounted) return;
    if (!c.current) draft.clear();
    if (revision != c.sentRevision) {
      revision = c.sentRevision;
      draft.clear();
    }
    if (!widget.embedded &&
        c.unavailable &&
        c.page == null &&
        c.error != null &&
        !c.busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/messages');
        }
      });
    }
    setState(() {});
    receipts();
  }

  void receipts() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !c.active ||
          !c.current ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }
      final box = viewport.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      var newest = 0;
      for (final entry in bubbleKeys.entries) {
        final bubble = entry.value.currentContext?.findRenderObject();
        if (bubble is RenderBox &&
            bubble.hasSize &&
            rect.overlaps(bubble.localToGlobal(Offset.zero) & bubble.size)) {
          if (entry.key > newest) newest = entry.key;
        }
      }
      if (newest > 0) c.displayed(newest);
    });
  }

  @override
  void onVisibility(bool visible) {
    c.visible(visible);
    if (visible) receipts();
  }

  @override
  void dispose() {
    c.removeListener(changed);
    c.dispose();
    draft.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: !widget.embedded,
    backgroundColor: const Color(0xFFF7F9FE),
    appBar: widget.embedded
        ? null
        : chatAppBar(
            'Booking #${widget.jobId}',
            leading: IconButton(
              tooltip: 'Back to messages',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/messages'),
            ),
          ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          if (widget.embedded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Row(
                children: [
                  if (!compactHeader(context))
                    ChatAvatar(
                      participant:
                          widget.participant ??
                          (c.page?.data['participants'] as List?)
                              ?.whereType<Map>()
                              .where((p) => p['you'] != true)
                              .firstOrNull,
                    ),
                  if (!compactHeader(context)) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.participant?['displayName'] as String? ??
                              participantNames(c.page?.data['participants']),
                          maxLines: compactHeader(context) ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              (compactHeader(context)
                                      ? ProviderChatTypography.card
                                      : ProviderChatTypography.section)
                                  .copyWith(
                                    color: const Color(0xFF101D42),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        if (!compactHeader(context))
                          Text(
                            'Booking #${widget.jobId} chat',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ProviderChatTypography.compact,
                          ),
                      ],
                    ),
                  ),
                  if (widget.onCall != null)
                    IconButton.filledTonal(
                      tooltip: 'Call provider',
                      style: IconButton.styleFrom(
                        backgroundColor: ProviderChatColors.selection,
                        foregroundColor: ProviderChatColors.action,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: widget.onCall,
                      icon: const Icon(Icons.call_outlined),
                    ),
                  IconButton(
                    tooltip: 'Close chat',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          if (c.page != null && !widget.embedded)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                participantNames(c.page!.data['participants']),
                style: ProviderChatTypography.card,
              ),
            ),
          if (c.error != null)
            _ChatError(c.error!, () => c.refresh(full: true)),
          Expanded(
            child: c.page == null && c.busy
                ? const Center(child: CircularProgressIndicator())
                : c.page == null && c.error != null
                ? const SizedBox.shrink()
                : c.messages.isEmpty
                ? const Center(
                    child: Text(
                      'Say hello to your customer.',
                      style: ProviderChatTypography.body,
                    ),
                  )
                : ListView.builder(
                    scrollCacheExtent: ScrollCacheExtent.pixels(0),
                    key: viewport,
                    controller: scroll,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: c.messages.length + (c.hasOlder ? 1 : 0),
                    itemBuilder: (_, index) {
                      if (index == c.messages.length) {
                        return TextButton(
                          onPressed: c.olderBusy ? null : c.older,
                          child: Text(
                            c.olderBusy
                                ? 'Loading...'
                                : 'Load earlier messages',
                          ),
                        );
                      }
                      final messageIndex = c.messages.length - 1 - index;
                      final m = c.messages[messageIndex];
                      final sent = DateTime.parse(m['sentAt'] as String)
                          .toLocal();
                      bool sameDay(DateTime a, DateTime b) =>
                          a.year == b.year &&
                          a.month == b.month &&
                          a.day == b.day;
                      final firstOfDay =
                          messageIndex == 0 ||
                          !sameDay(
                            sent,
                            DateTime.parse(
                              c.messages[messageIndex - 1]['sentAt'] as String,
                            ).toLocal(),
                          );
                      final now = ref.read(clockProvider)().toLocal();
                      final dateLabel = sameDay(sent, now)
                          ? 'Today'
                          : sameDay(sent, now.subtract(const Duration(days: 1)))
                          ? 'Yesterday'
                          : MaterialLocalizations.of(context)
                                .formatMediumDate(sent);
                      final id = m['messageId'] as int;
                      final own = m['fromYou'] == true;
                      final key = bubbleKeys.putIfAbsent(id, GlobalKey.new);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (index == 0 &&
                              c.allowed &&
                              c.page?.data['sendUntil'] is String)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                'You can reply until ${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(c.page!.data['sendUntil'] as String).toLocal())} ${TimeOfDay.fromDateTime(DateTime.parse(c.page!.data['sendUntil'] as String).toLocal()).format(context)}',
                                textAlign: TextAlign.center,
                                style: ProviderChatTypography.compact,
                              ),
                            ),
                          if (firstOfDay)
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 16,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECF0F8),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  dateLabel,
                                  style: ProviderChatTypography.compactStrong
                                      .copyWith(color: const Color(0xFF68718B)),
                                ),
                              ),
                            ),
                          Align(
                            alignment: own
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              key: key,
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * .82,
                              ),
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: own
                                    ? const Color(0xFFD4F1ED)
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(own ? 20 : 4),
                                  bottomRight: Radius.circular(own ? 4 : 20),
                                ),
                                boxShadow: own
                                    ? null
                                    : const [
                                        BoxShadow(
                                          color: Color(0x0B246777),
                                          blurRadius: 10,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!own &&
                                      (c.page?.data['participants'] as List? ??
                                                  [])
                                              .length >
                                          1)
                                    Text(
                                      '${m['senderName'] ?? 'Provider'}',
                                      style:
                                          ProviderChatTypography.compactStrong,
                                    ),
                                  Text(
                                    m['text'] as String? ??
                                        'Message unavailable',
                                    style: ProviderChatTypography.body.copyWith(
                                      color: const Color(0xFF101D42),
                                    ),
                                  ),
                                  if (m['contactInfoHidden'] == true)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Contact details are hidden for your safety.',
                                        style: ProviderChatTypography.compact,
                                      ),
                                    ),
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          TimeOfDay.fromDateTime(sent)
                                              .format(context),
                                          style: ProviderChatTypography.micro
                                              .copyWith(
                                                color: const Color(0xFF68718B),
                                              ),
                                        ),
                                      ),
                                      if (own && id <= c.othersRead) ...[
                                        const SizedBox(width: 5),
                                        const Icon(
                                          Icons.done_all_rounded,
                                          size: 16,
                                          color: ProviderChatColors.action,
                                          semanticLabel: 'Seen',
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (c.sendError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                c.sendError!,
                style: ProviderChatTypography.compact.copyWith(
                  color: ProviderChatColors.error,
                ),
              ),
            ),
          if (c.page != null && !c.allowed)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This chat is closed. You can still read past messages.',
                style: ProviderChatTypography.body,
              ),
            ),
          if (c.current && c.page != null && (c.allowed || c.pendingId != null))
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat-draft'),
                      controller: draft,
                      readOnly: c.pendingId != null,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFEEF2F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                            color: Color(0xFFDCE4F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(
                            color: Color(0xFFDCE4F0),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: ProviderChatColors.action,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
                    key: const ValueKey('chat-send'),
                    tooltip: c.pendingId != null
                        ? 'Retry message'
                        : 'Send message',
                    onPressed:
                        c.sending ||
                            c.waitSeconds > 0 ||
                            (draft.text.trim().isEmpty && c.pendingId == null)
                        ? null
                        : () => c.send(draft.text),
                    icon: c.sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            c.pendingId == null
                                ? Icons.send_outlined
                                : Icons.refresh_rounded,
                          ),
                  ),
                ],
              ),
            ),
          if (c.waitSeconds > 0)
            const Padding(
              padding: EdgeInsets.all(6),
              child: Text(
                'Please wait a moment before retrying.',
                style: ProviderChatTypography.compact,
              ),
            ),
        ],
      ),
    ),
  );
}

class _ChatError extends StatelessWidget {
  const _ChatError(this.message, this.retry);
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: ProviderChatTypography.body),
        TextButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );
}
