import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/services/notification_service.dart';

InventoryItem _item(
  String name, {
  required DateTime purchasedAt,
  required int estimatedDays,
}) {
  final cats = buildDefaultCategories();
  return InventoryItem(
    id: 'inv_$name',
    name: name,
    category: cats.fallback,
    purchasedAt: purchasedAt,
    estimatedDays: estimatedDays,
  );
}

void main() {
  // 一个固定的"提醒时刻"参照点，避免测试依赖真实当前时间。
  final base = DateTime(2026, 7, 2, 18, 0);

  test('empty inventory yields empty result', () {
    expect(lowStockAt(base, [], 5), isEmpty);
  });

  test('item with plenty of days left is not included', () {
    final items = [
      _item(
        '大米',
        purchasedAt: base.subtract(const Duration(days: 1)),
        estimatedDays: 30,
      ),
    ];
    expect(lowStockAt(base, items, 5), isEmpty);
  });

  test('item exactly at threshold is included', () {
    // 5 天前购入、能用 10 天 → 剩 5 天，正好等于阈值 5 → 属于"快没"
    final items = [
      _item(
        '牛奶',
        purchasedAt: base.subtract(const Duration(days: 5)),
        estimatedDays: 10,
      ),
    ];
    expect(lowStockAt(base, items, 5).map((i) => i.name), ['牛奶']);
  });

  test('used-up item (remaining <= 0) is included', () {
    final items = [
      _item(
        '鸡蛋',
        purchasedAt: base.subtract(const Duration(days: 20)),
        estimatedDays: 10,
      ),
    ];
    expect(lowStockAt(base, items, 5), hasLength(1));
  });

  test('estimatedDays = 0 is included immediately', () {
    final items = [_item('酸奶', purchasedAt: base, estimatedDays: 0)];
    expect(lowStockAt(base, items, 5), hasLength(1));
  });

  test('item becomes low only on a future day', () {
    // 今天买的 10 天物品：今天剩 10（充足），6 天后剩 4（低于阈值 5）
    final item = _item('牛奶', purchasedAt: base, estimatedDays: 10);
    expect(lowStockAt(base, [item], 5), isEmpty);
    expect(
      lowStockAt(base.add(const Duration(days: 6)), [item], 5),
      hasLength(1),
    );
  });
}
