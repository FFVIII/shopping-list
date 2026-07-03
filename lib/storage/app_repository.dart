import 'package:hive/hive.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../models/item.dart';
import 'hive_models.dart';

class AppData {
  final List<ShoppingItem> shoppingSimple;
  final List<ShoppingItem> shoppingSmart;
  final List<InventoryItem> inventory;
  final List<BudgetItem> budget;
  final List<Category> categories;
  final AppSettings settings;
  final List<ShelfZone> shelfZones;
  final List<String> shelfCodeOrder;

  AppData({
    required this.shoppingSimple,
    required this.shoppingSmart,
    required this.inventory,
    required this.budget,
    required this.categories,
    required this.settings,
    required this.shelfZones,
    required this.shelfCodeOrder,
  });
}

/// Single read/write entry point for all locally-persisted app data.
/// Backed by 6 Hive boxes, each storing one logical collection under a
/// fixed `'items'` (or named) key as a plain `Map`/`List` — no `TypeAdapter`
/// registration needed since [hive_models.dart] reduces every model to
/// primitives before it reaches Hive.
class AppRepository {
  late Box _shoppingSimpleBox;
  late Box _shoppingSmartBox;
  late Box _inventoryBox;
  late Box _budgetBox;
  late Box _categoriesBox;
  late Box _metaBox;

  Future<void> init() async {
    _shoppingSimpleBox = await Hive.openBox('shopping_simple');
    _shoppingSmartBox = await Hive.openBox('shopping_smart');
    _inventoryBox = await Hive.openBox('inventory');
    _budgetBox = await Hive.openBox('budget');
    _categoriesBox = await Hive.openBox('categories');
    _metaBox = await Hive.openBox('app_meta');
  }

  /// Loads all persisted data. On first install (no categories saved yet),
  /// seeds the sample data set once — translated to English category names
  /// when [lang] is [Lang.en] — and persists it before returning it.
  Future<AppData> load({required Lang lang}) async {
    final isFirstInstall = _categoriesBox.get('items') == null;
    if (isFirstInstall) {
      await _seedInitialData(lang);
    }

    final categories = (_categoriesBox.get('items') as List)
        .cast<Map>()
        .map(categoryFromMap)
        .toList();

    List<ShoppingItem> readShopping(Box box) =>
        ((box.get('items') as List?) ?? const [])
            .cast<Map>()
            .map((m) => shoppingItemFromMap(m, categories))
            .toList();

    final shoppingSimple = readShopping(_shoppingSimpleBox);
    final shoppingSmart = readShopping(_shoppingSmartBox);

    final inventory = ((_inventoryBox.get('items') as List?) ?? const [])
        .cast<Map>()
        .map((m) => inventoryItemFromMap(m, categories))
        .toList();

    final budget = ((_budgetBox.get('items') as List?) ?? const [])
        .cast<Map>()
        .map(budgetItemFromMap)
        .toList();

    final settingsMap = _metaBox.get('settings') as Map?;
    final settings =
        settingsMap != null ? appSettingsFromMap(settingsMap) : AppSettings();

    final zonesList = _metaBox.get('shelf_zones') as List?;
    final shelfZones = zonesList != null
        ? zonesList.cast<Map>().map(shelfZoneFromMap).toList()
        : defaultShelfZones.toList();

    final shelfCodeOrder =
        (_metaBox.get('shelf_code_order') as List?)?.cast<String>() ??
            <String>[];

    return AppData(
      shoppingSimple: shoppingSimple,
      shoppingSmart: shoppingSmart,
      inventory: inventory,
      budget: budget,
      categories: categories,
      settings: settings,
      shelfZones: shelfZones,
      shelfCodeOrder: shelfCodeOrder,
    );
  }

  Future<void> _seedInitialData(Lang lang) async {
    final categories = buildDefaultCategories();
    if (lang == Lang.en) {
      final en = EnStrings();
      for (final c in categories) {
        c.name = en.data(c.name);
      }
    }
    await _categoriesBox.put(
        'items', categories.map((c) => c.toMap()).toList());
    // Shopping/inventory/budget start empty — only the category structure
    // is seeded. See design spec 2026-07-02 §3.
    await _shoppingSmartBox.put('items', <Map>[]);
    await _inventoryBox.put('items', <Map>[]);
    await _budgetBox.put('items', <Map>[]);
  }

  Future<void> saveShoppingSimple(List<ShoppingItem> items) =>
      _shoppingSimpleBox.put('items', items.map((i) => i.toMap()).toList());

  Future<void> saveShoppingSmart(List<ShoppingItem> items) =>
      _shoppingSmartBox.put('items', items.map((i) => i.toMap()).toList());

  Future<void> saveInventory(List<InventoryItem> items) =>
      _inventoryBox.put('items', items.map((i) => i.toMap()).toList());

  Future<void> saveBudget(List<BudgetItem> items) =>
      _budgetBox.put('items', items.map((i) => i.toMap()).toList());

  Future<void> saveCategories(List<Category> categories) =>
      _categoriesBox.put('items', categories.map((c) => c.toMap()).toList());

  Future<void> saveSettings(AppSettings settings) =>
      _metaBox.put('settings', settings.toMap());

  Future<void> saveShelfZones(List<ShelfZone> zones) =>
      _metaBox.put('shelf_zones', zones.map((z) => z.toMap()).toList());

  Future<void> saveShelfCodeOrder(List<String> order) =>
      _metaBox.put('shelf_code_order', order);

  /// Overwrites every persisted collection with [data] (backup import,
  /// spec 2026-07-02 §5.3).
  Future<void> replaceAll(AppData data) async {
    await saveCategories(data.categories);
    await saveShoppingSimple(data.shoppingSimple);
    await saveShoppingSmart(data.shoppingSmart);
    await saveInventory(data.inventory);
    await saveBudget(data.budget);
    await saveSettings(data.settings);
    await saveShelfZones(data.shelfZones);
    await saveShelfCodeOrder(data.shelfCodeOrder);
  }
}
