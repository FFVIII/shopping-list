import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../storage/app_repository.dart';

/// Owns the one-time "Pro" unlock purchase (backup export/import restore).
///
/// Deliberately does NOT persist [isPro] through [AppData]/`replaceAll` —
/// restoring a backup from another install must not silently grant or
/// revoke the entitlement tied to *this* Apple ID.
class PurchaseService extends ChangeNotifier {
  static const kProProductId = 'com.ffviii.shoppinglist.pro_unlock';

  PurchaseService({
    Stream<List<PurchaseDetails>>? purchaseStream,
    Future<void> Function(PurchaseDetails)? completePurchase,
  }) : _purchaseStream =
           purchaseStream ?? InAppPurchase.instance.purchaseStream,
       _completePurchase =
           completePurchase ?? InAppPurchase.instance.completePurchase;

  final Stream<List<PurchaseDetails>> _purchaseStream;
  final Future<void> Function(PurchaseDetails) _completePurchase;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  late AppRepository _repo;

  bool isPro = false;
  ProductDetails? proProduct;
  String? lastError;

  Future<void> init(AppRepository repo) async {
    _repo = repo;
    isPro = await repo.loadIsPro();
    notifyListeners();
    _subscription = _purchaseStream.listen(_handlePurchaseUpdate);
    unawaited(_loadProduct());
  }

  Future<void> _loadProduct() async {
    try {
      final response = await InAppPurchase.instance.queryProductDetails({
        kProProductId,
      });
      if (response.productDetails.isNotEmpty) {
        proProduct = response.productDetails.first;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('PurchaseService: failed to query product details: $e');
    }
  }

  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      // Safe to skip entirely (including completePurchase) for anything
      // that isn't the Pro product — this app only ever sells the one.
      if (purchase.productID != kProProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          isPro = true;
          await _repo.saveIsPro(true);
          notifyListeners();
          break;
        case PurchaseStatus.error:
          lastError = purchase.error?.message ?? 'purchase failed';
          notifyListeners();
          break;
        case PurchaseStatus.pending:
        case PurchaseStatus.canceled:
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _completePurchase(purchase);
      }
    }
  }

  Future<void> buy() async {
    final product = proProduct;
    if (product == null) return;
    lastError = null;
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  Future<void> restorePurchases() async {
    lastError = null;
    await InAppPurchase.instance.restorePurchases();
  }

  /// Debug-only escape hatch to try the Pro-gated UI before the real
  /// in-app-purchase product exists in App Store Connect. Only wired up
  /// behind `kDebugMode` at the call site — never shipped to real users.
  Future<void> debugSetIsPro(bool value) async {
    isPro = value;
    await _repo.saveIsPro(value);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
