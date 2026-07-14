import 'package:excel/excel.dart';
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
    budgetHistory: [
      BudgetHistoryEntry(
        id: 'hist_1',
        clearedAt: DateTime(2026, 7, 1, 8, 30),
        items: [
          BudgetHistoryLineItem(name: '牛奶', quantity: 2, unitPrice: 8.5),
          BudgetHistoryLineItem(name: '鸡蛋', quantity: 1, unitPrice: 12.0),
        ],
      ),
    ],
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

// Builds a minimal valid .xlsx with just a Meta sheet holding the given
// format/version, for testing the validation checks in decodeBackupExcel.
List<int> _metaOnlyXlsx({required String format, required int version}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  final meta = excel['Meta'];
  meta.appendRow([TextCellValue('key'), TextCellValue('value')]);
  meta.appendRow([TextCellValue('format'), TextCellValue(format)]);
  meta.appendRow([TextCellValue('version'), IntCellValue(version)]);
  if (defaultSheet != null) excel.delete(defaultSheet);
  return excel.encode()!;
}

void main() {
  test('encode → decode round-trips all collections', () {
    final data = _sampleData();
    final decoded = decodeBackupExcel(encodeBackupExcel(data));

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
    expect(decoded.budgetHistory.length, 1);
    expect(decoded.budgetHistory.single.id, 'hist_1');
    expect(decoded.budgetHistory.single.items.length, 2);
    expect(decoded.budgetHistory.single.items[0].name, '牛奶');
    expect(decoded.budgetHistory.single.totalAmount,
        data.budgetHistory.single.totalAmount);
  });

  test('rejects non-xlsx input', () {
    expect(() => decodeBackupExcel([1, 2, 3]), throwsFormatException);
  });

  test('rejects wrong format field', () {
    expect(
        () => decodeBackupExcel(
            _metaOnlyXlsx(format: 'something_else', version: 1)),
        throwsFormatException);
  });

  test('rejects version above current', () {
    expect(
        () => decodeBackupExcel(
            _metaOnlyXlsx(format: kBackupFormat, version: 99)),
        throwsFormatException);
  });

  test('rejects missing data segments', () {
    expect(
        () => decodeBackupExcel(
            _metaOnlyXlsx(format: kBackupFormat, version: 1)),
        throwsFormatException);
  });

  test('decodes older backups that predate the SpendingHistory sheets', () {
    // Simulates a backup exported before this feature existed: every
    // required segment present, but no SpendingHistory/SpendingHistoryItems
    // sheets at all. encodeBackupExcel always writes those two sheets (the
    // `excel` package auto-creates a sheet on first access via `excel[name]`,
    // even for an empty list), so to get a workbook that truly lacks them we
    // decode the encoded bytes, delete the two sheets, and re-encode.
    final data = _sampleData();
    final excel = Excel.decodeBytes(encodeBackupExcel(data));
    excel.delete('SpendingHistory');
    excel.delete('SpendingHistoryItems');
    final bytes = excel.encode()!;

    final decoded = decodeBackupExcel(bytes);

    expect(decoded.budgetHistory, isEmpty);
  });
}
