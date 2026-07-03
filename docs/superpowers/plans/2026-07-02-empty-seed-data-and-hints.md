# 清空种子数据 + 三条永久关闭提示条 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 首次安装时清单/库存/记账全部为空（分类保留默认 6 个），并在计划清单、库存、提醒三个页面各加一条可永久关闭的说明提示条。

**Architecture:** 新增 `HintStore`（`shared_preferences` 持久化，仿照现有 `LanguageStore` 写法）+ `HintBanner`（跨文件复用的展示组件，样式照搬现有"计划清单"提示条）。`_AppShellState` 统一持有 `_dismissedHints` 状态，加载一次、往下传给三个页面。种子数据清空只改 `AppRepository._seedInitialData()` 和 `main.dart._buildFallbackData()` 两处，分类照常生成，商品类数据存空列表。

**Tech Stack:** Flutter/Dart，`shared_preferences`（已是项目依赖，无需新增）。

**Spec:** `docs/superpowers/specs/2026-07-02-empty-seed-data-and-hints-design.md`

**环境须知：**
```bash
FLUTTER="/Users/ffviii/Computer Science | Coding/Flutter/flutter/bin/flutter"
cd "/Users/ffviii/Computer Science | Coding/Flutter/projects/shopping_list"
```
每次 commit 只 `git add` 本任务明确列出的文件。

**File structure：**

| 文件 | 动作 | 职责 |
|---|---|---|
| `lib/services/hint_store.dart` | 建 | 已关闭提示条 id 集合的持久化读写 |
| `test/services/hint_store_test.dart` | 建 | `HintStore` 往返测试 |
| `lib/widgets/hint_banner.dart` | 建 | 通用提示条展示组件 |
| `lib/l10n/app_strings.dart` | 改 | 新增 `inventoryHint`/`reminderHint` |
| `lib/main.dart` | 改 | `_dismissedHints` 状态 + `_dismissHint` + 清空 `_buildFallbackData` 种子数据 + 三个页面构造传参 |
| `lib/screens/list_screen.dart` | 改 | 移除 `_smartHintDismissed`/`_buildSmartHint`，改用 `HintBanner`；新增构造参数 |
| `lib/screens/inventory_screen.dart` | 改 | 新增 `HintBanner` + 构造参数 |
| `lib/screens/reminder_screen.dart` | 改 | 新增 `HintBanner` + 构造参数 |
| `lib/storage/app_repository.dart` | 改 | `_seedInitialData()` 商品类数据改存空列表 |
| `test/storage/app_repository_test.dart` | 改 | 更新首次安装断言 |
| `test/widget_test.dart` | 可能改 | 若新增构造参数导致编译失败，补上 |

---

### Task 1: `HintStore` 持久化（TDD）

**Files:**
- Create: `test/services/hint_store_test.dart`
- Create: `lib/services/hint_store.dart`

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/services/hint_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load() returns an empty set when nothing has been saved', () async {
    expect(await HintStore.load(), isEmpty);
  });

  test('save() then load() round-trips the same ids', () async {
    await HintStore.save({'a', 'b'});
    expect(await HintStore.load(), {'a', 'b'});
  });

  test('save() fully overwrites the previous set (not a merge)', () async {
    await HintStore.save({'a'});
    await HintStore.save({'a', 'b'});
    expect(await HintStore.load(), {'a', 'b'});
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$FLUTTER" test test/services/hint_store_test.dart
```
Expected: FAIL —— 找不到 `shopping_list/services/hint_store.dart`。

- [ ] **Step 3: 实现**

创建 `lib/services/hint_store.dart`：

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Persists which hint banner ids the user has permanently dismissed.
/// Mirrors the pattern in `l10n/language_store.dart`.
class HintStore {
  static const _key = 'dismissed_hints';

  /// Ids of hint banners the user has closed. Empty if none yet.
  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  /// Overwrites the stored set with [dismissed] in full — callers pass the
  /// complete set they want persisted, not just the newly-added id.
  static Future<void> save(Set<String> dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, dismissed.toList());
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
"$FLUTTER" test test/services/hint_store_test.dart
```
Expected: `All tests passed!`（3 个）

- [ ] **Step 5: Commit**

```bash
git add lib/services/hint_store.dart test/services/hint_store_test.dart
git commit -m "feat: add HintStore for persisting dismissed hint banner ids"
```

---

### Task 2: `HintBanner` 展示组件

**Files:**
- Create: `lib/widgets/hint_banner.dart`

样式完全照搬 `list_screen.dart` 现有 `_buildSmartHint()`（第 564-598 行）的外观，做成跨文件可复用的公开组件。

- [ ] **Step 1: 创建组件**

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A dismissible lightbulb-icon hint banner. Callers own the "has this been
/// dismissed" state (see [HintStore]) — this widget is purely presentational
/// and always renders when built; the caller decides whether to build it.
class HintBanner extends StatelessWidget {
  final String text;
  final VoidCallback onDismiss;

  const HintBanner({super.key, required this.text, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: Color(0xFF4B6B4D)),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  size: 16, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
"$FLUTTER" analyze lib/widgets/hint_banner.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/hint_banner.dart
git commit -m "feat: add reusable HintBanner widget"
```

---

### Task 3: 新增 l10n 字符串

**Files:**
- Modify: `lib/l10n/app_strings.dart`

`smartHint` 已存在（第 24/210/406 行），不用新增，只新增 `inventoryHint`/`reminderHint`。

- [ ] **Step 1: 抽象类声明**

在 `abstract class AppStrings` 里 `String get addToInventoryBtn;`（约第 101 行，Inventory screen 分组的最后一行）之后加：

```dart
  String get inventoryHint; // inventory-tab explanation banner
```

在 `String get estimatedDaysSelected(int n);` 段落后、`// ── Reminder screen ──` 分组内 `String get reminderEmptySubtitle;` 之后加（约第 110 行附近）：

```dart
  String get reminderHint; // reminder-tab explanation banner
```

- [ ] **Step 2: ZhStrings 实现**

在 `ZhStrings` 类里找到 `@override String get addToInventoryBtn => '加入库存';` 之后加：

```dart
  @override String get inventoryHint =>
      '购买后的商品会自动出现在这里；快用完时会在「提醒」里提示补货。';
```

找到 `@override String get reminderEmptySubtitle => '没有需要补货的商品';` 之后加：

```dart
  @override String get reminderHint =>
      '库存快用完或已到期的商品会出现在这里，点「加入」放进购物清单。';
```

- [ ] **Step 3: EnStrings 实现**

在 `EnStrings` 类里找到 `@override String get addToInventoryBtn => 'Add to inventory';` 之后加：

```dart
  @override String get inventoryHint =>
      'Purchased items land here automatically; low stock shows up under Alerts.';
```

找到 `@override String get reminderEmptySubtitle => 'Nothing needs restocking';` 之后加：

```dart
  @override String get reminderHint =>
      'Items running low or out show up here — tap Add to put them back on your list.';
```

- [ ] **Step 4: 验证编译**

```bash
"$FLUTTER" analyze lib/l10n/app_strings.dart
```
Expected: `No issues found!`（缺任何一个 override 都会编译失败，因为 `AppStrings` 是抽象类）

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart
git commit -m "feat: add inventoryHint/reminderHint l10n strings"
```

---

### Task 4: `_AppShellState` 状态管理

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: import**

在 `lib/main.dart` 顶部 import 区加：

```dart
import 'services/hint_store.dart';
```

- [ ] **Step 2: 新增字段**

在 `_AppShellState` 的字段声明区（`late bool _storageUnavailable = widget.storageInitFailed;` 之后）加：

```dart
  Set<String> _dismissedHints = {};
```

- [ ] **Step 3: 加载时读取**

`HintStore.load()` 是异步的，不能直接写进同步的 `setState` 回调里，所以在它之前先 `await` 拿到结果，再在 `setState` 里赋值。把整个 `_loadData()` 方法改成：

```dart
  Future<void> _loadData() async {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final lang = resolveLang(widget.language, deviceLocale);
    AppData data;
    bool loadFailed = false;
    try {
      data = await _repo.load(lang: lang);
    } catch (e) {
      debugPrint('Failed to load persisted data, falling back to in-memory sample data: $e');
      data = _buildFallbackData(lang);
      loadFailed = true;
    }
    final dismissedHints = await HintStore.load();
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
      _dismissedHints = dismissedHints;
      _loading = false;
      if (loadFailed) _storageUnavailable = true;
    });
    // Top up the 14-day pre-scheduled window in case the app hasn't been
    // opened for a while (spec §4.3).
    _rescheduleNotifications();
  }
```

（只新增了 `final dismissedHints = await HintStore.load();` 一行和 `_dismissedHints = dismissedHints;` 一行，其余原样。）

- [ ] **Step 4: 新增关闭方法**

在 `_persistShelfCodeOrder()` 方法之后（`// ── 分类：增 / 改 / 删 / 重排 ──` 分隔线之前）加：

```dart
  // ── 提示条：永久关闭 ──────────────────────────────────────────────────────

  void _dismissHint(String id) {
    final updated = {..._dismissedHints, id};
    setState(() => _dismissedHints = updated);
    unawaited(HintStore.save(updated)
        .catchError((e) => debugPrint('save dismissedHints failed: $e')));
  }
```

- [ ] **Step 5: 验证编译（此时三个页面还没接收新参数，预期无报错，因为还没传）**

```bash
"$FLUTTER" analyze lib/main.dart
```
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "feat: load and persist dismissed hint banner ids in AppShell"
```

---

### Task 5: 接入计划清单（`list_screen.dart`）

**Files:**
- Modify: `lib/screens/list_screen.dart`
- Modify: `lib/main.dart`（传参）
- Modify: `test/widget_test.dart`（如需要，见 Step 6）

- [ ] **Step 1: import**

在 `lib/screens/list_screen.dart` 顶部 import 区（`import '../widgets/toast.dart';` 之后）加：

```dart
import '../widgets/hint_banner.dart';
```

- [ ] **Step 2: 新增构造参数**

在 `class ListScreen` 字段声明区，`final int smartModeRequest;` 之后加：

```dart
  final Set<String> dismissedHints;
  final void Function(String id) onDismissHint;
```

在构造函数参数列表，`required this.smartModeRequest,` 之后加：

```dart
    required this.dismissedHints,
    required this.onDismissHint,
```

- [ ] **Step 3: 移除旧的会话级关闭状态**

删除 `_ListScreenState` 里的字段：

```dart
  bool _smartHintDismissed = false;
```

- [ ] **Step 4: 替换渲染点**

把 `build()` 里的：

```dart
            if (_isSmart && !_smartHintDismissed) _buildSmartHint(),
```

改成：

```dart
            if (_isSmart && !widget.dismissedHints.contains('smart_hint'))
              HintBanner(
                text: l.smartHint,
                onDismiss: () => widget.onDismissHint('smart_hint'),
              ),
```

（这个 `build()` 方法开头已有 `final l = L10n.of(context);`，直接用。）

- [ ] **Step 5: 删除废弃的 `_buildSmartHint()` 方法**

删除整个方法（第 564-598 行左右）：

```dart
  Widget _buildSmartHint() {
    final l = L10n.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.smartHint,
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: Color(0xFF4B6B4D)),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _smartHintDismissed = true),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  size: 16, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 6: `main.dart` 传参**

在 `lib/main.dart` 的 `ListScreen(` 构造调用里，`shelfCodeOrder: shelfCodeOrder,` 之后加：

```dart
                    dismissedHints: _dismissedHints,
                    onDismissHint: _dismissHint,
```

- [ ] **Step 7: 验证编译**

```bash
"$FLUTTER" analyze
```
Expected: 如果 `test/widget_test.dart` 直接构造 `ShoppingListApp`/`AppShell`（不直接构造 `ListScreen`），这里不会报错。若报错提示 `ListScreen` 缺少必填参数，说明有测试直接构造了 `ListScreen`——按报错信息补上 `dismissedHints: const {}, onDismissHint: (_) {},` 即可。

- [ ] **Step 8: 跑全部测试**

```bash
"$FLUTTER" test
```
Expected: 全部通过（此步不应改变任何测试结果，只是接线）。

- [ ] **Step 9: Commit**

```bash
git add lib/screens/list_screen.dart lib/main.dart
git commit -m "feat: persist smart-list hint dismissal via HintBanner/HintStore"
```

---

### Task 6: 接入库存页（`inventory_screen.dart`）

**Files:**
- Modify: `lib/screens/inventory_screen.dart`
- Modify: `lib/main.dart`（传参）

- [ ] **Step 1: import**

在 `lib/screens/inventory_screen.dart` 顶部 import 区（`import '../widgets/batch_bar.dart';` 之后）加：

```dart
import '../widgets/hint_banner.dart';
```

- [ ] **Step 2: 新增构造参数**

在 `class InventoryScreen` 字段声明区，`final void Function(List<InventoryItem> items) onBatchAddToRestock;` 之后加：

```dart
  final Set<String> dismissedHints;
  final void Function(String id) onDismissHint;
```

构造函数参数列表 `required this.onBatchAddToRestock,` 之后加：

```dart
    required this.dismissedHints,
    required this.onDismissHint,
```

- [ ] **Step 3: 渲染**

把 `build()` 里的：

```dart
            _buildHeader(),
            _buildSearchBar(),
            if (!_batchMode) _buildSortToggle(),
            const SizedBox(height: 4),
```

改成：

```dart
            _buildHeader(),
            _buildSearchBar(),
            if (!_batchMode) _buildSortToggle(),
            if (!widget.dismissedHints.contains('inventory_hint'))
              HintBanner(
                text: L10n.of(context).inventoryHint,
                onDismiss: () => widget.onDismissHint('inventory_hint'),
              ),
            const SizedBox(height: 4),
```

- [ ] **Step 4: `main.dart` 传参**

在 `InventoryScreen(` 构造调用里，`onBatchAddToRestock: _batchAddToRestock,` 之后加：

```dart
                    dismissedHints: _dismissedHints,
                    onDismissHint: _dismissHint,
```

- [ ] **Step 5: 验证编译 + 跑测试**

```bash
"$FLUTTER" analyze && "$FLUTTER" test
```
Expected: `No issues found!`，全部测试通过。

- [ ] **Step 6: Commit**

```bash
git add lib/screens/inventory_screen.dart lib/main.dart
git commit -m "feat: add dismissible inventory-tab hint banner"
```

---

### Task 7: 接入提醒页（`reminder_screen.dart`）

**Files:**
- Modify: `lib/screens/reminder_screen.dart`
- Modify: `lib/main.dart`（传参）

- [ ] **Step 1: import**

在 `lib/screens/reminder_screen.dart` 顶部 import 区（`import '../widgets/toast.dart';` 之后）加：

```dart
import '../widgets/hint_banner.dart';
```

- [ ] **Step 2: 新增构造参数**

`ReminderScreen` 是 `StatelessWidget`，在字段声明区 `final Set<String> activeListNames;` 之后加：

```dart
  final Set<String> dismissedHints;
  final void Function(String id) onDismissHint;
```

构造函数参数列表 `required this.activeListNames,` 之后加：

```dart
    required this.dismissedHints,
    required this.onDismissHint,
```

- [ ] **Step 3: 渲染**

把 `build()` 里的：

```dart
            _buildHeader(context),
            Expanded(
              child: _hasAny ? _buildList(context) : _emptyState(context),
            ),
```

改成：

```dart
            _buildHeader(context),
            if (!dismissedHints.contains('reminder_hint'))
              HintBanner(
                text: L10n.of(context).reminderHint,
                onDismiss: () => onDismissHint('reminder_hint'),
              ),
            Expanded(
              child: _hasAny ? _buildList(context) : _emptyState(context),
            ),
```

（`ReminderScreen` 是 StatelessWidget，字段直接用 `dismissedHints`/`onDismissHint`，不用 `widget.` 前缀。）

- [ ] **Step 4: `main.dart` 传参**

在 `ReminderScreen(` 构造调用里，`activeListNames: _shopping.where((s) => !s.checked).map((s) => s.name).toSet(),` 之后加：

```dart
                    dismissedHints: _dismissedHints,
                    onDismissHint: _dismissHint,
```

- [ ] **Step 5: 验证编译 + 跑测试**

```bash
"$FLUTTER" analyze && "$FLUTTER" test
```
Expected: `No issues found!`，全部测试通过。

- [ ] **Step 6: Commit**

```bash
git add lib/screens/reminder_screen.dart lib/main.dart
git commit -m "feat: add dismissible reminder-tab hint banner"
```

---

### Task 8: 清空 `AppRepository` 种子数据

**Files:**
- Modify: `lib/storage/app_repository.dart`
- Modify: `test/storage/app_repository_test.dart`

- [ ] **Step 1: 改 `_seedInitialData()`**

把：

```dart
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
```

改成：

```dart
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
```

- [ ] **Step 2: 更新测试断言**

把 `test/storage/app_repository_test.dart` 里的：

```dart
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
```

改成：

```dart
  test('first load seeds default categories but leaves items empty', () async {
    final repo = AppRepository();
    await repo.init();

    final data = await repo.load(lang: Lang.zh);

    expect(data.categories, isNotEmpty);
    expect(data.shoppingSmart, isEmpty);
    expect(data.inventory, isEmpty);
    expect(data.budget, isEmpty);
    expect(data.shoppingSimple, isEmpty);
    expect(data.shelfCodeOrder, isEmpty);
    expect(data.settings.reminderThresholdDays, 5);
    expect(data.shelfZones, isNotEmpty);
  });
```

- [ ] **Step 3: 跑该测试文件确认通过**

```bash
"$FLUTTER" test test/storage/app_repository_test.dart
```
Expected: `All tests passed!`（5 个，测试名已改）

- [ ] **Step 4: 跑全部测试（`buildSampleShopping` 等函数仍被 `test/models/item_test.dart` 当工具函数用，不受影响）**

```bash
"$FLUTTER" test
```
Expected: 全部通过。

- [ ] **Step 5: Commit**

```bash
git add lib/storage/app_repository.dart test/storage/app_repository_test.dart
git commit -m "fix: seed only default categories on first install, no demo items"
```

---

### Task 9: 清空 `main.dart` 内存兜底路径的种子数据

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 改 `_buildFallbackData()`**

把：

```dart
  AppData _buildFallbackData(Lang lang) {
    final categories = buildDefaultCategories();
    if (lang == Lang.en) {
      final en = EnStrings();
      for (final c in categories) {
        c.name = en.data(c.name);
      }
    }
    return AppData(
      shoppingSimple: [],
      shoppingSmart: buildSampleShopping(categories),
      inventory: buildSampleInventory(categories),
      budget: buildSampleBudget(),
      categories: categories,
      settings: AppSettings(),
      shelfZones: defaultShelfZones.toList(),
      shelfCodeOrder: [],
    );
  }
```

改成：

```dart
  AppData _buildFallbackData(Lang lang) {
    final categories = buildDefaultCategories();
    if (lang == Lang.en) {
      final en = EnStrings();
      for (final c in categories) {
        c.name = en.data(c.name);
      }
    }
    return AppData(
      shoppingSimple: [],
      // Same as AppRepository._seedInitialData(): only the category
      // structure is real; items start empty. See design spec 2026-07-02 §3.
      shoppingSmart: [],
      inventory: [],
      budget: [],
      categories: categories,
      settings: AppSettings(),
      shelfZones: defaultShelfZones.toList(),
      shelfCodeOrder: [],
    );
  }
```

- [ ] **Step 2: 验证编译**

```bash
"$FLUTTER" analyze
```
Expected: `No issues found!`（`buildSampleShopping`/`buildSampleInventory`/`buildSampleBudget` 不再被 `main.dart` 引用，但仍被 `lib/models/item.dart` 定义、被测试文件使用，不会触发 unused 警告）

- [ ] **Step 3: 跑全部测试**

```bash
"$FLUTTER" test
```
Expected: 全部通过。

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "fix: empty items in the in-memory storage-failure fallback too"
```

---

### Task 10: 收尾验证

**Files:** 无代码改动

- [ ] **Step 1: 全量自动检查**

```bash
"$FLUTTER" analyze && "$FLUTTER" test
```
Expected: 无新增 issue（对比 Task 0 前的 3 条既有基线警告），全部测试通过。

- [ ] **Step 2: 模拟器手动验证**

先卸载重装以触发全新种子数据：

```bash
xcrun simctl uninstall <UDID> com.ffviii.shoppinglist
```

用 `flutter run -d <UDID>` 跑起来，检查：
1. 简单/记账/计划清单三个 tab 都是空的（"清单是空的"/"还没有记账"/对应空状态文案），商品分类选择器里仍有 6 个默认分类可选；
2. 库存页是空的（"库存还是空的"），顶部出现新的库存提示条；
3. 提醒页是空的（"库存都很充足"——因为库存本来就是空的，这个空状态文案本身依然成立），顶部出现新的提醒提示条；
4. 计划清单里能看到"圆圈选中=将存入库存..."提示条（沿用旧文案）；
5. 依次点掉三条提示条的 X，确认消失；
6. **完全重启 app**（不是切后台，是完全杀掉进程重开），确认三条提示条都不再出现——这一步是验证真正持久化，跟旧的"计划清单"提示条只能维持到下次重启的行为不同；
7. 切换到 English，确认新增的两条提示条文案是英文。

- [ ] **Step 3: 手动验证结果记录**

把每条结果（通过/问题）报给用户确认；有问题回到对应任务修。
