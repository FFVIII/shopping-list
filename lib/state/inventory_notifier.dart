import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../models/item.dart';
import '../services/tutorial_controller.dart';
import '../storage/app_repository.dart';

/// Owns the inventory domain. Cross-domain operations (that also touch the
/// shopping list) live in `_AppShellState` and call [applyPurchaseFor] /
/// mutate [items] directly before calling [persistItems].
class InventoryNotifier extends ChangeNotifier {
  InventoryNotifier(this._repo);

  final AppRepository _repo;

  /// Invoked after every persist — used by the shell to reschedule
  /// restock notifications, since that depends on settings too.
  VoidCallback? afterPersist;

  List<InventoryItem> items = [];

  void load(AppData data) {
    items = data.inventory;
    notifyListeners();
  }

  void persistItems() {
    notifyListeners();
    unawaited(
      _repo
          .saveInventory(items)
          .catchError((e) => debugPrint('save inventory failed: $e')),
    );
    afterPersist?.call();
  }

  void addItem(InventoryItem item) {
    items = [...items, item];
    persistItems();
  }

  void restock(String id, int days) {
    final idx = items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      items[idx].purchasedAt = DateTime.now();
      items[idx].estimatedDays = days;
    }
    persistItems();
  }

  void deleteItem(String id) {
    final idx = items.indexWhere((i) => i.id == id);
    final name = idx == -1 ? null : items[idx].name;
    items = items.where((i) => i.id != id).toList();
    persistItems();
    if (name != null) TutorialController.instance.onItemDeleted(name);
  }

  void batchDelete(List<String> ids) {
    final idSet = ids.toSet();
    items = items.where((i) => !idSet.contains(i.id)).toList();
    persistItems();
  }

  void editItem(
    String id,
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
  ) {
    final idx = items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    items[idx]
      ..name = name
      ..quantityLabel = quantityLabel
      ..shelfCode = shelfCode
      ..category = category;
    persistItems();
  }

  void reorder(
    String movedId,
    Category? newCategory,
    List<String> orderedIds,
    String? newShelfCode,
  ) {
    final idx = items.indexWhere((i) => i.id == movedId);
    if (idx != -1) {
      if (newCategory != null) items[idx].category = newCategory;
      if (newShelfCode != null) {
        items[idx].shelfCode = newShelfCode.isEmpty ? null : newShelfCode;
      }
    }
    items = orderedIds
        .map((id) => items.firstWhere((i) => i.id == id))
        .toList();
    persistItems();
  }

  // ── 供协调层（跨域级联）调用的纯变更方法：不在此处持久化 ───────────────────

  /// Updates or creates the inventory entry for a purchased shopping item.
  /// Callers persist once after looping over multiple purchases.
  void applyPurchaseFor(ShoppingItem item, int estimatedDays) {
    items = applyPurchase(
      inventory: items,
      item: item,
      estimatedDays: estimatedDays,
      newId: generateId('inv'),
      now: DateTime.now(),
    );
  }
}
