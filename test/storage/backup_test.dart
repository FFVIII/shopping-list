import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/storage/app_repository.dart';
import 'package:shopping_list/storage/backup.dart';

AppData _sampleData() {
  final categories = buildDefaultCategories();
  return AppData(
    shoppingSimple: [
      ShoppingItem(
        id: 's1',
        name: '纸巾',
        category: categories.fallback,
        quantityLabel: '',
        shelfZone: '其他',
      ),
    ],
    shoppingSmart: buildSampleShopping(categories),
    inventory: buildSampleInventory(categories),
    budget: buildSampleBudget(),
    categories: categories,
    settings: AppSettings(
      reminderThresholdDays: 3,
      restockReminderEnabled: false,
      reminderHour: 9,
      reminderMinute: 30,
    ),
    shelfZones: defaultShelfZones.toList(),
    shelfCodeOrder: ['货架B1', '货架B2'],
  );
}

void main() {
  test('encode → decode round-trips all collections', () {
    final data = _sampleData();
    final decoded = decodeBackup(encodeBackup(data));

    expect(decoded.shoppingSimple.map((i) => i.name),
        data.shoppingSimple.map((i) => i.name));
    expect(decoded.shoppingSmart.length, data.shoppingSmart.length);
    expect(decoded.shoppingSmart.first.category.id,
        data.shoppingSmart.first.category.id);
    expect(decoded.inventory.length, data.inventory.length);
    // toMap 存毫秒，DateTime.now() 带微秒 — 按毫秒比较
    expect(decoded.inventory.first.purchasedAt.millisecondsSinceEpoch,
        data.inventory.first.purchasedAt.millisecondsSinceEpoch);
    expect(decoded.budget.map((b) => b.unitPrice),
        data.budget.map((b) => b.unitPrice));
    expect(decoded.categories.map((c) => c.id),
        data.categories.map((c) => c.id));
    expect(decoded.settings.reminderThresholdDays, 3);
    expect(decoded.settings.restockReminderEnabled, false);
    expect(decoded.settings.reminderHour, 9);
    expect(decoded.settings.reminderMinute, 30);
    expect(decoded.shelfZones.map((z) => z.name),
        data.shelfZones.map((z) => z.name));
    expect(decoded.shelfCodeOrder, ['货架B1', '货架B2']);
  });

  test('rejects non-JSON input', () {
    expect(() => decodeBackup('not json at all'), throwsFormatException);
  });

  test('rejects JSON that is not an object', () {
    expect(() => decodeBackup('[1, 2, 3]'), throwsFormatException);
  });

  test('rejects wrong format field', () {
    expect(() => decodeBackup('{"format":"something_else","version":1}'),
        throwsFormatException);
  });

  test('rejects version above current', () {
    expect(
        () => decodeBackup('{"format":"shopping_list_backup","version":99}'),
        throwsFormatException);
  });

  test('rejects missing data segments', () {
    expect(() => decodeBackup('{"format":"shopping_list_backup","version":1}'),
        throwsFormatException);
  });
}
