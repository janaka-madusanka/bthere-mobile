import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bthere_session/bthere_session.dart';

import '../../../app/customer_providers.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../auth/data/customer_auth_service.dart';
import '../../profile/application/customer_profile_controller.dart';
import '../data/customer_discovery_repository.dart';
import '../data/customer_market_selection_store.dart';
import '../domain/customer_discovery.dart';

final customerMarketSelectionStoreProvider =
    Provider<CustomerMarketSelectionStore>((ref) {
      final config = ref.watch(customerConfigProvider);
      if (config == null) {
        throw StateError('Customer API configuration is required.');
      }
      return CustomerMarketSelectionStore(
        const FlutterSecureKeyValueStore(),
        apiScope: config.apiBaseUrl,
      );
    }, dependencies: [customerConfigProvider]);

final customerDiscoveryProvider = Provider<CustomerDiscoveryController>(
  (ref) {
    final controller = CustomerDiscoveryController(
      CustomerDiscoveryRepository(ref.watch(customerAuthServiceProvider)),
      ref.watch(customerAuthControllerProvider),
      ref.watch(customerProfileControllerProvider),
      selectionStore: ref.watch(customerMarketSelectionStoreProvider),
    );
    ref.onDispose(controller.dispose);
    return controller;
  },
  dependencies: [
    customerAuthServiceProvider,
    customerAuthControllerProvider,
    customerProfileControllerProvider,
    customerMarketSelectionStoreProvider,
  ],
);

enum DiscoveryStage { idle, loading, ready, failure }

class CustomerOptionsState {
  const CustomerOptionsState(this.stage, {this.options = const []});
  final DiscoveryStage stage;
  final List<CustomerServiceOption> options;
}

class CustomerDiscoveryController extends ChangeNotifier {
  CustomerDiscoveryController(
    this.repository,
    this.auth,
    this.profile, {
    required this.selectionStore,
  }) {
    auth.addListener(_sync);
    profile.addListener(_sync);
    _sync();
  }
  final CustomerDiscoveryRepository repository;
  final CustomerAuthController auth;
  final CustomerProfileController profile;
  final CustomerMarketSelectionStore selectionStore;
  DiscoveryStage marketStage = DiscoveryStage.idle,
      serviceStage = DiscoveryStage.idle;
  List<CustomerMarket> markets = const [];
  List<CustomerService> services = const [];
  final Map<int, CustomerOptionsState> _options = {};
  CustomerOptionsState optionsFor(int serviceId) =>
      _options[serviceId] ?? const CustomerOptionsState(DiscoveryStage.idle);
  CustomerMarket? candidate, activeMarket;
  bool countrySuggested = false, _disposed = false;
  bool savingMarket = false, _selectionRead = false;
  String? marketError, serviceError;
  int? _userId;
  int _epoch = 0, _catalogEpoch = 0;
  bool get confirmed => activeMarket != null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _reset() {
    _epoch++;
    _catalogEpoch++;
    _userId = null;
    markets = const [];
    services = const [];
    _options.clear();
    candidate = activeMarket = null;
    countrySuggested = false;
    savingMarket = _selectionRead = false;
    marketError = serviceError = null;
    marketStage = serviceStage = DiscoveryStage.idle;
  }

  void _sync() {
    if (auth.stage != CustomerAuthStage.authenticated) {
      _reset();
      _notify();
    } else if (profile.stage == CustomerProfileStage.ready &&
        _userId != auth.user?.id) {
      _reset();
      _userId = auth.user?.id;
      loadMarkets();
    }
  }

  Future<void> loadMarkets() async {
    if (_userId == null ||
        savingMarket ||
        marketStage == DiscoveryStage.loading) {
      return;
    }
    final epoch = ++_epoch;
    final userId = _userId!;
    final restoring = !_selectionRead;
    marketStage = DiscoveryStage.loading;
    marketError = null;
    _notify();
    try {
      final saved = restoring ? await selectionStore.read(userId) : null;
      if (_disposed || epoch != _epoch) return;
      final result = await repository.markets();
      if (_disposed || epoch != _epoch) return;
      markets = result;
      countrySuggested = false;
      final previous = activeMarket?.id ?? candidate?.id ?? saved;
      candidate = null;
      for (final market in result) {
        if (market.id == previous) candidate = market;
      }
      final restored = restoring && saved != null && candidate?.id == saved;
      if (restored) activeMarket = candidate;
      _selectionRead = true;
      if (activeMarket != null) {
        activeMarket = candidate;
        if (activeMarket == null) {
          _catalogEpoch++;
          services = const [];
          _options.clear();
          serviceStage = DiscoveryStage.idle;
        }
      }
      if (candidate == null && result.length == 1) candidate = result.single;
      if (candidate == null && result.length > 1) {
        final country = profile.profile?.details.country.trim().toLowerCase();
        final matches = result
            .where(
              (market) =>
                  market.name.toLowerCase() == country ||
                  market.countryCode.toLowerCase() == country,
            )
            .toList();
        if (matches.length == 1) {
          candidate = matches.single;
          countrySuggested = true;
        }
      }
      marketStage = DiscoveryStage.ready;
      if (restored) loadServices();
    } catch (error) {
      if (_disposed || epoch != _epoch) return;
      marketStage = DiscoveryStage.failure;
      marketError = 'Unable to load markets. Please try again.';
      await _checkSession(error);
    } finally {
      if (epoch == _epoch) _notify();
    }
  }

  void select(int id) {
    if (marketStage != DiscoveryStage.ready || savingMarket) return;
    for (final market in markets) {
      if (market.id == id) {
        candidate = market;
        countrySuggested = false;
        _notify();
        return;
      }
    }
  }

  Future<bool> continueMarket() async {
    final selected = candidate;
    final userId = _userId;
    if (_disposed ||
        savingMarket ||
        marketStage != DiscoveryStage.ready ||
        selected == null ||
        userId == null) {
      return false;
    }
    if (activeMarket?.id == candidate?.id &&
        serviceStage == DiscoveryStage.loading) {
      return true;
    }
    final epoch = _epoch;
    savingMarket = true;
    marketError = null;
    _notify();
    try {
      await selectionStore.save(userId, selected.id);
      if (_disposed || epoch != _epoch || userId != _userId) return false;
      activeMarket = selected;
      loadServices();
      return true;
    } catch (_) {
      if (!_disposed && epoch == _epoch && userId == _userId) {
        marketError = 'Unable to save your market. Please try again.';
      }
      return false;
    } finally {
      if (!_disposed && epoch == _epoch && userId == _userId) {
        savingMarket = false;
        _notify();
      }
    }
  }

  Future<void> loadServices() async {
    final market = activeMarket;
    if (market == null || _userId == null) return;
    final epoch = ++_catalogEpoch;
    serviceStage = DiscoveryStage.loading;
    serviceError = null;
    services = const [];
    _options.clear();
    _notify();
    try {
      final result = await repository.services(market.id);
      if (_disposed || epoch != _catalogEpoch) return;
      services = result;
      serviceStage = DiscoveryStage.ready;
    } catch (error) {
      if (_disposed || epoch != _catalogEpoch) return;
      serviceStage = DiscoveryStage.failure;
      serviceError = 'Unable to load services. Please try again.';
      await _checkSession(error);
    } finally {
      if (epoch == _catalogEpoch) _notify();
    }
  }

  Future<void> loadOptions(int serviceId, {bool retry = false}) async {
    final market = activeMarket;
    if (_disposed ||
        market == null ||
        _userId == null ||
        !services.any((service) => service.id == serviceId)) {
      return;
    }
    final current = optionsFor(serviceId).stage;
    if (current == DiscoveryStage.loading ||
        (!retry && current == DiscoveryStage.ready)) {
      return;
    }
    final epoch = _catalogEpoch;
    _options[serviceId] = const CustomerOptionsState(DiscoveryStage.loading);
    _notify();
    try {
      final result = await repository.options(market.id, serviceId);
      if (_disposed || epoch != _catalogEpoch) return;
      _options[serviceId] = CustomerOptionsState(
        DiscoveryStage.ready,
        options: result,
      );
    } catch (error) {
      if (_disposed || epoch != _catalogEpoch) return;
      _options[serviceId] = const CustomerOptionsState(DiscoveryStage.failure);
      await _checkSession(error);
    } finally {
      if (epoch == _catalogEpoch) _notify();
    }
  }

  Future<void> _checkSession(Object error) async {
    if (error is CustomerAuthFailure && error.status == 401) {
      await auth.restore();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    auth.removeListener(_sync);
    profile.removeListener(_sync);
    super.dispose();
  }
}
