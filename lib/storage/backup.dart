import 'dart:convert';

import '../models/item.dart';
import 'app_repository.dart';
import 'hive_models.dart';

const String kBackupFormat = 'shopping_list_backup';
const int kBackupVersion = 1;

/// Full-app backup as pretty-printed JSON. All eight data segments reuse the
/// primitive-only toMap encodings from hive_models.dart.
String encodeBackup(AppData data) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': kBackupFormat,
      'version': kBackupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': data.categories.map((c) => c.toMap()).toList(),
      'shoppingSimple': data.shoppingSimple.map((i) => i.toMap()).toList(),
      'shoppingSmart': data.shoppingSmart.map((i) => i.toMap()).toList(),
      'inventory': data.inventory.map((i) => i.toMap()).toList(),
      'budget': data.budget.map((i) => i.toMap()).toList(),
      'settings': data.settings.toMap(),
      'shelfZones': data.shelfZones.map((z) => z.toMap()).toList(),
      'shelfCodeOrder': data.shelfCodeOrder,
    });

/// Throws [FormatException] on any structural problem — never returns a
/// partially-decoded result (spec §6: import is all-or-nothing).
AppData decodeBackup(String source) {
  final Object? root;
  try {
    root = jsonDecode(source);
  } on FormatException {
    throw const FormatException('backup: not valid JSON');
  }
  if (root is! Map) {
    throw const FormatException('backup: root is not an object');
  }
  if (root['format'] != kBackupFormat) {
    throw const FormatException('backup: unrecognized format');
  }
  final version = root['version'];
  if (version is! int || version < 1 || version > kBackupVersion) {
    throw FormatException('backup: unsupported version $version');
  }
  final Map map = root;
  try {
    final categories =
        (map['categories'] as List).cast<Map>().map(categoryFromMap).toList();
    List<ShoppingItem> shopping(String key) => (map[key] as List)
        .cast<Map>()
        .map((m) => shoppingItemFromMap(m, categories))
        .toList();
    return AppData(
      shoppingSimple: shopping('shoppingSimple'),
      shoppingSmart: shopping('shoppingSmart'),
      inventory: (map['inventory'] as List)
          .cast<Map>()
          .map((m) => inventoryItemFromMap(m, categories))
          .toList(),
      budget:
          (map['budget'] as List).cast<Map>().map(budgetItemFromMap).toList(),
      categories: categories,
      settings: appSettingsFromMap(map['settings'] as Map),
      shelfZones: (map['shelfZones'] as List)
          .cast<Map>()
          .map(shelfZoneFromMap)
          .toList(),
      shelfCodeOrder: (map['shelfCodeOrder'] as List).cast<String>(),
    );
  } catch (e) {
    // Covers wrong types, missing keys (null casts), bad values, etc.
    throw FormatException('backup: malformed content: $e');
  }
}
