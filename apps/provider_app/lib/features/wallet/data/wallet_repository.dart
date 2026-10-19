import 'dart:convert';
import 'dart:math';

import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../../app/providers/app_providers.dart';
import '../domain/wallet_models.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(ref.watch(apiClientProvider)),
  dependencies: [apiClientProvider],
);

/// All paths are relative to /api/v1. No administrator or customer booking APIs.
class WalletRepository {
  WalletRepository(this.client);
  final ApiClient client;
  static const base = '/me/wallets/LKR';
  Options get _plain => Options(responseType: ResponseType.plain);
  Future<Object?> _get(String path, {Map<String, dynamic>? query}) async {
    final decoded = decodeWalletJson(
      (await client.get<String>(
        path,
        requiresAuth: true,
        queryParameters: query,
        options: _plain,
      )).data!,
    );
    if (kDebugMode) {
      // Log schema only: never payment data, account details, or credentials.
      final shape = decoded is Map
          ? decoded.map(
              (key, value) =>
                  MapEntry(key.toString(), value.runtimeType.toString()),
            )
          : decoded.runtimeType.toString();
      debugPrint('[WalletSchema] $path $shape');
    }
    return decoded;
  }

  Future<WalletCapabilities> capabilities() async =>
      WalletCapabilities.fromJson(await _get('/me/payment-settings'));

  Future<WalletCapabilities> walletCapabilities() async =>
      WalletCapabilities.fromJson({
        'capabilities': await _get('/me/wallet-capabilities'),
      });

  Future<List<WalletBalance>> wallets() async =>
      (await _get('/me/wallets') as List).map(WalletBalance.fromJson).toList();

  Future<WalletBalance> open() async => WalletBalance.fromJson(
    decodeWalletJson(
      (await client.put<String>(
        base,
        requiresAuth: true,
        options: _plain,
      )).data!,
    ),
  );

  Future<WalletReconciliation> reconciliation() async =>
      WalletReconciliation.fromJson(await _get('$base/reconciliation'));

  Future<WalletBalance> balance() async {
    try {
      return WalletBalance.fromJson(await _get(base));
    } on NetworkException catch (e) {
      if (e.statusCode != 404) rethrow;
      return open();
    }
  }

  Future<List<WalletMethod>> methods() async =>
      (await _get('/me/payment-methods') as List)
          .map(WalletMethod.fromJson)
          .toList();

  Future<WalletMethod> setup(String type) async {
    if (!['CARD', 'BANK_ACCOUNT'].contains(type)) {
      throw const FormatException('Invalid method');
    }
    return WalletMethod.fromJson(
      decodeWalletJson(
        (await client.post<String>(
          '/me/payment-methods/setup',
          queryParameters: {'type': type},
          requiresAuth: true,
          options: _plain,
        )).data!,
      ),
    );
  }

  Future<WalletHistory> history({int page = 0}) async => WalletHistory.fromJson(
    await _get('$base/transactions', query: {'page': page, 'size': 20}),
  );

  Future<WalletSnapshot> load() async {
    final settings = await capabilities();
    if (!settings.ledger) {
      throw StateError('Wallet balance and history are currently unavailable.');
    }
    final b = await balance();
    final result = await Future.wait<Object?>([
      methods(),
      history(),
      reconciliation(),
    ]);
    final report = result[2] as WalletReconciliation;
    if (report.walletId != b.id) {
      throw const FormatException('Invalid reconciliation response');
    }
    return WalletSnapshot(
      capabilities: settings,
      balance: b,
      methods: result[0] as List<WalletMethod>,
      history: result[1] as WalletHistory,
      balanced: report.balanced,
    );
  }

  Future<WalletIntent> create(WalletRequest request) async {
    if (!request.amount.validPayment ||
        !['TOPUP', 'WITHDRAWAL'].contains(request.purpose) ||
        (request.purpose == 'WITHDRAWAL' && request.methodId == null)) {
      throw const FormatException('Invalid payment request');
    }
    // A raw decimal token avoids converting integer hundredths to double.
    final body =
        '{"amount":${request.amount.decimal},"methodId":${request.methodId ?? 'null'}}';
    return WalletIntent.fromJson(
      decodeWalletJson(
        (await client.post<String>(
          '$base/${request.purpose == 'TOPUP' ? 'topups' : 'withdrawals'}',
          requiresAuth: true,
          data: body,
          options: Options(
            responseType: ResponseType.plain,
            contentType: 'application/json',
            headers: {'Idempotency-Key': request.key},
          ),
        )).data!,
      ),
    );
  }

  Future<WalletIntent> intent(int id) async =>
      WalletIntent.fromJson(await _get('/me/payment-intents/$id'));

  /// Only invoked by explicitly labelled test-result controls, never on submit.
  Future<WalletIntent> simulate(int id, String outcome) async {
    if (!['SUCCESS', 'FAILURE', 'PENDING', 'REFUND'].contains(outcome)) {
      throw const FormatException('Unsupported test outcome');
    }
    return WalletIntent.fromJson(
      decodeWalletJson(
        (await client.post<String>(
          '/me/mock-payments/$id/events',
          requiresAuth: true,
          data: {'outcome': outcome},
          options: _plain,
        )).data!,
      ),
    );
  }
}

class WalletRequest {
  const WalletRequest({
    required this.purpose,
    required this.amount,
    required this.methodId,
    required this.key,
    this.intentId,
  });
  factory WalletRequest.newRequest(
    String purpose,
    WalletMoney amount,
    int? methodId,
  ) => WalletRequest(
    purpose: purpose,
    amount: amount,
    methodId: methodId,
    key:
        '${purpose.toLowerCase()}-${DateTime.now().microsecondsSinceEpoch}-${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}',
  );
  factory WalletRequest.fromJson(Map<String, dynamic> j) => WalletRequest(
    purpose: j['purpose'] as String,
    amount: WalletMoney.parse(j['amount']),
    methodId: j['methodId'] as int?,
    key: j['key'] as String,
    intentId: j['intentId'] as int?,
  );
  final String purpose, key;
  final WalletMoney amount;
  final int? methodId, intentId;
  WalletRequest withIntent(int id) => WalletRequest(
    purpose: purpose,
    amount: amount,
    methodId: methodId,
    key: key,
    intentId: id,
  );
  Map<String, dynamic> toJson() => {
    'purpose': purpose,
    'amount': amount.decimal,
    'methodId': methodId,
    'key': key,
    'intentId': intentId,
  };
}

/// Durable, account-scoped retry journal. Persist before sending a mutation.
abstract interface class WalletJournal {
  Future<WalletRequest?> read(int owner);
  Future<void> write(int owner, WalletRequest request);
  Future<void> clear(int owner);
  Future<List<int>> intentIds(int owner);
  Future<void> rememberIntent(int owner, int id);
}

class SecureWalletJournal implements WalletJournal {
  const SecureWalletJournal();
  static const _store = FlutterSecureKeyValueStore();
  String _key(int owner) => 'bthere.wallet.pending.$owner';
  @override
  Future<List<int>> intentIds(int owner) async {
    final raw = await _store.read('${_key(owner)}.intents');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<int>();
  }

  @override
  Future<void> rememberIntent(int owner, int id) async {
    final ids = await intentIds(owner);
    await _store.write(
      '${_key(owner)}.intents',
      jsonEncode([id, ...ids.where((value) => value != id)].take(50).toList()),
    );
  }

  @override
  Future<WalletRequest?> read(int owner) async {
    final raw = await _store.read(_key(owner));
    return raw == null
        ? null
        : WalletRequest.fromJson(walletObject(jsonDecode(raw)));
  }

  @override
  Future<void> write(int owner, WalletRequest request) =>
      _store.write(_key(owner), jsonEncode(request.toJson()));
  @override
  Future<void> clear(int owner) => _store.delete(_key(owner));
}

final walletJournalProvider = Provider<WalletJournal>(
  (ref) => const SecureWalletJournal(),
);
