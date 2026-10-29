import 'package:flutter/foundation.dart';

import '../../auth/data/customer_auth_service.dart';
import '../domain/customer_discovery.dart';

class CustomerDiscoveryRepository {
  const CustomerDiscoveryRepository(this.auth);
  final CustomerAuthService auth;

  Future<List<CustomerServiceOption>> options(
    int marketId,
    int serviceId,
  ) async {
    if (marketId <= 0 || serviceId <= 0) {
      throw ArgumentError('Invalid catalog ID');
    }
    final response = await auth.get(
      '/customers/me/services/$serviceId/options?marketId=$marketId',
    );
    final data = response.data;
    if (response.statusCode != 200 || data is! List) {
      throw const DiscoveryContractException('options.response');
    }
    final result = data
        .where((value) => object(object(value)['option'])['status'] == 'ACTIVE')
        .map(CustomerServiceOption.fromJson)
        .toList();
    if (result.any((item) => item.serviceId != serviceId) ||
        result.map((item) => item.id).toSet().length != result.length) {
      throw const DiscoveryContractException(
        'option.serviceTypeId/options.ids',
      );
    }
    result.sort((a, b) {
      final order = a.displayOrder.compareTo(b.displayOrder);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    return List.unmodifiable(result);
  }

  Future<List<CustomerMarket>> markets() async {
    final response = await auth.get('/markets');
    final data = response.data;
    if (response.statusCode != 200 || data is! List) {
      throw const FormatException('Invalid markets');
    }
    final result = data
        .where((value) => object(value)['status'] == 'ACTIVE')
        .map(CustomerMarket.fromJson)
        .toList();
    if (result.map((item) => item.id).toSet().length != result.length) {
      throw const FormatException('Duplicate markets');
    }
    return List.unmodifiable(result);
  }

  Future<List<CustomerService>> services(int marketId) async {
    if (marketId <= 0) throw ArgumentError.value(marketId);
    try {
      final response = await auth.get(
        '/customers/me/services?marketId=$marketId',
      );
      final data = response.data;
      if (kDebugMode) {
        debugPrint(
          'Customer discovery: method=GET path=/customers/me/services status=${response.statusCode ?? 'unavailable'} outcome=response shape=${data is List
              ? 'list'
              : data is Map
              ? 'object'
              : 'other'}',
        );
      }
      if (response.statusCode != 200 || data is! List) {
        throw const DiscoveryContractException('response');
      }
      final result = data
          .where(
            (value) => object(object(value)['service'])['status'] == 'ACTIVE',
          )
          .map(CustomerService.fromJson)
          .toList();
      if (result.map((item) => item.id).toSet().length != result.length) {
        throw const FormatException('Duplicate services');
      }
      if (kDebugMode) {
        debugPrint(
          'Customer discovery: method=GET path=/customers/me/services outcome=parsed received=${data.length} active=${result.length}',
        );
      }
      return List.unmodifiable(result);
    } on CustomerAuthFailure catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Customer discovery: method=GET path=/customers/me/services status=${error.status ?? 'unavailable'} outcome=http_error',
        );
      }
      rethrow;
    } on FormatException catch (error) {
      final field = error is DiscoveryContractException
          ? error.field
          : 'response';
      if (kDebugMode) {
        debugPrint(
          'Customer discovery: method=GET path=/customers/me/services outcome=parse_error field=$field',
        );
      }
      rethrow;
    } catch (_) {
      if (kDebugMode) {
        debugPrint(
          'Customer discovery: method=GET path=/customers/me/services status=unavailable outcome=request_error',
        );
      }
      rethrow;
    }
  }
}
