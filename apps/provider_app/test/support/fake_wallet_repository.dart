import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/features/wallet/data/wallet_repository.dart';
import 'package:provider_app/features/wallet/domain/wallet_models.dart';

Map<String, dynamic> walletBalanceJson({
  Object available = '12480.00',
  String mode = 'MOCK',
}) => {
  'walletId': 10,
  'currencyCode': 'LKR',
  'available': available,
  'reserved': '0',
  'pending': '2350.00',
  'status': 'ACTIVE',
  'fundingMode': mode,
};

WalletSnapshot walletSnapshot({
  bool enabled = true,
  bool balanced = true,
  bool empty = false,
}) => WalletSnapshot(
  capabilities: WalletCapabilities(
    ledger: true,
    topups: enabled,
    withdrawals: enabled,
    cardLinking: enabled,
    bankLinking: enabled,
  ),
  balance: WalletBalance.fromJson(walletBalanceJson()),
  balanced: balanced,
  methods: empty
      ? []
      : [
          WalletMethod.fromJson({
            'methodId': 5,
            'type': 'CARD',
            'displayLabel': 'TEST CARD **** 4242',
            'status': 'VERIFIED_MOCK',
          }),
          WalletMethod.fromJson({
            'methodId': 6,
            'type': 'BANK_ACCOUNT',
            'displayLabel': 'TEST BANK **** 0001',
            'status': 'VERIFIED_MOCK',
          }),
        ],
  history: WalletHistory.fromJson({
    'content': empty
        ? []
        : [
            {
              'entryId': 31,
              'operationId': 41,
              'bucket': 'AVAILABLE',
              'delta': '3500.00',
              'balanceBefore': '8980.00',
              'balanceAfter': '12480.00',
              'createdAt': '2026-10-17T12:00:00',
            },
            {
              'entryId': 30,
              'operationId': 40,
              'bucket': 'AVAILABLE',
              'delta': '-2000.00',
              'balanceBefore': '10980.00',
              'balanceAfter': '8980.00',
              'createdAt': '2026-10-16T12:00:00',
            },
            {
              'entryId': 29,
              'operationId': 40,
              'bucket': 'RESERVED',
              'delta': '2000.00',
              'balanceBefore': '0',
              'balanceAfter': '2000.00',
              'createdAt': '2026-10-16T12:00:00',
            },
          ],
    'number': 0,
    'last': true,
  }),
);

class FakeWalletRepository extends Fake implements WalletRepository {
  WalletSnapshot snapshot = walletSnapshot();
  int loads = 0, creates = 0, events = 0, setups = 0;
  Object? createError, loadError;
  WalletRequest? lastRequest;
  WalletIntent currentIntent = WalletIntent.fromJson({
    'intentId': 21,
    'purpose': 'TOPUP',
    'status': 'PENDING',
    'amount': '1000.00',
  });
  @override
  Future<WalletSnapshot> load() async {
    loads++;
    if (loadError != null) throw loadError!;
    return snapshot;
  }

  @override
  Future<WalletHistory> history({int page = 0}) async => snapshot.history;
  @override
  Future<WalletIntent> create(WalletRequest request) async {
    creates++;
    lastRequest = request;
    if (createError != null) throw createError!;
    return currentIntent;
  }

  @override
  Future<WalletIntent> intent(int id) async => currentIntent;
  @override
  Future<WalletMethod> setup(String type) async {
    setups++;
    final method = WalletMethod.fromJson({
      'methodId': type == 'CARD' ? 5 : 6,
      'type': type,
      'displayLabel': type == 'CARD'
          ? 'TEST CARD **** 4242'
          : 'TEST BANK **** 0001',
      'status': 'VERIFIED_MOCK',
    });
    snapshot = WalletSnapshot(
      capabilities: snapshot.capabilities,
      balance: snapshot.balance,
      methods: [
        ...snapshot.methods.where((value) => value.id != method.id),
        method,
      ],
      history: snapshot.history,
      balanced: snapshot.balanced,
    );
    return method;
  }

  @override
  Future<List<WalletBalance>> wallets() async => [snapshot.balance];
  @override
  Future<WalletCapabilities> walletCapabilities() async =>
      snapshot.capabilities;
  @override
  Future<WalletReconciliation> reconciliation() async =>
      WalletReconciliation.fromJson({
        'walletId': snapshot.balance.id,
        'balanced': snapshot.balanced,
        'available': snapshot.balance.available.decimal,
        'reserved': snapshot.balance.reserved.decimal,
        'pending': snapshot.balance.pending.decimal,
      });
  @override
  Future<WalletIntent> simulate(int id, String outcome) async {
    events++;
    currentIntent = WalletIntent.fromJson({
      'intentId': id,
      'purpose': currentIntent.purpose,
      'status': {
        'SUCCESS': 'SUCCEEDED',
        'FAILURE': 'FAILED',
        'PENDING': 'PENDING',
        'REFUND': 'REFUNDED',
      }[outcome],
      'amount': currentIntent.amount.decimal,
    });
    return currentIntent;
  }
}

class MemoryWalletJournal implements WalletJournal {
  final savedIds = <int, List<int>>{};
  @override
  Future<List<int>> intentIds(int owner) async => savedIds[owner] ?? [];
  @override
  Future<void> rememberIntent(int owner, int id) async {
    savedIds[owner] = [id, ...?savedIds[owner]?.where((value) => value != id)];
  }

  final requests = <int, WalletRequest>{};
  @override
  Future<WalletRequest?> read(int owner) async => requests[owner];
  @override
  Future<void> write(int owner, WalletRequest request) async {
    requests[owner] = request;
  }

  @override
  Future<void> clear(int owner) async {
    requests.remove(owner);
  }
}
