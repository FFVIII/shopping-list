import 'package:excel/excel.dart';

import '../models/item.dart';
import 'app_repository.dart';
import 'hive_models.dart';

const String kBackupFormat = 'shopping_list_backup';
const int kBackupVersion = 1;

// Column order per sheet — must match the keys produced by the matching
// toMap() extension in hive_models.dart.
const _categoriesColumns = [
  'id', 'name', 'color', 'bgColor', 'shelfZone', 'defaultDays'
];
const _shoppingColumns = [
  'id', 'name', 'categoryId', 'quantityLabel', 'shelfZone', 'shelfCode',
  'estimatedDays', 'checked', 'addedToInventory', 'sourceInventoryId'
];
const _inventoryColumns = [
  'id', 'name', 'categoryId', 'shelfZone', 'shelfCode', 'quantityLabel',
  'purchasedAt', 'estimatedDays'
];
const _budgetColumns = ['id', 'name', 'quantity', 'unitPrice'];
const _settingsColumns = [
  'reminderThresholdDays', 'restockReminderEnabled', 'reminderHour',
  'reminderMinute'
];
const _shelfZonesColumns = ['name', 'dotColor'];
const _shelfCodeOrderColumns = ['code'];

CellValue? _cellValueFor(Object? v) {
  if (v == null) return null;
  if (v is bool) return BoolCellValue(v);
  if (v is int) return IntCellValue(v);
  if (v is double) return DoubleCellValue(v);
  return TextCellValue(v.toString());
}

Object? _rawValueFromCell(Data? cell) {
  final v = cell?.value;
  return switch (v) {
    null => null,
    BoolCellValue() => v.value,
    IntCellValue() => v.value,
    DoubleCellValue() => v.value,
    TextCellValue() => v.value.toString(),
    _ => v.toString(),
  };
}

void _writeMapsSheet(
  Excel excel,
  String sheetName,
  List<Map<String, dynamic>> maps,
  List<String> columns,
) {
  final sheet = excel[sheetName];
  sheet.appendRow(columns.map((c) => TextCellValue(c)).toList());
  for (final m in maps) {
    sheet.appendRow(columns.map((c) => _cellValueFor(m[c])).toList());
  }
}

List<Map<String, dynamic>> _readMapsSheet(Excel excel, String sheetName) {
  final sheet = excel.tables[sheetName];
  if (sheet == null) {
    throw FormatException('backup: missing sheet $sheetName');
  }
  final rows = sheet.rows;
  if (rows.isEmpty) {
    throw FormatException('backup: sheet $sheetName has no header row');
  }
  final header =
      rows.first.map((c) => _rawValueFromCell(c) as String? ?? '').toList();
  return rows.skip(1).map((row) {
    final map = <String, dynamic>{};
    for (var i = 0; i < header.length; i++) {
      map[header[i]] = i < row.length ? _rawValueFromCell(row[i]) : null;
    }
    return map;
  }).toList();
}

/// Full-app backup as an .xlsx workbook, one sheet per data segment (plus a
/// `Meta` sheet with format/version/exportedAt). All segments reuse the
/// primitive-only toMap encodings from hive_models.dart.
List<int> encodeBackupExcel(AppData data) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();

  final meta = excel['Meta'];
  meta.appendRow([TextCellValue('key'), TextCellValue('value')]);
  meta.appendRow([TextCellValue('format'), TextCellValue(kBackupFormat)]);
  meta.appendRow([TextCellValue('version'), IntCellValue(kBackupVersion)]);
  meta.appendRow([
    TextCellValue('exportedAt'),
    TextCellValue(DateTime.now().toIso8601String()),
  ]);

  _writeMapsSheet(excel, 'Categories',
      data.categories.map((c) => c.toMap()).toList(), _categoriesColumns);
  _writeMapsSheet(excel, 'ShoppingSimple',
      data.shoppingSimple.map((i) => i.toMap()).toList(), _shoppingColumns);
  _writeMapsSheet(excel, 'ShoppingSmart',
      data.shoppingSmart.map((i) => i.toMap()).toList(), _shoppingColumns);
  _writeMapsSheet(excel, 'Inventory',
      data.inventory.map((i) => i.toMap()).toList(), _inventoryColumns);
  _writeMapsSheet(excel, 'Budget',
      data.budget.map((i) => i.toMap()).toList(), _budgetColumns);
  _writeMapsSheet(excel, 'Settings', [data.settings.toMap()], _settingsColumns);
  _writeMapsSheet(excel, 'ShelfZones',
      data.shelfZones.map((z) => z.toMap()).toList(), _shelfZonesColumns);
  _writeMapsSheet(
      excel,
      'ShelfCodeOrder',
      data.shelfCodeOrder.map((c) => {'code': c}).toList(),
      _shelfCodeOrderColumns);

  if (defaultSheet != null) excel.delete(defaultSheet);

  final bytes = excel.encode();
  if (bytes == null) {
    throw const FormatException('backup: failed to encode excel file');
  }
  return bytes;
}

/// Throws [FormatException] on any structural problem — never returns a
/// partially-decoded result (spec §6: import is all-or-nothing).
AppData decodeBackupExcel(List<int> bytes) {
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (e) {
    throw const FormatException('backup: not a valid .xlsx file');
  }
  try {
    final metaRows = (excel.tables['Meta']?.rows ?? []).skip(1);
    final meta = <String, dynamic>{
      for (final row in metaRows)
        if (row.isNotEmpty)
          (_rawValueFromCell(row[0]) as String?) ?? '':
              row.length > 1 ? _rawValueFromCell(row[1]) : null,
    };
    if (meta['format'] != kBackupFormat) {
      throw const FormatException('backup: unrecognized format');
    }
    final version = meta['version'];
    if (version is! int || version < 1 || version > kBackupVersion) {
      throw FormatException('backup: unsupported version $version');
    }

    final categories = _readMapsSheet(excel, 'Categories')
        .map(categoryFromMap)
        .toList();
    List<ShoppingItem> shopping(String sheetName) =>
        _readMapsSheet(excel, sheetName)
            .map((m) => shoppingItemFromMap(m, categories))
            .toList();

    return AppData(
      shoppingSimple: shopping('ShoppingSimple'),
      shoppingSmart: shopping('ShoppingSmart'),
      inventory: _readMapsSheet(excel, 'Inventory')
          .map((m) => inventoryItemFromMap(m, categories))
          .toList(),
      budget:
          _readMapsSheet(excel, 'Budget').map(budgetItemFromMap).toList(),
      categories: categories,
      settings: appSettingsFromMap(_readMapsSheet(excel, 'Settings').first),
      shelfZones: _readMapsSheet(excel, 'ShelfZones')
          .map(shelfZoneFromMap)
          .toList(),
      shelfCodeOrder: _readMapsSheet(excel, 'ShelfCodeOrder')
          .map((m) => m['code'] as String)
          .toList(),
    );
  } on FormatException {
    rethrow;
  } catch (e) {
    // Covers wrong types, missing sheets/keys, bad values, etc.
    throw FormatException('backup: malformed content: $e');
  }
}
