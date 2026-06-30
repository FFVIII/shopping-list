# 本地数据库持久化（Hive）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist all user data (shopping lists, inventory, budget, categories, shelf zones/codes, settings) to a local Hive database so it survives a full app restart, replacing the current in-memory-only state.

**Architecture:** New `lib/storage/` layer: `hive_models.dart` (hand-written `toMap`/`fromMap` converters, no codegen) + `app_repository.dart` (single `AppRepository` class wrapping 6 Hive boxes, exposing `load()`/`save*()`). `main.dart` opens Hive and the repository before `runApp`, `_AppShellState` loads data asynchronously on `initState`, and every existing mutation method gets one extra line calling the matching `save*()` after its `setState`.

**Tech Stack:** Flutter, Dart, `hive` + `hive_flutter` packages (no `hive_generator`/`build_runner`).

See design spec: `docs/superpowers/specs/2026-06-30-local-persistence-design.md`

---

## Task 1: Add Hive dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add `hive` and `hive_flutter` to `dependencies`**

In `pubspec.yaml`, find this block:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  cupertino_icons: ^1.0.8
  speech_to_text: ^7.0.0
  shared_preferences: ^2.3.2
```

Replace it with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  cupertino_icons: ^1.0.8
  speech_to_text: ^7.0.0
  shared_preferences: ^2.3.2
  hive: ^2.2.3
  hive_flutter: ^1.1.0
```

- [ ] **Step 2: Fetch packages**

Run: `flutter pub get`
Expected: completes with `hive` and `hive_flutter` listed as added/changed dependencies, no errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add hive for local persistence"
```

---

## Task 2: Storage format converters (`hive_models.dart`)

**Files:**
- Create: `lib/storage/hive_models.dart`
- Test: `test/storage/hive_models_test.dart`
- Reference: `lib/models/item.dart` (existing `Category`, `ShoppingItem`, `InventoryItem`, `BudgetItem`, `AppSettings`, `ShelfZone`, `CategoryListLookup.findById`)

This task converts each model to/from a plain `Map` (the format Hive stores natively, no `TypeAdapter` needed since every field collapses to `String`/`int`/`double`/`bool`/`List`).

- [ ] **Step 1: Write the failing tests**

Create `test/storage/hive_models_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/storage/hive_models_test.dart`
Expected: FAIL — `lib/storage/hive_models.dart` doesn't exist yet (`Target of URI doesn't exist` compile error).

- [ ] **Step 3: Create `lib/storage/hive_models.dart`**

```dart
import 'package:flutter/material.dart';
import '../models/item.dart';

// ─── Category ────────────────────────────────────────────────────────────────

extension CategoryHiveX on Category {
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
        'bgColor': bgColor.toARGB32(),
        'shelfZone': shelfZone,
        'defaultDays': defaultDays,
      };
}

Category categoryFromMap(Map map) => Category(
      id: map['id'] as String,
      name: map['name'] as String,
      color: Color(map['color'] as int),
      bgColor: Color(map['bgColor'] as int),
      shelfZone: map['shelfZone'] as String,
      defaultDays: map['defaultDays'] as int,
    );

// ─── ShoppingItem ─────────────────────────────────────────────────────────────

extension ShoppingItemHiveX on ShoppingItem {
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'categoryId': category.id,
        'quantityLabel': quantityLabel,
        'shelfZone': shelfZone,
        'shelfCode': shelfCode,
        'estimatedDays': estimatedDays,
        'checked': checked,
        'addedToInventory': addedToInventory,
      };
}

ShoppingItem shoppingItemFromMap(Map map, List<Category> categories) =>
    ShoppingItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category:
          categories.findById(map['categoryId'] as String) ?? categories.fallback,
      quantityLabel: map['quantityLabel'] as String,
      shelfZone: map['shelfZone'] as String,
      shelfCode: map['shelfCode'] as String?,
      estimatedDays: map['estimatedDays'] as int?,
      checked: map['checked'] as bool? ?? false,
      addedToInventory: map['addedToInventory'] as bool? ?? false,
    );

// ─── InventoryItem ────────────────────────────────────────────────────────────

extension InventoryItemHiveX on InventoryItem {
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'categoryId': category.id,
        'shelfZone': shelfZone,
        'shelfCode': shelfCode,
        'quantityLabel': quantityLabel,
        'purchasedAt': purchasedAt.millisecondsSinceEpoch,
        'estimatedDays': estimatedDays,
      };
}

InventoryItem inventoryItemFromMap(Map map, List<Category> categories) =>
    InventoryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category:
          categories.findById(map['categoryId'] as String) ?? categories.fallback,
      shelfZone: map['shelfZone'] as String,
      shelfCode: map['shelfCode'] as String?,
      quantityLabel: map['quantityLabel'] as String? ?? '',
      purchasedAt: DateTime.fromMillisecondsSinceEpoch(map['purchasedAt'] as int),
      estimatedDays: map['estimatedDays'] as int,
    );

// ─── BudgetItem ───────────────────────────────────────────────────────────────

extension BudgetItemHiveX on BudgetItem {
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}

BudgetItem budgetItemFromMap(Map map) => BudgetItem(
      id: map['id'] as String,
      name: map['name'] as String,
      quantity: map['quantity'] as int? ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
    );

// ─── AppSettings ──────────────────────────────────────────────────────────────

extension AppSettingsHiveX on AppSettings {
  Map<String, dynamic> toMap() => {
        'reminderThresholdDays': reminderThresholdDays,
        'restockReminderEnabled': restockReminderEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      };
}

AppSettings appSettingsFromMap(Map map) => AppSettings(
      reminderThresholdDays: map['reminderThresholdDays'] as int? ?? 5,
      restockReminderEnabled: map['restockReminderEnabled'] as bool? ?? true,
      reminderHour: map['reminderHour'] as int? ?? 18,
      reminderMinute: map['reminderMinute'] as int? ?? 0,
    );

// ─── ShelfZone ────────────────────────────────────────────────────────────────

extension ShelfZoneHiveX on ShelfZone {
  Map<String, dynamic> toMap() => {
        'name': name,
        'dotColor': dotColor.toARGB32(),
      };
}

ShelfZone shelfZoneFromMap(Map map) => ShelfZone(
      map['name'] as String,
      Color(map['dotColor'] as int),
    );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/storage/hive_models_test.dart`
Expected: PASS — all 6 groups (`Category`, `ShoppingItem` x2, `InventoryItem`, `BudgetItem`, `AppSettings`, `ShelfZone`) green.

- [ ] **Step 5: Commit**

```bash
git add lib/storage/hive_models.dart test/storage/hive_models_test.dart
git commit -m "feat: add Hive map converters for all models"
```

---

## Task 3: Repository (`app_repository.dart`)

**Files:**
- Create: `lib/storage/app_repository.dart`
- Test: `test/storage/app_repository_test.dart`
- Reference: `lib/storage/hive_models.dart` (Task 2), `lib/models/item.dart` (`buildDefaultCategories`, `buildSampleShopping`, `buildSampleInventory`, `buildSampleBudget`, `defaultShelfZones`), `lib/l10n/app_language.dart` (`Lang`), `lib/l10n/app_strings.dart` (`EnStrings`)

- [ ] **Step 1: Write the failing tests**

Create `test/storage/app_repository_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/storage/app_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('first load seeds sample data and reports it back', () async {
    final repo = AppRepository();
    await repo.init();

    final data = await repo.load(lang: Lang.zh);

    expect(data.categories, isNotEmpty);
    expect(data.shoppingSmart, isNotEmpty);
    expect(data.inventory, isNotEmpty);
    expect(data.budget, isNotEmpty);
    expect(data.shoppingSimple, isEmpty);
    expect(data.shelfCodeOrder, isEmpty);
    expect(data.settings.reminderThresholdDays, 5);
    expect(data.shelfZones, isNotEmpty);
  });

  test('seeds English category names when lang is en', () async {
    final repo = AppRepository();
    await repo.init();

    final data = await repo.load(lang: Lang.en);

    final produce = data.categories.findById('produce');
    expect(produce, isNotNull);
    expect(produce!.name, isNot('果蔬'));
  });

  test('second load does not reseed — preserves saved changes', () async {
    final repo1 = AppRepository();
    await repo1.init();
    final firstData = await repo1.load(lang: Lang.zh);

    final edited = [...firstData.shoppingSimple, ShoppingItem(
      id: 'manual_1',
      name: '手动添加',
      category: firstData.categories.fallback,
      quantityLabel: '',
      shelfZone: '其他',
    )];
    await repo1.saveShoppingSimple(edited);

    final repo2 = AppRepository();
    await repo2.init();
    final secondData = await repo2.load(lang: Lang.zh);

    expect(secondData.shoppingSimple.map((i) => i.id), contains('manual_1'));
    // Sample data must not have been regenerated a second time.
    expect(secondData.categories.length, firstData.categories.length);
  });

  test('saveCategories/saveSettings/saveShelfZones/saveShelfCodeOrder round-trip',
      () async {
    final repo = AppRepository();
    await repo.init();
    final data = await repo.load(lang: Lang.zh);

    final newSettings = AppSettings(
      reminderThresholdDays: 2,
      restockReminderEnabled: false,
      reminderHour: 7,
      reminderMinute: 45,
    );
    await repo.saveSettings(newSettings);
    await repo.saveShelfCodeOrder(['货架A1', '货架B2']);

    final repo2 = AppRepository();
    await repo2.init();
    final reloaded = await repo2.load(lang: Lang.zh);

    expect(reloaded.settings.reminderThresholdDays, 2);
    expect(reloaded.settings.reminderHour, 7);
    expect(reloaded.shelfCodeOrder, ['货架A1', '货架B2']);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/storage/app_repository_test.dart`
Expected: FAIL — `lib/storage/app_repository.dart` doesn't exist yet.

- [ ] **Step 3: Create `lib/storage/app_repository.dart`**

```dart
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
    await _shoppingSmartBox.put('items',
        buildSampleShopping(categories).map((i) => i.toMap()).toList());
    await _inventoryBox.put('items',
        buildSampleInventory(categories).map((i) => i.toMap()).toList());
    await _budgetBox.put(
        'items', buildSampleBudget().map((i) => i.toMap()).toList());
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
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/storage/app_repository_test.dart`
Expected: PASS — all 4 tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/storage/app_repository.dart test/storage/app_repository_test.dart
git commit -m "feat: add AppRepository for Hive-backed persistence"
```

---

## Task 4: Wire app bootstrap and loading state

**Files:**
- Modify: `lib/main.dart:1-122` (imports, `main()`, `ShoppingListApp`, `AppShell`, `_AppShellState.initState`)
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Update imports and `main()`**

In `lib/main.dart`, replace:

```dart
import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'models/item.dart';
import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';
import 'l10n/l10n.dart';
import 'l10n/language_store.dart';
import 'screens/list_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reminder_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/days_selector.dart';

part 'main.widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final lang = await LanguageStore.load();
  runApp(ShoppingListApp(initialLanguage: lang));
}
```

with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'models/item.dart';
import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';
import 'l10n/l10n.dart';
import 'l10n/language_store.dart';
import 'screens/list_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reminder_screen.dart';
import 'screens/settings_screen.dart';
import 'storage/app_repository.dart';
import 'widgets/days_selector.dart';

part 'main.widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final repository = AppRepository();
  await repository.init();
  final lang = await LanguageStore.load();
  runApp(ShoppingListApp(initialLanguage: lang, repository: repository));
}
```

- [ ] **Step 2: Thread `repository` through `ShoppingListApp` and `AppShell`**

Replace:

```dart
class ShoppingListApp extends StatefulWidget {
  final AppLanguage initialLanguage;
  const ShoppingListApp({super.key, required this.initialLanguage});

  @override
  State<ShoppingListApp> createState() => _ShoppingListAppState();
}
```

with:

```dart
class ShoppingListApp extends StatefulWidget {
  final AppLanguage initialLanguage;
  final AppRepository repository;
  const ShoppingListApp({
    super.key,
    required this.initialLanguage,
    required this.repository,
  });

  @override
  State<ShoppingListApp> createState() => _ShoppingListAppState();
}
```

Then replace:

```dart
        home: AppShell(
          language: _language,
          onLanguageChanged: _setLanguage,
        ),
```

with:

```dart
        home: AppShell(
          language: _language,
          onLanguageChanged: _setLanguage,
          repository: widget.repository,
        ),
```

Then replace:

```dart
class AppShell extends StatefulWidget {
  final AppLanguage language;
  final void Function(AppLanguage) onLanguageChanged;
  const AppShell({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}
```

with:

```dart
class AppShell extends StatefulWidget {
  final AppLanguage language;
  final void Function(AppLanguage) onLanguageChanged;
  final AppRepository repository;
  const AppShell({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.repository,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}
```

- [ ] **Step 3: Replace synchronous sample-data `initState` with async load**

Replace:

```dart
class _AppShellState extends State<AppShell> {
  int _tab = 0;
  int _smartModeRequest = 0;
  late List<ShoppingItem> _shoppingSimple;
  late List<ShoppingItem> _shopping;
  late List<InventoryItem> _inventory;
  late List<BudgetItem> _budget;
  late AppSettings _settings;
  late List<ShelfZone> _shelfZones;
  List<String> _shelfCodeOrder = [];
  late List<Category> _categories;

  @override
  void initState() {
    super.initState();
    _shoppingSimple = [];
    _categories = buildDefaultCategories();
    // Seed default category names in the active language (English if resolved
    // to en). After seeding, names are plain user-editable strings.
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final lang = resolveLang(widget.language, deviceLocale);
    if (lang == Lang.en) {
      final en = EnStrings();
      for (final c in _categories) {
        c.name = en.data(c.name);
      }
    }
    _shopping = buildSampleShopping(_categories);
    _inventory = buildSampleInventory(_categories);
    _budget = buildSampleBudget();
    _settings = AppSettings();
    _shelfZones = defaultShelfZones.toList();
  }
```

with:

```dart
class _AppShellState extends State<AppShell> {
  int _tab = 0;
  int _smartModeRequest = 0;
  bool _loading = true;
  late List<ShoppingItem> _shoppingSimple;
  late List<ShoppingItem> _shopping;
  late List<InventoryItem> _inventory;
  late List<BudgetItem> _budget;
  late AppSettings _settings;
  late List<ShelfZone> _shelfZones;
  List<String> _shelfCodeOrder = [];
  late List<Category> _categories;

  AppRepository get _repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final lang = resolveLang(widget.language, deviceLocale);
    final data = await _repo.load(lang: lang);
    if (!mounted) return;
    setState(() {
      _shoppingSimple = data.shoppingSimple;
      _shopping = data.shoppingSmart;
      _inventory = data.inventory;
      _budget = data.budget;
      _categories = data.categories;
      _settings = data.settings;
      _shelfZones = data.shelfZones;
      _shelfCodeOrder = data.shelfCodeOrder;
      _loading = false;
    });
  }

  // ── Persistence: one helper per persisted collection, called after the ──
  // matching field is mutated. Fire-and-forget: write failures are logged,
  // not surfaced to the user (see design spec §5).
  void _persistShoppingSimple() => unawaited(_repo
      .saveShoppingSimple(_shoppingSimple)
      .catchError((e) => debugPrint('save shoppingSimple failed: $e')));
  void _persistShoppingSmart() => unawaited(_repo
      .saveShoppingSmart(_shopping)
      .catchError((e) => debugPrint('save shoppingSmart failed: $e')));
  void _persistInventory() => unawaited(_repo
      .saveInventory(_inventory)
      .catchError((e) => debugPrint('save inventory failed: $e')));
  void _persistBudget() => unawaited(_repo
      .saveBudget(_budget)
      .catchError((e) => debugPrint('save budget failed: $e')));
  void _persistCategories() => unawaited(_repo
      .saveCategories(_categories)
      .catchError((e) => debugPrint('save categories failed: $e')));
  void _persistSettings() => unawaited(_repo
      .saveSettings(_settings)
      .catchError((e) => debugPrint('save settings failed: $e')));
  void _persistShelfZones() => unawaited(_repo
      .saveShelfZones(_shelfZones)
      .catchError((e) => debugPrint('save shelfZones failed: $e')));
  void _persistShelfCodeOrder() => unawaited(_repo
      .saveShelfCodeOrder(_shelfCodeOrder)
      .catchError((e) => debugPrint('save shelfCodeOrder failed: $e')));
```

- [ ] **Step 4: Show a loading placeholder while data loads**

In `_AppShellState.build`, replace:

```dart
  @override
  Widget build(BuildContext context) {
    final threshold = _settings.reminderThresholdDays;
```

with:

```dart
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final threshold = _settings.reminderThresholdDays;
```

- [ ] **Step 5: Update the existing widget smoke test for the new constructor and async load**

Read `test/widget_test.dart` in full first (it has two `testWidgets` blocks, one per language). For **each** of the two blocks, apply these two changes:

1. Construct a real `AppRepository` against a temp Hive directory before pumping the widget.
2. Pass `repository:` into `ShoppingListApp(...)`.
3. Replace the single `await tester.pump();` after `pumpWidget` with `await tester.pumpAndSettle();` so the async `_loadData()` future (and its `setState`) completes before assertions run.

Add these imports to the top of `test/widget_test.dart`:

```dart
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:shopping_list/storage/app_repository.dart';
```

Wrap the body of `main()` with shared setup/teardown so both tests get an isolated Hive directory:

```dart
void main() {
  late Directory tempDir;
  late AppRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_widget_test_');
    Hive.init(tempDir.path);
    repository = AppRepository();
    await repository.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('App smoke test (zh): renders bottom nav labels',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ShoppingListApp(initialLanguage: AppLanguage.zh, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('清单'), findsOneWidget);
    expect(find.text('库存'), findsOneWidget);
    expect(find.text('提醒'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('App smoke test (en): renders bottom nav labels',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ShoppingListApp(initialLanguage: AppLanguage.en, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('List'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
```

Remove the old top-level `void main() { ... }` wrapper and the two `testWidgets` blocks' old bodies — they're fully replaced by the block above. Keep the existing `import 'package:flutter/material.dart';`, `import 'package:flutter_test/flutter_test.dart';`, `import 'package:shopping_list/main.dart';`, and `import 'package:shopping_list/l10n/app_language.dart';` lines at the top.

- [ ] **Step 6: Run the test suite**

Run: `flutter test`
Expected: PASS — `test/storage/hive_models_test.dart`, `test/storage/app_repository_test.dart`, and `test/widget_test.dart` all green. (The `l10n` test directory's existing tests, if any, should be unaffected — they don't touch `ShoppingListApp` construction.)

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "feat: bootstrap Hive and load app data asynchronously"
```

---

## Task 5: Wire shopping-list mutation methods (simple + smart)

**Files:**
- Modify: `lib/main.dart` (methods listed below, all already shown in full in the file read during planning — context lines included per edit)

For each method below, append exactly one persist call as the **last line inside the `setState` callback's enclosing method** (after the `setState(...)` call, not inside it — these run synchronously right after `setState` returns). Apply them one at a time; this task has no new tests of its own (mechanical wiring of already-tested persistence calls) — Task 9 verifies the end result manually.

- [ ] **Step 1: `_addSimple`**

Replace:

```dart
  void _addSimple(String name) {
    setState(() {
      _shoppingSimple.add(ShoppingItem(
        id: 's_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: _categories.fallback,
        quantityLabel: '',
        shelfZone: '其他',
      ));
    });
  }
```

with:

```dart
  void _addSimple(String name) {
    setState(() {
      _shoppingSimple.add(ShoppingItem(
        id: 's_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: _categories.fallback,
        quantityLabel: '',
        shelfZone: '其他',
      ));
    });
    _persistShoppingSimple();
  }
```

- [ ] **Step 2: `_addSmart`**

Replace:

```dart
  void _addSmart(String name, String quantityLabel, String? shelfCode, int estimatedDays, Category category, String shelfZone) {
    setState(() {
      _shopping.add(ShoppingItem(
        id: 'u_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: category,
        quantityLabel: quantityLabel.isEmpty ? '1件' : quantityLabel,
        shelfZone: shelfZone,
        shelfCode: shelfCode,
        estimatedDays: estimatedDays,
      ));
    });
  }
```

with:

```dart
  void _addSmart(String name, String quantityLabel, String? shelfCode, int estimatedDays, Category category, String shelfZone) {
    setState(() {
      _shopping.add(ShoppingItem(
        id: 'u_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: category,
        quantityLabel: quantityLabel.isEmpty ? '1件' : quantityLabel,
        shelfZone: shelfZone,
        shelfCode: shelfCode,
        estimatedDays: estimatedDays,
      ));
    });
    _persistShoppingSmart();
  }
```

- [ ] **Step 3: `_toggleSimple`**

Replace:

```dart
  void _toggleSimple(String id) {
    setState(() {
      final idx = _shoppingSimple.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _shoppingSimple[idx].checked = !_shoppingSimple[idx].checked;
    });
  }
```

with:

```dart
  void _toggleSimple(String id) {
    setState(() {
      final idx = _shoppingSimple.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _shoppingSimple[idx].checked = !_shoppingSimple[idx].checked;
    });
    _persistShoppingSimple();
  }
```

- [ ] **Step 4: `_confirmPurchase`**

Replace:

```dart
  void _confirmPurchase(
    ShoppingItem shoppingItem,
    int estimatedDays,
    String name,
    String quantity,
    String? shelfCode,
    Category category,
    String zone,
  ) {
    setState(() {
      final idx = _shopping.indexWhere((i) => i.id == shoppingItem.id);
      if (idx != -1) {
        _shopping[idx]
          ..estimatedDays = estimatedDays
          ..name = name
          ..quantityLabel = quantity
          ..shelfCode = shelfCode
          ..category = category
          ..shelfZone = zone;
      }
    });
  }
```

with:

```dart
  void _confirmPurchase(
    ShoppingItem shoppingItem,
    int estimatedDays,
    String name,
    String quantity,
    String? shelfCode,
    Category category,
    String zone,
  ) {
    setState(() {
      final idx = _shopping.indexWhere((i) => i.id == shoppingItem.id);
      if (idx != -1) {
        _shopping[idx]
          ..estimatedDays = estimatedDays
          ..name = name
          ..quantityLabel = quantity
          ..shelfCode = shelfCode
          ..category = category
          ..shelfZone = zone;
      }
    });
    _persistShoppingSmart();
  }
```

- [ ] **Step 5: `_reorderSimple`**

Replace:

```dart
  void _reorderSimple(List<String> orderedIds) {
    setState(() {
      _shoppingSimple = orderedIds
          .map((id) => _shoppingSimple.firstWhere((i) => i.id == id))
          .toList();
    });
  }
```

with:

```dart
  void _reorderSimple(List<String> orderedIds) {
    setState(() {
      _shoppingSimple = orderedIds
          .map((id) => _shoppingSimple.firstWhere((i) => i.id == id))
          .toList();
    });
    _persistShoppingSimple();
  }
```

- [ ] **Step 6: `_reorderSmart`**

Replace:

```dart
  void _reorderSmart(
    String movedId,
    String? newShelfZone,
    Category? newCategory,
    List<String> orderedIds,
    String? newShelfCode,
  ) {
    setState(() {
      final idx = _shopping.indexWhere((i) => i.id == movedId);
      if (idx != -1) {
        if (newShelfZone != null) _shopping[idx].shelfZone = newShelfZone;
        if (newCategory != null) _shopping[idx].category = newCategory;
        // newShelfCode non-null means shelf-mode drag: "" = clear code, else set
        if (newShelfCode != null) {
          _shopping[idx].shelfCode = newShelfCode.isEmpty ? null : newShelfCode;
        }
      }
      _shopping = orderedIds
          .map((id) => _shopping.firstWhere((i) => i.id == id))
          .toList();
    });
  }
```

with:

```dart
  void _reorderSmart(
    String movedId,
    String? newShelfZone,
    Category? newCategory,
    List<String> orderedIds,
    String? newShelfCode,
  ) {
    setState(() {
      final idx = _shopping.indexWhere((i) => i.id == movedId);
      if (idx != -1) {
        if (newShelfZone != null) _shopping[idx].shelfZone = newShelfZone;
        if (newCategory != null) _shopping[idx].category = newCategory;
        // newShelfCode non-null means shelf-mode drag: "" = clear code, else set
        if (newShelfCode != null) {
          _shopping[idx].shelfCode = newShelfCode.isEmpty ? null : newShelfCode;
        }
      }
      _shopping = orderedIds
          .map((id) => _shopping.firstWhere((i) => i.id == id))
          .toList();
    });
    _persistShoppingSmart();
  }
```

- [ ] **Step 7: `_deleteSimpleItem` and `_deleteSmartItem`**

Replace:

```dart
  void _deleteSimpleItem(String id) {
    setState(() => _shoppingSimple.removeWhere((i) => i.id == id));
  }

  void _deleteSmartItem(String id) {
    setState(() => _shopping.removeWhere((i) => i.id == id));
  }
```

with:

```dart
  void _deleteSimpleItem(String id) {
    setState(() => _shoppingSimple.removeWhere((i) => i.id == id));
    _persistShoppingSimple();
  }

  void _deleteSmartItem(String id) {
    setState(() => _shopping.removeWhere((i) => i.id == id));
    _persistShoppingSmart();
  }
```

- [ ] **Step 8: `_batchDeleteSmart`**

Replace:

```dart
  void _batchDeleteSmart(List<String> ids) {
    final idSet = ids.toSet();
    setState(() => _shopping = _shopping.where((i) => !idSet.contains(i.id)).toList());
  }
```

with:

```dart
  void _batchDeleteSmart(List<String> ids) {
    final idSet = ids.toSet();
    setState(() => _shopping = _shopping.where((i) => !idSet.contains(i.id)).toList());
    _persistShoppingSmart();
  }
```

- [ ] **Step 9: `_batchMarkBought`**

Replace:

```dart
  void _batchMarkBought(List<String> ids) {
    setState(() {
      for (final id in ids) {
        final idx = _shopping.indexWhere((i) => i.id == id);
        if (idx == -1) continue;
        final item = _shopping[idx];
        if (item.checked) continue;
        _shopping[idx].checked = true;
        _shopping[idx].addedToInventory = true;
        // Update or create inventory entry using category default days
        final days = item.category.defaultDays;
        final invIdx = _inventory.indexWhere((i) => i.name == item.name);
        if (invIdx != -1) {
          _inventory[invIdx].purchasedAt = DateTime.now();
          _inventory[invIdx].estimatedDays = days;
          _inventory[invIdx].quantityLabel = item.quantityLabel;
          if (item.shelfCode != null) _inventory[invIdx].shelfCode = item.shelfCode;
        } else {
          _inventory = [
            ..._inventory,
            InventoryItem(
              id: 'inv_${DateTime.now().millisecondsSinceEpoch}_$id',
              name: item.name,
              category: item.category,
              shelfZone: item.shelfZone,
              shelfCode: item.shelfCode,
              quantityLabel: item.quantityLabel,
              purchasedAt: DateTime.now(),
              estimatedDays: days,
            ),
          ];
        }
      }
    });
  }
```

with:

```dart
  void _batchMarkBought(List<String> ids) {
    setState(() {
      for (final id in ids) {
        final idx = _shopping.indexWhere((i) => i.id == id);
        if (idx == -1) continue;
        final item = _shopping[idx];
        if (item.checked) continue;
        _shopping[idx].checked = true;
        _shopping[idx].addedToInventory = true;
        // Update or create inventory entry using category default days
        final days = item.category.defaultDays;
        final invIdx = _inventory.indexWhere((i) => i.name == item.name);
        if (invIdx != -1) {
          _inventory[invIdx].purchasedAt = DateTime.now();
          _inventory[invIdx].estimatedDays = days;
          _inventory[invIdx].quantityLabel = item.quantityLabel;
          if (item.shelfCode != null) _inventory[invIdx].shelfCode = item.shelfCode;
        } else {
          _inventory = [
            ..._inventory,
            InventoryItem(
              id: 'inv_${DateTime.now().millisecondsSinceEpoch}_$id',
              name: item.name,
              category: item.category,
              shelfZone: item.shelfZone,
              shelfCode: item.shelfCode,
              quantityLabel: item.quantityLabel,
              purchasedAt: DateTime.now(),
              estimatedDays: days,
            ),
          ];
        }
      }
    });
    _persistShoppingSmart();
    _persistInventory();
  }
```

- [ ] **Step 10: `_renameSimpleItem` and `_editSmartItem`**

Replace:

```dart
  void _renameSimpleItem(String id, String newName) {
    setState(() {
      final idx = _shoppingSimple.indexWhere((i) => i.id == id);
      if (idx != -1) _shoppingSimple[idx].name = newName;
    });
  }

  void _editSmartItem(
    String id,
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
    String shelfZone,
  ) {
    setState(() {
      final idx = _shopping.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _shopping[idx]
        ..name = name
        ..quantityLabel = quantityLabel
        ..shelfCode = shelfCode
        ..category = category
        ..shelfZone = shelfZone;
      _shopping = List<ShoppingItem>.from(_shopping);
    });
  }
```

with:

```dart
  void _renameSimpleItem(String id, String newName) {
    setState(() {
      final idx = _shoppingSimple.indexWhere((i) => i.id == id);
      if (idx != -1) _shoppingSimple[idx].name = newName;
    });
    _persistShoppingSimple();
  }

  void _editSmartItem(
    String id,
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
    String shelfZone,
  ) {
    setState(() {
      final idx = _shopping.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _shopping[idx]
        ..name = name
        ..quantityLabel = quantityLabel
        ..shelfCode = shelfCode
        ..category = category
        ..shelfZone = shelfZone;
      _shopping = List<ShoppingItem>.from(_shopping);
    });
    _persistShoppingSmart();
  }
```

- [ ] **Step 11: `_completeTripSimple` and `_completeTripSmart`**

Replace:

```dart
  void _completeTripSimple() {
    setState(() => _shoppingSimple.removeWhere((i) => i.checked));
  }

  void _completeTripSmart(List<String> selectedIds) {
    final selectedSet = selectedIds.toSet();
    setState(() {
      // Work on a mutable copy so new entries are visible to subsequent lookups
      final inv = List<InventoryItem>.from(_inventory);
      int idx = 0;
      for (final item in _shopping) {
        if (!selectedSet.contains(item.id)) { idx++; continue; }
        final days = item.estimatedDays ?? item.category.defaultDays;
        final invIdx = inv.indexWhere((i) => i.name == item.name);
        if (invIdx != -1) {
          inv[invIdx]
            ..purchasedAt = DateTime.now()
            ..estimatedDays = days
            ..quantityLabel = item.quantityLabel;
          if (item.shelfCode != null) inv[invIdx].shelfCode = item.shelfCode;
        } else {
          inv.add(InventoryItem(
            id: 'inv_${DateTime.now().millisecondsSinceEpoch}_$idx',
            name: item.name,
            category: item.category,
            shelfZone: item.shelfZone,
            shelfCode: item.shelfCode,
            quantityLabel: item.quantityLabel,
            purchasedAt: DateTime.now(),
            estimatedDays: days,
          ));
        }
        idx++;
      }
      _inventory = inv;
      _shopping.clear();
    });
  }
```

with:

```dart
  void _completeTripSimple() {
    setState(() => _shoppingSimple.removeWhere((i) => i.checked));
    _persistShoppingSimple();
  }

  void _completeTripSmart(List<String> selectedIds) {
    final selectedSet = selectedIds.toSet();
    setState(() {
      // Work on a mutable copy so new entries are visible to subsequent lookups
      final inv = List<InventoryItem>.from(_inventory);
      int idx = 0;
      for (final item in _shopping) {
        if (!selectedSet.contains(item.id)) { idx++; continue; }
        final days = item.estimatedDays ?? item.category.defaultDays;
        final invIdx = inv.indexWhere((i) => i.name == item.name);
        if (invIdx != -1) {
          inv[invIdx]
            ..purchasedAt = DateTime.now()
            ..estimatedDays = days
            ..quantityLabel = item.quantityLabel;
          if (item.shelfCode != null) inv[invIdx].shelfCode = item.shelfCode;
        } else {
          inv.add(InventoryItem(
            id: 'inv_${DateTime.now().millisecondsSinceEpoch}_$idx',
            name: item.name,
            category: item.category,
            shelfZone: item.shelfZone,
            shelfCode: item.shelfCode,
            quantityLabel: item.quantityLabel,
            purchasedAt: DateTime.now(),
            estimatedDays: days,
          ));
        }
        idx++;
      }
      _inventory = inv;
      _shopping.clear();
    });
    _persistInventory();
    _persistShoppingSmart();
  }
```

- [ ] **Step 12: `_addToListFromReminder` and `_removeFromListByReminder`**

Replace:

```dart
  void _addToListFromReminder(InventoryItem inv) {
    if (_shopping.any((s) => s.name == inv.name && !s.checked)) return;
    setState(() {
      _shopping = [
        ..._shopping,
        ShoppingItem(
          id: 'r_${DateTime.now().millisecondsSinceEpoch}',
          name: inv.name,
          category: inv.category,
          quantityLabel: '1件',
          shelfZone: inv.shelfZone,
          shelfCode: inv.shelfCode,
        ),
      ];
      _smartModeRequest++;
    });
  }

  // ── 提醒：从清单移除（取消加入）──────────────────────────────────────────────

  void _removeFromListByReminder(InventoryItem inv) {
    setState(() {
      _shopping = _shopping
          .where((s) => !(s.name == inv.name && !s.checked))
          .toList();
    });
  }
```

with:

```dart
  void _addToListFromReminder(InventoryItem inv) {
    if (_shopping.any((s) => s.name == inv.name && !s.checked)) return;
    setState(() {
      _shopping = [
        ..._shopping,
        ShoppingItem(
          id: 'r_${DateTime.now().millisecondsSinceEpoch}',
          name: inv.name,
          category: inv.category,
          quantityLabel: '1件',
          shelfZone: inv.shelfZone,
          shelfCode: inv.shelfCode,
        ),
      ];
      _smartModeRequest++;
    });
    _persistShoppingSmart();
  }

  // ── 提醒：从清单移除（取消加入）──────────────────────────────────────────────

  void _removeFromListByReminder(InventoryItem inv) {
    setState(() {
      _shopping = _shopping
          .where((s) => !(s.name == inv.name && !s.checked))
          .toList();
    });
    _persistShoppingSmart();
  }
```

- [ ] **Step 13: `_batchAddToRestock` and `_addAllToList`**

Replace:

```dart
  void _batchAddToRestock(List<InventoryItem> items) {
    setState(() {
      for (final inv in items) {
        if (_shopping.any((s) => s.name == inv.name && !s.checked)) continue;
        _shopping = [
          ..._shopping,
          ShoppingItem(
            id: 'shop_${DateTime.now().millisecondsSinceEpoch}_${inv.id}',
            name: inv.name,
            category: inv.category,
            shelfZone: inv.shelfZone,
            shelfCode: inv.shelfCode,
            quantityLabel: inv.quantityLabel,
          ),
        ];
      }
    });
  }
```

with:

```dart
  void _batchAddToRestock(List<InventoryItem> items) {
    setState(() {
      for (final inv in items) {
        if (_shopping.any((s) => s.name == inv.name && !s.checked)) continue;
        _shopping = [
          ..._shopping,
          ShoppingItem(
            id: 'shop_${DateTime.now().millisecondsSinceEpoch}_${inv.id}',
            name: inv.name,
            category: inv.category,
            shelfZone: inv.shelfZone,
            shelfCode: inv.shelfCode,
            quantityLabel: inv.quantityLabel,
          ),
        ];
      }
    });
    _persistShoppingSmart();
  }
```

And replace:

```dart
    setState(() {
      final newItems = <ShoppingItem>[];
      for (var idx = 0; idx < toAdd.length; idx++) {
        final inv = toAdd[idx];
        newItems.add(ShoppingItem(
          id: 'r_${base}_$idx',
          name: inv.name,
          category: inv.category,
          quantityLabel: '1件',
          shelfZone: inv.shelfZone,
          shelfCode: inv.shelfCode,
        ));
      }
      _shopping = [..._shopping, ...newItems];
      _smartModeRequest++;
    });
  }
```

with:

```dart
    setState(() {
      final newItems = <ShoppingItem>[];
      for (var idx = 0; idx < toAdd.length; idx++) {
        final inv = toAdd[idx];
        newItems.add(ShoppingItem(
          id: 'r_${base}_$idx',
          name: inv.name,
          category: inv.category,
          quantityLabel: '1件',
          shelfZone: inv.shelfZone,
          shelfCode: inv.shelfCode,
        ));
      }
      _shopping = [..._shopping, ...newItems];
      _smartModeRequest++;
    });
    _persistShoppingSmart();
  }
```

(This is the end of `_addAllToList` — the closing `}` after `_persistShoppingSmart();` closes the method, matching the original.)

- [ ] **Step 14: Commit**

```bash
git add lib/main.dart
git commit -m "feat: persist shopping list (simple + smart) mutations"
```

---

## Task 6: Wire inventory mutation methods

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: `_addInventoryItem`, `_restockInventoryItem`, `_deleteInventoryItem`, `_batchDeleteInventory`**

Replace:

```dart
  void _addInventoryItem(InventoryItem item) {
    setState(() => _inventory = [..._inventory, item]);
  }

  void _restockInventoryItem(String id, int days) {
    setState(() {
      final idx = _inventory.indexWhere((i) => i.id == id);
      if (idx != -1) {
        _inventory[idx].purchasedAt = DateTime.now();
        _inventory[idx].estimatedDays = days;
        _inventory = List<InventoryItem>.from(_inventory);
      }
    });
  }

  void _deleteInventoryItem(String id) {
    setState(() => _inventory = _inventory.where((i) => i.id != id).toList());
  }

  void _batchDeleteInventory(List<String> ids) {
    final idSet = ids.toSet();
    setState(() => _inventory = _inventory.where((i) => !idSet.contains(i.id)).toList());
  }
```

with:

```dart
  void _addInventoryItem(InventoryItem item) {
    setState(() => _inventory = [..._inventory, item]);
    _persistInventory();
  }

  void _restockInventoryItem(String id, int days) {
    setState(() {
      final idx = _inventory.indexWhere((i) => i.id == id);
      if (idx != -1) {
        _inventory[idx].purchasedAt = DateTime.now();
        _inventory[idx].estimatedDays = days;
        _inventory = List<InventoryItem>.from(_inventory);
      }
    });
    _persistInventory();
  }

  void _deleteInventoryItem(String id) {
    setState(() => _inventory = _inventory.where((i) => i.id != id).toList());
    _persistInventory();
  }

  void _batchDeleteInventory(List<String> ids) {
    final idSet = ids.toSet();
    setState(() => _inventory = _inventory.where((i) => !idSet.contains(i.id)).toList());
    _persistInventory();
  }
```

- [ ] **Step 2: `_editInventoryItem` and `_reorderInventory`**

Replace:

```dart
  void _editInventoryItem(
    String id,
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
    String shelfZone,
  ) {
    setState(() {
      final idx = _inventory.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _inventory[idx]
        ..name = name
        ..quantityLabel = quantityLabel
        ..shelfCode = shelfCode
        ..category = category
        ..shelfZone = shelfZone;
      _inventory = List<InventoryItem>.from(_inventory);
    });
  }

  void _reorderInventory(String movedId, String? newZone,
      Category? newCategory, List<String> orderedIds) {
    setState(() {
      final idx = _inventory.indexWhere((i) => i.id == movedId);
      if (idx != -1) {
        if (newZone != null) _inventory[idx].shelfZone = newZone;
        if (newCategory != null) _inventory[idx].category = newCategory;
      }
      _inventory = orderedIds
          .map((id) => _inventory.firstWhere((i) => i.id == id))
          .toList();
    });
  }
```

with:

```dart
  void _editInventoryItem(
    String id,
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
    String shelfZone,
  ) {
    setState(() {
      final idx = _inventory.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _inventory[idx]
        ..name = name
        ..quantityLabel = quantityLabel
        ..shelfCode = shelfCode
        ..category = category
        ..shelfZone = shelfZone;
      _inventory = List<InventoryItem>.from(_inventory);
    });
    _persistInventory();
  }

  void _reorderInventory(String movedId, String? newZone,
      Category? newCategory, List<String> orderedIds) {
    setState(() {
      final idx = _inventory.indexWhere((i) => i.id == movedId);
      if (idx != -1) {
        if (newZone != null) _inventory[idx].shelfZone = newZone;
        if (newCategory != null) _inventory[idx].category = newCategory;
      }
      _inventory = orderedIds
          .map((id) => _inventory.firstWhere((i) => i.id == id))
          .toList();
    });
    _persistInventory();
  }
```

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: persist inventory mutations"
```

---

## Task 7: Wire budget mutation methods

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: `_addBudgetItem`, `_editBudgetItem`, `_deleteBudgetItem`, `_batchDeleteBudget`, `_reorderBudget`**

Replace:

```dart
  void _addBudgetItem(String name, int quantity, double unitPrice) {
    setState(() {
      _budget = [
        ..._budget,
        BudgetItem(
          id: 'bud_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          quantity: quantity,
          unitPrice: unitPrice,
        ),
      ];
    });
  }

  void _editBudgetItem(
      String id, String name, int quantity, double unitPrice) {
    setState(() {
      final idx = _budget.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _budget[idx]
        ..name = name
        ..quantity = quantity
        ..unitPrice = unitPrice;
      _budget = List<BudgetItem>.from(_budget);
    });
  }

  void _deleteBudgetItem(String id) {
    setState(() => _budget = _budget.where((i) => i.id != id).toList());
  }
```

with:

```dart
  void _addBudgetItem(String name, int quantity, double unitPrice) {
    setState(() {
      _budget = [
        ..._budget,
        BudgetItem(
          id: 'bud_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          quantity: quantity,
          unitPrice: unitPrice,
        ),
      ];
    });
    _persistBudget();
  }

  void _editBudgetItem(
      String id, String name, int quantity, double unitPrice) {
    setState(() {
      final idx = _budget.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _budget[idx]
        ..name = name
        ..quantity = quantity
        ..unitPrice = unitPrice;
      _budget = List<BudgetItem>.from(_budget);
    });
    _persistBudget();
  }

  void _deleteBudgetItem(String id) {
    setState(() => _budget = _budget.where((i) => i.id != id).toList());
    _persistBudget();
  }
```

Replace:

```dart
  void _batchDeleteBudget(List<String> ids) {
    final idSet = ids.toSet();
    setState(() => _budget = _budget.where((i) => !idSet.contains(i.id)).toList());
  }

  void _reorderBudget(List<String> orderedIds) {
    setState(() {
      _budget = orderedIds
          .map((id) => _budget.firstWhere((i) => i.id == id))
          .toList();
    });
  }
```

with:

```dart
  void _batchDeleteBudget(List<String> ids) {
    final idSet = ids.toSet();
    setState(() => _budget = _budget.where((i) => !idSet.contains(i.id)).toList());
    _persistBudget();
  }

  void _reorderBudget(List<String> orderedIds) {
    setState(() {
      _budget = orderedIds
          .map((id) => _budget.firstWhere((i) => i.id == id))
          .toList();
    });
    _persistBudget();
  }
```

- [ ] **Step 2: Commit**

```bash
git add lib/main.dart
git commit -m "feat: persist budget mutations"
```

---

## Task 8: Wire category, shelf, and settings mutation methods

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: `_addCategory`, `_editCategory`, `_deleteCategory`, `_reorderCategories`**

Replace:

```dart
  Category _addCategory(String name, Color color, String shelfZone, int defaultDays) {
    final cat = Category(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      color: color,
      bgColor: Category.tintOf(color),
      shelfZone: shelfZone,
      defaultDays: defaultDays,
    );
    setState(() {
      _categories = [..._categories, cat];
    });
    return cat;
  }

  void _editCategory(
    String id,
    String name,
    Color color,
    String shelfZone,
    int defaultDays,
  ) {
    setState(() {
      final cat = _categories.findById(id);
      if (cat == null) return;
      cat
        ..name = name
        ..color = color
        ..bgColor = Category.tintOf(color)
        ..shelfZone = shelfZone
        ..defaultDays = defaultDays;
      _categories = List<Category>.from(_categories);
    });
  }

  void _deleteCategory(String id) {
    if (id == kFallbackCategoryId) return; // never delete fallback
    setState(() {
      final fallback = _categories.fallback;
      // Reassign any items using the deleted category to the fallback.
      for (final s in _shopping) {
        if (s.category.id == id) s.category = fallback;
      }
      for (final s in _shoppingSimple) {
        if (s.category.id == id) s.category = fallback;
      }
      for (final inv in _inventory) {
        if (inv.category.id == id) inv.category = fallback;
      }
      _categories = _categories.where((c) => c.id != id).toList();
      _shopping = List<ShoppingItem>.from(_shopping);
      _shoppingSimple = List<ShoppingItem>.from(_shoppingSimple);
      _inventory = List<InventoryItem>.from(_inventory);
    });
  }

  void _reorderCategories(int oldIndex, int newIndex) {
    setState(() {
      final cat = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, cat);
      _categories = List<Category>.from(_categories);
      // Keep "group by category" rendering consistent with the new order.
      int idx(Category c) => _categories.indexWhere((x) => x.id == c.id);
      _shopping.sort((a, b) => idx(a.category).compareTo(idx(b.category)));
      _inventory.sort((a, b) => idx(a.category).compareTo(idx(b.category)));
      _shopping = List<ShoppingItem>.from(_shopping);
      _inventory = List<InventoryItem>.from(_inventory);
    });
  }
```

with:

```dart
  Category _addCategory(String name, Color color, String shelfZone, int defaultDays) {
    final cat = Category(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      color: color,
      bgColor: Category.tintOf(color),
      shelfZone: shelfZone,
      defaultDays: defaultDays,
    );
    setState(() {
      _categories = [..._categories, cat];
    });
    _persistCategories();
    return cat;
  }

  void _editCategory(
    String id,
    String name,
    Color color,
    String shelfZone,
    int defaultDays,
  ) {
    setState(() {
      final cat = _categories.findById(id);
      if (cat == null) return;
      cat
        ..name = name
        ..color = color
        ..bgColor = Category.tintOf(color)
        ..shelfZone = shelfZone
        ..defaultDays = defaultDays;
      _categories = List<Category>.from(_categories);
    });
    _persistCategories();
  }

  void _deleteCategory(String id) {
    if (id == kFallbackCategoryId) return; // never delete fallback
    setState(() {
      final fallback = _categories.fallback;
      // Reassign any items using the deleted category to the fallback.
      for (final s in _shopping) {
        if (s.category.id == id) s.category = fallback;
      }
      for (final s in _shoppingSimple) {
        if (s.category.id == id) s.category = fallback;
      }
      for (final inv in _inventory) {
        if (inv.category.id == id) inv.category = fallback;
      }
      _categories = _categories.where((c) => c.id != id).toList();
      _shopping = List<ShoppingItem>.from(_shopping);
      _shoppingSimple = List<ShoppingItem>.from(_shoppingSimple);
      _inventory = List<InventoryItem>.from(_inventory);
    });
    _persistCategories();
    _persistShoppingSmart();
    _persistShoppingSimple();
    _persistInventory();
  }

  void _reorderCategories(int oldIndex, int newIndex) {
    setState(() {
      final cat = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, cat);
      _categories = List<Category>.from(_categories);
      // Keep "group by category" rendering consistent with the new order.
      int idx(Category c) => _categories.indexWhere((x) => x.id == c.id);
      _shopping.sort((a, b) => idx(a.category).compareTo(idx(b.category)));
      _inventory.sort((a, b) => idx(a.category).compareTo(idx(b.category)));
      _shopping = List<ShoppingItem>.from(_shopping);
      _inventory = List<InventoryItem>.from(_inventory);
    });
    _persistCategories();
    _persistShoppingSmart();
    _persistInventory();
  }
```

- [ ] **Step 2: `_reorderShelfCodes`, `_addShelfCode`, `_deleteShelfCode`, `_renameShelfCode`**

Replace:

```dart
  void _reorderShelfCodes(int oldIndex, int newIndex) {
    setState(() {
      final codes = _orderedShelfCodes;
      final code = codes.removeAt(oldIndex);
      codes.insert(newIndex, code);
      _shelfCodeOrder = codes;
    });
  }

  void _addShelfCode(String code) {
    if (code.isEmpty || _shelfCodeOrder.contains(code)) return;
    setState(() => _shelfCodeOrder = [..._orderedShelfCodes, code]);
  }

  void _deleteShelfCode(String code) {
    setState(() => _shelfCodeOrder = _orderedShelfCodes.where((c) => c != code).toList());
  }

  void _renameShelfCode(String oldCode, String newCode) {
    if (newCode.isEmpty || newCode == oldCode) return;
    setState(() {
      _shelfCodeOrder = _orderedShelfCodes
          .map((c) => c == oldCode ? newCode : c)
          .toList();
      for (final item in _shopping) {
        if (item.shelfCode == oldCode) item.shelfCode = newCode;
      }
    });
  }
```

with:

```dart
  void _reorderShelfCodes(int oldIndex, int newIndex) {
    setState(() {
      final codes = _orderedShelfCodes;
      final code = codes.removeAt(oldIndex);
      codes.insert(newIndex, code);
      _shelfCodeOrder = codes;
    });
    _persistShelfCodeOrder();
  }

  void _addShelfCode(String code) {
    if (code.isEmpty || _shelfCodeOrder.contains(code)) return;
    setState(() => _shelfCodeOrder = [..._orderedShelfCodes, code]);
    _persistShelfCodeOrder();
  }

  void _deleteShelfCode(String code) {
    setState(() => _shelfCodeOrder = _orderedShelfCodes.where((c) => c != code).toList());
    _persistShelfCodeOrder();
  }

  void _renameShelfCode(String oldCode, String newCode) {
    if (newCode.isEmpty || newCode == oldCode) return;
    setState(() {
      _shelfCodeOrder = _orderedShelfCodes
          .map((c) => c == oldCode ? newCode : c)
          .toList();
      for (final item in _shopping) {
        if (item.shelfCode == oldCode) item.shelfCode = newCode;
      }
    });
    _persistShelfCodeOrder();
    _persistShoppingSmart();
  }
```

- [ ] **Step 3: `_reorderShelfZones`**

Replace:

```dart
  void _reorderShelfZones(int oldIndex, int newIndex) {
    setState(() {
      // onReorderItem already adjusts newIndex; no manual correction needed.
      final zone = _shelfZones.removeAt(oldIndex);
      _shelfZones.insert(newIndex, zone);
      // Sort.List is stable: items within the same zone keep their order.
      _shopping.sort((a, b) => _shelfZones
          .orderIndexOf(a.shelfZone)
          .compareTo(_shelfZones.orderIndexOf(b.shelfZone)));
      _inventory.sort((a, b) => _shelfZones
          .orderIndexOf(a.shelfZone)
          .compareTo(_shelfZones.orderIndexOf(b.shelfZone)));
      _shopping = List<ShoppingItem>.from(_shopping);
      _inventory = List<InventoryItem>.from(_inventory);
    });
  }
```

with:

```dart
  void _reorderShelfZones(int oldIndex, int newIndex) {
    setState(() {
      // onReorderItem already adjusts newIndex; no manual correction needed.
      final zone = _shelfZones.removeAt(oldIndex);
      _shelfZones.insert(newIndex, zone);
      // Sort.List is stable: items within the same zone keep their order.
      _shopping.sort((a, b) => _shelfZones
          .orderIndexOf(a.shelfZone)
          .compareTo(_shelfZones.orderIndexOf(b.shelfZone)));
      _inventory.sort((a, b) => _shelfZones
          .orderIndexOf(a.shelfZone)
          .compareTo(_shelfZones.orderIndexOf(b.shelfZone)));
      _shopping = List<ShoppingItem>.from(_shopping);
      _inventory = List<InventoryItem>.from(_inventory);
    });
    _persistShelfZones();
    _persistShoppingSmart();
    _persistInventory();
  }
```

- [ ] **Step 4: Settings — `onChanged` callback in `build()`**

Replace:

```dart
            SettingsScreen(
              settings: _settings,
              onChanged: (s) => setState(() => _settings = s),
```

with:

```dart
            SettingsScreen(
              settings: _settings,
              onChanged: (s) {
                setState(() => _settings = s);
                _persistSettings();
              },
```

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: persist category, shelf, and settings mutations"
```

---

## Task 9: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Static analysis**

Run: `flutter analyze`
Expected: `No issues found!` (or only pre-existing issues unrelated to this change — compare against `git stash` baseline if anything unexpected shows up).

- [ ] **Step 2: Full automated test suite**

Run: `flutter test`
Expected: every test passes, including `test/storage/hive_models_test.dart`, `test/storage/app_repository_test.dart`, `test/widget_test.dart`, and the existing `test/l10n/` tests.

- [ ] **Step 3: Manual verification — fresh install**

1. Uninstall the app from the simulator/device (or use `flutter clean` + reinstall) so no Hive files exist yet.
2. `flutter run` on a simulator/device.
3. Confirm sample data appears (香蕉/番茄/牛奶 etc. in 计划清单 and 库存, 牛奶/鸡蛋/香蕉 in 记账).
4. Fully quit the app (swipe away, not just background) and relaunch.
5. Confirm the exact same sample data is still there (not regenerated — e.g. rename one item first, relaunch, confirm the rename persisted).

- [ ] **Step 4: Manual verification — user edits persist across full restart**

For each of: 简单清单 add/check/delete, 计划清单 add/buy/delete/reorder, 库存 add/restock/delete, 记账 add/edit/delete, 分类管理 add/edit/delete, 货架码 add/rename/delete, 货架分区 reorder, 设置 (提醒阈值/开关/时间) change — make one change, fully quit the app, relaunch, and confirm the change is still there.

- [ ] **Step 5: Manual verification — category deletion cascade**

1. Create a test category, assign it to one clean-list item and one inventory item.
2. Delete that category from 分类管理.
3. Confirm both items fall back to "其他".
4. Fully quit and relaunch — confirm the fallback reassignment persisted (items still show "其他", not the deleted category re-appearing).

- [ ] **Step 6: Final commit (if any fixups were needed during manual verification)**

```bash
git add -A
git commit -m "fix: address issues found during persistence verification"
```

(Skip this step if no fixes were needed.)
