import 'package:flutter/material.dart';

// ─── Id generation ────────────────────────────────────────────────────────────

int _idSeq = 0;

/// A unique id of the form `<prefix>_<millis>_<seq>`. The trailing counter
/// guarantees uniqueness even when several ids are requested within the same
/// millisecond (e.g. rapid consecutive taps) — a plain millisecond timestamp
/// alone can collide there.
String generateId(String prefix) =>
    '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_idSeq++}';

// ─── Category ────────────────────────────────────────────────────────────────

/// Mutable category model. Identity is `id` (stable across renames).
class Category {
  final String id;
  String name;
  Color color;
  Color bgColor;
  String shelfZone;
  int defaultDays;

  Category({
    required this.id,
    required this.name,
    required this.color,
    required this.bgColor,
    required this.shelfZone,
    required this.defaultDays,
  });

  /// Light tint of `color` to use as a chip background.
  static Color tintOf(Color color) => Color.lerp(color, Colors.white, 0.85)!;

  /// Shared swatch choices for the category color picker.
  static const List<Color> palette = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFE53935),
    Color(0xFFFF9800),
    Color(0xFF7B1FA2),
    Color(0xFF8D6E63),
    Color(0xFF0288D1),
    Color(0xFF78909C),
  ];
}

/// Fallback category id — always present, never deleted.
const String kFallbackCategoryId = 'other';

/// Default categories in default order. App state owns a mutable copy.
List<Category> buildDefaultCategories() => [
      Category(
        id: 'produce',
        name: '果蔬',
        color: const Color(0xFF4CAF50),
        bgColor: const Color(0xFFE8F5E9),
        shelfZone: '果蔬区',
        defaultDays: 7,
      ),
      Category(
        id: 'dairy',
        name: '乳制品',
        color: const Color(0xFF2196F3),
        bgColor: const Color(0xFFE3F2FD),
        shelfZone: '乳制品',
        defaultDays: 7,
      ),
      Category(
        id: 'meat',
        name: '肉类',
        color: const Color(0xFFE53935),
        bgColor: const Color(0xFFFFEBEE),
        shelfZone: '冷藏',
        defaultDays: 5,
      ),
      Category(
        id: 'grain',
        name: '粮油',
        color: const Color(0xFF8D6E63),
        bgColor: const Color(0xFFEFEBE9),
        shelfZone: '粮油区',
        defaultDays: 30,
      ),
      Category(
        id: 'household',
        name: '日用品',
        color: const Color(0xFF7B1FA2),
        bgColor: const Color(0xFFF3E5F5),
        shelfZone: '日用品',
        defaultDays: 30,
      ),
      Category(
        id: kFallbackCategoryId,
        name: '其他',
        color: const Color(0xFF78909C),
        bgColor: const Color(0xFFECEFF1),
        shelfZone: '其他',
        defaultDays: 7,
      ),
    ];

extension CategoryListLookup on List<Category> {
  Category? findById(String id) {
    for (final c in this) {
      if (c.id == id) return c;
    }
    return null;
  }

  Category get fallback => findById(kFallbackCategoryId) ?? first;
}

/// Reassigns every item referencing category [categoryId] (in [shopping],
/// [shoppingSimple], and [inventory]) to [fallback]. Mutates the items in
/// place; does not rebuild the lists themselves — callers still need to
/// replace their list fields to trigger a rebuild, same as before extraction.
void reassignCategoryToFallback({
  required String categoryId,
  required Category fallback,
  required List<ShoppingItem> shopping,
  required List<ShoppingItem> shoppingSimple,
  required List<InventoryItem> inventory,
}) {
  for (final s in shopping) {
    if (s.category.id == categoryId) s.category = fallback;
  }
  for (final s in shoppingSimple) {
    if (s.category.id == categoryId) s.category = fallback;
  }
  for (final inv in inventory) {
    if (inv.category.id == categoryId) inv.category = fallback;
  }
}

// ─── Shelf Zone ───────────────────────────────────────────────────────────────

class ShelfZone {
  final String name;
  final Color dotColor;
  const ShelfZone(this.name, this.dotColor);
}

/// Default shelf zones in default order. App state owns a mutable copy.
const List<ShelfZone> defaultShelfZones = [
  ShelfZone('果蔬区', Color(0xFF4CAF50)),
  ShelfZone('乳制品', Color(0xFF2196F3)),
  ShelfZone('冷藏',   Color(0xFF00ACC1)),
  ShelfZone('粮油区', Color(0xFF8D6E63)),
  ShelfZone('日用品', Color(0xFF7B1FA2)),
  ShelfZone('其他',   Color(0xFF78909C)),
];

extension ShelfZoneListLookup on List<ShelfZone> {
  ShelfZone? findByName(String name) {
    for (final z in this) {
      if (z.name == name) return z;
    }
    return null;
  }

  int orderIndexOf(String name) {
    for (int i = 0; i < length; i++) {
      if (this[i].name == name) return i;
    }
    return length; // unknown zones sort last
  }
}

// ─── Stock Status ─────────────────────────────────────────────────────────────

enum StockStatus { sufficient, low, empty }

extension StockStatusInfo on StockStatus {
  Color get color {
    switch (this) {
      case StockStatus.sufficient: return const Color(0xFF4CAF50);
      case StockStatus.low:        return const Color(0xFFFF9800);
      case StockStatus.empty:      return const Color(0xFFE53935);
    }
  }

  Color get bgColor {
    switch (this) {
      case StockStatus.sufficient: return const Color(0xFFE8F5E9);
      case StockStatus.low:        return const Color(0xFFFFF3E0);
      case StockStatus.empty:      return const Color(0xFFFFEBEE);
    }
  }
}

// ─── Shopping Item ────────────────────────────────────────────────────────────

class ShoppingItem {
  final String id;
  String name;
  Category category;
  String quantityLabel;
  String shelfZone;
  String? shelfCode;
  int? estimatedDays;
  bool checked;
  bool addedToInventory;
  // Set when this entry was created from an existing InventoryItem (restock /
  // reminder "add to list"). Lets purchase/dedup logic match the exact
  // inventory row by id instead of by name, so it survives renames and
  // doesn't collide with other items that happen to share a name. Manually
  // typed items (via the add bar) have no source, so they still fall back
  // to name matching.
  String? sourceInventoryId;

  ShoppingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantityLabel,
    required this.shelfZone,
    this.shelfCode,
    this.estimatedDays,
    this.checked = false,
    this.addedToInventory = false,
    this.sourceInventoryId,
  });
}

// ─── Inventory Item ───────────────────────────────────────────────────────────

class InventoryItem {
  final String id;
  String name;
  Category category;
  String shelfZone;
  String? shelfCode;
  String quantityLabel; // e.g. "2盒" — may be empty
  DateTime purchasedAt;
  int estimatedDays;   // how long this purchase lasts

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.shelfZone,
    this.shelfCode,
    this.quantityLabel = '',
    required this.purchasedAt,
    required this.estimatedDays,
  });

  int get daysRemaining {
    final elapsed = DateTime.now().difference(purchasedAt).inDays;
    return (estimatedDays - elapsed).clamp(0, estimatedDays);
  }

  double get progressRatio {
    if (estimatedDays == 0) return 0;
    return (daysRemaining / estimatedDays).clamp(0.0, 1.0);
  }

  StockStatus statusFor(int thresholdDays) {
    final remaining = daysRemaining;
    if (remaining <= 0) return StockStatus.empty;
    if (remaining <= thresholdDays) return StockStatus.low;
    return StockStatus.sufficient;
  }
}

// ─── Purchasing: shopping-list item → inventory ──────────────────────────────

/// True if [s] and [inv] represent the same product. Prefers matching by
/// [ShoppingItem.sourceInventoryId] when set (survives renames and doesn't
/// collide with same-named products); falls back to matching by name for
/// entries that never had a source (manually typed items).
bool sameProduct(ShoppingItem s, InventoryItem inv) =>
    s.sourceInventoryId != null
        ? s.sourceInventoryId == inv.id
        : s.name == inv.name;

/// Index of the entry in [inventory] that corresponds to [item], per
/// [sameProduct]'s matching rule; -1 if none.
int inventoryIndexForShoppingItem(
    List<InventoryItem> inventory, ShoppingItem item) {
  if (item.sourceInventoryId != null) {
    final idx = inventory.indexWhere((i) => i.id == item.sourceInventoryId);
    if (idx != -1) return idx;
  }
  return inventory.indexWhere((i) => i.name == item.name);
}

/// Applies a purchase of [item] to [inventory]: updates the matching
/// existing entry in place (see [inventoryIndexForShoppingItem]) — setting
/// purchasedAt, estimatedDays, and quantityLabel, plus shelfCode when the
/// shopping item has one — or appends a freshly created entry with id
/// [newId]. Returns the resulting list; the matched entry (if any) is
/// mutated in place, so only a new List wrapper is allocated in that case.
List<InventoryItem> applyPurchase({
  required List<InventoryItem> inventory,
  required ShoppingItem item,
  required int estimatedDays,
  required String newId,
  required DateTime now,
}) {
  final invIdx = inventoryIndexForShoppingItem(inventory, item);
  if (invIdx != -1) {
    inventory[invIdx]
      ..purchasedAt = now
      ..estimatedDays = estimatedDays
      ..quantityLabel = item.quantityLabel;
    if (item.shelfCode != null) inventory[invIdx].shelfCode = item.shelfCode;
    return inventory;
  }
  return [
    ...inventory,
    InventoryItem(
      id: newId,
      name: item.name,
      category: item.category,
      shelfZone: item.shelfZone,
      shelfCode: item.shelfCode,
      quantityLabel: item.quantityLabel,
      purchasedAt: now,
      estimatedDays: estimatedDays,
    ),
  ];
}

// ─── Budget Item (记账) ────────────────────────────────────────────────────────

class BudgetItem {
  final String id;
  String name;
  int quantity;      // count, ≥ 1
  double unitPrice;  // price per unit

  BudgetItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.unitPrice = 0,
  });

  double get lineTotal => quantity * unitPrice;
}

// ─── App Settings ─────────────────────────────────────────────────────────────

class AppSettings {
  int reminderThresholdDays; // 1–14, default 5
  bool restockReminderEnabled;
  int reminderHour;   // 0–23
  int reminderMinute; // 0–59

  AppSettings({
    this.reminderThresholdDays = 5,
    // Off by default: the toggle is what triggers the iOS permission
    // request (spec §4.4). Defaulting to true meant most users never saw
    // the request at all, since the on->off->on edge never fired.
    this.restockReminderEnabled = false,
    this.reminderHour = 18,
    this.reminderMinute = 0,
  });
}

// ─── Sample Data ──────────────────────────────────────────────────────────────

List<ShoppingItem> buildSampleShopping(List<Category> categories) {
  Category cat(String id) => categories.findById(id) ?? categories.fallback;
  return [
    ShoppingItem(
      id: 's1',
      name: '香蕉',
      category: cat('produce'),
      quantityLabel: '1串',
      shelfZone: '果蔬区',
      shelfCode: '货架B3',
    ),
    ShoppingItem(
      id: 's2',
      name: '番茄',
      category: cat('produce'),
      quantityLabel: '6个',
      shelfZone: '果蔬区',
      shelfCode: '货架B1',
    ),
    ShoppingItem(
      id: 's3',
      name: '藻菜',
      category: cat('produce'),
      quantityLabel: '1把',
      shelfZone: '果蔬区',
      shelfCode: '货架B2',
    ),
    ShoppingItem(
      id: 's4',
      name: '牛奶',
      category: cat('dairy'),
      quantityLabel: '2盒',
      shelfZone: '乳制品',
      shelfCode: '冷柜C2',
    ),
    ShoppingItem(
      id: 's5',
      name: '鸡蛋',
      category: cat('dairy'),
      quantityLabel: '1打',
      shelfZone: '乳制品',
      shelfCode: '冷柜C1',
    ),
  ];
}

List<BudgetItem> buildSampleBudget() => [
      BudgetItem(id: 'b1', name: '牛奶', quantity: 2, unitPrice: 8.5),
      BudgetItem(id: 'b2', name: '鸡蛋', quantity: 1, unitPrice: 15),
      BudgetItem(id: 'b3', name: '香蕉', quantity: 3, unitPrice: 2.5),
    ];

List<InventoryItem> buildSampleInventory(List<Category> categories) {
  Category cat(String id) => categories.findById(id) ?? categories.fallback;
  final now = DateTime.now();
  return [
    InventoryItem(
      id: 'i1',
      name: '牛奶',
      category: cat('dairy'),
      shelfZone: '乳制品',
      shelfCode: '冷柜C2',
      quantityLabel: '2盒',
      purchasedAt: now.subtract(const Duration(days: 1)),
      estimatedDays: 6,
    ),
    InventoryItem(
      id: 'i2',
      name: '鸡蛋',
      category: cat('dairy'),
      shelfZone: '乳制品',
      shelfCode: '冷柜C1',
      quantityLabel: '1打',
      purchasedAt: now.subtract(const Duration(days: 8)),
      estimatedDays: 9,
    ),
    InventoryItem(
      id: 'i3',
      name: '洗洁精',
      category: cat('household'),
      shelfZone: '日用品',
      shelfCode: '货架D1',
      quantityLabel: '1瓶',
      purchasedAt: now.subtract(const Duration(days: 30)),
      estimatedDays: 30,
    ),
    InventoryItem(
      id: 'i4',
      name: '大米',
      category: cat('grain'),
      shelfZone: '粮油区',
      shelfCode: '货架E2',
      quantityLabel: '1袋',
      purchasedAt: now.subtract(const Duration(days: 10)),
      estimatedDays: 30,
    ),
    InventoryItem(
      id: 'i5',
      name: '酸奶',
      category: cat('dairy'),
      shelfZone: '乳制品',
      shelfCode: '冷柜C3',
      quantityLabel: '4杯',
      purchasedAt: now.subtract(const Duration(days: 8)),
      estimatedDays: 10,
    ),
  ];
}
