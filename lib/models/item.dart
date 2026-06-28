import 'package:flutter/material.dart';

// ─── Category ────────────────────────────────────────────────────────────────

enum Category {
  produce,
  dairy,
  meat,
  grain,
  cleaning,
  beverage,
  other,
}

extension CategoryInfo on Category {
  String get label {
    switch (this) {
      case Category.produce:  return '果蔬';
      case Category.dairy:    return '乳制品';
      case Category.meat:     return '肉类';
      case Category.grain:    return '粮油';
      case Category.cleaning: return '清洁';
      case Category.beverage: return '饮料';
      case Category.other:    return '其他';
    }
  }

  Color get color {
    switch (this) {
      case Category.produce:  return const Color(0xFF4CAF50);
      case Category.dairy:    return const Color(0xFF2196F3);
      case Category.meat:     return const Color(0xFFE53935);
      case Category.grain:    return const Color(0xFF8D6E63);
      case Category.cleaning: return const Color(0xFF7B1FA2);
      case Category.beverage: return const Color(0xFF0288D1);
      case Category.other:    return const Color(0xFF78909C);
    }
  }

  Color get bgColor {
    switch (this) {
      case Category.produce:  return const Color(0xFFE8F5E9);
      case Category.dairy:    return const Color(0xFFE3F2FD);
      case Category.meat:     return const Color(0xFFFFEBEE);
      case Category.grain:    return const Color(0xFFEFEBE9);
      case Category.cleaning: return const Color(0xFFF3E5F5);
      case Category.beverage: return const Color(0xFFE1F5FE);
      case Category.other:    return const Color(0xFFECEFF1);
    }
  }
}

// ─── Shelf Zone ───────────────────────────────────────────────────────────────

class ShelfZone {
  final String name;
  final Color dotColor;
  const ShelfZone(this.name, this.dotColor);
}

final kShelfZones = <String, ShelfZone>{
  '果蔬区':      ShelfZone('果蔬区',      const Color(0xFF4CAF50)),
  '冷藏/乳制品': ShelfZone('冷藏/乳制品', const Color(0xFF2196F3)),
  '粮油区':      ShelfZone('粮油区',      const Color(0xFF8D6E63)),
  '日用品':      ShelfZone('日用品',      const Color(0xFF7B1FA2)),
  '其他':        ShelfZone('其他',        const Color(0xFF78909C)),
};

// ─── Stock Status ─────────────────────────────────────────────────────────────

enum StockStatus { sufficient, low, empty }

extension StockStatusInfo on StockStatus {
  String get label {
    switch (this) {
      case StockStatus.sufficient: return '充足';
      case StockStatus.low:        return '快没';
      case StockStatus.empty:      return '用完';
    }
  }

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
  bool checked;
  bool addedToInventory;

  ShoppingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantityLabel,
    required this.shelfZone,
    this.shelfCode,
    this.checked = false,
    this.addedToInventory = false,
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

// ─── App Settings ─────────────────────────────────────────────────────────────

class AppSettings {
  int reminderThresholdDays; // 1–14, default 5
  bool restockReminderEnabled;
  String reminderTime; // display string

  AppSettings({
    this.reminderThresholdDays = 5,
    this.restockReminderEnabled = true,
    this.reminderTime = '每天 18:00',
  });
}

// ─── Sample Data ──────────────────────────────────────────────────────────────

List<ShoppingItem> buildSampleShopping() => [
      ShoppingItem(
        id: 's1',
        name: '香蕉',
        category: Category.produce,
        quantityLabel: '1串',
        shelfZone: '果蔬区',
        shelfCode: '货架B3',
      ),
      ShoppingItem(
        id: 's2',
        name: '番茄',
        category: Category.produce,
        quantityLabel: '6个',
        shelfZone: '果蔬区',
        shelfCode: '货架B1',
      ),
      ShoppingItem(
        id: 's3',
        name: '藻菜',
        category: Category.produce,
        quantityLabel: '1把',
        shelfZone: '果蔬区',
        shelfCode: '货架B2',
      ),
      ShoppingItem(
        id: 's4',
        name: '牛奶',
        category: Category.dairy,
        quantityLabel: '2盒',
        shelfZone: '冷藏/乳制品',
        shelfCode: '冷柜C2',
      ),
      ShoppingItem(
        id: 's5',
        name: '鸡蛋',
        category: Category.dairy,
        quantityLabel: '1打',
        shelfZone: '冷藏/乳制品',
        shelfCode: '冷柜C1',
      ),
    ];

List<InventoryItem> buildSampleInventory() {
  final now = DateTime.now();
  return [
    InventoryItem(
      id: 'i1',
      name: '牛奶',
      category: Category.dairy,
      shelfZone: '冷藏/乳制品',
      shelfCode: '冷柜C2',
      quantityLabel: '2盒',
      purchasedAt: now.subtract(const Duration(days: 1)),
      estimatedDays: 6,
    ),
    InventoryItem(
      id: 'i2',
      name: '鸡蛋',
      category: Category.produce,
      shelfZone: '果蔬区',
      shelfCode: '货架B1',
      quantityLabel: '1打',
      purchasedAt: now.subtract(const Duration(days: 8)),
      estimatedDays: 9,
    ),
    InventoryItem(
      id: 'i3',
      name: '洗洁精',
      category: Category.cleaning,
      shelfZone: '日用品',
      shelfCode: '货架D1',
      quantityLabel: '1瓶',
      purchasedAt: now.subtract(const Duration(days: 30)),
      estimatedDays: 30,
    ),
    InventoryItem(
      id: 'i4',
      name: '大米',
      category: Category.grain,
      shelfZone: '粮油区',
      shelfCode: '货架E2',
      quantityLabel: '1袋',
      purchasedAt: now.subtract(const Duration(days: 10)),
      estimatedDays: 30,
    ),
    InventoryItem(
      id: 'i5',
      name: '酸奶',
      category: Category.dairy,
      shelfZone: '冷藏/乳制品',
      shelfCode: '冷柜C3',
      quantityLabel: '4杯',
      purchasedAt: now.subtract(const Duration(days: 8)),
      estimatedDays: 10,
    ),
  ];
}
