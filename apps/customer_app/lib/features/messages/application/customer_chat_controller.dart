import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_providers.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../auth/data/customer_auth_service.dart';
import '../data/customer_chat_repository.dart';

final customerChatInboxProvider = Provider<ChatInbox?>(
  (ref) {
    if (ref.watch(customerConfigProvider) == null) return null;
    final c = ChatInbox(
      ref.watch(customerChatRepositoryProvider),
      ref.watch(customerAuthControllerProvider),
    );
    ref.onDispose(c.dispose);
    return c;
  },
  dependencies: [
    customerConfigProvider,
    customerChatRepositoryProvider,
    customerAuthControllerProvider,
  ],
);

class ChatInbox extends ChangeNotifier {
  ChatInbox(this.repository, this.auth) {
    auth.addListener(identity);
    identity();
  }
  final CustomerChatRepository repository;
  final CustomerAuthController auth;
  int? owner;
  int epoch = 0, unread = 0;
  bool busy = false, disposed = false;
  String? error;
  List<Map<String, dynamic>> rows = [];
  void identity() {
    final next = auth.stage == CustomerAuthStage.authenticated
        ? auth.user?.id
        : null;
    if (owner == next) return;
    epoch++;
    owner = next;
    rows = [];
    unread = 0;
    error = null;
    busy = false;
    if (next != null) refresh();
    notifyListeners();
  }

  Future<void> refresh() async {
    if (disposed || owner == null || busy) return;
    final ticket = epoch;
    busy = true;
    notifyListeners();
    try {
      final value = await repository.inbox();
      if (disposed || ticket != epoch) return;
      rows = (value['conversations'] as List)
          .cast<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      unread = value['totalUnread'] as int;
      error = null;
    } catch (e) {
      if (!disposed && ticket == epoch) {
        error = 'Messages could not be loaded. Please retry.';
        if (e is CustomerAuthFailure && e.status == 401) {
          await auth.restore();
        }
      }
    } finally {
      if (!disposed && ticket == epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    epoch++;
    auth.removeListener(identity);
    super.dispose();
  }
}

/// One visible chat. Text lives in memory only; a send is retried explicitly
/// with its original id, and only the server's masked message is displayed.
class CustomerChatController extends ChangeNotifier {
  CustomerChatController(
    this.jobId,
    this.repository,
    this.auth, {
    required this.onRead,
  }) {
    owner = auth.user?.id;
    auth.addListener(identity);
  }
  final int jobId;
  final CustomerChatRepository repository;
  final CustomerAuthController auth;
  final VoidCallback onRead;
  int? owner;
  int epoch = 0, lastRead = 0, othersRead = 0, sentRevision = 0;
  bool disposed = false,
      active = false,
      busy = false,
      sending = false,
      olderBusy = false,
      hasOlder = false,
      unavailable = false,
      canSend = false;
  ChatPage? page;
  List<Map<String, dynamic>> messages = [];
  String? error, sendError, pendingId, pendingText;
  DateTime? blockedUntil;
  Timer? timer;
  bool get current =>
      !disposed &&
      owner != null &&
      auth.user?.id == owner &&
      auth.stage == CustomerAuthStage.authenticated;
  int get waitSeconds => blockedUntil == null
      ? 0
      : (blockedUntil!.difference(repository.now()).inMilliseconds / 1000)
            .ceil()
            .clamp(0, 3600);
  bool get allowed =>
      canSend &&
      (DateTime.tryParse('${page?.data['sendUntil']}')
              ?.isAfter(repository.now()) ??
          true);
  void emit() {
    if (!disposed) notifyListeners();
  }

  void identity() {
    if (current) return;
    epoch++;
    timer?.cancel();
    messages = [];
    page = null;
    pendingId = pendingText = null;
    canSend = false;
    active = false;
    emit();
  }

  void visible(bool value) {
    if (active == value) return;
    active = value;
    timer?.cancel();
    if (value && current) {
      refresh();
      timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (active && current && !unavailable) refresh();
      });
    }
  }

  void merge(List<Map<String, dynamic>> incoming) {
    final all = {for (final m in messages) m['messageId'] as int: m};
    for (final m in incoming) {
      all[m['messageId'] as int] = m;
      if (pendingId != null &&
          m['fromYou'] == true &&
          m['clientMessageId'] == pendingId) {
        sentRevision++;
        pendingId = pendingText = null;
        sendError = null;
      }
    }
    messages = all.values.toList()
      ..sort(
        (a, b) => (a['messageId'] as int).compareTo(b['messageId'] as int),
      );
  }

  Future<void> refresh({bool full = false}) async {
    if (!current || !active || busy) return;
    final ticket = epoch;
    busy = true;
    emit();
    try {
      final result = await repository.page(
        jobId,
        after: full || page == null || messages.isEmpty
            ? null
            : messages.last['messageId'] as int,
      );
      if (!current || ticket != epoch) return;
      page = result;
      canSend = result.data['canSend'] as bool;
      final others = result.data['othersLastReadMessageId'] as int? ?? 0;
      final own = result.data['yourLastReadMessageId'] as int? ?? 0;
      if (others > othersRead) othersRead = others;
      if (own > lastRead) lastRead = own;
      if (full || messages.isEmpty) hasOlder = result.data['hasOlder'] as bool;
      merge(result.messages);
      var cursorPage = result;
      while (cursorPage.data['hasNewer'] == true) {
        final cursor = messages.lastOrNull?['messageId'] as int?;
        if (cursor == null) break;
        cursorPage = await repository.page(jobId, after: cursor);
        if (!current || ticket != epoch) return;
        merge(cursorPage.messages);
        if ((messages.lastOrNull?['messageId'] as int? ?? cursor) <= cursor) {
          break;
        }
        page = cursorPage;
        canSend = cursorPage.data['canSend'] as bool;
        final read = cursorPage.data['othersLastReadMessageId'] as int? ?? 0;
        if (read > othersRead) othersRead = read;
      }
      error = null;
      unavailable = false;
    } catch (e) {
      if (!current || ticket != epoch) return;
      error = e is ChatProblem
          ? e.message
          : 'Messages could not be loaded. Please retry.';
      if (e is ChatProblem &&
          (e.status == 404 || e.status == 409 || e.status == 403)) {
        canSend = false;
        unavailable = true;
        if (e.status == 404) {
          messages = [];
          page = null;
        }
      }
      if (e is CustomerAuthFailure && e.status == 401) {
        await auth.restore();
      }
    } finally {
      if (current && ticket == epoch) {
        busy = false;
        emit();
      }
    }
  }

  Future<void> older() async {
    if (!current || !active || olderBusy || !hasOlder || messages.isEmpty) {
      return;
    }
    olderBusy = true;
    final ticket = epoch;
    emit();
    try {
      final result = await repository.page(
        jobId,
        before: messages.first['messageId'] as int,
      );
      if (!current || ticket != epoch) return;
      merge(result.messages);
      hasOlder = result.data['hasOlder'] as bool;
    } catch (_) {
      if (current && ticket == epoch) {
        error = 'Earlier messages could not be loaded.';
      }
    } finally {
      if (current && ticket == epoch) {
        olderBusy = false;
        emit();
      }
    }
  }

  bool reading = false;
  Future<void> displayed(int id) async {
    if (!current || !active || reading || id <= lastRead) return;
    final ticket = epoch;
    reading = true;
    try {
      await repository.read(jobId, id);
      if (current && ticket == epoch) {
        lastRead = id;
        onRead();
      }
    } catch (_) {
      /* Retry the receipt only after the next visible frame/poll. */
    } finally {
      reading = false;
    }
  }

  Future<void> send(String text) async {
    if (!current ||
        !active ||
        sending ||
        (!allowed && pendingId == null) ||
        waitSeconds > 0) {
      return;
    }
    if (pendingId == null) {
      final value = text.trim();
      if (value.isEmpty || value.length > 1000) {
        sendError = 'Use between 1 and 1000 characters for your message.';
        emit();
        return;
      }
      pendingId = CustomerChatRepository.newMessageId();
      pendingText = value;
    }
    final ticket = epoch, id = pendingId!, value = pendingText!;
    sending = true;
    sendError = null;
    emit();
    try {
      final result = await repository.send(jobId, value, id);
      if (!current || ticket != epoch) return;
      // A response belongs to this exact send, not an unrelated message.
      if (result['fromYou'] != true || result['clientMessageId'] != id) {
        throw const FormatException('Invalid send acknowledgement');
      }
      merge([result]);
      pendingId = pendingText = null;
      onRead();
    } catch (e) {
      if (!current || ticket != epoch) return;
      sendError = e is ChatProblem
          ? e.message
          : 'Message not confirmed. Retry to check or send it safely.';
      if (e is ChatProblem) {
        if (e.status == 400) pendingId = pendingText = null;
        if (e.status == 429) {
          blockedUntil = repository.now().add(
            Duration(seconds: e.retrySeconds),
          );
        }
        if (e.status == 409 || e.status == 404) {
          pendingId = pendingText = null;
          canSend = false;
          await refresh(full: true);
        }
      }
      if (e is CustomerAuthFailure && e.status == 401) {
        await auth.restore();
      }
    } finally {
      if (current && ticket == epoch) {
        sending = false;
        emit();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    epoch++;
    timer?.cancel();
    auth.removeListener(identity);
    super.dispose();
  }
}
