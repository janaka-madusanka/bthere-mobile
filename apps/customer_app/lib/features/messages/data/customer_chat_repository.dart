import 'dart:math';
import 'dart:io' show HttpDate;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../../auth/data/customer_auth_service.dart';
import '../../discovery/domain/customer_discovery.dart';

final customerChatRepositoryProvider = Provider(
  (ref) => CustomerChatRepository(ref.watch(customerAuthServiceProvider)),
  dependencies: [customerAuthServiceProvider],
);

class ChatProblem implements Exception {
  ChatProblem(this.status, this.message, {this.retrySeconds = 0, this.detail});
  final int status, retrySeconds;
  final String? detail;
  final String message;
  @override
  String toString() => 'ChatProblem(status=$status)';
}

class ChatPage {
  ChatPage(Object? raw, int jobId) : data = object(raw) {
    if (data['jobId'] != jobId ||
        data['canSend'] is! bool ||
        data['messages'] is! List ||
        data['participants'] is! List ||
        data['hasOlder'] is! bool ||
        data['hasNewer'] is! bool) {
      throw const FormatException('Invalid chat response');
    }
    for (final raw in data['messages'] as List) {
      chatMessage(raw);
    }
    if (data['sendUntil'] != null &&
        DateTime.tryParse('${data['sendUntil']}') == null) {
      throw const FormatException('Invalid chat deadline');
    }
  }
  final Map<String, dynamic> data;
  List<Map<String, dynamic>> get messages =>
      (data['messages'] as List).map(object).toList();
}

Map<String, dynamic> chatMessage(Object? raw) {
  final m = object(raw);
  positiveId(m['messageId']);
  if (m['fromYou'] is! bool ||
      m['contactInfoHidden'] is! bool ||
      (m['text'] != null && m['text'] is! String) ||
      DateTime.tryParse('${m['sentAt']}') == null) {
    throw const FormatException('Invalid chat message');
  }
  return m;
}

class CustomerChatRepository {
  CustomerChatRepository(this.auth);
  final CustomerAuthService auth;
  DateTime? _serverTime;
  final _sinceServerTime = Stopwatch();
  DateTime now() =>
      _serverTime?.add(_sinceServerTime.elapsed) ?? DateTime.now().toUtc();
  static final _random = Random.secure();
  static String newMessageId() => List.generate(
    24,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Future<Object?> _request(String method, String path, {Object? data}) async {
    final response = await auth.bookingRequest(
      method,
      path,
      data: data,
      safeRead: method == 'GET',
    );
    final date = response.headers.value('date');
    if (date != null) {
      try {
        _serverTime = HttpDate.parse(date).toUtc();
        _sinceServerTime
          ..reset()
          ..start();
      } catch (_) {
        /* Invalid Date headers do not replace a valid clock. */
      }
    }
    if (response.statusCode !=
        (method == 'POST' && !path.endsWith('/read') ? 201 : 200)) {
      final body = response.data is Map ? response.data as Map : const {};
      final retry =
          int.tryParse('${body['retryAfterSeconds']}') ??
          int.tryParse(response.headers.value('retry-after') ?? '') ??
          1;
      final detail = body['detail'] ?? body['message'];
      throw ChatProblem(
        response.statusCode ?? 0,
        response.statusCode == 400 && detail is String
            ? detail
            : switch (response.statusCode) {
                403 =>
                  'This account does not have access to customer booking chat.',
                404 => 'This booking chat is unavailable.',
                409 => switch (detail) {
                  'Chat opens once the booking is confirmed' =>
                    'Chat opens once the booking is confirmed.',
                  'This chat is closed for new messages' =>
                    'This chat is closed. You can still read past messages.',
                  _ => 'Chat availability has changed. Please check again.',
                },
                429 => 'Please wait before sending another message.',
                _ => 'Chat could not be updated. Please try again.',
              },
        retrySeconds: retry.clamp(1, 3600),
        detail: detail is String ? detail : null,
      );
    }
    return response.data;
  }

  Future<Map<String, dynamic>> inbox() async {
    final value = object(await _request('GET', '/customers/me/conversations'));
    if (value['conversations'] is! List ||
        value['totalUnread'] is! int ||
        (value['totalUnread'] as int) < 0) {
      throw const FormatException('Invalid inbox');
    }
    for (final raw in value['conversations']) {
      final row = object(raw);
      positiveId(row['jobId']);
      if (row['participants'] is! List ||
          row['canSend'] is! bool ||
          row['unreadCount'] is! int) {
        throw const FormatException('Invalid conversation');
      }
    }
    return value;
  }

  Future<ChatPage> page(int job, {int? after, int? before}) async => ChatPage(
    await _request(
      'GET',
      '/customers/me/bookings/$job/messages'
          '${after != null
              ? '?after=$after'
              : before != null
              ? '?before=$before'
              : ''}',
    ),
    job,
  );

  Future<Map<String, dynamic>> send(int job, String text, String id) async =>
      chatMessage(
        await _request(
          'POST',
          '/customers/me/bookings/$job/messages',
          data: {'text': text, 'clientMessageId': id},
        ),
      );

  Future<void> read(int job, int message) async {
    final value = object(
      await _request(
        'POST',
        '/customers/me/bookings/$job/messages/read',
        data: {'lastReadMessageId': message},
      ),
    );
    if (value['jobId'] != job ||
        value['yourLastReadMessageId'] is! int ||
        (value['yourLastReadMessageId'] as int) < message) {
      throw const FormatException('Invalid read receipt');
    }
  }
}
