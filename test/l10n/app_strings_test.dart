import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/l10n/app_strings.dart';
import 'package:shopping_list/models/item.dart';

void main() {
  final zh = ZhStrings();
  final en = EnStrings();

  test('static strings differ by language', () {
    expect(zh.inventoryTitle, '库存');
    expect(en.inventoryTitle, 'Inventory');
    expect(zh.navList, '清单');
    expect(en.navList, 'List');
  });

  test('parameterized strings interpolate', () {
    expect(zh.days(7), '7天');
    expect(en.days(7), '7 days');
    expect(zh.recordToInventory(5), '记录到库存（5天）');
    expect(en.recordToInventory(5), 'Save to inventory (5 days)');
    expect(zh.boughtTitle('香蕉'), '「香蕉」买到了！');
    expect(en.boughtTitle('Banana'), '"Banana" bought!');
  });

  test('default categories carry plain-text names (no l10n)', () {
    final cats = buildDefaultCategories();
    final produce = cats.findById('produce')!;
    expect(produce.name, '果蔬');
    expect(cats.fallback.id, 'other');
  });

  test('stock status labels localize', () {
    expect(zh.stockStatus(StockStatus.low), '快没');
    expect(en.stockStatus(StockStatus.low), 'Low');
  });

  test('data() translates known canonical tokens in en, passes through unknown',
      () {
    expect(en.data('果蔬区'), 'Produce');
    expect(en.data('香蕉'), 'Banana');
    expect(en.data('自定义商品'), '自定义商品'); // unknown user input passes through
    expect(zh.data('果蔬区'), '果蔬区'); // zh is always passthrough
    expect(zh.data('香蕉'), '香蕉');
  });

  test('data() translates the generic default quantity label', () {
    // Regression test: '1件' is the app's own fallback quantity label
    // (used whenever the user leaves quantity blank), not sample data —
    // it was missing from the translation map, so English users saw the
    // literal Chinese string.
    expect(en.data('1件'), '1 item');
    expect(zh.data('1件'), '1件');
  });
}
