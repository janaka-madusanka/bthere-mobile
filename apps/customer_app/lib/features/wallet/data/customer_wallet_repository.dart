import '../../auth/data/customer_auth_service.dart';

/// Monetary values use integer minor units, never floating-point arithmetic.
BigInt walletMinorUnits(Object? value) {
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$')
      .firstMatch('$value');
  if (match == null) throw const FormatException('Invalid money');
  final fraction = match[3] ?? '';
  final exponent = int.parse(match[4] ?? '0') + 2 - fraction.length;
  if (exponent.abs() > 30) throw const FormatException('Invalid money scale');
  var result = BigInt.parse('${match[2]}$fraction');
  if (exponent >= 0) {
    result *= BigInt.from(10).pow(exponent);
  } else {
    final divisor = BigInt.from(10).pow(-exponent);
    if (result.remainder(divisor) != BigInt.zero) {
      throw const FormatException('Invalid money precision');
    }
    result ~/= divisor;
  }
  return match[1] == '-' ? -result : result;
}

String walletMoney(Object? value) {
  final minor = walletMinorUnits(value);
  final digits = minor.abs().toString().padLeft(3, '0');
  final whole = digits
      .substring(0, digits.length - 2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${minor.isNegative ? '-' : ''}Rs. $whole.${digits.substring(digits.length - 2)}';
}

class WalletFailure implements Exception {
  const WalletFailure(this.message, this.status);
  final String message;
  final int status;
}

class WalletPage {
  WalletPage(this.entries, this.number, this.last);
  final List<Map<String, dynamic>> entries;
  final int number;
  final bool last;
}

class WalletSnapshot {
  WalletSnapshot(
    this.balance,
    this.capabilities,
    this.methods,
    this.history,
    this.balanced,
  );
  final Map<String, dynamic>? balance;
  final Map<String, dynamic> capabilities;
  final List<Map<String, dynamic>> methods;
  final WalletPage history;
  final bool balanced;
  bool get active => balance?['status'] == 'ACTIVE' && balanced;
  bool get testFunds =>
      ['MOCK', 'PAYHERE_SANDBOX'].contains(balance?['fundingMode']);
}

class CustomerWalletRepository {
  CustomerWalletRepository(this.auth);
  final CustomerAuthService auth;

  Future<Map<String, dynamic>> topup(
    String amount,
    int methodId,
    String key,
  ) async {
    final response = await auth.bookingRequest(
      'POST',
      '/me/wallets/LKR/topups',
      data: {'amount': amount, 'methodId': methodId},
      headers: {'Idempotency-Key': key},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw WalletFailure(
        'Top-up could not be confirmed. Retry with the same details.',
        response.statusCode ?? 0,
      );
    }
    return topupView(response.data);
  }

  Map<String, dynamic> topupView(Object? value) {
    final view = object(value);
    if (view['intentId'] is! int ||
        (view['intentId'] as int) <= 0 ||
        view['purpose'] != 'TOPUP' ||
        view['currencyCode'] != 'LKR' ||
        !{
          'PENDING',
          'SUCCEEDED',
          'FAILED',
          'CANCELLED',
          'REFUNDED',
        }.contains(view['status'])) {
      throw const FormatException('Invalid top-up response');
    }
    if (walletMinorUnits(view['amount']) <= BigInt.zero) {
      throw const FormatException('Invalid top-up amount');
    }
    return view;
  }

  Future<Map<String, dynamic>> readTopup(int id) async =>
      topupView(await request('GET', '/me/payment-intents/$id'));

  Future<Map<String, dynamic>> completeTestTopup(int id) async {
    final response = await auth.bookingRequest(
      'POST',
      '/me/mock-payments/$id/events',
      data: {'outcome': 'SUCCESS'},
    );
    if (response.statusCode != 200) {
      throw WalletFailure(
        'Test result could not be confirmed. Refresh status before trying again.',
        response.statusCode ?? 0,
      );
    }
    final view = topupView(response.data);
    if (view['intentId'] != id) {
      throw const FormatException('Invalid top-up identity');
    }
    return view;
  }

  Future<Object?> request(String method, String path) async {
    final response = await auth.bookingRequest(
      method,
      path,
      safeRead: method == 'GET',
    );
    if (response.statusCode != 200) {
      final body = response.data;
      final detail = body is Map ? body['detail'] ?? body['message'] : null;
      throw WalletFailure(
        detail is String
            ? detail
            : 'Wallet could not be loaded. Please try again.',
        response.statusCode ?? 0,
      );
    }
    return response.data;
  }

  Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid wallet response');
    }
    return value;
  }

  List<Map<String, dynamic>> rows(Object? value) {
    if (value is! List) throw const FormatException('Invalid wallet list');
    return value.map(object).toList();
  }

  Future<WalletPage> history(int page) async {
    final data = object(
      await request('GET', '/me/wallets/LKR/transactions?page=$page&size=20'),
    );
    if (data['number'] != page || data['last'] is! bool) {
      throw const FormatException('Invalid wallet page');
    }
    final entries = rows(data['content']);
    for (final row in entries) {
      if (row['entryId'] is! int ||
          row['operationId'] is! int ||
          row['currencyCode'] != 'LKR' ||
          !['AVAILABLE', 'RESERVED', 'PENDING'].contains(row['bucket']) ||
          row['createdAt'] is! String ||
          DateTime.tryParse(row['createdAt']) == null) {
        throw const FormatException('Invalid wallet entry');
      }
      walletMinorUnits(row['delta']);
    }
    return WalletPage(entries, page, data['last'] as bool);
  }

  Future<WalletSnapshot> load() async {
    Map<String, dynamic>? balance;
    try {
      balance = object(await request('GET', '/me/wallets/LKR'));
      if (balance['currencyCode'] != 'LKR' ||
          balance['walletId'] is! int ||
          balance['status'] is! String) {
        throw const FormatException('Invalid wallet');
      }
      for (final field in ['available', 'reserved', 'pending']) {
        if (walletMinorUnits(balance[field]).isNegative) {
          throw const FormatException('Invalid balance');
        }
      }
    } on WalletFailure catch (failure) {
      if (failure.status != 404) rethrow;
    }
    final settings = object(await request('GET', '/me/payment-settings'));
    final capabilities = object(settings['capabilities']);
    if (capabilities.values.any((value) => value is! bool)) {
      throw const FormatException('Invalid wallet capabilities');
    }
    final methods = rows(await request('GET', '/me/payment-methods'));
    for (final method in methods) {
      if (method['methodId'] is! int ||
          method['displayLabel'] is! String ||
          !['CARD', 'BANK_ACCOUNT'].contains(method['type']) ||
          method['status'] is! String) {
        throw const FormatException('Invalid method');
      }
    }
    final page = balance == null ? WalletPage([], 0, true) : await history(0);
    final reconciliation = balance == null
        ? null
        : object(await request('GET', '/me/wallets/LKR/reconciliation'));
    if (reconciliation != null &&
        (reconciliation['walletId'] != balance!['walletId'] ||
            reconciliation['balanced'] is! bool)) {
      throw const FormatException('Invalid reconciliation');
    }
    return WalletSnapshot(
      balance,
      capabilities,
      methods,
      page,
      reconciliation?['balanced'] == true || balance == null,
    );
  }

  Future<void> open() async => request('PUT', '/me/wallets/LKR');
  Future<void> linkTestMethod(String type) async {
    if (!['CARD', 'BANK_ACCOUNT'].contains(type)) {
      throw ArgumentError.value(type);
    }
    final method = object(
      await request('POST', '/me/payment-methods/setup?type=$type'),
    );
    if (method['type'] != type ||
        method['status'] != 'VERIFIED_MOCK' ||
        method['methodId'] is! int) {
      throw const FormatException('Invalid setup result');
    }
  }
}
