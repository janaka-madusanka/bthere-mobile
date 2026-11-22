import 'package:bthere_network/bthere_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/core/auth/provider_session_api.dart';
import 'package:provider_app/features/messages/application/provider_chat_auth.dart';
import 'package:provider_app/features/messages/presentation/messages_screen.dart';
import 'package:provider_app/features/messages/presentation/provider_chat_views.dart';

import 'support/fake_session_storage.dart';
import 'provider_chat_test.dart' show ChatAdapter, session, json, thread, msg;

void main() {
  testWidgets(
    'real provider inbox opens shared chat, reads visible messages and sends once',
    (tester) async {
      final adapter = ChatAdapter();
      final storage = FakeSessionStorage()..session = session(7);
      final client = ApiClient(
        config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
        adapter: adapter,
      );
      final auth = ProviderChatAuth(
        client,
        storage,
        ProviderSessionApi(client, storage, DateTime.now),
      );
      await auth.restore();
      adapter.handler = (r) async {
        if (r.path.endsWith('/conversations')) {
          return json({
            'conversations': [
              {
                'jobId': 40,
                'jobStatus': 'CONFIRMED',
                'canSend': true,
                'participants': [
                  {'displayName': 'Customer', 'role': 'CUSTOMER', 'you': false},
                ],
                'lastMessage': null,
                'unreadCount': 1,
              },
            ],
            'totalUnread': 1,
          });
        }
        if (r.path.endsWith('/read')) {
          return json({'jobId': 40, 'yourLastReadMessageId': 100});
        }
        if (r.method == 'POST') {
          return json(
            msg(
              101,
              own: true,
              client: (r.data as Map)['clientMessageId'] as String,
            ),
            201,
          );
        }
        return json(thread());
      };
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const MessagesScreen())],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
            ),
            providerChatBootstrapProvider.overrideWith((ref) async => auth),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Customer'), findsOneWidget);
      await tester.tap(find.text('Customer'));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderChatScreen), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('chat-draft')), 'Hello');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pumpAndSettle();
      expect(
        adapter.calls.where(
          (r) => r.method == 'POST' && r.path.endsWith('/messages'),
        ),
        hasLength(1),
      );
      await tester.tap(find.byTooltip('Close chat'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      router.dispose();
      auth.close();
      client.close();
    },
  );
}
