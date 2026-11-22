import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/core/auth/provider_session_api.dart';
import 'package:provider_app/features/messages/application/provider_chat_auth.dart';
import 'package:provider_app/features/messages/application/provider_chat_controller.dart';
import 'package:provider_app/features/messages/data/provider_chat_repository.dart';

import 'support/fake_session_storage.dart';

Map<String, dynamic> msg(int id, {bool own = false, String? client}) => {
  'messageId': id,
  'senderName': own ? 'Provider' : 'Customer',
  'senderRole': own ? 'PROVIDER' : 'CUSTOMER',
  'fromYou': own,
  'contactInfoHidden': false,
  'text': 'Hello',
  'sentAt': '2026-11-22T10:00:00Z',
  'clientMessageId': client,
};
Map<String, dynamic> thread({
  List<Map<String, dynamic>>? messages,
  bool more = false,
  bool canSend = true,
}) => {
  'jobId': 40,
  'jobStatus': 'CONFIRMED',
  'canSend': canSend,
  'sendUntil': null,
  'participants': [
    {'displayName': 'Customer', 'role': 'CUSTOMER', 'you': false},
  ],
  'messages': messages ?? [msg(100)],
  'hasOlder': false,
  'hasNewer': more,
  'yourLastReadMessageId': 0,
  'othersLastReadMessageId': 0,
  'unreadCount': 0,
};
ResponseBody json(Object? body, [int code = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  code,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class ChatAdapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  late Future<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) {
    calls.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

AuthSession session(int owner) => AuthSession(
  accessToken: 'test',
  refreshToken: 'refresh',
  tokenType: 'Bearer',
  expiresAt: DateTime.utc(2040),
  user: SessionUser(
    id: owner,
    username: 'provider',
    status: 'ACTIVE',
    roles: ['SERVICE_PROVIDER'],
  ),
);
void main() {
  late ChatAdapter adapter;
  late FakeSessionStorage storage;
  late ApiClient client;
  late ProviderChatAuth auth;
  late ProviderChatController c;
  setUp(() async {
    adapter = ChatAdapter();
    storage = FakeSessionStorage()..session = session(7);
    client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      adapter: adapter,
    );
    auth = ProviderChatAuth(
      client,
      storage,
      ProviderSessionApi(client, storage, DateTime.now),
    );
    await auth.restore();
    c = ProviderChatController(
      40,
      ProviderChatRepository(auth),
      auth,
      onRead: () {},
    )..active = true;
  });
  tearDown(() {
    c.dispose();
    auth.close();
    client.close();
  });
  test(
    'uses provider prefix and catches up all newer pages without duplicates',
    () async {
      adapter.handler = (r) async {
        expect(r.path.startsWith('/providers/me/'), isTrue);
        final after = r.uri.queryParameters['after'];
        return json(
          after == null
              ? thread(messages: [msg(100)], more: true)
              : after == '100'
              ? thread(messages: [msg(101)], more: true)
              : thread(messages: [msg(101), msg(102)]),
        );
      };
      await c.refresh();
      expect(c.messages.map((m) => m['messageId']), [100, 101, 102]);
      expect(adapter.calls.length, 3);
    },
  );
  test(
    'uncertain send reuses id and text; no duplicate optimistic bubble',
    () async {
      var first = true;
      final ids = <String>[];
      adapter.handler = (r) async {
        if (r.method == 'GET') return json(thread());
        final id = (r.data as Map)['clientMessageId'] as String;
        ids.add(id);
        if (first) {
          first = false;
          throw const NetworkException(
            kind: NetworkExceptionKind.timeout,
            message: 'Timeout',
          );
        }
        expect((r.data as Map)['text'], 'Hello');
        return json(msg(101, own: true, client: id), 201);
      };
      await c.refresh();
      await c.send('Hello');
      expect(c.pendingId, isNotNull);
      await c.send('Changed draft');
      expect(ids.toSet().length, 1);
      expect(c.messages.length, 2);
      expect(c.pendingId, isNull);
    },
  );
  test(
    'late account-switch response never exposes messages or sends as new owner',
    () async {
      final pending = Completer<ResponseBody>();
      adapter.handler = (_) => pending.future;
      final read = c.refresh();
      await Future<void>.delayed(Duration.zero);
      storage.session = session(8);
      pending.complete(json(thread()));
      await read;
      expect(c.messages, isEmpty);
      expect(auth.user, isNull);
      final count = adapter.calls.length;
      await c.send('No');
      expect(adapter.calls.length, count);
    },
  );
  test('read-only and unavailable chat block sending; wrong-role does not erase session', () async {
    adapter.handler = (_) async => json(thread(canSend: false));
    await c.refresh();
    await c.send('No');
    expect(adapter.calls.where((r) => r.method == 'POST'), isEmpty);
    adapter.handler = (_) async => json({'detail': 'Forbidden'}, 403);
    await c.refresh(full: true);
    expect(storage.session, isNotNull);
    expect(c.unavailable, isTrue);
  });
  test(
    'read receipt only for displayed messages and polling stops when hidden',
    () async {
      adapter.handler = (r) async => r.path.endsWith('/read')
          ? json({'jobId': 40, 'yourLastReadMessageId': 100})
          : json(thread());
      await c.refresh();
      expect(adapter.calls.length, 1);
      await c.displayed(100);
      expect(adapter.calls.length, 2);
      c.visible(false);
      await c.refresh();
      await c.displayed(101);
      expect(adapter.calls.length, 2);
    },
  );
  test(
    'uncertain send can be checked with the same ID after chat closes',
    () async {
      adapter.handler = (_) async => json(thread());
      await c.refresh();
      c.pendingId = '11111111-1111-4111-8111-111111111111';
      c.pendingText = 'Hello';
      c.canSend = false;
      adapter.handler = (r) async {
        expect((r.data as Map)['clientMessageId'], c.pendingId);
        return json(msg(101, own: true, client: c.pendingId), 201);
      };
      await c.send('different');
      expect(c.pendingId, isNull);
      expect(c.messages.last['messageId'], 101);
    },
  );
  test(
    'shared session refresh updates inbox badge after a chat read',
    () async {
      var unread = 3;
      adapter.handler = (_) async =>
          json({'conversations': [], 'totalUnread': unread});
      final inbox = ChatInbox(ProviderChatRepository(auth), auth);
      addTearDown(inbox.dispose);
      for (var i = 0; inbox.busy && i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(inbox.unread, 3);
      unread = 0;
      auth.refreshInboxes();
      for (var i = 0; inbox.busy && i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(inbox.unread, 0);
    },
  );

  test(
    'chat deadline uses HTTP Date rather than a wrong phone clock',
    () async {
      adapter.handler = (_) async => ResponseBody.fromString(
        jsonEncode({...thread(), 'sendUntil': '2030-01-01T00:00:10Z'}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          'date': ['Tue, 01 Jan 2030 00:00:20 GMT'],
        },
      );
      await c.refresh();
      expect(c.allowed, isFalse);
    },
  );
}
