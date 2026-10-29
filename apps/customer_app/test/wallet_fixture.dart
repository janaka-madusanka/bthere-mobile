import 'dart:convert';
import 'dart:async';

import 'package:bthere_network/bthere_network.dart';

import 'customer_auth_test.dart' show Fixture;

class WalletFixture {
  final f = Fixture();
  int walletStatus = 200;
  Completer<void>? pendingWallet, walletReadStarted;
  bool balanced = true, last = true;
  int topupStatus = 201;
  Map<String, dynamic>? topupIntent;
  Map<String, dynamic> balance = {
    'walletId': 10,
    'currencyCode': 'LKR',
    'available': 0,
    'reserved': 0,
    'pending': 0,
    'status': 'ACTIVE',
    'fundingMode': 'UNFUNDED',
  };
  List<Map<String, dynamic>> methods = [], entries = [];
  Map<String, dynamic> capabilities = {
    'walletLedger': true,
    'topups': false,
    'cardLinking': false,
    'bankLinking': false,
    'withdrawals': false,
  };
  WalletFixture() {
    f.adapter.extraHandler = (request) async {
      Object? body;
      var status = 200;
      switch (Uri.parse(request.path).path) {
        case '/me/wallets/LKR/topups':
          final input = request.data as Map;
          topupIntent ??= {
            'intentId': 21,
            'purpose': 'TOPUP',
            'currencyCode': 'LKR',
            'amount': input['amount'],
            'methodId': input['methodId'],
            'status': 'PENDING',
          };
          status = topupStatus;
          body = status == 201
              ? topupIntent
              : {'detail': 'Temporarily unavailable'};
        case '/me/mock-payments/21/events':
          if (topupIntent!['status'] != 'SUCCEEDED') {
            balance['available'] = topupIntent!['amount'];
            balance['fundingMode'] = 'MOCK';
          }
          topupIntent!['status'] = 'SUCCEEDED';
          body = topupIntent;
        case '/me/payment-intents/21':
          body = topupIntent;
        case '/me/wallets/LKR':
          if (request.method == 'GET' && pendingWallet != null) {
            if (!(walletReadStarted?.isCompleted ?? true)) {
              walletReadStarted!.complete();
            }
            await pendingWallet!.future;
          }
          if (request.method == 'PUT') walletStatus = 200;
          status = walletStatus;
          body = status == 200 ? balance : {'detail': 'Wallet unavailable'};
        case '/me/payment-settings':
          body = {'capabilities': capabilities};
        case '/me/payment-methods':
          body = methods;
        case '/me/wallets/LKR/reconciliation':
          body = {
            'walletId': 10,
            'balanced': balanced,
            'available': balance['available'],
            'reserved': balance['reserved'],
            'pending': balance['pending'],
          };
        case '/me/wallets/LKR/transactions':
          body = {
            'content': entries,
            'number': int.parse(request.uri.queryParameters['page']!),
            'last': last,
            'size': 20,
            'totalElements': entries.length,
          };
        case '/me/payment-methods/setup':
          final type = request.uri.queryParameters['type']!;
          final method = {
            'methodId': 5,
            'type': type,
            'displayLabel': 'TEST CARD •••• 4242',
            'status': 'VERIFIED_MOCK',
          };
          methods = [method];
          body = method;
        default:
          return null;
      }
      return ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    };
  }
}
