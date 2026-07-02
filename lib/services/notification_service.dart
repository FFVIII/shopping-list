import '../models/item.dart';

/// Items that will be low or out of stock at [moment]: projected remaining
/// days <= [thresholdDays]. Mirrors the math in [InventoryItem.statusFor]
/// (covers both StockStatus.low and StockStatus.empty).
List<InventoryItem> lowStockAt(
    DateTime moment, List<InventoryItem> inventory, int thresholdDays) {
  return inventory.where((item) {
    final elapsed = moment.difference(item.purchasedAt).inDays;
    final remaining = item.estimatedDays - elapsed;
    return remaining <= thresholdDays;
  }).toList();
}
