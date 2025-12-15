import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

final premiumServiceProvider = Provider<PremiumService>((ref) {
  return PremiumService();
});

final premiumProductsProvider = FutureProvider<List<ProductDetails>>((
  ref,
) async {
  return ref.read(premiumServiceProvider).loadProducts();
});

class PremiumService {
  PremiumService();

  static const _key = 'nightbuddy_premium';
  static const _productIds = {'nightbuddy_premium_lifetime'};

  bool _cached = false;
  List<ProductDetails> _products = [];
  late final Stream<List<PurchaseDetails>> _purchaseStream;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> initialize() async {
    if (!_supportsPurchases) {
      _cached = false;
      _products = [];
      return;
    }
    _cached = await _loadStored();
    _purchaseStream = InAppPurchase.instance.purchaseStream;
    _subscription = _purchaseStream.listen(_handlePurchaseUpdates);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  bool get isPremium => _cached;
  List<ProductDetails> get products => _products;

  Future<List<ProductDetails>> loadProducts() async {
    if (!_supportsPurchases) return _products;
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return _products;

    final response = await InAppPurchase.instance.queryProductDetails(
      _productIds,
    );
    if (response.error != null) {
      return _products;
    }
    _products = response.productDetails;
    return _products;
  }

  Future<bool> startPurchase() async {
    if (!_supportsPurchases) return false;
    if (_products.isEmpty) {
      await loadProducts();
    }
    if (_products.isEmpty) return false;
    final product = _products.first;
    final purchaseParam = PurchaseParam(productDetails: product);
    final ok = await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
    return ok;
  }

  Future<void> restorePurchases() async {
    if (!_supportsPurchases) return;
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> setPremium(bool value) async {
    _cached = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  Future<bool> _loadStored() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    if (!_supportsPurchases) return;
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await setPremium(true);
      }
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  bool get _supportsPurchases => !kIsWeb;
}
