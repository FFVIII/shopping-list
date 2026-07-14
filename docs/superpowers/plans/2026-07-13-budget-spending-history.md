# Budget Spending History (Pro-only) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a Pro user clears the Budget list, snapshot the cleared items into a persisted, read-mostly "spending history" record (timestamp + line items + total), viewable and individually-deletable from a new Settings-page screen.

**Architecture:** Two new plain Dart model classes (`BudgetHistoryEntry`, `BudgetHistoryLineItem`) serialized through the existing manual Hive-map pattern, stored in a 7th `AppRepository` box, held as a list on the existing `ShoppingListNotifier`, and surfaced through a new `SpendingHistoryScreen` reached from a Pro-gated row in `SettingsScreen`. The existing "Clear Budget" confirm flow in `list_screen.dart` gets one new callback invoked just before the existing delete callback — it does not replace or alter the delete.

**Tech Stack:** Flutter/Dart (SDK `^3.12.2`), `hive`/`hive_flutter` (manual map serialization, no `TypeAdapter`s, no `provider` package), `flutter_test` (real Hive against temp dirs, no mocks).

**Spec:** `docs/superpowers/specs/2026-07-13-budget-spending-history-design.md`

---

### Task 1: Data models + Hive serialization

**Files:**
- Modify: `lib/models/item.dart:332-334` (insert new classes between `BudgetItem` and the `AppSettings` divider)
- Modify: `lib/storage/hive_models.dart:102-104` (insert new extensions/functions between the `BudgetItem` and `AppSettings` sections)
- Test: `test/storage/hive_models_test.dart`

- [ ] **Step 1: Write the failing round-trip test**

Add this new `group` to `test/storage/hive_models_test.dart`, right after the existing `group('BudgetItem', ...)` block (after line 166, before `group('AppSettings', ...)` at line 168):

```dart
  group('BudgetHistoryEntry', () {
    test('toMap/fromMap round-trips all fields', () {
      final clearedAt = DateTime(2026, 7, 13, 20, 15);
      final entry = BudgetHistoryEntry(
        id: 'hist_1',
        clearedAt: clearedAt,
        items: [
          BudgetHistoryLineItem(name: '牛奶', quantity: 2, unitPrice: 8.5),
          BudgetHistoryLineItem(name: '鸡蛋', quantity: 1, unitPrice: 12.0),
        ],
      );

      final restored = budgetHistoryEntryFromMap(entry.toMap());

      expect(restored.id, entry.id);
      expect(restored.clearedAt, clearedAt);
      expect(restored.items.length, 2);
      expect(restored.items[0].name, '牛奶');
      expect(restored.items[0].quantity, 2);
      expect(restored.items[0].unitPrice, 8.5);
      expect(restored.items[1].name, '鸡蛋');
      expect(restored.totalAmount, 2 * 8.5 + 1 * 12.0);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/storage/hive_models_test.dart`
Expected: FAIL — `budgetHistoryEntryFromMap`, `BudgetHistoryEntry`, `BudgetHistoryLineItem` are undefined.

- [ ] **Step 3: Add the model classes**

In `lib/models/item.dart`, insert between line 332 (`}` closing `BudgetItem`) and line 334 (`// ─── App Settings ───...` divider):

```dart

class BudgetHistoryLineItem {
  final String name;
  final int quantity;
  final double unitPrice;

  BudgetHistoryLineItem({
    required this.name,
    this.quantity = 1,
    this.unitPrice = 0,
  });

  double get lineTotal => quantity * unitPrice;
}

class BudgetHistoryEntry {
  final String id;
  final DateTime clearedAt;
  final List<BudgetHistoryLineItem> items;

  BudgetHistoryEntry({
    required this.id,
    required this.clearedAt,
    required this.items,
  });

  double get totalAmount =>
      items.fold(0.0, (sum, i) => sum + i.lineTotal);
}
```

- [ ] **Step 4: Add the Hive serialization**

In `lib/storage/hive_models.dart`, insert between line 102 (`);` closing `budgetItemFromMap`) and line 104 (`// ─── AppSettings ───...` divider):

```dart

// ─── BudgetHistoryEntry ───────────────────────────────────────────────────────

extension BudgetHistoryLineItemHiveX on BudgetHistoryLineItem {
  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}

BudgetHistoryLineItem budgetHistoryLineItemFromMap(Map map) =>
    BudgetHistoryLineItem(
      name: map['name'] as String,
      quantity: map['quantity'] as int? ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
    );

extension BudgetHistoryEntryHiveX on BudgetHistoryEntry {
  Map<String, dynamic> toMap() => {
        'id': id,
        'clearedAt': clearedAt.millisecondsSinceEpoch,
        'items': items.map((i) => i.toMap()).toList(),
      };
}

BudgetHistoryEntry budgetHistoryEntryFromMap(Map map) => BudgetHistoryEntry(
      id: map['id'] as String,
      clearedAt: DateTime.fromMillisecondsSinceEpoch(map['clearedAt'] as int),
      items: (map['items'] as List)
          .cast<Map>()
          .map(budgetHistoryLineItemFromMap)
          .toList(),
    );
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/storage/hive_models_test.dart`
Expected: PASS (all groups, including the new `BudgetHistoryEntry` group)

- [ ] **Step 6: Commit**

```bash
git add lib/models/item.dart lib/storage/hive_models.dart test/storage/hive_models_test.dart
git commit -m "feat: add BudgetHistoryEntry/BudgetHistoryLineItem models and Hive serialization"
```

---

### Task 2: AppRepository persistence

**Files:**
- Modify: `lib/storage/app_repository.dart`
- Test: `test/storage/app_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

In `test/storage/app_repository_test.dart`:

a) Add `expect(data.budgetHistory, isEmpty);` to the existing first-load test (after line 31 `expect(data.budget, isEmpty);`):

```dart
    expect(data.budget, isEmpty);
    expect(data.budgetHistory, isEmpty);
```

b) Add a new round-trip test, right after the existing `'saveCategories/saveSettings/saveShelfZones/saveShelfCodeOrder round-trip'` test (after line 99, before `test('replaceAll overwrites every collection'...`):

```dart

  test('saveHistory persists and round-trips budget history entries',
      () async {
    final repo = AppRepository();
    await repo.init();
    await repo.load(lang: Lang.zh);

    final entry = BudgetHistoryEntry(
      id: 'hist_1',
      clearedAt: DateTime(2026, 7, 13, 9, 0),
      items: [BudgetHistoryLineItem(name: '牛奶', quantity: 2, unitPrice: 8.5)],
    );
    await repo.saveHistory([entry]);

    final repo2 = AppRepository();
    await repo2.init();
    final reloaded = await repo2.load(lang: Lang.zh);

    expect(reloaded.budgetHistory.single.id, 'hist_1');
    expect(reloaded.budgetHistory.single.items.single.name, '牛奶');
    expect(reloaded.budgetHistory.single.totalAmount, 17.0);
  });
```

c) Extend the `replaceAll` test (lines 101–131): add `budgetHistory` to the `AppData(...)` constructed there and assert it round-trips:

```dart
    final replacement = AppData(
      shoppingSimple: [],
      shoppingSmart: [],
      inventory: [],
      budget: [BudgetItem(id: 'only', name: '替换', quantity: 2, unitPrice: 3.5)],
      budgetHistory: [
        BudgetHistoryEntry(
          id: 'h1',
          clearedAt: DateTime(2026, 1, 1),
          items: [BudgetHistoryLineItem(name: '旧记录', quantity: 1, unitPrice: 1)],
        ),
      ],
      categories: categories,
      settings: AppSettings(
        reminderThresholdDays: 1,
        restockReminderEnabled: false,
        reminderHour: 6,
        reminderMinute: 15,
      ),
      shelfZones: defaultShelfZones.toList(),
      shelfCodeOrder: ['A1'],
    );
    await repo.replaceAll(replacement);

    final reloaded = await repo.load(lang: Lang.zh);
    expect(reloaded.shoppingSmart, isEmpty);
    expect(reloaded.inventory, isEmpty);
    expect(reloaded.budget.single.name, '替换');
    expect(reloaded.budgetHistory.single.id, 'h1');
    expect(reloaded.settings.reminderHour, 6);
    expect(reloaded.settings.restockReminderEnabled, false);
    expect(reloaded.shelfCodeOrder, ['A1']);
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/storage/app_repository_test.dart`
Expected: FAIL — `AppData` has no `budgetHistory` parameter, `AppRepository.saveHistory` undefined.

- [ ] **Step 3: Add the box, `AppData` field, load/save/replaceAll wiring**

In `lib/storage/app_repository.dart`:

Add `budgetHistory` to `AppData` (lines 45–65):

```dart
class AppData {
  final List<ShoppingItem> shoppingSimple;
  final List<ShoppingItem> shoppingSmart;
  final List<InventoryItem> inventory;
  final List<BudgetItem> budget;
  final List<BudgetHistoryEntry> budgetHistory;
  final List<Category> categories;
  final AppSettings settings;
  final List<ShelfZone> shelfZones;
  final List<String> shelfCodeOrder;

  AppData({
    required this.shoppingSimple,
    required this.shoppingSmart,
    required this.inventory,
    required this.budget,
    required this.budgetHistory,
    required this.categories,
    required this.settings,
    required this.shelfZones,
    required this.shelfCodeOrder,
  });
}
```

Add the box field (lines 72–78):

```dart
class AppRepository {
  late Box _shoppingSimpleBox;
  late Box _shoppingSmartBox;
  late Box _inventoryBox;
  late Box _budgetBox;
  late Box _budgetHistoryBox;
  late Box _categoriesBox;
  late Box _metaBox;
```

Open it in `init()` (lines 80–87):

```dart
  Future<void> init() async {
    _shoppingSimpleBox = await Hive.openBox('shopping_simple');
    _shoppingSmartBox = await Hive.openBox('shopping_smart');
    _inventoryBox = await Hive.openBox('inventory');
    _budgetBox = await Hive.openBox('budget');
    _budgetHistoryBox = await Hive.openBox('budget_history');
    _categoriesBox = await Hive.openBox('categories');
    _metaBox = await Hive.openBox('app_meta');
  }
```

In `load()`, add the read right after the `budget` read (after line 133, before the `settingsMap` read at line 135):

```dart
    final budgetHistory =
        ((_budgetHistoryBox.get('items') as List?) ?? const [])
            .cast<Map>()
            .map(budgetHistoryEntryFromMap)
            .toList();

```

And add it to the returned `AppData` (lines 148–157):

```dart
    return AppData(
      shoppingSimple: shoppingSimple,
      shoppingSmart: shoppingSmart,
      inventory: inventory,
      budget: budget,
      budgetHistory: budgetHistory,
      categories: categories,
      settings: settings,
      shelfZones: shelfZones,
      shelfCodeOrder: shelfCodeOrder,
    );
```

Add the save method, right after `saveBudget` (lines 183–184):

```dart
  Future<void> saveHistory(List<BudgetHistoryEntry> entries) =>
      _budgetHistoryBox.put('items', entries.map((e) => e.toMap()).toList());
```

Add it to `replaceAll` (lines 208–217):

```dart
  Future<void> replaceAll(AppData data) async {
    await saveCategories(data.categories);
    await saveShoppingSimple(data.shoppingSimple);
    await saveShoppingSmart(data.shoppingSmart);
    await saveInventory(data.inventory);
    await saveBudget(data.budget);
    await saveHistory(data.budgetHistory);
    await saveSettings(data.settings);
    await saveShelfZones(data.shelfZones);
    await saveShelfCodeOrder(data.shelfCodeOrder);
  }
```

Update the doc comment on the class (line 68) from "Backed by 6 Hive boxes" to "Backed by 7 Hive boxes".

Note: no change needed in `_seedInitialData()` — the `?? const []` fallback in `load()` already handles the box being empty on first install, exactly like `shelfZones`/`shelfCodeOrder` do via `_metaBox`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/storage/app_repository_test.dart`
Expected: PASS (all tests, including the two new/extended ones)

- [ ] **Step 5: Commit**

```bash
git add lib/storage/app_repository.dart test/storage/app_repository_test.dart
git commit -m "feat: persist budget history through a 7th AppRepository Hive box"
```

---

### Task 2.5: Include budgetHistory in Excel backup export/import

**Added during execution:** `lib/storage/backup.dart` also constructs `AppData` directly (for the Pro backup-export/import feature) — this was missed when the plan was originally written. The design spec (§ "备份/恢复") requires spending history to travel with the existing backup export/import path, so this must be fixed before `AppData.budgetHistory` is a required field everywhere.

**Files:**
- Modify: `lib/storage/backup.dart`
- Modify: `test/storage/backup_test.dart`

**Design decision:** `BudgetHistoryEntry` has a nested `List<BudgetHistoryLineItem>`, which doesn't fit the flat one-row-per-record sheets every other segment uses. Model it as two sheets, joined by an `entryId` foreign key — the same relational shape `ShoppingItem`/`Category` already use via `categoryId`:
- `SpendingHistory`: one row per entry — `id`, `clearedAt` (millis). `totalAmount` is derived, not persisted (same policy as not persisting `BudgetItem.lineTotal`).
- `SpendingHistoryItems`: one row per line item — `entryId`, `name`, `quantity`, `unitPrice`.

**Backward compatibility:** Backups exported before this change won't have these two sheets. `decodeBackupExcel` currently treats every segment as mandatory (`_readMapsSheet` throws `FormatException: backup: missing sheet $sheetName` if absent — see the "rejects missing data segments" test). Don't extend that all-or-nothing policy to the two new sheets: add a tolerant reader that returns `[]` when the sheet is absent, and use it only for `SpendingHistory`/`SpendingHistoryItems`, so old backups still import cleanly (with empty history).

- [ ] **Step 1: Write the failing test**

In `test/storage/backup_test.dart`, add a `budgetHistory` to `_sampleData()`:

```dart
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
```

Extend the `'encode → decode round-trips all collections'` test with:

```dart
    expect(decoded.budgetHistory.length, 1);
    expect(decoded.budgetHistory.single.id, 'hist_1');
    expect(decoded.budgetHistory.single.items.length, 2);
    expect(decoded.budgetHistory.single.items[0].name, '牛奶');
    expect(decoded.budgetHistory.single.totalAmount,
        data.budgetHistory.single.totalAmount);
```

Add a new backward-compatibility test, verifying old backups (without the two new sheets) still decode:

```dart

  test('decodes older backups that predate the SpendingHistory sheets', () {
    // Simulates a backup exported before this feature existed: every
    // required segment present, but no SpendingHistory/SpendingHistoryItems
    // sheets at all.
    final data = _sampleData();
    final bytes = encodeBackupExcel(
        AppData(
          shoppingSimple: data.shoppingSimple,
          shoppingSmart: data.shoppingSmart,
          inventory: data.inventory,
          budget: data.budget,
          budgetHistory: const [], // nothing to encode either
          categories: data.categories,
          settings: data.settings,
          shelfZones: data.shelfZones,
          shelfCodeOrder: data.shelfCodeOrder,
        ));

    final decoded = decodeBackupExcel(bytes);

    expect(decoded.budgetHistory, isEmpty);
  });
```

(This test alone won't fail before the implementation — it can't, since `encodeBackupExcel`/`AppData` don't compile yet without `budgetHistory`. That's expected: the whole file fails to compile until Step 3 lands, which is the "RED" state for this step.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/storage/backup_test.dart`
Expected: FAIL — compile error, `AppData` has no `budgetHistory` parameter (from Task 2's change), sheets don't exist yet.

- [ ] **Step 3: Implement**

In `lib/storage/backup.dart`, add column consts near the other `_xColumns` consts:

```dart
const _historyColumns = ['id', 'clearedAt'];
const _historyItemColumns = ['entryId', 'name', 'quantity', 'unitPrice'];
```

Add a tolerant sheet reader, right after `_readMapsSheet`:

```dart
/// Like [_readMapsSheet], but returns `[]` instead of throwing when the
/// sheet is absent — for segments added after the backup format shipped,
/// so backups exported before they existed still import.
List<Map<String, dynamic>> _readMapsSheetOptional(Excel excel, String sheetName) {
  if (excel.tables[sheetName] == null) return const [];
  return _readMapsSheet(excel, sheetName);
}
```

In `encodeBackupExcel`, after the `Budget` sheet write:

```dart
  _writeMapsSheet(excel, 'SpendingHistory', [
    for (final e in data.budgetHistory)
      {'id': e.id, 'clearedAt': e.clearedAt.millisecondsSinceEpoch},
  ], _historyColumns);
  _writeMapsSheet(excel, 'SpendingHistoryItems', [
    for (final e in data.budgetHistory)
      for (final i in e.items)
        {
          'entryId': e.id,
          'name': i.name,
          'quantity': i.quantity,
          'unitPrice': i.unitPrice,
        },
  ], _historyItemColumns);
```

In `decodeBackupExcel`, after the `budget` read, build the history list:

```dart
    final historyItemsByEntryId = <String, List<BudgetHistoryLineItem>>{};
    for (final m in _readMapsSheetOptional(excel, 'SpendingHistoryItems')) {
      historyItemsByEntryId
          .putIfAbsent(m['entryId'] as String, () => [])
          .add(BudgetHistoryLineItem(
            name: m['name'] as String,
            quantity: (m['quantity'] as num).toInt(),
            unitPrice: (m['unitPrice'] as num).toDouble(),
          ));
    }
    final budgetHistory = _readMapsSheetOptional(excel, 'SpendingHistory')
        .map((m) => BudgetHistoryEntry(
              id: m['id'] as String,
              clearedAt:
                  DateTime.fromMillisecondsSinceEpoch(m['clearedAt'] as int),
              items: historyItemsByEntryId[m['id']] ?? const [],
            ))
        .toList();
```

And add `budgetHistory: budgetHistory,` to the `AppData(...)` returned by `decodeBackupExcel` (right after `budget: ...`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/storage/backup_test.dart`
Expected: PASS (all tests, including the round-trip extension and the new backward-compatibility test)

Then run the full suite to confirm no other regressions:
Run: `flutter test`
Expected: PASS (all suites — this was the last `AppData(...)` call site outside `lib/main.dart`, which Task 8 still needs to fix)

- [ ] **Step 5: Commit**

```bash
git add lib/storage/backup.dart test/storage/backup_test.dart
git commit -m "feat: include budget spending history in Excel backup export/import"
```

---

### Task 3: Notifier — record and delete history entries

**Files:**
- Modify: `lib/state/shopping_list_notifier.dart`
- Test (new): `test/state/shopping_list_notifier_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/state/shopping_list_notifier_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/state/shopping_list_notifier.dart';
import 'package:shopping_list/storage/app_repository.dart';

void main() {
  late Directory tempDir;
  late AppRepository repo;
  late ShoppingListNotifier notifier;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    repo = AppRepository();
    await repo.init();
    final data = await repo.load(lang: Lang.zh);
    notifier = ShoppingListNotifier(repo)..load(data);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('recordBudgetPurchase creates an entry with the correct snapshot and total',
      () {
    final snapshot = [
      BudgetItem(id: 'b1', name: '牛奶', quantity: 2, unitPrice: 8.5),
      BudgetItem(id: 'b2', name: '鸡蛋', quantity: 1, unitPrice: 12.0),
    ];

    notifier.recordBudgetPurchase(snapshot);

    expect(notifier.budgetHistory.length, 1);
    final entry = notifier.budgetHistory.single;
    expect(entry.items.length, 2);
    expect(entry.items[0].name, '牛奶');
    expect(entry.totalAmount, 2 * 8.5 + 1 * 12.0);
  });

  test('recordBudgetPurchase inserts the newest entry at the head of the list',
      () {
    notifier.recordBudgetPurchase(
        [BudgetItem(id: 'b1', name: '第一次', quantity: 1, unitPrice: 1)]);
    notifier.recordBudgetPurchase(
        [BudgetItem(id: 'b2', name: '第二次', quantity: 1, unitPrice: 1)]);

    expect(notifier.budgetHistory.length, 2);
    expect(notifier.budgetHistory.first.items.single.name, '第二次');
    expect(notifier.budgetHistory.last.items.single.name, '第一次');
  });

  test('recordBudgetPurchase with an empty snapshot does not create an entry',
      () {
    notifier.recordBudgetPurchase(const []);

    expect(notifier.budgetHistory, isEmpty);
  });

  test('deleteBudgetHistoryEntry removes only the matching entry', () {
    notifier.recordBudgetPurchase(
        [BudgetItem(id: 'b1', name: '保留', quantity: 1, unitPrice: 1)]);
    notifier.recordBudgetPurchase(
        [BudgetItem(id: 'b2', name: '删除', quantity: 1, unitPrice: 1)]);
    final toDelete = notifier.budgetHistory
        .firstWhere((e) => e.items.single.name == '删除');

    notifier.deleteBudgetHistoryEntry(toDelete.id);

    expect(notifier.budgetHistory.length, 1);
    expect(notifier.budgetHistory.single.items.single.name, '保留');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/state/shopping_list_notifier_test.dart`
Expected: FAIL — `notifier.budgetHistory`, `recordBudgetPurchase`, `deleteBudgetHistoryEntry` undefined, and `AppData` construction site (`repo.load`) still needs Task 2 to already be merged (it is, from the prior task).

- [ ] **Step 3: Implement the notifier changes**

In `lib/state/shopping_list_notifier.dart`:

Add the field (line 20, after `budget`):

```dart
  List<BudgetItem> budget = [];
  List<BudgetHistoryEntry> budgetHistory = [];
```

Update `load()` (lines 22–27):

```dart
  void load(AppData data) {
    simple = data.shoppingSimple;
    smart = data.shoppingSmart;
    budget = data.budget;
    budgetHistory = data.budgetHistory;
    notifyListeners();
  }
```

Add a `persistBudgetHistory()` helper, right after `persistBudget()` (lines 43–48):

```dart
  void persistBudgetHistory() {
    notifyListeners();
    unawaited(_repo
        .saveHistory(budgetHistory)
        .catchError((e) => debugPrint('save budgetHistory failed: $e')));
  }
```

Add the two new methods at the end of the "── 记账模式 ──" section, right after `batchDeleteBudget` (lines 219–223):

```dart

  /// Snapshots [snapshot] (the budget items about to be cleared) into a new
  /// history entry. Does not itself clear `budget` — the caller (list_screen's
  /// clear-confirm flow) still calls `batchDeleteBudget` separately for that.
  void recordBudgetPurchase(List<BudgetItem> snapshot) {
    if (snapshot.isEmpty) return;
    budgetHistory = [
      BudgetHistoryEntry(
        id: generateId('hist'),
        clearedAt: DateTime.now(),
        items: snapshot
            .map((b) => BudgetHistoryLineItem(
                  name: b.name,
                  quantity: b.quantity,
                  unitPrice: b.unitPrice,
                ))
            .toList(),
      ),
      ...budgetHistory,
    ];
    persistBudgetHistory();
  }

  void deleteBudgetHistoryEntry(String id) {
    budgetHistory = budgetHistory.where((e) => e.id != id).toList();
    persistBudgetHistory();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/state/shopping_list_notifier_test.dart`
Expected: PASS (all 4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/state/shopping_list_notifier.dart test/state/shopping_list_notifier_test.dart
git commit -m "feat: add recordBudgetPurchase/deleteBudgetHistoryEntry to ShoppingListNotifier"
```

---

### Task 4: Wire the record-callback into the Clear Budget flow

**Files:**
- Modify: `lib/screens/list_screen.dart:65-115,331-354`
- Modify: `test/screens/list_screen_test.dart:50-109`

- [ ] **Step 1: Write/extend the failing test**

In `test/screens/list_screen_test.dart`, add an `onRecordBudgetPurchase` param to `_pumpList` and wire it in (edit lines 50–109):

```dart
Future<void> _pumpList(
  WidgetTester tester, {
  List<ShoppingItem> simpleItems = const [],
  List<ShoppingItem> smartItems = const [],
  List<BudgetItem> budgetItems = const [],
  void Function(String id)? onToggleSimple,
  void Function(String id)? onToggleSmart,
  void Function(String name)? onAddSimple,
  void Function(List<String> ids)? onBatchDeleteSimple,
  void Function(List<String> ids)? onBatchMarkBought,
  VoidCallback? onCompleteSimple,
  void Function(List<String> ids)? onCompleteSmart,
  void Function(List<BudgetItem> snapshot)? onRecordBudgetPurchase,
  void Function(List<String> ids)? onBatchDeleteBudget,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    L10n(
      strings: ZhStrings(),
      language: AppLanguage.zh,
      child: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: MaterialApp(
          home: ListScreen(
            simpleItems: simpleItems,
            smartItems: smartItems,
            categories: [_category('other')],
            onToggleSimple: onToggleSimple ?? (_) {},
            onToggleSmart: onToggleSmart ?? (_) {},
            onAddSimple: onAddSimple ?? (_) {},
            onAddSmart: (_, _, _, _, _, _) {},
            onDeleteSimple: (_) {},
            onDeleteSmart: (_) {},
            onCompleteSimple: onCompleteSimple ?? () {},
            onCompleteSmart: onCompleteSmart ?? (_) {},
            onReorderSimple: (_) {},
            onReorderSmart: (_, _, _, _, _) {},
            onRenameSimple: (_, _) {},
            onEditSmart: (_, _, _, _, _, _) {},
            budgetItems: budgetItems,
            onAddBudget: (_, _, _) {},
            onEditBudget: (_, _, _, _) {},
            onDeleteBudget: (_) {},
            onReorderBudget: (_) {},
            onRecordBudgetPurchase: onRecordBudgetPurchase ?? (_) {},
            onBatchDeleteSimple: onBatchDeleteSimple ?? (_) {},
            onBatchDeleteSmart: (_) {},
            onBatchMarkBought: onBatchMarkBought ?? (_) {},
            onBatchDeleteBudget: onBatchDeleteBudget ?? (_) {},
            smartModeRequest: 0,
            shelfCodeOrder: const [],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
```

Then add this test to the `main()` body (anywhere after the helper, alongside other budget-mode tests):

```dart
  testWidgets(
      'confirming Clear Budget records the snapshot before batch-deleting',
      (tester) async {
    final recorded = <BudgetItem>[];
    final deletedIds = <String>[];
    await _pumpList(
      tester,
      budgetItems: [_budget('b1', '牛奶')],
      onRecordBudgetPurchase: recorded.addAll,
      onBatchDeleteBudget: deletedIds.addAll,
    );

    // Switch to budget mode and trigger the clear-budget confirm dialog.
    await tester.tap(find.text(ZhStrings().budgetMode));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ZhStrings().clearBudget));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ZhStrings().delete));
    await tester.pumpAndSettle();

    expect(recorded.single.id, 'b1');
    expect(deletedIds, ['b1']);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/list_screen_test.dart`
Expected: FAIL — `onRecordBudgetPurchase` is not a parameter of `ListScreen`.

- [ ] **Step 3: Add the callback to `ListScreen` and wire it into `_confirmClearBudget`**

In `lib/screens/list_screen.dart`, add the field right after `onReorderBudget` (line 70):

```dart
  final void Function(String id) onDeleteBudget;
  final void Function(List<String> orderedIds) onReorderBudget;
  final void Function(List<BudgetItem> snapshot) onRecordBudgetPurchase;
```

Add the constructor param right after `required this.onReorderBudget,` (line 104):

```dart
    required this.onReorderBudget,
    required this.onRecordBudgetPurchase,
```

In `_confirmClearBudget()` (lines 331–354), call it before the existing delete call:

```dart
    if (ok != true) return;
    widget.onRecordBudgetPurchase(widget.budgetItems);
    widget.onBatchDeleteBudget(widget.budgetItems.map((i) => i.id).toList());
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/list_screen_test.dart`
Expected: PASS (all tests, including the new one)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/list_screen.dart test/screens/list_screen_test.dart
git commit -m "feat: snapshot cleared budget items before deleting them"
```

---

### Task 5: l10n strings

**Files:**
- Modify: `lib/l10n/app_strings.dart:39,235,444` (abstract + zh + en)

- [ ] **Step 1: Add the abstract declarations**

Insert after line 39 (`String get budgetEmptySubtitle;`):

```dart
  String get budgetEmptySubtitle;
  String get spendingHistory; // 设置页入口/页面标题 / "Spending History"
  String spendingHistoryMonthTotal(String formattedAmount); // "本月共花 ¥xxx"
  String get spendingHistoryEmpty;
  String get deleteHistoryEntryTitle;
  String get deleteHistoryEntryMessage;
```

- [ ] **Step 2: Add the Zh implementation**

Insert after line 235 (`@override String get budgetEmptySubtitle => '在下方记一笔花费';`):

```dart
  @override String get budgetEmptySubtitle => '在下方记一笔花费';
  @override String get spendingHistory => '消费历史';
  @override String spendingHistoryMonthTotal(String formattedAmount) =>
      '本月共花 $formattedAmount';
  @override String get spendingHistoryEmpty => '暂无消费记录';
  @override String get deleteHistoryEntryTitle => '删除这条记录？';
  @override String get deleteHistoryEntryMessage => '删除后无法恢复。';
```

- [ ] **Step 3: Add the En implementation**

Insert after line 444 (`@override String get budgetEmptySubtitle => 'Add an expense below';`):

```dart
  @override String get budgetEmptySubtitle => 'Add an expense below';
  @override String get spendingHistory => 'Spending History';
  @override String spendingHistoryMonthTotal(String formattedAmount) =>
      '$formattedAmount spent this month';
  @override String get spendingHistoryEmpty => 'No spending history yet';
  @override String get deleteHistoryEntryTitle => 'Delete this record?';
  @override String get deleteHistoryEntryMessage => 'This cannot be undone.';
```

- [ ] **Step 4: Verify it compiles (abstract class enforces both implementations exist)**

Run: `flutter analyze lib/l10n/app_strings.dart`
Expected: No errors (a missing `@override` on either concrete class would fail analysis since `AppStrings` is abstract).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart
git commit -m "feat: add zh/en strings for the spending history screen"
```

---

### Task 6: `SpendingHistoryScreen`

**Files:**
- Create: `lib/screens/spending_history_screen.dart`
- Test (new): `test/screens/spending_history_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/screens/spending_history_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/l10n/app_strings.dart';
import 'package:shopping_list/l10n/l10n.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/screens/spending_history_screen.dart';

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<BudgetHistoryEntry> budgetHistory,
  void Function(String id)? onDeleteEntry,
}) async {
  await tester.pumpWidget(
    L10n(
      strings: ZhStrings(),
      language: AppLanguage.zh,
      child: MaterialApp(
        home: SpendingHistoryScreen(
          budgetHistory: budgetHistory,
          onDeleteEntry: onDeleteEntry ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the empty state when there is no history', (tester) async {
    await _pumpScreen(tester, budgetHistory: const []);

    expect(find.text(ZhStrings().spendingHistoryEmpty), findsOneWidget);
  });

  testWidgets('sums only current-month entries into the month total banner',
      (tester) async {
    final now = DateTime.now();
    final thisMonth = BudgetHistoryEntry(
      id: 'h1',
      clearedAt: now,
      items: [BudgetHistoryLineItem(name: '本月', quantity: 1, unitPrice: 10)],
    );
    final lastYear = BudgetHistoryEntry(
      id: 'h2',
      clearedAt: DateTime(2020, 1, 1),
      items: [BudgetHistoryLineItem(name: '旧的', quantity: 1, unitPrice: 999)],
    );

    await _pumpScreen(tester, budgetHistory: [thisMonth, lastYear]);

    expect(
      find.text(ZhStrings().spendingHistoryMonthTotal(ZhStrings().money(10))),
      findsOneWidget,
    );
  });

  testWidgets('tapping an entry expands it to show line items', (tester) async {
    final entry = BudgetHistoryEntry(
      id: 'h1',
      clearedAt: DateTime(2026, 7, 13, 9, 0),
      items: [BudgetHistoryLineItem(name: '牛奶', quantity: 2, unitPrice: 8.5)],
    );
    await _pumpScreen(tester, budgetHistory: [entry]);

    expect(find.text('牛奶 × 2'), findsNothing);
    await tester.tap(find.byKey(const Key('history_h1')));
    await tester.pumpAndSettle();
    expect(find.text('牛奶 × 2'), findsOneWidget);
  });

  testWidgets('canceling the delete dialog keeps the entry', (tester) async {
    final entry = BudgetHistoryEntry(
      id: 'h1',
      clearedAt: DateTime(2026, 7, 13, 9, 0),
      items: [BudgetHistoryLineItem(name: '牛奶', quantity: 1, unitPrice: 1)],
    );
    var deleted = false;
    await _pumpScreen(
      tester,
      budgetHistory: [entry],
      onDeleteEntry: (_) => deleted = true,
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text(ZhStrings().deleteHistoryEntryTitle), findsOneWidget);
    await tester.tap(find.text(ZhStrings().cancel));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
  });

  testWidgets('confirming the delete dialog calls onDeleteEntry with the id',
      (tester) async {
    final entry = BudgetHistoryEntry(
      id: 'h1',
      clearedAt: DateTime(2026, 7, 13, 9, 0),
      items: [BudgetHistoryLineItem(name: '牛奶', quantity: 1, unitPrice: 1)],
    );
    String? deletedId;
    await _pumpScreen(
      tester,
      budgetHistory: [entry],
      onDeleteEntry: (id) => deletedId = id,
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ZhStrings().delete));
    await tester.pumpAndSettle();

    expect(deletedId, 'h1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/spending_history_screen_test.dart`
Expected: FAIL — `package:shopping_list/screens/spending_history_screen.dart` does not exist.

- [ ] **Step 3: Create the screen**

Create `lib/screens/spending_history_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/item.dart';
import '../theme/app_colors.dart';

class SpendingHistoryScreen extends StatelessWidget {
  final List<BudgetHistoryEntry> budgetHistory;
  final void Function(String id) onDeleteEntry;

  const SpendingHistoryScreen({
    super.key,
    required this.budgetHistory,
    required this.onDeleteEntry,
  });

  double _monthTotal() {
    final now = DateTime.now();
    return budgetHistory
        .where((e) =>
            e.clearedAt.year == now.year && e.clearedAt.month == now.month)
        .fold(0.0, (sum, e) => sum + e.totalAmount);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final l = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteHistoryEntryTitle),
        content: Text(l.deleteHistoryEntryMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok == true) onDeleteEntry(id);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: Text(l.spendingHistory)),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              l.spendingHistoryMonthTotal(l.money(_monthTotal())),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
            ),
          ),
          Expanded(
            child: budgetHistory.isEmpty
                ? Center(
                    child: Text(
                      l.spendingHistoryEmpty,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: budgetHistory.length,
                    itemBuilder: (ctx, i) {
                      final entry = budgetHistory[i];
                      return ExpansionTile(
                        key: Key('history_${entry.id}'),
                        title: Text(_formatDate(entry.clearedAt)),
                        subtitle: Text(l.money(entry.totalAmount)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.danger),
                          onPressed: () => _confirmDelete(context, entry.id),
                        ),
                        children: entry.items
                            .map((i) => ListTile(
                                  title: Text('${i.name} × ${i.quantity}'),
                                  trailing: Text(l.money(i.unitPrice)),
                                ))
                            .toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/spending_history_screen_test.dart`
Expected: PASS (all 5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/spending_history_screen.dart test/screens/spending_history_screen_test.dart
git commit -m "feat: add SpendingHistoryScreen"
```

---

### Task 7: Settings-page entry point

**Files:**
- Modify: `lib/screens/settings_screen.dart:22,36-51,53-75,176-179,469`
- Modify: `test/screens/settings_screen_test.dart:1-53`

- [ ] **Step 1: Write/extend the failing tests**

In `test/screens/settings_screen_test.dart`, add the import and the two new stub params to `_pumpSettings`:

```dart
import 'package:shopping_list/models/item.dart';
```
(already imported at line 6 — no change needed there)

Edit the `_pumpSettings` signature and body (lines 10–53):

```dart
Future<void> _pumpSettings(
  WidgetTester tester, {
  bool isPro = false,
  Future<bool> Function()? requestNotificationPermission,
  TextScaler textScaler = TextScaler.noScaling,
  List<BudgetHistoryEntry> budgetHistory = const [],
  void Function(String id)? onDeleteBudgetHistoryEntry,
}) async {
  final purchaseService = PurchaseService()..isPro = isPro;

  await tester.pumpWidget(
    L10n(
      strings: ZhStrings(),
      language: AppLanguage.zh,
      child: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: MaterialApp(
        home: SettingsScreen(
          settings: AppSettings(),
          onChanged: (_) {},
          language: AppLanguage.zh,
          onLanguageChanged: (_) {},
          shelfZones: defaultShelfZones,
          onReorderShelfZones: (_, _) {},
          shelfCodeOrder: const [],
          onReorderShelfCodes: (_, _) {},
          onAddShelfCode: (_) {},
          onDeleteShelfCode: (_) {},
          onRenameShelfCode: (_, _) {},
          categories: buildDefaultCategories(),
          onAddCategory: (name, color, zone, days) => buildDefaultCategories().fallback,
          onEditCategory: (_, _, _, _, _) {},
          onDeleteCategory: (_) {},
          onReorderCategories: (_, _) {},
          buildBackupBytes: () => <int>[],
          onImportBackup: (_) async {},
          requestNotificationPermission:
              requestNotificationPermission ?? () async => true,
          purchaseService: purchaseService,
          budgetHistory: budgetHistory,
          onDeleteBudgetHistoryEntry: onDeleteBudgetHistoryEntry ?? (_) {},
        ),
        ),
      ),
    ),
  );
  await tester.pump();
}
```

Then add these two tests to `main()`, alongside the existing Pro-gating tests:

```dart
  testWidgets('Spending History row hidden when not Pro', (tester) async {
    await _pumpSettings(tester, isPro: false);

    expect(find.text(ZhStrings().spendingHistory), findsNothing);
  });

  testWidgets(
      'Spending History row visible and navigates when Pro', (tester) async {
    await _pumpSettings(tester, isPro: true);

    expect(find.text(ZhStrings().spendingHistory), findsOneWidget);
    await tester.tap(find.text(ZhStrings().spendingHistory));
    await tester.pumpAndSettle();

    expect(find.text(ZhStrings().spendingHistoryEmpty), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: FAIL — `budgetHistory`/`onDeleteBudgetHistoryEntry` are not parameters of `SettingsScreen`.

- [ ] **Step 3: Add the fields, constructor params, nav row, and navigation method**

In `lib/screens/settings_screen.dart`, add the import after line 22 (`import 'category_manage_screen.dart';`):

```dart
import 'spending_history_screen.dart';
```

Add the fields right after `purchaseService` (line 51):

```dart
  final PurchaseService purchaseService;
  final List<BudgetHistoryEntry> budgetHistory;
  final void Function(String id) onDeleteBudgetHistoryEntry;
```

Add the constructor params right after `required this.purchaseService,` (line 74):

```dart
    required this.purchaseService,
    required this.budgetHistory,
    required this.onDeleteBudgetHistoryEntry,
```

Add the nav row inside the existing Pro-gated `sectionData` block (lines 176–179):

```dart
              _buildSection(l.sectionData, [
                _navRow(l.backupExport, onTap: _exportBackup),
                _navRow(l.importRestore, onTap: _importBackup),
                _navRow(l.spendingHistory, onTap: _openSpendingHistory),
              ]),
```

Add the navigation method, right after `_openShelfOrder` (after line 469):

```dart

  void _openSpendingHistory() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SpendingHistoryScreen(
        budgetHistory: widget.budgetHistory,
        onDeleteEntry: widget.onDeleteBudgetHistoryEntry,
      ),
    ));
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: PASS (all tests, including the two new ones)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings_screen.dart test/screens/settings_screen_test.dart
git commit -m "feat: add Pro-gated Spending History entry to SettingsScreen"
```

---

### Task 8: Wire everything through `main.dart`

**Files:**
- Modify: `lib/main.dart:471-480,522-550,577-599`

- [ ] **Step 1: Add `budgetHistory` to the backup snapshot**

In `_buildBackupBytes()` (lines 471–480):

```dart
  List<int> _buildBackupBytes() => encodeBackupExcel(AppData(
        shoppingSimple: _shoppingNotifier.simple,
        shoppingSmart: _shoppingNotifier.smart,
        inventory: _inventoryNotifier.items,
        budget: _shoppingNotifier.budget,
        budgetHistory: _shoppingNotifier.budgetHistory,
        categories: _categoriesNotifier.categories,
        settings: _settingsNotifier.settings,
        shelfZones: _categoriesNotifier.shelfZones,
        shelfCodeOrder: _categoriesNotifier.shelfCodeOrder,
      ));
```

- [ ] **Step 2: Wire the new `ListScreen` callback**

In the `ListScreen(...)` instantiation (lines 522–550), add `onRecordBudgetPurchase` right after `onReorderBudget` (line 543):

```dart
                    onReorderBudget: _shoppingNotifier.reorderBudget,
                    onRecordBudgetPurchase: _shoppingNotifier.recordBudgetPurchase,
```

- [ ] **Step 3: Wire the new `SettingsScreen` params**

In the `SettingsScreen(...)` instantiation (lines 577–599), add both new params after `purchaseService` (line 598):

```dart
                    purchaseService: _purchaseService,
                    budgetHistory: _shoppingNotifier.budgetHistory,
                    onDeleteBudgetHistoryEntry:
                        _shoppingNotifier.deleteBudgetHistoryEntry,
                  ),
```

- [ ] **Step 4: Run the full test suite and the smoke test**

Run: `flutter test`
Expected: PASS — all suites green, including `test/widget_test.dart`'s full-app smoke test (which builds this exact widget tree) and every suite touched in Tasks 1–7.

Run: `flutter analyze`
Expected: No errors or warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire budget spending history through main.dart"
```

---

### Task 9: Manual verification on a real device/simulator

Per this repo's collaboration convention, the user verifies UI changes on a real device before merging — do not claim this feature "works" from tests alone.

- [ ] **Step 1: Launch the app and force Pro on for local testing**

The Settings screen has a `kDebugMode`-only "Force Pro (debug only)" switch (`lib/screens/settings_screen.dart:181-190`). Use it to enable Pro locally rather than going through a real purchase.

- [ ] **Step 2: Exercise the golden path**

1. Add 2–3 items in Budget mode.
2. Tap "Clear" → confirm. Verify the list empties as before (no regression).
3. Open Settings → confirm "Spending History" row appears (Pro is on) → tap it.
4. Verify the just-cleared entry appears at the top, with the correct total and this-month summary banner.
5. Tap the entry to expand it → verify line items (name × qty, unit price) match what was cleared.
6. Tap delete on the entry → cancel → verify entry remains.
7. Tap delete again → confirm → verify entry disappears and the month-total banner updates.

- [ ] **Step 3: Exercise edge cases**

1. With Pro off, confirm the "Spending History" row is absent from Settings.
2. Clear Budget while the list is already empty (if reachable via UI) → confirm no history entry is created (guarded by the `recordBudgetPurchase` empty-snapshot check).
3. Force-quit and relaunch the app → confirm history persisted (Hive box round-trip).
4. Export a backup, then import it back → confirm history entries survive the round-trip.

- [ ] **Step 4: Confirm this is dev-only**

Per the spec, this feature must not be cherry-picked to `release-free`. No action needed here beyond awareness — do not run the `release-workflow` skill's dev→release-free sync step for these commits.

