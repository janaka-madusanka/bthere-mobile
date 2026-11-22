import 'dart:async';
import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/messages/application/customer_chat_controller.dart';
import 'package:customer_app/features/messages/data/customer_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_auth_test.dart' show Fixture;
import 'customer_discovery_test.dart' show waitForState;

Map<String, Object?> message(
  int id, {
  String? client,
  String? text = 'Hello',
  bool own = false,
}) => {
  'messageId': id,
  'senderRole': own ? 'CUSTOMER' : 'PROVIDER',
  'senderName': 'Provider',
  'fromYou': own,
  'text': text,
  'contactInfoHidden': text?.contains('[hidden]') ?? false,
  'sentAt': '2026-11-18T10:15:02Z',
  'clientMessageId': client,
};
Map<String, Object?> page({
  List<Map<String, Object?>>? messages,
  bool send = true,
  bool older = false,
  int seen = 0,
}) => {
  'jobId': 40,
  'jobStatus': 'CONFIRMED',
  'canSend': send,
  'sendUntil': null,
  'participants': [
    {'role': 'PROVIDER', 'displayName': 'Provider', 'you': false},
  ],
  'messages': messages ?? [message(100)],
  'hasOlder': older,
  'hasNewer': false,
  'yourLastReadMessageId': 0,
  'othersLastReadMessageId': seen,
  'unreadCount': 1,
};
ResponseBody jsonResponse(Object? body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  late Fixture f;
  late CustomerChatRepository repo;
  late CustomerChatController c;
  var reads = 0;
  setUp(() async {
    f = Fixture();
    await f.controller.login('test', 'password');
    repo = CustomerChatRepository(f.service);
    reads = 0;
    c = CustomerChatController(40, repo, f.controller, onRead: () => reads++);
  });
  tearDown(() {
    c.dispose();
    f.dispose();
  });
  Future<void> open() async {
    c.active = true;
    await c.refresh();
  }

  test('loads latest, merges pages without duplicates, and marks only displayed messages read', () async {
    f.adapter.extraHandler = (r) async {
      if (r.path.endsWith('/read')) {
        return jsonResponse({
          'jobId': 40,
          'yourLastReadMessageId': 101,
          'unreadCount': 0,
        });
      }
      if (r.uri.queryParameters.containsKey('before')) {
        return jsonResponse(page(messages: [message(99)], older: false));
      }
      if (r.uri.queryParameters.containsKey('after')) {
        return jsonResponse(
          page(messages: [message(100), message(101)], seen: 100),
        );
      }
      return jsonResponse(page(older: true));
    };
    await open();
    expect(reads, 0);
    expect(c.hasOlder, isTrue);
    await c.refresh();
    expect(c.messages.map((m) => m['messageId']), [100, 101]);
    expect(f.adapter.requests.last.uri.queryParameters['after'], '100');
    await c.older();
    expect(c.messages.map((m) => m['messageId']), [99, 100, 101]);
    expect(c.hasOlder, isFalse);
    await c.displayed(101);
    await c.displayed(100);
    expect(reads, 1);
    await c.refresh();
    expect(c.lastRead, 101);
    expect(c.othersRead, 100);
    c.visible(false);
    final count = f.adapter.requests.length;
    await c.refresh();
    await c.displayed(102);
    expect(f.adapter.requests.length, count);
  });

  test('uncertain send preserves original id, explicit retry displays only server-masked text', () async {
    final ids = <String>[];
    f.adapter.extraHandler = (r) async {
      if (r.method == 'GET') return jsonResponse(page());
      final id = (r.data as Map)['clientMessageId'] as String;
      ids.add(id);
      if (ids.length == 1) {
        throw const NetworkException(
          kind: NetworkExceptionKind.timeout,
          message: 'Timeout',
        );
      }
      return jsonResponse(
        message(101, own: true, client: id, text: 'Call [hidden]'),
        201,
      );
    };
    await open();
    await c.send('Call 0771234567');
    expect(c.pendingId, isNotNull);
    expect(c.messages.length, 1);
    await c.send('different text must not replace pending payload');
    expect(ids.toSet().length, 1);
    expect((f.adapter.requests.last.data as Map)['text'], 'Call 0771234567');
    expect(c.messages.last['text'], 'Call [hidden]');
    expect(c.pendingId, isNull);
    expect(c.sentRevision, 1);
  });

  test('rate limit disables send, validation keeps draft editable, read-only server blocks sends', () async {
    var code = 429;
    f.adapter.extraHandler = (r) async => r.method == 'GET'
        ? jsonResponse(page())
        : jsonResponse({
            'detail': 'Fix the message',
            'retryAfterSeconds': 60,
          }, code);
    await open();
    await c.send('Hello');
    expect(c.waitSeconds, greaterThan(0));
    final count = f.adapter.requests.length;
    await c.send('Hello');
    expect(f.adapter.requests.length, count);
    c.blockedUntil = null;
    code = 400;
    await c.send('Hello');
    expect(c.pendingId, isNull);
    expect(c.sendError, 'Fix the message');
    f.adapter.extraHandler = (_) async => jsonResponse(page(send: false));
    await c.refresh(full: true);
    expect(c.allowed, isFalse);
    final before = f.adapter.requests.length;
    await c.send('Hello');
    expect(f.adapter.requests.length, before);
  });

  test(
    'logout clears messages and pending text; ignores late response',
    () async {
      final pending = Completer<ResponseBody>();
      f.adapter.extraHandler = (r) async {
        if (r.path.endsWith('/messages')) return pending.future;
        return null;
      };
      c.active = true;
      final loading = c.refresh();
      await Future<void>.delayed(Duration.zero);
      await f.controller.logout();
      pending.complete(jsonResponse(page()));
      await loading;
      expect(c.messages, isEmpty);
      expect(c.page, isNull);
      expect(c.active, isFalse);
    },
  );

  test(
    'poll reconciliation finds accepted timed-out send without another POST',
    () async {
      String? id;
      f.adapter.extraHandler = (r) async {
        if (r.method == 'POST') {
          id = (r.data as Map)['clientMessageId'] as String;
          throw const NetworkException(
            kind: NetworkExceptionKind.timeout,
            message: 'Timeout',
          );
        }
        return jsonResponse(
          page(
            messages: [
              message(100),
              if (id != null) message(101, own: true, client: id),
            ],
          ),
        );
      };
      await open();
      await c.send('Hello');
      await c.refresh();
      expect(c.pendingId, isNull);
      expect(c.messages.length, 2);
      expect(
        f.adapter.requests.where((r) => r.method == 'POST').length,
        2,
      ); // login + one send
    },
  );

  test('catches up every newer page and deduplicates IDs', () async {
    var calls = 0;
    f.adapter.extraHandler = (r) async {
      calls++;
      return jsonResponse({
        ...page(messages: [message(99 + calls)]),
        'hasNewer': calls < 3,
      });
    };
    await open();
    expect(calls, 3);
    expect(c.messages.map((m) => m['messageId']), [100, 101, 102]);
  });

  test('wrong role does not sign out the customer', () async {
    f.adapter.extraHandler = (_) async =>
        jsonResponse({'detail': 'Forbidden'}, 403);
    await open();
    expect(f.controller.user, isNotNull);
  });

  test('inbox unread uses server total and clears on sign out', () async {
    f.adapter.extraHandler = (r) async => r.path.endsWith('/conversations')
        ? jsonResponse({'conversations': [], 'totalUnread': 7})
        : null;
    final inbox = ChatInbox(repo, f.controller);
    addTearDown(inbox.dispose);
    await waitForState(inbox, () => !inbox.busy);
    expect(inbox.unread, 7);
    await f.controller.logout();
    expect(inbox.unread, 0);
    expect(inbox.rows, isEmpty);
  });
  test(
    'uncertain send can be checked with the same ID after chat closes',
    () async {
      f.adapter.extraHandler = (_) async => jsonResponse(page());
      await open();
      c.pendingId = '11111111-1111-4111-8111-111111111111';
      c.pendingText = 'Hello';
      c.canSend = false;
      f.adapter.extraHandler = (r) async {
        expect((r.data as Map)['clientMessageId'], c.pendingId);
        return jsonResponse(message(101, own: true, client: c.pendingId), 201);
      };
      await c.send('different');
      expect(c.pendingId, isNull);
      expect(c.messages.last['messageId'], 101);
    },
  );
  test(
    'chat deadline uses HTTP Date rather than a wrong phone clock',
    () async {
      f.adapter.extraHandler = (_) async => ResponseBody.fromString(
        jsonEncode({...page(), 'sendUntil': '2030-01-01T00:00:10Z'}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          'date': ['Tue, 01 Jan 2030 00:00:20 GMT'],
        },
      );
      await open();
      expect(c.allowed, isFalse);
    },
  );
}
