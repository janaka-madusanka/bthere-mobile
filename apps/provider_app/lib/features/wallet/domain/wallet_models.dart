import 'dart:convert';

/// Money remains integer hundredths, including at the JSON boundary.
class WalletMoney implements Comparable<WalletMoney> {
  WalletMoney(this.minor);
  final BigInt minor;
  static final zero = WalletMoney(BigInt.zero);
  factory WalletMoney.parse(Object? value) {
    final text = value.toString();
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$')
        .firstMatch(text);
    if (match == null) {
      throw const FormatException('Enter an amount with at most two decimals.');
    }
    final fraction = match[3] ?? '';
    final exponent = int.tryParse(match[4] ?? '0');
    if (exponent == null || exponent.abs() > 100) {
      throw const FormatException('Invalid wallet amount.');
    }
    final coefficient = BigInt.parse('${match[2]}$fraction');
    final shift = 2 + exponent - fraction.length;
    BigInt units;
    if (shift >= 0) {
      units = coefficient * BigInt.from(10).pow(shift);
    } else {
      final divisor = BigInt.from(10).pow(-shift);
      if (coefficient.remainder(divisor) != BigInt.zero) {
        throw const FormatException(
          'Enter an amount with at most two decimals.',
        );
      }
      units = coefficient ~/ divisor;
    }
    return WalletMoney(match[1] == '-' ? -units : units);
  }

  String get decimal {
    final digits = minor.abs().toString().padLeft(3, '0');
    return '${minor.isNegative ? '-' : ''}${digits.substring(0, digits.length - 2)}.${digits.substring(digits.length - 2)}';
  }

  String get formatted {
    final parts = decimal.split('.');
    return '${parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}.${parts[1]}';
  }

  bool get validPayment =>
      minor > BigInt.zero && minor <= BigInt.parse('9999999999999999');
  @override
  int compareTo(WalletMoney other) => minor.compareTo(other.minor);
}

Map<String, dynamic> walletObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid wallet response');
  }
  return value;
}

Object? decodeWalletJson(String raw) => jsonDecode(
  raw.replaceAllMapped(
    RegExp(
      r'("(?:available|reserved|pending|amount|delta|balanceBefore|balanceAfter)"\s*:\s*)(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)(?=\s*[,}])',
    ),
    (m) => '${m[1]}"${m[2]}"',
  ),
);

class WalletCapabilities {
  const WalletCapabilities({
    this.ledger = false,
    this.topups = false,
    this.withdrawals = false,
    this.cardLinking = false,
    this.bankLinking = false,
  });
  factory WalletCapabilities.fromJson(Object? value) {
    final j = walletObject(walletObject(value)['capabilities']);
    return WalletCapabilities(
      ledger: j['walletLedger'] == true,
      topups: j['topups'] == true,
      withdrawals: j['withdrawals'] == true,
      cardLinking: j['cardLinking'] == true,
      bankLinking: j['bankLinking'] == true,
    );
  }
  final bool ledger, topups, withdrawals, cardLinking, bankLinking;
}

class WalletBalance {
  WalletBalance.fromJson(Object? value) {
    final j = walletObject(value);
    id = j['walletId'] as int;
    currency = j['currencyCode'] as String;
    if (currency != 'LKR') throw const FormatException('Unsupported currency');
    available = WalletMoney.parse(j['available']);
    reserved = WalletMoney.parse(j['reserved']);
    pending = WalletMoney.parse(j['pending']);
    status = j['status'] as String;
    fundingMode = j['fundingMode'] as String?;
  }
  late final int id;
  late final String currency, status;
  late final String? fundingMode;
  late final WalletMoney available, reserved, pending;
  bool get mock => fundingMode == 'MOCK';
}

class WalletMethod {
  WalletMethod.fromJson(Object? value) {
    final j = walletObject(value);
    id = j['methodId'] as int;
    type = j['type'] as String;
    label = j['displayLabel'] as String;
    status = j['status'] as String;
  }
  late final int id;
  late final String type, label, status;
  bool get card => type == 'CARD';
  bool get usable => status == 'VERIFIED_MOCK';
}

class WalletEntry {
  WalletEntry.fromJson(Object? value) {
    final j = walletObject(value);
    id = j['entryId'] as int;
    operationId = j['operationId'] as int;
    bucket = j['bucket'] as String;
    delta = WalletMoney.parse(j['delta']);
    before = WalletMoney.parse(j['balanceBefore']);
    after = WalletMoney.parse(j['balanceAfter']);
    createdAt = DateTime.parse(j['createdAt'] as String);
  }
  late final int id, operationId;
  late final String bucket;
  late final WalletMoney delta, before, after;
  // API timestamps have no offset; preserve the supplied local wall time.
  late final DateTime createdAt;
}

class WalletHistory {
  WalletHistory.fromJson(Object? value) {
    final j = walletObject(value);
    entries = (j['content'] as List).map(WalletEntry.fromJson).toList();
    page = j['number'] as int;
    last = j['last'] as bool;
  }
  late final List<WalletEntry> entries;
  late final int page;
  late final bool last;
}

class WalletIntent {
  WalletIntent.fromJson(Object? value) {
    final j = walletObject(value);
    id = j['intentId'] as int;
    purpose = j['purpose'] as String;
    status = j['status'] as String;
    amount = WalletMoney.parse(j['amount']);
  }
  late final int id;
  late final String purpose, status;
  late final WalletMoney amount;
  bool get terminal => ['SUCCEEDED', 'FAILED', 'REFUNDED'].contains(status);
}

class WalletSnapshot {
  const WalletSnapshot({
    required this.capabilities,
    required this.balance,
    required this.methods,
    required this.history,
    required this.balanced,
  });
  final WalletCapabilities capabilities;
  final WalletBalance balance;
  final List<WalletMethod> methods;
  final WalletHistory history;
  final bool balanced;
  bool get canMove =>
      balanced &&
      balance.status == 'ACTIVE' &&
      [null, 'UNFUNDED', 'MOCK'].contains(balance.fundingMode);
}

class WalletReconciliation {
  WalletReconciliation.fromJson(Object? value) {
    final j = walletObject(value);
    walletId = j['walletId'] as int;
    balanced = j['balanced'] as bool;
    available = WalletMoney.parse(j['available']);
    reserved = WalletMoney.parse(j['reserved']);
    pending = WalletMoney.parse(j['pending']);
  }
  late final int walletId;
  late final bool balanced;
  late final WalletMoney available, reserved, pending;
}
