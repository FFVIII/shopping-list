# English Language Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Chinese/English language switch (with a "follow system" option) that re-renders the entire UI live and persists across restarts.

**Architecture:** A lightweight self-built i18n layer in `lib/l10n/`: an `AppStrings` abstract class with `ZhStrings`/`EnStrings` implementations, exposed down the tree via an `L10n` InheritedWidget. `ShoppingListApp` becomes stateful, holds the chosen `AppLanguage`, persists it via `shared_preferences`, and rebuilds on change. Shelf-zone strings keep their existing Chinese values as **stable grouping keys**; only their *display* is translated, so grouping/drag/sync logic is untouched.

**Tech Stack:** Flutter, Dart, `shared_preferences`.

**Reference spec:** `docs/superpowers/specs/2026-06-27-i18n-english-language-design.md`

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/l10n/app_language.dart` | `AppLanguage` enum (system/zh/en) + `Lang` enum (zh/en) + `resolveLang()` from a device locale |
| `lib/l10n/app_strings.dart` | Abstract `AppStrings` + `ZhStrings` + `EnStrings` (all UI text + `data()` lookup) |
| `lib/l10n/l10n.dart` | `L10n` InheritedWidget; `L10n.of(context)` → `AppStrings` |
| `lib/l10n/language_store.dart` | Load/save `AppLanguage` via `shared_preferences` |
| `lib/main.dart` | async `main()`, stateful app, wrap with `L10n`, set `MaterialApp.locale`, translate nav + days sheet |
| `lib/models/item.dart` | `Category`/`StockStatus` labels stay as enums; remove hardcoded Chinese `label` getters' use in UI (labels move to `AppStrings`); sample data unchanged (canonical Chinese), translated at display via `AppStrings.data()` |
| `lib/screens/list_screen.dart` | Replace all literals with `L10n.of(context)` calls |
| `lib/screens/inventory_screen.dart` | Same |
| `lib/screens/reminder_screen.dart` | Same |
| `lib/screens/settings_screen.dart` | Same + new language selector row |
| `pubspec.yaml` | Add `shared_preferences` |
| `test/l10n/app_language_test.dart` | Unit tests for `resolveLang` |
| `test/l10n/app_strings_test.dart` | Unit tests for parity + `data()` lookup |

**Key invariant (protect existing behavior):** `item.shelfZone` and `item.name`/`quantityLabel`/`shelfCode` keep their canonical (Chinese) values in the model. Grouping, drag-reorder, and the `_confirmPurchase` name-match all run on these canonical values. Language only changes *displayed* text via `AppStrings`.

---

## Task 1: Add shared_preferences dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependency**

In `pubspec.yaml`, under `dependencies:` (alongside `speech_to_text:`), add:

```yaml
  shared_preferences: ^2.3.2
```

- [ ] **Step 2: Fetch packages**

Run: `flutter pub get`
Expected: "Got dependencies!" / "Changed N dependencies!", exit 0.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add shared_preferences dependency"
```

---

## Task 2: Language enums + locale resolution

**Files:**
- Create: `lib/l10n/app_language.dart`
- Test: `test/l10n/app_language_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/l10n/app_language_test.dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/l10n/app_language.dart';

void main() {
  group('resolveLang', () {
    test('system + zh locale → Lang.zh', () {
      expect(resolveLang(AppLanguage.system, const Locale('zh', 'CN')), Lang.zh);
    });
    test('system + en locale → Lang.en', () {
      expect(resolveLang(AppLanguage.system, const Locale('en', 'US')), Lang.en);
    });
    test('system + other locale → Lang.en (fallback)', () {
      expect(resolveLang(AppLanguage.system, const Locale('fr', 'FR')), Lang.en);
    });
    test('explicit zh always zh', () {
      expect(resolveLang(AppLanguage.zh, const Locale('en')), Lang.zh);
    });
    test('explicit en always en', () {
      expect(resolveLang(AppLanguage.en, const Locale('zh')), Lang.en);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/l10n/app_language_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:shopping_list/l10n/app_language.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/l10n/app_language.dart
import 'dart:ui';

/// User-facing language *setting* (what's stored & shown in Settings).
enum AppLanguage { system, zh, en }

/// Effective language actually used to pick strings.
enum Lang { zh, en }

/// Resolve the effective [Lang] from the user's setting and a device locale.
/// `system` follows the device: zh* → zh, everything else → en.
Lang resolveLang(AppLanguage setting, Locale deviceLocale) {
  switch (setting) {
    case AppLanguage.zh:
      return Lang.zh;
    case AppLanguage.en:
      return Lang.en;
    case AppLanguage.system:
      return deviceLocale.languageCode == 'zh' ? Lang.zh : Lang.en;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/l10n/app_language_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_language.dart test/l10n/app_language_test.dart
git commit -m "feat(l10n): add AppLanguage/Lang enums and resolveLang"
```

---

## Task 3: AppStrings (zh/en) — the full text contract

**Files:**
- Create: `lib/l10n/app_strings.dart`
- Test: `test/l10n/app_strings_test.dart`

This is the central contract. Every later task references these members.

- [ ] **Step 1: Write the failing test**

```dart
// test/l10n/app_strings_test.dart
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

  test('category labels localize', () {
    expect(zh.category(Category.produce), '果蔬');
    expect(en.category(Category.produce), 'Produce');
  });

  test('stock status labels localize', () {
    expect(zh.stockStatus(StockStatus.low), '快没');
    expect(en.stockStatus(StockStatus.low), 'Low');
  });

  test('data() translates known canonical tokens in en, passes through unknown', () {
    expect(en.data('果蔬区'), 'Produce');
    expect(en.data('香蕉'), 'Banana');
    expect(en.data('自定义商品'), '自定义商品'); // unknown user input passes through
    expect(zh.data('果蔬区'), '果蔬区'); // zh is always passthrough
    expect(zh.data('香蕉'), '香蕉');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/l10n/app_strings_test.dart`
Expected: FAIL — URI for `app_strings.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

Create `lib/l10n/app_strings.dart`. Implement the abstract base and both subclasses. The `data()` map covers all canonical sample-data tokens + shelf-zone display names.

```dart
// lib/l10n/app_strings.dart
import '../models/item.dart';

/// All user-visible text. One implementation per language.
/// `data()` translates *canonical data tokens* (sample product names,
/// quantity labels, shelf codes, shelf-zone display, default reminder time).
/// Unknown strings (user-entered) pass through unchanged.
abstract class AppStrings {
  // ── Bottom nav ──
  String get navList;
  String get navInventory;
  String get navReminder;
  String get navSettings;

  // ── List screen ──
  String get shoppingListTitle;
  String listSubtitlePending(int remaining, DateTime date);
  String listSubtitleDone(DateTime date);
  String get completeTrip;
  String get modeSimple;
  String get modeSmart;
  String get byShelf;
  String get byCategory;
  String get purchasedSection;
  String itemCountChip(int n); // "3件" / "3"
  String get listEmptyTitle;
  String get listEmptySubtitle;
  String get listeningHint;
  String get smartAddHint;
  String get simpleAddHint;
  String addItemTitle(String name);
  String get chooseCategoryHint;
  String shelfZoneInline(String zoneDisplay); // "货架区：果蔬区" / "Aisle: Produce"
  String get addToList;
  String get rename;
  String get confirmEdit;
  String get recordedBadge; // "已记" / "Logged"
  String itemMeta(String quantity, String? shelfCode); // "1串 · 货架B3"

  // ── Days sheet (main.dart) ──
  String boughtTitle(String name);
  String get estimatedDaysQuestion;
  String days(int n); // "7天" / "7 days"
  String recordToInventory(int n);

  // ── Inventory screen ──
  String get inventoryTitle;
  String inventorySummary(int total, int restock);
  String get searchHint;
  String get inventoryEmptyTitle;
  String get inventoryEmptyTitleQuery; // uses query
  String inventoryNoResults(String query);
  String get inventoryEmptySubtitle;
  String get inventoryEmptySubtitleQuery;
  String get addManually;
  String get usedUp; // "已用完" / "Used up"
  String daysRemainingLong(int n); // "还剩约 N 天" / "About N days left"
  String daysShort(int n); // "N天"
  String daysShortApprox(int n); // "约N天" / "~N days"
  String get resetTimerSection; // "重新购买，重置计时"
  String resetTimer(int n); // "重置计时（N天）"
  String get addToRestockList; // "加入补货清单"
  String get deleteFromInventory; // "从库存删除"
  String get addToInventoryTitle; // "添加到库存"
  String get productNameHint; // "商品名称"
  String get categoryLabel; // "分类"
  String get estimatedUseDays; // "预计使用天数"
  String get addToInventoryBtn; // "加入库存"

  // ── Reminder screen ──
  String get reminderTitle;
  String reminderSummary(int restock, int expiring);
  String get addAll;
  String get sectionRestock; // "该补货"
  String get sectionExpiringSoon; // "即将用完"
  String get reminderEmptyTitle; // "库存都很充足"
  String get reminderEmptySubtitle; // "没有需要补货的商品"
  String get usedUpNeedRestock; // "已用完，需要补货"
  String daysLeftApprox(int n); // "还剩约N天" / "~N days left"
  String get add; // "加入" / "Add"

  // ── Settings screen ──
  String get settingsTitle;
  String get proUpgrade;
  String get proDesc;
  String get proCta;
  String get sectionCategoryShelf;
  String get manageCategories;
  String categoriesCount(int n); // "12类"
  String get shelfOrder;
  String get sectionReminder;
  String get restockReminder;
  String get reminderTimeLabel;
  String get advanceDays; // "提前天数"
  String get sectionData;
  String get backupExport;
  String get importRestore;
  String get appFooter; // "购物清单 v1.0 · 本地优先"
  String get language; // "语言" / "Language"
  String get languageSystem; // "跟随系统"
  String get languageZh; // "中文"
  String get languageEn; // "English"
  String labelForLanguage(/* AppLanguage */ Object lang); // trailing display

  // ── Enum + data lookups ──
  String category(Category c);
  String stockStatus(StockStatus s);
  String data(String canonical);
  String thresholdScaleMin; // "1天"/"1d" actually keep simple below
}
```

Then the two implementations. NOTE: keep `thresholdScaleMin` etc. minimal — replace that last abstract line with three concrete getters used by the settings slider labels:

Replace the final `String thresholdScaleMin;` line in the abstract class with:

```dart
  String get scale1Day;   // "1天" / "1d"
  String get scale1Week;  // "1周" / "1wk"
  String get scale2Week;  // "2周" / "2wk"
```

Now `ZhStrings`:

```dart
class ZhStrings extends AppStrings {
  @override String get navList => '清单';
  @override String get navInventory => '库存';
  @override String get navReminder => '提醒';
  @override String get navSettings => '设置';

  @override String get shoppingListTitle => '购物清单';
  @override String listSubtitlePending(int r, DateTime d) => '还差 $r 件 · ${_zhDate(d)}';
  @override String listSubtitleDone(DateTime d) => '今天买齐啦 🎉 · ${_zhDate(d)}';
  @override String get completeTrip => '完成购物';
  @override String get modeSimple => '简单';
  @override String get modeSmart => '智能';
  @override String get byShelf => '按货架';
  @override String get byCategory => '按分类';
  @override String get purchasedSection => '已购';
  @override String itemCountChip(int n) => '$n件';
  @override String get listEmptyTitle => '清单是空的';
  @override String get listEmptySubtitle => '在下方输入要买的商品';
  @override String get listeningHint => '正在听，请说商品名称...';
  @override String get smartAddHint => '添加商品，选分类后入库...';
  @override String get simpleAddHint => '随手记，添加到清单...';
  @override String addItemTitle(String name) => '添加「$name」';
  @override String get chooseCategoryHint => '选择分类，方便按货架分组';
  @override String shelfZoneInline(String z) => '货架区：$z';
  @override String get addToList => '加入清单';
  @override String get rename => '重命名';
  @override String get confirmEdit => '确认修改';
  @override String get recordedBadge => '已记';
  @override String itemMeta(String q, String? code) => code != null ? '$q · $code' : q;

  @override String boughtTitle(String name) => '「$name」买到了！';
  @override String get estimatedDaysQuestion => '预计能用几天？';
  @override String days(int n) => '$n天';
  @override String recordToInventory(int n) => '记录到库存（$n天）';

  @override String get inventoryTitle => '库存';
  @override String inventorySummary(int t, int r) => '$t件常备 · $r件需补货';
  @override String get searchHint => '搜索商品或货架';
  @override String get inventoryEmptyTitle => '库存还是空的';
  @override String get inventoryEmptyTitleQuery => '';
  @override String inventoryNoResults(String q) => '没有找到「$q」';
  @override String get inventoryEmptySubtitle => '先从清单购买并记录到库存';
  @override String get inventoryEmptySubtitleQuery => '试试其他关键词';
  @override String get addManually => '手动添加商品';
  @override String get usedUp => '已用完';
  @override String daysRemainingLong(int n) => '还剩约 $n 天';
  @override String daysShort(int n) => '$n天';
  @override String daysShortApprox(int n) => '约$n天';
  @override String get resetTimerSection => '重新购买，重置计时';
  @override String resetTimer(int n) => '重置计时（$n天）';
  @override String get addToRestockList => '加入补货清单';
  @override String get deleteFromInventory => '从库存删除';
  @override String get addToInventoryTitle => '添加到库存';
  @override String get productNameHint => '商品名称';
  @override String get categoryLabel => '分类';
  @override String get estimatedUseDays => '预计使用天数';
  @override String get addToInventoryBtn => '加入库存';

  @override String get reminderTitle => '提醒';
  @override String reminderSummary(int r, int e) => '$r件该补货 · $e件即将用完';
  @override String get addAll => '全部加入';
  @override String get sectionRestock => '该补货';
  @override String get sectionExpiringSoon => '即将用完';
  @override String get reminderEmptyTitle => '库存都很充足';
  @override String get reminderEmptySubtitle => '没有需要补货的商品';
  @override String get usedUpNeedRestock => '已用完，需要补货';
  @override String daysLeftApprox(int n) => '还剩约$n天';
  @override String get add => '加入';

  @override String get settingsTitle => '设置';
  @override String get proUpgrade => '升级 Pro';
  @override String get proDesc => '拍照识别配图 · 快捷加项组件 · 多设备同步备份';
  @override String get proCta => '查看 Pro 功能 →';
  @override String get sectionCategoryShelf => '分类与货架';
  @override String get manageCategories => '管理分类';
  @override String categoriesCount(int n) => '$n类';
  @override String get shelfOrder => '货架顺序';
  @override String get sectionReminder => '提醒';
  @override String get restockReminder => '补货提醒';
  @override String get reminderTimeLabel => '提醒时间';
  @override String get advanceDays => '提前天数';
  @override String get sectionData => '数据';
  @override String get backupExport => '备份导出';
  @override String get importRestore => '导入恢复';
  @override String get appFooter => '购物清单 v1.0 · 本地优先';
  @override String get language => '语言';
  @override String get languageSystem => '跟随系统';
  @override String get languageZh => '中文';
  @override String get languageEn => 'English';
  @override String labelForLanguage(Object lang) =>
      lang == AppLanguage.zh ? '中文' : lang == AppLanguage.en ? 'English' : '跟随系统';
  @override String get scale1Day => '1天';
  @override String get scale1Week => '1周';
  @override String get scale2Week => '2周';

  @override String category(Category c) {
    switch (c) {
      case Category.produce:  return '果蔬';
      case Category.dairy:    return '乳制品';
      case Category.meat:     return '肉类';
      case Category.grain:    return '粮油';
      case Category.cleaning: return '清洁';
      case Category.beverage: return '饮料';
      case Category.other:    return '其他';
    }
  }

  @override String stockStatus(StockStatus s) {
    switch (s) {
      case StockStatus.sufficient: return '充足';
      case StockStatus.low:        return '快没';
      case StockStatus.empty:      return '用完';
    }
  }

  @override String data(String canonical) => canonical; // zh is canonical
}

String _zhDate(DateTime d) => '${d.month}月${d.day}日';
```

Now `EnStrings`. Reuse the same member list; `data()` uses `_enData` map.

```dart
class EnStrings extends AppStrings {
  @override String get navList => 'List';
  @override String get navInventory => 'Inventory';
  @override String get navReminder => 'Alerts';
  @override String get navSettings => 'Settings';

  @override String get shoppingListTitle => 'Shopping List';
  @override String listSubtitlePending(int r, DateTime d) => '$r left · ${_enDate(d)}';
  @override String listSubtitleDone(DateTime d) => 'All done 🎉 · ${_enDate(d)}';
  @override String get completeTrip => 'Done';
  @override String get modeSimple => 'Simple';
  @override String get modeSmart => 'Smart';
  @override String get byShelf => 'By aisle';
  @override String get byCategory => 'By category';
  @override String get purchasedSection => 'Bought';
  @override String itemCountChip(int n) => '$n';
  @override String get listEmptyTitle => 'Your list is empty';
  @override String get listEmptySubtitle => 'Add items to buy below';
  @override String get listeningHint => 'Listening, say the item name...';
  @override String get smartAddHint => 'Add item, pick a category...';
  @override String get simpleAddHint => 'Jot it down, add to list...';
  @override String addItemTitle(String name) => 'Add "$name"';
  @override String get chooseCategoryHint => 'Pick a category to group by aisle';
  @override String shelfZoneInline(String z) => 'Aisle: $z';
  @override String get addToList => 'Add to list';
  @override String get rename => 'Rename';
  @override String get confirmEdit => 'Save';
  @override String get recordedBadge => 'Logged';
  @override String itemMeta(String q, String? code) => code != null ? '$q · $code' : q;

  @override String boughtTitle(String name) => '"$name" bought!';
  @override String get estimatedDaysQuestion => 'How long will it last?';
  @override String days(int n) => '$n days';
  @override String recordToInventory(int n) => 'Save to inventory ($n days)';

  @override String get inventoryTitle => 'Inventory';
  @override String inventorySummary(int t, int r) => '$t stocked · $r to restock';
  @override String get searchHint => 'Search items or aisle';
  @override String get inventoryEmptyTitle => 'Inventory is empty';
  @override String get inventoryEmptyTitleQuery => '';
  @override String inventoryNoResults(String q) => 'No results for "$q"';
  @override String get inventoryEmptySubtitle => 'Buy from your list and log it here';
  @override String get inventoryEmptySubtitleQuery => 'Try another keyword';
  @override String get addManually => 'Add item manually';
  @override String get usedUp => 'Used up';
  @override String daysRemainingLong(int n) => 'About $n days left';
  @override String daysShort(int n) => '${n}d';
  @override String daysShortApprox(int n) => '~${n}d';
  @override String get resetTimerSection => 'Repurchase, reset the timer';
  @override String resetTimer(int n) => 'Reset timer ($n days)';
  @override String get addToRestockList => 'Add to restock list';
  @override String get deleteFromInventory => 'Delete from inventory';
  @override String get addToInventoryTitle => 'Add to inventory';
  @override String get productNameHint => 'Item name';
  @override String get categoryLabel => 'Category';
  @override String get estimatedUseDays => 'Estimated days of use';
  @override String get addToInventoryBtn => 'Add to inventory';

  @override String get reminderTitle => 'Alerts';
  @override String reminderSummary(int r, int e) => '$r to restock · $e running low';
  @override String get addAll => 'Add all';
  @override String get sectionRestock => 'Restock now';
  @override String get sectionExpiringSoon => 'Running low';
  @override String get reminderEmptyTitle => 'Everything is well stocked';
  @override String get reminderEmptySubtitle => 'Nothing needs restocking';
  @override String get usedUpNeedRestock => 'Used up, needs restocking';
  @override String daysLeftApprox(int n) => '~$n days left';
  @override String get add => 'Add';

  @override String get settingsTitle => 'Settings';
  @override String get proUpgrade => 'Upgrade to Pro';
  @override String get proDesc => 'Photo recognition · Quick-add widget · Multi-device sync';
  @override String get proCta => 'See Pro features →';
  @override String get sectionCategoryShelf => 'Categories & aisles';
  @override String get manageCategories => 'Manage categories';
  @override String categoriesCount(int n) => '$n';
  @override String get shelfOrder => 'Aisle order';
  @override String get sectionReminder => 'Reminders';
  @override String get restockReminder => 'Restock reminder';
  @override String get reminderTimeLabel => 'Reminder time';
  @override String get advanceDays => 'Lead days';
  @override String get sectionData => 'Data';
  @override String get backupExport => 'Backup & export';
  @override String get importRestore => 'Import & restore';
  @override String get appFooter => 'Shopping List v1.0 · Local-first';
  @override String get language => 'Language';
  @override String get languageSystem => 'Follow system';
  @override String get languageZh => '中文';
  @override String get languageEn => 'English';
  @override String labelForLanguage(Object lang) =>
      lang == AppLanguage.zh ? '中文' : lang == AppLanguage.en ? 'English' : 'Follow system';
  @override String get scale1Day => '1d';
  @override String get scale1Week => '1wk';
  @override String get scale2Week => '2wk';

  @override String category(Category c) {
    switch (c) {
      case Category.produce:  return 'Produce';
      case Category.dairy:    return 'Dairy';
      case Category.meat:     return 'Meat';
      case Category.grain:    return 'Grains';
      case Category.cleaning: return 'Cleaning';
      case Category.beverage: return 'Beverage';
      case Category.other:    return 'Other';
    }
  }

  @override String stockStatus(StockStatus s) {
    switch (s) {
      case StockStatus.sufficient: return 'Good';
      case StockStatus.low:        return 'Low';
      case StockStatus.empty:      return 'Out';
    }
  }

  @override String data(String canonical) => _enData[canonical] ?? canonical;
}

String _enDate(DateTime d) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${m[d.month - 1]} ${d.day}';
}

/// Canonical (zh) → English display for the fixed sample-data set,
/// shelf-zone display names, and the default reminder time.
const Map<String, String> _enData = {
  // shelf zones (DISPLAY ONLY — keys in code stay Chinese)
  '果蔬区': 'Produce',
  '冷藏/乳制品': 'Fridge / Dairy',
  '粮油区': 'Pantry',
  '日用品': 'Household',
  '其他': 'Other',
  // sample product names
  '香蕉': 'Banana',
  '番茄': 'Tomato',
  '藻菜': 'Greens',
  '牛奶': 'Milk',
  '鸡蛋': 'Eggs',
  '洗洁精': 'Dish soap',
  '大米': 'Rice',
  '酸奶': 'Yogurt',
  // sample quantity labels
  '1串': '1 bunch',
  '6个': '6 pcs',
  '1把': '1 bunch',
  '2盒': '2 boxes',
  '1打': '1 dozen',
  // sample shelf codes
  '货架B3': 'Shelf B3',
  '货架B1': 'Shelf B1',
  '货架B2': 'Shelf B2',
  '冷柜C2': 'Fridge C2',
  '冷柜C1': 'Fridge C1',
  // default reminder time
  '每天 18:00': 'Daily 18:00',
};
```

> Note: `AppLanguage` is referenced in `labelForLanguage`. Add `import 'app_language.dart';` at the top of `app_strings.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/l10n/app_strings_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart test/l10n/app_strings_test.dart
git commit -m "feat(l10n): add AppStrings with zh/en implementations"
```

---

## Task 4: L10n InheritedWidget

**Files:**
- Create: `lib/l10n/l10n.dart`

- [ ] **Step 1: Write implementation**

```dart
// lib/l10n/l10n.dart
import 'package:flutter/widgets.dart';
import 'app_strings.dart';
import 'app_language.dart';

/// Exposes the current [AppStrings] to the widget tree.
class L10n extends InheritedWidget {
  final AppStrings strings;
  final AppLanguage language;

  const L10n({
    super.key,
    required this.strings,
    required this.language,
    required super.child,
  });

  static AppStrings of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<L10n>();
    assert(w != null, 'No L10n found in context');
    return w!.strings;
  }

  static AppLanguage languageOf(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<L10n>();
    return w?.language ?? AppLanguage.system;
  }

  @override
  bool updateShouldNotify(L10n oldWidget) =>
      oldWidget.strings.runtimeType != strings.runtimeType;
}
```

- [ ] **Step 2: Verify it analyzes**

Run: `flutter analyze lib/l10n/l10n.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/l10n.dart
git commit -m "feat(l10n): add L10n InheritedWidget"
```

---

## Task 5: Language persistence store

**Files:**
- Create: `lib/l10n/language_store.dart`

- [ ] **Step 1: Write implementation**

```dart
// lib/l10n/language_store.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'app_language.dart';

/// Loads/saves the chosen [AppLanguage] using shared_preferences.
class LanguageStore {
  static const _key = 'app_language';

  static Future<AppLanguage> load() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_key)) {
      case 'zh':
        return AppLanguage.zh;
      case 'en':
        return AppLanguage.en;
      default:
        return AppLanguage.system;
    }
  }

  static Future<void> save(AppLanguage lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang.name); // 'system' | 'zh' | 'en'
  }
}
```

- [ ] **Step 2: Verify it analyzes**

Run: `flutter analyze lib/l10n/language_store.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/language_store.dart
git commit -m "feat(l10n): persist language choice via shared_preferences"
```

---

## Task 6: Wire app shell (async main, stateful app, L10n provider) + nav + days sheet

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Rewrite `main()` + `ShoppingListApp` to be stateful and language-aware**

Replace the top of `lib/main.dart` (imports through the `ShoppingListApp` class) with:

```dart
import 'package:flutter/material.dart';
import 'models/item.dart';
import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';
import 'l10n/l10n.dart';
import 'l10n/language_store.dart';
import 'screens/list_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reminder_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final lang = await LanguageStore.load();
  runApp(ShoppingListApp(initialLanguage: lang));
}

class ShoppingListApp extends StatefulWidget {
  final AppLanguage initialLanguage;
  const ShoppingListApp({super.key, required this.initialLanguage});

  @override
  State<ShoppingListApp> createState() => _ShoppingListAppState();
}

class _ShoppingListAppState extends State<ShoppingListApp> {
  late AppLanguage _language = widget.initialLanguage;

  void _setLanguage(AppLanguage lang) {
    setState(() => _language = lang);
    LanguageStore.save(lang);
  }

  @override
  Widget build(BuildContext context) {
    final deviceLocale =
        WidgetsBinding.instance.platformDispatcher.locale;
    final lang = resolveLang(_language, deviceLocale);
    final AppStrings strings = lang == Lang.zh ? ZhStrings() : EnStrings();

    return L10n(
      strings: strings,
      language: _language,
      child: MaterialApp(
        title: strings.shoppingListTitle,
        debugShowCheckedModeBanner: false,
        locale: lang == Lang.zh ? const Locale('zh') : const Locale('en'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4CAF50),
            primary: const Color(0xFF4CAF50),
            surface: const Color(0xFFF2F2ED),
          ),
          scaffoldBackgroundColor: const Color(0xFFF2F2ED),
        ),
        home: AppShell(
          language: _language,
          onLanguageChanged: _setLanguage,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Thread language into `AppShell`**

In `AppShell` add fields and constructor params:

```dart
class AppShell extends StatefulWidget {
  final AppLanguage language;
  final void Function(AppLanguage) onLanguageChanged;
  const AppShell({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });
  ...
```

- [ ] **Step 3: Localize the days sheet (`_DaysSheet`) and nav**

In `_showDaysSheet`/`_DaysSheet`, replace literals. In `_DaysSheet.build`, use `L10n.of(context)`:
- `'「${widget.item.name}」买到了！'` → `l.boughtTitle(l.data(widget.item.name))`
- `'预计能用几天？'` → `l.estimatedDaysQuestion`
- the chip `'$d天'` → `l.days(d)`
- button `'记录到库存（$_days天）'` → `l.recordToInventory(_days)`

Add `final l = L10n.of(context);` at the top of `_DaysSheet.build`.

In `_BottomNav` / `_NavItem`, the labels are passed as strings from the `_BottomNav` build. Update `_BottomNav` to take an `AppStrings` and pass `l.navList`, `l.navInventory`, `l.navReminder`, `l.navSettings`. Simplest: in `_AppShellState.build`, get `final l = L10n.of(ctx);` (use the `Builder` ctx already present) and pass the four labels into `_BottomNav` via new `String` params, OR call `L10n.of(context)` inside `_BottomNav.build`. Use the latter:

In `_NavItem` list inside `_BottomNav.build`, add `final l = L10n.of(context);` and replace `label: '清单'`→`label: l.navList`, `'库存'`→`l.navInventory`, `'提醒'`→`l.navReminder`, `'设置'`→`l.navSettings`.

- [ ] **Step 4: Pass language props to `SettingsScreen`**

In `_AppShellState.build`, update the `SettingsScreen(...)` child to also pass:

```dart
SettingsScreen(
  settings: _settings,
  onChanged: (s) => setState(() => _settings = s),
  language: widget.language,
  onLanguageChanged: widget.onLanguageChanged,
),
```

(SettingsScreen gains these params in Task 10.)

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/main.dart`
Expected: errors only about `SettingsScreen` not yet accepting `language`/`onLanguageChanged` (resolved in Task 10) and screens not yet localized. Note them; proceed. After Task 10 a full analyze must be clean.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "feat(l10n): make app shell language-aware (async main, L10n provider, nav, days sheet)"
```

---

## Task 7: Localize List screen

**Files:**
- Modify: `lib/screens/list_screen.dart`

- [ ] **Step 1: Import + access**

Add `import '../l10n/l10n.dart';` at top. In `_ListScreenState.build` add `final l = L10n.of(context);` (pass `l` into the `_build*` helpers as a param, or call `L10n.of(context)` inside each builder method). Recommended: call `L10n.of(context)` at the start of each builder method that needs it.

- [ ] **Step 2: Replace literals (mapping table)**

| Location | Old | New |
|---|---|---|
| `_buildHeader` title | `'购物清单'` | `l.shoppingListTitle` |
| `_buildHeader` subtitle | `'还差 $_pendingCount 件 · $dateLabel'` / `'今天买齐啦 🎉 · $dateLabel'` | `l.listSubtitlePending(_pendingCount, today)` / `l.listSubtitleDone(today)` — pass `today` (DateTime) into header; remove the `dateLabel` string param |
| complete button | `'完成购物'` | `l.completeTrip` |
| mode toggle | `'简单'` / `'智能'` | `l.modeSimple` / `l.modeSmart` |
| sub toggle | `'按货架'` / `'按分类'` | `l.byShelf` / `l.byCategory` |
| done section | `'已购'` | `l.purchasedSection` |
| count chips `'${done.length}件'`, `'$count件'` | | `l.itemCountChip(done.length)`, `l.itemCountChip(count)` |
| empty state | `'清单是空的'` / `'在下方输入要买的商品'` | `l.listEmptyTitle` / `l.listEmptySubtitle` |
| add bar hint | listening/smart/simple | `l.listeningHint` / `l.smartAddHint` / `l.simpleAddHint` |
| smart add sheet | `'添加「$name」'` | `l.addItemTitle(l.data(name))` |
| | `'选择分类，方便按货架分组'` | `l.chooseCategoryHint` |
| | `'货架区：$selectedZone'` | `l.shelfZoneInline(l.data(selectedZone))` |
| | `'加入清单'` | `l.addToList` |
| rename sheet | `'重命名'` / `'确认修改'` | `l.rename` / `l.confirmEdit` |
| smart row badge | `'已记'` | `l.recordedBadge` |
| smart row meta | `'${item.quantityLabel} · ${item.shelfCode}'` / `item.quantityLabel` | `l.itemMeta(l.data(item.quantityLabel), item.shelfCode != null ? l.data(item.shelfCode!) : null)` |
| smart row name `item.name` | | `l.data(item.name)` |
| category chips in smart add sheet `cat.label` | | `l.category(cat)` |
| section header `zone` text | (smart list group title) | `l.data(zone)` |

For the section header method `_buildSectionHeader(String zone, ...)`: the displayed `Text(zone)` becomes `Text(L10n.of(context).data(zone))`. The grouping key `zone` passed in stays canonical — do NOT change the map keys.

Pass `today` into `_buildHeader`: change its signature from `_buildHeader(String dateLabel)` to `_buildHeader(DateTime today)` and update the call site in `build` (remove `dateLabel` local).

- [ ] **Step 3: Replace `cat.label` usages**

In `_showSmartAddSheet`, the category chips use `cat.label`. Replace with `L10n.of(ctx).category(cat)` (the sheet has its own `ctx`).

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/screens/list_screen.dart`
Expected: "No issues found!" (assuming `item.dart` still exposes `Category` — it does).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/list_screen.dart
git commit -m "feat(l10n): localize list screen"
```

---

## Task 8: Localize Inventory screen

**Files:**
- Modify: `lib/screens/inventory_screen.dart`

- [ ] **Step 1: Import + access**

Add `import '../l10n/l10n.dart';`. Use `final l = L10n.of(context);` inside each builder/sheet that renders text.

- [ ] **Step 2: Replace literals (mapping table)**

| Location | Old | New |
|---|---|---|
| header title | `'库存'` | `l.inventoryTitle` |
| header summary | `'${widget.items.length}件常备 · $_needRestockCount件需补货'` | `l.inventorySummary(widget.items.length, _needRestockCount)` |
| search hint | `'搜索商品或货架'` | `l.searchHint` |
| section header `zone` Text | | `l.data(zone)` (key stays canonical) |
| section count `'$count件'` | | `l.itemCountChip(count)` |
| empty title | `'库存还是空的'` / `'没有找到「$_query」'` | `_query.isEmpty ? l.inventoryEmptyTitle : l.inventoryNoResults(_query)` |
| empty subtitle | `'先从清单购买并记录到库存'` / `'试试其他关键词'` | `_query.isEmpty ? l.inventoryEmptySubtitle : l.inventoryEmptySubtitleQuery` |
| empty button | `'手动添加商品'` | `l.addManually` |
| detail sheet category chip `item.category.label` | | `l.category(item.category)` |
| detail sheet `item.shelfZone` text | | `l.data(item.shelfZone)` |
| detail status chip `status.label` | | `l.stockStatus(status)` |
| detail `'已用完'` / `'还剩约 ${item.daysRemaining} 天'` | | `l.usedUp` / `l.daysRemainingLong(item.daysRemaining)` |
| detail `'重新购买，重置计时'` | | `l.resetTimerSection` |
| detail day chips `'$d天'` | | `l.days(d)` |
| detail button `'重置计时（$selectedDays天）'` | | `l.resetTimer(selectedDays)` |
| detail `'加入补货清单'` | | `l.addToRestockList` |
| detail `'从库存删除'` | | `l.deleteFromInventory` |
| card name `item.name` | | `l.data(item.name)` |
| card status badge `status.label` | | `l.stockStatus(status)` |
| card `'已用完'` / `'约$remaining天'` / `'$remaining天'` | | `l.usedUp` / `l.daysShortApprox(remaining)` / `l.daysShort(remaining)` |
| card thumbnail substring of `item.name` | uses `item.name.substring` | use `l.data(item.name)` first: `final dn = l.data(item.name); dn.length > 2 ? dn.substring(0,2) : dn` |
| add sheet title `'添加到库存'` | | `l.addToInventoryTitle` |
| add sheet field hint `'商品名称'` | | `l.productNameHint` |
| add sheet `'分类'` | | `l.categoryLabel` |
| add sheet category chips `cat.label` | | `l.category(cat)` |
| add sheet `'预计使用天数'` | | `l.estimatedUseDays` |
| add sheet day chips `'$d天'` | | `l.days(d)` |
| add sheet button `'加入库存'` | | `l.addToInventoryBtn` |

`_InventoryCard` and `_AddInventorySheet` are separate widgets — call `L10n.of(context)` inside their own `build`. `_InventoryCard.build` already has `BuildContext context`.

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/screens/inventory_screen.dart`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add lib/screens/inventory_screen.dart
git commit -m "feat(l10n): localize inventory screen"
```

---

## Task 9: Localize Reminder screen

**Files:**
- Modify: `lib/screens/reminder_screen.dart`

- [ ] **Step 1: Import + access**

Add `import '../l10n/l10n.dart';`. Use `final l = L10n.of(context);` in `build`, `_buildHeader`, `_buildList`, `_emptyState`, and in `_ReminderRow.build`.

- [ ] **Step 2: Replace literals (mapping table)**

| Location | Old | New |
|---|---|---|
| header title | `'提醒'` | `l.reminderTitle` |
| header summary | `'${_restock.length}件该补货 · ${_expiringSoon.length}件即将用完'` | `l.reminderSummary(_restock.length, _expiringSoon.length)` |
| add-all button | `'全部加入'` | `l.addAll` |
| section headers | `'该补货'` / `'即将用完'` | `l.sectionRestock` / `l.sectionExpiringSoon` |
| empty | `'库存都很充足'` / `'没有需要补货的商品'` | `l.reminderEmptyTitle` / `l.reminderEmptySubtitle` |
| row thumbnail `item.name` | | `l.data(item.name)` (and length check on the translated value) |
| row name `item.name` | | `l.data(item.name)` |
| row hint | `'已用完，需要补货'` / `'还剩约$remaining天'` | `l.usedUpNeedRestock` / `l.daysLeftApprox(remaining)` |
| row button `'加入'` | | `l.add` |
| row badge `'约$remaining天'` | | `l.daysShortApprox(remaining)` |

`_emptyState` is currently `const` — remove `const` so it can read `l`. The `'🌿'` emoji stays as-is.

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/screens/reminder_screen.dart`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add lib/screens/reminder_screen.dart
git commit -m "feat(l10n): localize reminder screen"
```

---

## Task 10: Localize Settings screen + add language selector

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Add imports + new props**

Add:
```dart
import '../l10n/l10n.dart';
import '../l10n/app_language.dart';
```

Add fields to `SettingsScreen`:
```dart
  final AppLanguage language;
  final void Function(AppLanguage) onLanguageChanged;
```
and constructor params `required this.language, required this.onLanguageChanged,`.

- [ ] **Step 2: Replace literals (mapping table)**

Add `final l = L10n.of(context);` at the start of `build`. Pass `l` where needed (or re-fetch in helpers).

| Old | New |
|---|---|
| `'设置'` | `l.settingsTitle` |
| `'升级 Pro'` | `l.proUpgrade` |
| `'拍照识别配图 · 快捷加项组件 · 多设备同步备份'` | `l.proDesc` |
| `'查看 Pro 功能 →'` | `l.proCta` |
| `'分类与货架'` | `l.sectionCategoryShelf` |
| `'管理分类'` | `l.manageCategories` |
| trailing `'12类'` | `l.categoriesCount(12)` |
| `'货架顺序'` | `l.shelfOrder` |
| `'提醒'` (section) | `l.sectionReminder` |
| `'补货提醒'` | `l.restockReminder` |
| `'提醒时间'` | `l.reminderTimeLabel` |
| trailing `_settings.reminderTime` | `l.data(_settings.reminderTime)` |
| `'提前天数'` | `l.advanceDays` |
| `'${...}天'` (threshold value) | `l.days(_settings.reminderThresholdDays)` |
| scale labels `'1天'`/`'1周'`/`'2周'` | `l.scale1Day` / `l.scale1Week` / `l.scale2Week` |
| `'数据'` | `l.sectionData` |
| `'备份导出'` | `l.backupExport` |
| `'导入恢复'` | `l.importRestore` |
| footer `'购物清单 v1.0 · 本地优先'` | `l.appFooter` |

`_buildProCard`, `_buildSection`, `_navRow`, `_switchRow`, `_thresholdRow` take strings already; pass localized strings from `build`/callers. For helpers that build their own text (e.g. `_thresholdRow` scale labels), add `final l = L10n.of(context);` inside them.

- [ ] **Step 3: Add the language selector row + sheet**

Add a new section after the title/Pro card (before or after "提醒"; place it in `sectionCategoryShelf` group as a third row or its own section). Add an "Appearance"-style section:

```dart
_buildSection(l.language, [
  _navRow(
    l.language,
    trailing: l.labelForLanguage(widget.language),
    onTap: () => _showLanguageSheet(l),
  ),
]),
const SizedBox(height: 16),
```

Update `_navRow` to accept an optional `VoidCallback? onTap` and pass it to `ListTile.onTap`:

```dart
Widget _navRow(String label, {String? trailing, VoidCallback? onTap}) {
  return ListTile(
    onTap: onTap,
    ...
```

Add the sheet method:

```dart
void _showLanguageSheet(AppStrings l) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          for (final entry in <AppLanguage, String>{
            AppLanguage.system: l.languageSystem,
            AppLanguage.zh: l.languageZh,
            AppLanguage.en: l.languageEn,
          }.entries)
            ListTile(
              title: Text(entry.value),
              trailing: widget.language == entry.key
                  ? const Icon(Icons.check_rounded, color: Color(0xFF4CAF50))
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                widget.onLanguageChanged(entry.key);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
```

Add `import '../l10n/app_strings.dart';` for the `AppStrings` param type.

- [ ] **Step 4: Full project analyze**

Run: `flutter analyze`
Expected: "No issues found!" (all screens localized; main.dart's earlier references now resolve).

- [ ] **Step 5: Run all tests**

Run: `flutter test`
Expected: all PASS (existing `test/widget_test.dart` may need a trivial update if it constructs `ShoppingListApp` without `initialLanguage` — if it fails to compile, update it to `ShoppingListApp(initialLanguage: AppLanguage.zh)` and import `app_language.dart`).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings_screen.dart test/widget_test.dart
git commit -m "feat(l10n): localize settings screen and add language selector"
```

---

## Task 11: Manual verification on simulator

**Files:** none (verification only)

- [ ] **Step 1: Run the app**

Run: `flutter run -d <iphone-simulator-id>`
Expected: builds and launches; UI in Chinese (assuming zh device locale) or English (en locale).

- [ ] **Step 2: Switch to English**

Settings → Language → English. Verify ALL four tabs (List/Inventory/Alerts/Settings) render English, including sample data (Banana, Milk…), category labels, status badges, aisle/group headers, empty states, and bottom-sheets (days sheet, add-to-inventory, smart-add).

- [ ] **Step 3: Regression check**

In English, smart mode: check off "Banana" → days sheet → save → Inventory tab shows Banana under Produce (group/sync still works). Drag-reorder a smart item across groups. Confirm grouping/drag/sync behave exactly as before.

- [ ] **Step 4: Persistence check**

Fully quit and relaunch the app (stop the run, `flutter run` again). Language should remain English.

- [ ] **Step 5: Switch back to 中文**

Settings → Language → 中文. Verify full revert.

- [ ] **Step 6: Commit (if any fixups were needed)**

```bash
git add -A
git commit -m "fix(l10n): verification fixups"
```

---

## Self-Review Notes

- **Spec coverage:** approach (Task 2-4), persistence (Task 1,5,6), follow-system default (Task 2,6), sample-data translation (Task 3 `_enData` + `data()` calls in Tasks 7-9), settings selector (Task 10), shelf-zone key invariant (Tasks 7,8 keep keys canonical, translate display only) — all covered.
- **No placeholders:** every replacement has an exact `AppStrings` member.
- **Type consistency:** all `l.*` members used in Tasks 6-10 are declared in Task 3's abstract class.
