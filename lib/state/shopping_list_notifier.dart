import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../models/item.dart';
import '../services/tutorial_controller.dart';
import '../storage/app_repository.dart';

/// Owns the shopping-list domain: simple-mode items, smart-mode items, and
/// budget items. Cross-domain operations (that also touch inventory or
/// categories) live in `_AppShellState` and mutate the public lists here
/// directly before calling the matching `persist*` method.
class ShoppingListNotifier extends ChangeNotifier {
  ShoppingListNotifier(this._repo);

  final AppRepository _repo;

  List<ShoppingItem> simple = [];
  List<ShoppingItem> smart = [];
  List<BudgetItem> budget = [];
  List<BudgetHistoryEntry> budgetHistory = [];

  void load(AppData data) {
    simple = data.shoppingSimple;
    smart = data.shoppingSmart;
    budget = data.budget;
    budgetHistory = data.budgetHistory;
    notifyListeners();
  }

  void persistSimple() {
    notifyListeners();
    unawaited(_repo
        .saveShoppingSimple(simple)
        .catchError((e) => debugPrint('save shoppingSimple failed: $e')));
  }

  void persistSmart() {
    notifyListeners();
    unawaited(_repo
        .saveShoppingSmart(smart)
        .catchError((e) => debugPrint('save shoppingSmart failed: $e')));
  }

  void persistBudget() {
    notifyListeners();
    unawaited(_repo
        .saveBudget(budget)
        .catchError((e) => debugPrint('save budget failed: $e')));
  }

  void persistBudgetHistory() {
    notifyListeners();
    unawaited(_repo
        .saveHistory(budgetHistory)
        .catchError((e) => debugPrint('save budgetHistory failed: $e')));
  }

  // ── 简单模式 ──────────────────────────────────────────────────────────────

  void addSimple(String name, Category fallbackCategory) {
    simple.add(ShoppingItem(
      id: generateId('s'),
      name: name,
      category: fallbackCategory,
      quantityLabel: '',
      shelfZone: '其他',
    ));
    persistSimple();
  }

  void toggleSimple(String id) {
    final idx = simple.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    simple[idx].checked = !simple[idx].checked;
    persistSimple();
  }

  void reorderSimple(List<String> orderedIds) {
    simple =
        orderedIds.map((id) => simple.firstWhere((i) => i.id == id)).toList();
    persistSimple();
  }

  void deleteSimpleItem(String id) {
    simple.removeWhere((i) => i.id == id);
    persistSimple();
  }

  void batchDeleteSimple(List<String> ids) {
    final idSet = ids.toSet();
    simple = simple.where((i) => !idSet.contains(i.id)).toList();
    persistSimple();
  }

  void renameSimpleItem(String id, String newName) {
    final idx = simple.indexWhere((i) => i.id == id);
    if (idx != -1) simple[idx].name = newName;
    persistSimple();
  }

  void completeTripSimple() {
    simple.removeWhere((i) => i.checked);
    persistSimple();
  }

  // ── 智能模式 ──────────────────────────────────────────────────────────────

  void addSmart(String name, String quantityLabel, String? shelfCode,
      int estimatedDays, Category category, String shelfZone,
      {double? unitPrice}) {
    smart.add(ShoppingItem(
      id: generateId('u'),
      name: name,
      category: category,
      quantityLabel: quantityLabel.isEmpty ? '1' : quantityLabel,
      shelfZone: shelfZone,
      shelfCode: shelfCode,
      estimatedDays: estimatedDays,
      unitPrice: unitPrice,
    ));
    persistSmart();
    TutorialController.instance.onItemAdded(name);
  }

  /// Used after the "how many days?" sheet is confirmed (single-domain: only
  /// updates the shopping item, no inventory write).
  void updateSmartItemFields(
    String id, {
    required int estimatedDays,
    required String name,
    required String quantity,
    String? shelfCode,
    required Category category,
    required String zone,
  }) {
    final idx = smart.indexWhere((i) => i.id == id);
    if (idx != -1) {
      smart[idx]
        ..estimatedDays = estimatedDays
        ..name = name
        ..quantityLabel = quantity
        ..shelfCode = shelfCode
        ..category = category
        ..shelfZone = zone;
    }
    persistSmart();
  }

  void editSmartItem(String id, String name, String quantityLabel,
      String? shelfCode, Category category, String shelfZone,
      {double? unitPrice}) {
    final idx = smart.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    smart[idx]
      ..name = name
      ..quantityLabel = quantityLabel
      ..shelfCode = shelfCode
      ..category = category
      ..shelfZone = shelfZone
      ..unitPrice = unitPrice;
    persistSmart();
  }

  void reorderSmart(String movedId, String? newShelfZone,
      Category? newCategory, List<String> orderedIds, String? newShelfCode) {
    final idx = smart.indexWhere((i) => i.id == movedId);
    if (idx != -1) {
      if (newShelfZone != null) smart[idx].shelfZone = newShelfZone;
      if (newCategory != null) smart[idx].category = newCategory;
      // newShelfCode non-null means shelf-mode drag: "" = clear code, else set
      if (newShelfCode != null) {
        smart[idx].shelfCode = newShelfCode.isEmpty ? null : newShelfCode;
      }
    }
    smart =
        orderedIds.map((id) => smart.firstWhere((i) => i.id == id)).toList();
    persistSmart();
  }

  void deleteSmartItem(String id) {
    final idx = smart.indexWhere((i) => i.id == id);
    final name = idx == -1 ? null : smart[idx].name;
    smart.removeWhere((i) => i.id == id);
    persistSmart();
    if (name != null) TutorialController.instance.onItemDeleted(name);
  }

  void batchDeleteSmart(List<String> ids) {
    final idSet = ids.toSet();
    smart = smart.where((i) => !idSet.contains(i.id)).toList();
    persistSmart();
  }

  // ── 记账模式 ──────────────────────────────────────────────────────────────

  void addBudgetItem(String name, int quantity, double unitPrice) {
    budget = [
      ...budget,
      BudgetItem(
        id: generateId('bud'),
        name: name,
        quantity: quantity,
        unitPrice: unitPrice,
      ),
    ];
    persistBudget();
  }

  void editBudgetItem(String id, String name, int quantity, double unitPrice) {
    final idx = budget.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    budget[idx]
      ..name = name
      ..quantity = quantity
      ..unitPrice = unitPrice;
    persistBudget();
  }

  void deleteBudgetItem(String id) {
    budget = budget.where((i) => i.id != id).toList();
    persistBudget();
  }

  void reorderBudget(List<String> orderedIds) {
    budget = orderedIds
        .map((id) => budget.firstWhere((i) => i.id == id))
        .toList();
    persistBudget();
  }

  void batchDeleteBudget(List<String> ids) {
    final idSet = ids.toSet();
    budget = budget.where((i) => !idSet.contains(i.id)).toList();
    persistBudget();
  }

  /// Snapshots [snapshot] (the budget items about to be cleared) into a new
  /// history entry. Does not itself clear `budget` — the caller (list_screen's
  /// clear-confirm flow) still calls `batchDeleteBudget` separately for that.
  void recordBudgetPurchase(List<BudgetItem> snapshot) {
    if (snapshot.isEmpty) return;
    budgetHistory = [
      BudgetHistoryEntry(
        id: generateId('hist'),
        clearedAt: DateTime.now(),
        items: snapshot
            .map((b) => BudgetHistoryLineItem(
                  name: b.name,
                  quantity: b.quantity,
                  unitPrice: b.unitPrice,
                ))
            .toList(),
      ),
      ...budgetHistory,
    ];
    persistBudgetHistory();
  }

  void deleteBudgetHistoryEntry(String id) {
    budgetHistory = budgetHistory.where((e) => e.id != id).toList();
    persistBudgetHistory();
  }

  // ── 提醒联动（只影响清单）──────────────────────────────────────────────────

  /// Returns true if an item was actually added (false if already present).
  bool addFromReminder(InventoryItem inv) {
    if (smart.any((s) => !s.checked && sameProduct(s, inv))) return false;
    smart = [
      ...smart,
      ShoppingItem(
        id: generateId('r'),
        name: inv.name,
        category: inv.category,
        quantityLabel: '1',
        shelfZone: inv.shelfZone,
        shelfCode: inv.shelfCode,
        sourceInventoryId: inv.id,
      ),
    ];
    persistSmart();
    return true;
  }

  void removeFromListByReminder(InventoryItem inv) {
    smart = smart
        .where((s) => !(!s.checked && sameProduct(s, inv)))
        .toList();
    persistSmart();
  }

  void batchAddToRestock(List<InventoryItem> items) {
    for (final inv in items) {
      if (smart.any((s) => !s.checked && sameProduct(s, inv))) continue;
      smart = [
        ...smart,
        ShoppingItem(
          id: generateId('shop'),
          name: inv.name,
          category: inv.category,
          shelfZone: inv.shelfZone,
          shelfCode: inv.shelfCode,
          quantityLabel: inv.quantityLabel,
          sourceInventoryId: inv.id,
        ),
      ];
    }
    persistSmart();
  }

  /// Returns the number of items actually added.
  int addAllFromInventory(List<InventoryItem> toAdd) {
    if (toAdd.isEmpty) return 0;
    final newItems = <ShoppingItem>[];
    for (final inv in toAdd) {
      newItems.add(ShoppingItem(
        id: generateId('r'),
        name: inv.name,
        category: inv.category,
        quantityLabel: '1',
        shelfZone: inv.shelfZone,
        shelfCode: inv.shelfCode,
        sourceInventoryId: inv.id,
      ));
    }
    smart = [...smart, ...newItems];
    persistSmart();
    return newItems.length;
  }

  // ── 供协调层（跨域级联）调用的纯变更方法：不在此处持久化 ───────────────────

  void renameShelfCodeInItems(String oldCode, String newCode) {
    for (final item in smart) {
      if (item.shelfCode == oldCode) item.shelfCode = newCode;
    }
  }
}
