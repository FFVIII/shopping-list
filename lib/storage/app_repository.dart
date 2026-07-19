import 'package:hive/hive.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../models/item.dart';
import 'hive_models.dart';

/// Restores canonical (Chinese) names for the six built-in default categories
/// that older builds persisted with translated (English) names — which broke
/// UI language switching, since display translation only goes canonical→other.
///
/// Only a category whose `id` matches a default AND whose current name is still
/// exactly that default's English translation is rewritten; custom categories
/// and user-renamed defaults are left untouched. Idempotent: canonical names
/// don't match the English translation, so re-running is a no-op.
void migrateDefaultCategoryNamesToCanonical(List<Category> categories) {
  final canonicalById = {
    for (final c in buildDefaultCategories()) c.id: c.name,
  };
  final en = EnStrings();
  for (final c in categories) {
    final canonical = canonicalById[c.id];
    if (canonical != null && c.name == en.data(canonical)) {
      c.name = canonical;
    }
  }
}

/// Strips non-digit characters from persisted quantity labels. Older builds
/// stored them as free text with a unit (e.g. "2件", "500g"); quantities are
/// now plain numbers entered via a digits-only field. Idempotent — labels that
/// are already numeric (or empty) are unchanged.
void migrateQuantityLabelsToDigits(
  List<ShoppingItem> shopping,
  List<InventoryItem> inventory,
) {
  String digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');
  for (final i in shopping) {
    i.quantityLabel = digitsOnly(i.quantityLabel);
  }
  for (final i in inventory) {
    i.quantityLabel = digitsOnly(i.quantityLabel);
  }
}

class AppData {
  final List<ShoppingItem> shoppingSimple;
  final List<ShoppingItem> shoppingSmart;
  final List<InventoryItem> inventory;
  final List<BudgetItem> budget;
  final List<BudgetHistoryEntry> budgetHistory;
  final List<Category> categories;
  final AppSettings settings;
  final List<String> shelfCodeOrder;

  AppData({
    required this.shoppingSimple,
    required this.shoppingSmart,
    required this.inventory,
    required this.budget,
    required this.budgetHistory,
    required this.categories,
    required this.settings,
    required this.shelfCodeOrder,
  });
}

/// Single read/write entry point for all locally-persisted app data.
/// Backed by 7 Hive boxes, each storing one logical collection under a
/// fixed `'items'` (or named) key as a plain `Map`/`List` — no `TypeAdapter`
/// registration needed since [hive_models.dart] reduces every model to
/// primitives before it reaches Hive.
class AppRepository {
  late Box _shoppingSimpleBox;
  late Box _shoppingSmartBox;
  late Box _inventoryBox;
  late Box _budgetBox;
  late Box _budgetHistoryBox;
  late Box _categoriesBox;
  late Box _metaBox;

  Future<void> init() async {
    _shoppingSimpleBox = await Hive.openBox('shopping_simple');
    _shoppingSmartBox = await Hive.openBox('shopping_smart');
    _inventoryBox = await Hive.openBox('inventory');
    _budgetBox = await Hive.openBox('budget');
    _budgetHistoryBox = await Hive.openBox('budget_history');
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
    // Older builds seeded default category names translated into the install
    // language (e.g. '果蔬' → 'Produce'), which broke language switching since
    // display translation is one-way (canonical zh → en). Restore canonical
    // names so l.data() can localize them again. Idempotent; leaves custom and
    // user-renamed categories untouched.
    migrateDefaultCategoryNamesToCanonical(categories);

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
    // Older builds stored quantity labels as free text with units (e.g. "2件");
    // quantities are now plain numbers. Strip any non-digits so existing data
    // matches the new digits-only input. Idempotent.
    migrateQuantityLabelsToDigits([
      ...shoppingSimple,
      ...shoppingSmart,
    ], inventory);

    final budget = ((_budgetBox.get('items') as List?) ?? const [])
        .cast<Map>()
        .map(budgetItemFromMap)
        .toList();

    final budgetHistory =
        ((_budgetHistoryBox.get('items') as List?) ?? const [])
            .cast<Map>()
            .map(budgetHistoryEntryFromMap)
            .toList();

    final settingsMap = _metaBox.get('settings') as Map?;
    final settings = settingsMap != null
        ? appSettingsFromMap(settingsMap)
        : AppSettings();

    final shelfCodeOrder =
        (_metaBox.get('shelf_code_order') as List?)?.cast<String>() ??
        <String>[];

    return AppData(
      shoppingSimple: shoppingSimple,
      shoppingSmart: shoppingSmart,
      inventory: inventory,
      budget: budget,
      budgetHistory: budgetHistory,
      categories: categories,
      settings: settings,
      shelfCodeOrder: shelfCodeOrder,
    );
  }

  Future<void> _seedInitialData(Lang lang) async {
    // Always seed canonical (zh) category names; display sites localize them
    // via l.data(). Storing translated names here would break switching the UI
    // language later (see migrateDefaultCategoryNamesToCanonical).
    final categories = buildDefaultCategories();
    await _categoriesBox.put(
      'items',
      categories.map((c) => c.toMap()).toList(),
    );
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

  Future<void> saveHistory(List<BudgetHistoryEntry> entries) =>
      _budgetHistoryBox.put('items', entries.map((e) => e.toMap()).toList());

  Future<void> saveCategories(List<Category> categories) =>
      _categoriesBox.put('items', categories.map((c) => c.toMap()).toList());

  Future<void> saveSettings(AppSettings settings) =>
      _metaBox.put('settings', settings.toMap());

  Future<void> saveShelfCodeOrder(List<String> order) =>
      _metaBox.put('shelf_code_order', order);

  /// Purchase entitlement — intentionally NOT part of [AppData]/[replaceAll]:
  /// restoring a backup from another install must not overwrite whether
  /// *this* Apple ID has purchased Pro.
  Future<bool> loadIsPro() async => _metaBox.get('is_pro') as bool? ?? false;

  Future<void> saveIsPro(bool value) => _metaBox.put('is_pro', value);

  /// Overwrites every persisted collection with [data] (backup import,
  /// spec 2026-07-02 §5.3).
  Future<void> replaceAll(AppData data) async {
    await saveCategories(data.categories);
    await saveShoppingSimple(data.shoppingSimple);
    await saveShoppingSmart(data.shoppingSmart);
    await saveInventory(data.inventory);
    await saveBudget(data.budget);
    await saveHistory(data.budgetHistory);
    await saveSettings(data.settings);
    await saveShelfCodeOrder(data.shelfCodeOrder);
  }
}
