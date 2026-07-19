import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/models/item.dart';

Category _category(String id, {int defaultDays = 7}) {
  return Category(
    id: id,
    name: id,
    color: const Color(0xFF000000),
    bgColor: const Color(0xFFFFFFFF),
    defaultDays: defaultDays,
  );
}

InventoryItem _inventoryItem(
  String id, {
  required Category category,
  String name = 'item',
  required DateTime purchasedAt,
  required int estimatedDays,
  String quantityLabel = '',
  String? shelfCode,
}) {
  return InventoryItem(
    id: id,
    name: name,
    category: category,
    shelfCode: shelfCode,
    quantityLabel: quantityLabel,
    purchasedAt: purchasedAt,
    estimatedDays: estimatedDays,
  );
}

ShoppingItem _shoppingItem(
  String id, {
  required Category category,
  String name = 'item',
  String quantityLabel = '1',
  String? shelfCode,
  int? estimatedDays,
  bool checked = false,
  String? sourceInventoryId,
}) {
  return ShoppingItem(
    id: id,
    name: name,
    category: category,
    quantityLabel: quantityLabel,
    shelfCode: shelfCode,
    estimatedDays: estimatedDays,
    checked: checked,
    sourceInventoryId: sourceInventoryId,
  );
}

void main() {
  group('generateId', () {
    test('never collides across rapid consecutive calls', () {
      // Simulates the exact failure mode being fixed: many ids requested
      // in the same tick, where DateTime.now() alone would be identical
      // for every call.
      final ids = List.generate(1000, (_) => generateId('cat'));
      expect(ids.toSet(), hasLength(1000));
    });

    test('starts with the given prefix', () {
      expect(generateId('bud'), startsWith('bud_'));
    });
  });

  group('InventoryItem.statusFor day boundary', () {
    final cat = _category('dairy');

    test('remaining strictly above threshold is sufficient', () {
      final item = _inventoryItem(
        'i1',
        category: cat,
        purchasedAt: DateTime.now().subtract(const Duration(days: 4)),
        estimatedDays: 10,
      ); // remaining = 6
      expect(item.statusFor(5), StockStatus.sufficient);
    });

    test('remaining exactly at threshold is low (boundary)', () {
      final item = _inventoryItem(
        'i2',
        category: cat,
        purchasedAt: DateTime.now().subtract(const Duration(days: 5)),
        estimatedDays: 10,
      ); // remaining = 5
      expect(item.statusFor(5), StockStatus.low);
    });

    test('remaining exactly zero is empty', () {
      final item = _inventoryItem(
        'i3',
        category: cat,
        purchasedAt: DateTime.now().subtract(const Duration(days: 10)),
        estimatedDays: 10,
      ); // remaining = 0
      expect(item.statusFor(5), StockStatus.empty);
    });

    test('elapsed past estimatedDays stays empty, never negative', () {
      final item = _inventoryItem(
        'i4',
        category: cat,
        purchasedAt: DateTime.now().subtract(const Duration(days: 30)),
        estimatedDays: 10,
      ); // remaining would be -20, clamped to 0
      expect(item.statusFor(5), StockStatus.empty);
    });

    test('estimatedDays = 0 is always empty regardless of threshold', () {
      final item = _inventoryItem(
        'i5',
        category: cat,
        purchasedAt: DateTime.now(),
        estimatedDays: 0,
      );
      expect(item.statusFor(5), StockStatus.empty);
      expect(item.statusFor(0), StockStatus.empty);
    });

    test('purchasedAt in the future clamps remaining to estimatedDays', () {
      final item = _inventoryItem(
        'i6',
        category: cat,
        purchasedAt: DateTime.now().add(const Duration(days: 5)),
        estimatedDays: 10,
      ); // remaining clamped to 10, not 15
      expect(item.statusFor(5), StockStatus.sufficient);
    });
  });

  group('applyPurchase (完成购物 → 入库存)', () {
    final cat = _category('dairy');
    final now = DateTime(2026, 7, 2, 18, 0);

    test('creates a new inventory entry when no match exists', () {
      final result = applyPurchase(
        inventory: const [],
        item: _shoppingItem(
          's1',
          category: cat,
          name: '牛奶',
          quantityLabel: '2盒',
        ),
        estimatedDays: 7,
        newId: 'inv_new',
        now: now,
      );

      expect(result, hasLength(1));
      expect(result.single.id, 'inv_new');
      expect(result.single.name, '牛奶');
      expect(result.single.purchasedAt, now);
      expect(result.single.estimatedDays, 7);
    });

    test(
      'updates the matching existing entry in place instead of duplicating',
      () {
        final existing = _inventoryItem(
          'inv_1',
          category: cat,
          name: '牛奶',
          purchasedAt: DateTime(2026, 1, 1),
          estimatedDays: 3,
          quantityLabel: '1盒',
        );

        final result = applyPurchase(
          inventory: [existing],
          item: _shoppingItem(
            's1',
            category: cat,
            name: '牛奶',
            quantityLabel: '2盒',
            sourceInventoryId: 'inv_1',
          ),
          estimatedDays: 7,
          newId: 'inv_should_not_be_used',
          now: now,
        );

        expect(result, hasLength(1));
        expect(result.single.id, 'inv_1'); // same row, not a new one
        expect(result.single.purchasedAt, now);
        expect(result.single.estimatedDays, 7);
        expect(result.single.quantityLabel, '2盒');
      },
    );

    test(
      'two same-named inventory rows: sourceInventoryId picks the right one',
      () {
        // Regression test for the "name-only matching updates the wrong row"
        // bug: two distinct 牛奶 entries exist, and the shopping item must
        // update the one it actually came from, not whichever name matches
        // first.
        final rowA = _inventoryItem(
          'inv_a',
          category: cat,
          name: '牛奶',
          purchasedAt: DateTime(2026, 1, 1),
          estimatedDays: 3,
        );
        final rowB = _inventoryItem(
          'inv_b',
          category: cat,
          name: '牛奶',
          purchasedAt: DateTime(2026, 1, 1),
          estimatedDays: 3,
        );

        final result = applyPurchase(
          inventory: [rowA, rowB],
          item: _shoppingItem(
            's1',
            category: cat,
            name: '牛奶',
            sourceInventoryId: 'inv_b',
          ),
          estimatedDays: 9,
          newId: 'unused',
          now: now,
        );

        expect(result, hasLength(2));
        expect(
          result.firstWhere((i) => i.id == 'inv_a').estimatedDays,
          3,
        ); // untouched
        expect(
          result.firstWhere((i) => i.id == 'inv_b').estimatedDays,
          9,
        ); // updated
      },
    );

    test('falls back to name matching when sourceInventoryId is absent', () {
      final existing = _inventoryItem(
        'inv_1',
        category: cat,
        name: '鸡蛋',
        purchasedAt: DateTime(2026, 1, 1),
        estimatedDays: 3,
      );

      final result = applyPurchase(
        inventory: [existing],
        item: _shoppingItem(
          's1',
          category: cat,
          name: '鸡蛋',
        ), // manually typed, no source
        estimatedDays: 9,
        newId: 'unused',
        now: now,
      );

      expect(result, hasLength(1));
      expect(result.single.id, 'inv_1');
      expect(result.single.estimatedDays, 9);
    });

    test(
      'preserves the existing shelfCode when the shopping item has none',
      () {
        final existing = _inventoryItem(
          'inv_1',
          category: cat,
          name: '牛奶',
          purchasedAt: DateTime(2026, 1, 1),
          estimatedDays: 3,
          shelfCode: '冷柜C2',
        );

        final result = applyPurchase(
          inventory: [existing],
          item: _shoppingItem(
            's1',
            category: cat,
            name: '牛奶',
            sourceInventoryId: 'inv_1',
          ), // no shelfCode
          estimatedDays: 7,
          newId: 'unused',
          now: now,
        );

        expect(result.single.shelfCode, '冷柜C2');
      },
    );
  });

  group('reassignCategoryToFallback (删除分类后重新指派)', () {
    test(
      'reassigns matching items across all three lists, leaves others untouched',
      () {
        final deleted = _category('meat');
        final other = _category('dairy');
        final fallback = _category(kFallbackCategoryId);

        final shopping = [
          _shoppingItem('s1', category: deleted, name: '牛排'),
          _shoppingItem('s2', category: other, name: '牛奶'),
        ];
        final shoppingSimple = [
          _shoppingItem('ss1', category: deleted, name: '香肠'),
        ];
        final inventory = [
          _inventoryItem(
            'i1',
            category: deleted,
            name: '培根',
            purchasedAt: DateTime.now(),
            estimatedDays: 5,
          ),
          _inventoryItem(
            'i2',
            category: other,
            name: '酸奶',
            purchasedAt: DateTime.now(),
            estimatedDays: 5,
          ),
        ];

        reassignCategoryToFallback(
          categoryId: 'meat',
          fallback: fallback,
          shopping: shopping,
          shoppingSimple: shoppingSimple,
          inventory: inventory,
        );

        expect(shopping[0].category.id, kFallbackCategoryId); // was meat
        expect(shopping[1].category.id, 'dairy'); // untouched
        expect(shoppingSimple[0].category.id, kFallbackCategoryId); // was meat
        expect(inventory[0].category.id, kFallbackCategoryId); // was meat
        expect(inventory[1].category.id, 'dairy'); // untouched
      },
    );

    test('does nothing when no item references the deleted category', () {
      final other = _category('dairy');
      final fallback = _category(kFallbackCategoryId);
      final shopping = [_shoppingItem('s1', category: other, name: '牛奶')];

      reassignCategoryToFallback(
        categoryId: 'meat',
        fallback: fallback,
        shopping: shopping,
        shoppingSimple: const [],
        inventory: const [],
      );

      expect(shopping[0].category.id, 'dairy');
    });
  });
}
