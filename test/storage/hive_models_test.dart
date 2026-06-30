import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/storage/hive_models.dart';

void main() {
  group('Category', () {
    test('toMap/fromMap round-trips all fields', () {
      final cat = Category(
        id: 'cat_1',
        name: '果蔬',
        color: const Color(0xFF4CAF50),
        bgColor: const Color(0xFFE8F5E9),
        shelfZone: '果蔬区',
        defaultDays: 7,
      );

      final restored = categoryFromMap(cat.toMap());

      expect(restored.id, cat.id);
      expect(restored.name, cat.name);
      expect(restored.color.toARGB32(), cat.color.toARGB32());
      expect(restored.bgColor.toARGB32(), cat.bgColor.toARGB32());
      expect(restored.shelfZone, cat.shelfZone);
      expect(restored.defaultDays, cat.defaultDays);
    });
  });

  group('ShoppingItem', () {
    test('toMap/fromMap round-trips and resolves category by id', () {
      final cat = Category(
        id: 'cat_1',
        name: '乳制品',
        color: const Color(0xFF2196F3),
        bgColor: const Color(0xFFE3F2FD),
        shelfZone: '冷藏/乳制品',
        defaultDays: 7,
      );
      final categories = [cat];
      final item = ShoppingItem(
        id: 's1',
        name: '牛奶',
        category: cat,
        quantityLabel: '2盒',
        shelfZone: '冷藏/乳制品',
        shelfCode: '冷柜C2',
        estimatedDays: 6,
        checked: true,
        addedToInventory: true,
      );

      final restored = shoppingItemFromMap(item.toMap(), categories);

      expect(restored.id, item.id);
      expect(restored.name, item.name);
      expect(restored.category.id, cat.id);
      expect(restored.quantityLabel, item.quantityLabel);
      expect(restored.shelfZone, item.shelfZone);
      expect(restored.shelfCode, item.shelfCode);
      expect(restored.estimatedDays, item.estimatedDays);
      expect(restored.checked, item.checked);
      expect(restored.addedToInventory, item.addedToInventory);
    });

    test('falls back to the fallback category when categoryId is unknown', () {
      final fallback = Category(
        id: kFallbackCategoryId,
        name: '其他',
        color: const Color(0xFF78909C),
        bgColor: const Color(0xFFECEFF1),
        shelfZone: '其他',
        defaultDays: 7,
      );
      final map = {
        'id': 's2',
        'name': '神秘商品',
        'categoryId': 'does_not_exist',
        'quantityLabel': '',
        'shelfZone': '其他',
        'shelfCode': null,
        'estimatedDays': null,
        'checked': false,
        'addedToInventory': false,
      };

      final restored = shoppingItemFromMap(map, [fallback]);

      expect(restored.category.id, kFallbackCategoryId);
    });
  });

  group('InventoryItem', () {
    test('toMap/fromMap round-trips including purchasedAt', () {
      final cat = Category(
        id: 'cat_1',
        name: '果蔬',
        color: const Color(0xFF4CAF50),
        bgColor: const Color(0xFFE8F5E9),
        shelfZone: '果蔬区',
        defaultDays: 7,
      );
      final purchasedAt = DateTime(2026, 6, 30, 10, 30);
      final item = InventoryItem(
        id: 'i1',
        name: '番茄',
        category: cat,
        shelfZone: '果蔬区',
        shelfCode: '货架B1',
        quantityLabel: '6个',
        purchasedAt: purchasedAt,
        estimatedDays: 7,
      );

      final restored = inventoryItemFromMap(item.toMap(), [cat]);

      expect(restored.id, item.id);
      expect(restored.name, item.name);
      expect(restored.category.id, cat.id);
      expect(restored.shelfZone, item.shelfZone);
      expect(restored.shelfCode, item.shelfCode);
      expect(restored.quantityLabel, item.quantityLabel);
      expect(restored.purchasedAt, purchasedAt);
      expect(restored.estimatedDays, item.estimatedDays);
    });
  });

  group('BudgetItem', () {
    test('toMap/fromMap round-trips all fields', () {
      final item = BudgetItem(id: 'b1', name: '牛奶', quantity: 2, unitPrice: 8.5);

      final restored = budgetItemFromMap(item.toMap());

      expect(restored.id, item.id);
      expect(restored.name, item.name);
      expect(restored.quantity, item.quantity);
      expect(restored.unitPrice, item.unitPrice);
    });
  });

  group('AppSettings', () {
    test('toMap/fromMap round-trips all fields', () {
      final settings = AppSettings(
        reminderThresholdDays: 3,
        restockReminderEnabled: false,
        reminderHour: 9,
        reminderMinute: 15,
      );

      final restored = appSettingsFromMap(settings.toMap());

      expect(restored.reminderThresholdDays, settings.reminderThresholdDays);
      expect(restored.restockReminderEnabled, settings.restockReminderEnabled);
      expect(restored.reminderHour, settings.reminderHour);
      expect(restored.reminderMinute, settings.reminderMinute);
    });
  });

  group('ShelfZone', () {
    test('toMap/fromMap round-trips all fields', () {
      const zone = ShelfZone('果蔬区', Color(0xFF4CAF50));

      final restored = shelfZoneFromMap(zone.toMap());

      expect(restored.name, zone.name);
      expect(restored.dotColor.toARGB32(), zone.dotColor.toARGB32());
    });
  });
}
