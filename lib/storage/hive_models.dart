import 'package:flutter/material.dart';
import '../models/item.dart';

// ─── Category ────────────────────────────────────────────────────────────────

extension CategoryHiveX on Category {
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
        'bgColor': bgColor.toARGB32(),
        'shelfZone': shelfZone,
        'defaultDays': defaultDays,
      };
}

Category categoryFromMap(Map map) => Category(
      id: map['id'] as String,
      name: map['name'] as String,
      color: Color(map['color'] as int),
      bgColor: Color(map['bgColor'] as int),
      shelfZone: map['shelfZone'] as String,
      defaultDays: map['defaultDays'] as int,
    );

// ─── ShoppingItem ─────────────────────────────────────────────────────────────

extension ShoppingItemHiveX on ShoppingItem {
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'categoryId': category.id,
        'quantityLabel': quantityLabel,
        'shelfZone': shelfZone,
        'shelfCode': shelfCode,
        'estimatedDays': estimatedDays,
        'checked': checked,
        'addedToInventory': addedToInventory,
      };
}

ShoppingItem shoppingItemFromMap(Map map, List<Category> categories) =>
    ShoppingItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category:
          categories.findById(map['categoryId'] as String) ?? categories.fallback,
      quantityLabel: map['quantityLabel'] as String,
      shelfZone: map['shelfZone'] as String,
      shelfCode: map['shelfCode'] as String?,
      estimatedDays: map['estimatedDays'] as int?,
      checked: map['checked'] as bool? ?? false,
      addedToInventory: map['addedToInventory'] as bool? ?? false,
    );

// ─── InventoryItem ────────────────────────────────────────────────────────────

extension InventoryItemHiveX on InventoryItem {
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'categoryId': category.id,
        'shelfZone': shelfZone,
        'shelfCode': shelfCode,
        'quantityLabel': quantityLabel,
        'purchasedAt': purchasedAt.millisecondsSinceEpoch,
        'estimatedDays': estimatedDays,
      };
}

InventoryItem inventoryItemFromMap(Map map, List<Category> categories) =>
    InventoryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category:
          categories.findById(map['categoryId'] as String) ?? categories.fallback,
      shelfZone: map['shelfZone'] as String,
      shelfCode: map['shelfCode'] as String?,
      quantityLabel: map['quantityLabel'] as String? ?? '',
      purchasedAt: DateTime.fromMillisecondsSinceEpoch(map['purchasedAt'] as int),
      estimatedDays: map['estimatedDays'] as int,
    );

// ─── BudgetItem ───────────────────────────────────────────────────────────────

extension BudgetItemHiveX on BudgetItem {
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}

BudgetItem budgetItemFromMap(Map map) => BudgetItem(
      id: map['id'] as String,
      name: map['name'] as String,
      quantity: map['quantity'] as int? ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
    );

// ─── AppSettings ──────────────────────────────────────────────────────────────

extension AppSettingsHiveX on AppSettings {
  Map<String, dynamic> toMap() => {
        'reminderThresholdDays': reminderThresholdDays,
        'restockReminderEnabled': restockReminderEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      };
}

AppSettings appSettingsFromMap(Map map) => AppSettings(
      reminderThresholdDays: map['reminderThresholdDays'] as int? ?? 5,
      restockReminderEnabled: map['restockReminderEnabled'] as bool? ?? true,
      reminderHour: map['reminderHour'] as int? ?? 18,
      reminderMinute: map['reminderMinute'] as int? ?? 0,
    );

// ─── ShelfZone ────────────────────────────────────────────────────────────────

extension ShelfZoneHiveX on ShelfZone {
  Map<String, dynamic> toMap() => {
        'name': name,
        'dotColor': dotColor.toARGB32(),
      };
}

ShelfZone shelfZoneFromMap(Map map) => ShelfZone(
      map['name'] as String,
      Color(map['dotColor'] as int),
    );
