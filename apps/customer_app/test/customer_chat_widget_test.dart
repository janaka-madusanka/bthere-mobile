import 'package:customer_app/features/messages/presentation/customer_messages_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_auth_test.dart' show Fixture;
import 'customer_chat_test.dart' show jsonResponse, page, message;
import 'customer_discovery_test.dart' show marketEntry, continueMarket;

void main() {
  testWidgets(
    'booking chat stays open on unavailable response and Retry recovers',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      var unavailable = true;
      bool? available;
      f.adapter.extraHandler = (r) async {
        if (r.path.endsWith('/messages/read')) {
          return jsonResponse({'jobId': 40, 'yourLastReadMessageId': 100});
        }
        if (r.path.endsWith('/messages')) {
          return unavailable
              ? jsonResponse({
                  'detail': 'Booking chat is not available yet.',
                }, 404)
              : jsonResponse(page());
        }
        return null;
      };
      await marketEntry(tester, f);
      await continueMarket(tester);
      final closed = showBookingChatSheet(
        tester.element(find.byKey(const ValueKey('customer-home-account'))),
        40,
        participant: {'displayName': 'Tharushi Silva'},
        onAvailabilityChanged: (value) => available = value,
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomerChatScreen), findsOneWidget);
      expect(find.byTooltip('Close chat'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-draft')), findsNothing);
      expect(available, isFalse);
      unavailable = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-draft')), findsOneWidget);
      expect(available, isTrue);
      await tester.tap(find.byTooltip('Close chat'));
      await tester.pumpAndSettle();
      await closed;
      expect(
        f.adapter.requests.where(
          (r) => r.path.endsWith('/messages') && r.method == 'POST',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'booking chat opens as a rounded sheet and keeps composer usable above keyboard',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      f.adapter.extraHandler = (r) async {
        if (r.path.endsWith('/messages/read')) {
          return jsonResponse({'jobId': 40, 'yourLastReadMessageId': 100});
        }
        if (r.path.endsWith('/messages')) return jsonResponse(page());
        return null;
      };
      await marketEntry(tester, f);
      await continueMarket(tester);
      final context = tester.element(
        find.byKey(const ValueKey('customer-home-account')),
      );
      final closed = showBookingChatSheet(
        context,
        40,
        participant: {'displayName': 'Tharushi Silva'},
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CustomerChatScreen>(find.byType(CustomerChatScreen))
            .embedded,
        isTrue,
      );
      expect(find.text('Tharushi Silva'), findsOneWidget);
      expect(
        tester.getSize(find.byType(CustomerChatScreen)).height,
        closeTo(422, 1),
      );
      await tester.enterText(find.byKey(const ValueKey('chat-draft')), 'Hello');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('chat-send')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close chat'));
      await tester.pumpAndSettle();
      await closed;
      expect(find.byType(CustomerChatScreen), findsNothing);
      expect(
        f.adapter.requests.where(
          (r) => r.path.endsWith('/messages') && r.method == 'POST',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'inbox opens booking chat, renders masked/plain text and sends explicitly',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      String? clientId;
      f.adapter.extraHandler = (r) async {
        if (r.path.endsWith('/conversations')) {
          return jsonResponse({
            'conversations': [
              {
                'jobId': 40,
                'jobStatus': 'CONFIRMED',
                'canSend': true,
                'participants': [
                  {'displayName': 'Tharushi', 'you': false},
                ],
                'lastMessage': null,
                'unreadCount': 1,
              },
            ],
            'totalUnread': 1,
          });
        }
        if (r.path.endsWith('/messages/read')) {
          return jsonResponse({
            'jobId': 40,
            'yourLastReadMessageId': 103,
            'unreadCount': 0,
          });
        }
        if (r.path.endsWith('/messages')) {
          if (r.method == 'POST') {
            clientId = (r.data as Map)['clientMessageId'] as String;
            return jsonResponse(
              message(104, client: clientId, own: true, text: 'Call [hidden]'),
              201,
            );
          }
          return jsonResponse(
            page(
              messages: [
                message(101, text: 'Call [hidden]'),
                message(102, text: null),
                message(103, text: '<b>Hello</b>'),
              ],
            ),
          );
        }
        return null;
      };
      await marketEntry(tester, f);
      await continueMarket(tester);
      GoRouter.of(
        tester.element(find.byKey(const ValueKey('customer-nav-home'))),
      ).go('/messages');
      await tester.pumpAndSettle();
      expect(find.text('Tharushi'), findsOneWidget);
      expect(find.text('Start a conversation'), findsOneWidget);
      await tester.tap(find.text('Tharushi'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerChatScreen), findsOneWidget);
      expect(find.text('Message unavailable'), findsOneWidget);
      expect(find.text('<b>Hello</b>'), findsOneWidget);
      expect(
        find.text('Contact details are hidden for your safety.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('chat-draft')),
        'Call 0771234567',
      );
      await tester.pump();
      expect(clientId, isNull);
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pumpAndSettle();
      expect(clientId, isNotNull);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat-draft')))
            .controller!
            .text,
        isEmpty,
      );
      final before = f.adapter.requests
          .where((r) => r.path.endsWith('/messages'))
          .length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(
        f.adapter.requests.where((r) => r.path.endsWith('/messages')).length,
        before,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to messages'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closed chat hides composer and fits narrow enlarged text', (
    tester,
  ) async {
    final f = Fixture();
    addTearDown(f.dispose);
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    f.wrapApp = (child) => MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: child,
    );
    f.adapter.extraHandler = (r) async {
      if (r.path.endsWith('/conversations')) {
        return jsonResponse({
          'conversations': [
            {
              'jobId': 40,
              'canSend': false,
              'unreadCount': 0,
              'participants': [
                {'displayName': 'Provider with a long name', 'you': false},
              ],
              'lastMessage': null,
            },
          ],
          'totalUnread': 0,
        });
      }
      if (r.path.endsWith('/messages/read')) {
        return jsonResponse({'jobId': 40, 'yourLastReadMessageId': 100});
      }
      if (r.path.endsWith('/messages')) return jsonResponse(page(send: false));
      return null;
    };
    await marketEntry(tester, f);
    await continueMarket(tester);
    GoRouter.of(tester.element(find.byKey(const ValueKey('customer-nav-home'))))
        .go('/messages');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Provider with a long name'));
    await tester.pumpAndSettle();
    expect(
      find.text('This chat is closed. You can still read past messages.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('chat-draft')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'sent messages show one grey tick and read messages two blue ticks',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.extraHandler = (r) async {
        if (r.path.endsWith('/messages')) {
          return jsonResponse(
            page(
              messages: [message(100, own: true), message(101, own: true)],
              seen: 100,
            ),
          );
        }
        if (r.path.endsWith('/messages/read')) {
          return jsonResponse({'jobId': 40, 'yourLastReadMessageId': 101});
        }
        return null;
      };
      await marketEntry(tester, f);
      await continueMarket(tester);
      final closed = showBookingChatSheet(
        tester.element(find.byKey(const ValueKey('customer-home-account'))),
        40,
      );
      await tester.pumpAndSettle();
      final seen = tester.widget<Icon>(find.byIcon(Icons.done_all_rounded));
      final sent = tester.widget<Icon>(find.byIcon(Icons.done_rounded));
      expect(seen.color, const Color(0xFF2196F3));
      expect(seen.semanticLabel, 'Seen');
      expect(sent.color, const Color(0xFF68718B));
      expect(sent.semanticLabel, 'Sent');
      await tester.tap(find.byTooltip('Close chat'));
      await tester.pumpAndSettle();
      await closed;
      await tester.pumpWidget(const SizedBox());
    },
  );
}
