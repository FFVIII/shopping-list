# iOS 补货通知 + JSON 备份导出/导入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让"补货提醒"开关真正发 iOS 本地通知（确定性预排未来 14 天），并让设置页"备份导出/导入恢复"两行可用（JSON 全量导出 + 完全覆盖式导入）。

**Architecture:** 通知采用"确定性预排"：库存消耗由 `purchasedAt + estimatedDays` 完全决定，每次库存/设置变化时取消全部待发通知、重算未来 14 天并只给有低库存的天预约（见 spec §4.1）。备份复用 `hive_models.dart` 现有 `toMap`/`fromMap`（输出已是 JSON 安全的基本类型），导入完全覆盖并经确认框。

**Tech Stack:** Flutter/Dart，`flutter_local_notifications` + `timezone` + `flutter_timezone`（iOS 本地通知），`share_plus`（导出分享面板），`file_picker`（导入选文件），`path_provider`（临时文件），Hive（现有持久化）。

**Spec:** `docs/superpowers/specs/2026-07-02-notifications-and-backup-design.md`

**环境须知（每个任务都适用）：**
- `flutter` 不在默认 PATH 上。所有命令用绝对路径（注意路径里有空格和竖线，必须整个加引号）：
  ```bash
  FLUTTER="/Users/ffviii/Computer Science | Coding/Flutter/flutter/bin/flutter"
  cd "/Users/ffviii/Computer Science | Coding/Flutter/projects/shopping_list"
  "$FLUTTER" test
  ```
- 工作区里有大量**属于别的工作、尚未提交的改动**（17 个文件）。每次 commit 只 `git add` 本任务明确列出的文件，**绝不用 `git add -A` / `git add .`**。
- 与 spec 的一处偏差已确认：新增 `flutter_timezone` 依赖（spec §3 只列了 `timezone`）。原因：`zonedSchedule` 需要 `tz.local` 是设备真实时区，而 `timezone` 包初始化后默认 UTC，需要 `flutter_timezone` 拿到设备的 IANA 时区名。

**File structure（全景）：**

| 文件 | 动作 | 职责 |
|---|---|---|
| `pubspec.yaml` | 改 | 新依赖 |
| `lib/l10n/app_strings.dart` | 改 | 9 条新字符串（通知文案 + 备份 UI 文案） |
| `lib/services/notification_service.dart` | 建 | `lowStockAt` 纯函数 + `NotificationService`（init/requestPermission/reschedule） |
| `lib/storage/backup.dart` | 建 | `encodeBackup`/`decodeBackup`（纯函数） |
| `lib/storage/app_repository.dart` | 改 | 加 `replaceAll(AppData)` |
| `lib/main.dart` | 改 | 服务注入、persist 钩子接 reschedule、备份快照/应用回调 |
| `lib/screens/settings_screen.dart` | 改 | 开关权限流程、导出/导入 UI 流程 |
| `ios/Runner/AppDelegate.swift` | 改 | 前台展示通知的 delegate |
| `test/services/notification_service_test.dart` | 建 | `lowStockAt` 边界测试 |
| `test/storage/backup_test.dart` | 建 | encode/decode 往返 + 坏输入测试 |
| `test/storage/app_repository_test.dart` | 改 | `replaceAll` 测试 |

---

### Task 1: 添加依赖

**Files:**
- Modify: `pubspec.yaml`（由 `flutter pub add` 自动改）

- [ ] **Step 1: 添加 6 个依赖**

```bash
cd "/Users/ffviii/Computer Science | Coding/Flutter/projects/shopping_list"
FLUTTER="/Users/ffviii/Computer Science | Coding/Flutter/flutter/bin/flutter"
"$FLUTTER" pub add flutter_local_notifications timezone flutter_timezone share_plus file_picker path_provider
```

Expected: 6 个包出现在 `pubspec.yaml` dependencies 段，`pub get` 成功。

- [ ] **Step 2: 确认无损坏**

```bash
"$FLUTTER" analyze
```

Expected: `No issues found!`（或与改动前相同的既有告警——本项目当前是干净的）。

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add local notifications + backup export/import packages"
```

注意：`pub add` 之后如果 `ios/Podfile.lock` 等 iOS 侧文件此时没变化就不用管；真机构建时 CocoaPods 相关文件会更新，那些留给 Task 10 的手动验证 commit。

---

### Task 2: 新增字符串（通知文案 + 备份 UI 文案）

**Files:**
- Modify: `lib/l10n/app_strings.dart`

没有独立测试——抽象类加 getter 后，Zh/En 两个实现不补齐就编译不过，编译器就是测试。

- [ ] **Step 1: 抽象类加声明**

在 `abstract class AppStrings` 的 `String get importRestore;`（约 158 行）之后加：

```dart
  // ── Notifications & backup ──
  String get notifRestockTitle;                       // "该补货了" / "Time to restock"
  String notifRestockBody(int count, List<String> names); // 最多列 3 个名字
  String get notifPermissionDenied; // 开关打开但授权被拒时的 toast
  String get importConfirmTitle;    // "导入备份？" / "Import backup?"
  String get importConfirmMessage;  // 覆盖警告
  String get importAction;          // "导入" / "Import"
  String get importInvalidFile;     // "文件无效，无法导入"
  String get importSuccessToast;    // "已恢复备份"
  String get exportFailedToast;     // "导出失败"
```

- [ ] **Step 2: ZhStrings 实现**

在 `ZhStrings` 的 `@override String get importRestore => '导入恢复';`（约 331 行）之后加：

```dart
  @override String get notifRestockTitle => '该补货了';
  @override String notifRestockBody(int count, List<String> names) {
    final shown = names.take(3).join('、');
    final suffix = count > 3 ? ' 等' : '';
    return '有 $count 件物品需要补货：$shown$suffix';
  }
  @override String get notifPermissionDenied => '通知权限未开启，请在系统设置中允许通知';
  @override String get importConfirmTitle => '导入备份？';
  @override String get importConfirmMessage =>
      '将覆盖当前全部数据（清单、库存、记账、分类、设置），此操作不可撤销。';
  @override String get importAction => '导入';
  @override String get importInvalidFile => '文件无效，无法导入';
  @override String get importSuccessToast => '已恢复备份';
  @override String get exportFailedToast => '导出失败';
```

- [ ] **Step 3: EnStrings 实现**

在 `EnStrings` 的 `@override String get importRestore => 'Import & restore';`（约 515 行）之后加：

```dart
  @override String get notifRestockTitle => 'Time to restock';
  @override String notifRestockBody(int count, List<String> names) {
    final shown = names.take(3).join(', ');
    final suffix = count > 3 ? '…' : '';
    return count == 1
        ? '1 item needs restocking: $shown'
        : '$count items need restocking: $shown$suffix';
  }
  @override String get notifPermissionDenied =>
      'Notifications are off. Enable them in system Settings.';
  @override String get importConfirmTitle => 'Import backup?';
  @override String get importConfirmMessage =>
      'This will replace ALL current data (lists, inventory, expenses, categories, settings). This cannot be undone.';
  @override String get importAction => 'Import';
  @override String get importInvalidFile => 'Invalid backup file';
  @override String get importSuccessToast => 'Backup restored';
  @override String get exportFailedToast => 'Export failed';
```

- [ ] **Step 4: 验证编译**

```bash
"$FLUTTER" analyze
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart
git commit -m "feat: add notification and backup UI strings (zh/en)"
```

---

### Task 3: `lowStockAt` 纯函数（TDD）

通知预排的核心计算：给定一个未来时刻，哪些库存物品届时处于"快没/用完"。与 `InventoryItem.statusFor` 用同一套数学（`remaining = estimatedDays - elapsed.inDays`，`remaining <= threshold` 即需要提醒——覆盖 low 和 empty 两档）。

**Files:**
- Create: `test/services/notification_service_test.dart`
- Create: `lib/services/notification_service.dart`（本任务只放纯函数，service 类在 Task 4）

- [ ] **Step 1: 写失败测试**

创建 `test/services/notification_service_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/services/notification_service.dart';

InventoryItem _item(String name,
    {required DateTime purchasedAt, required int estimatedDays}) {
  final cats = buildDefaultCategories();
  return InventoryItem(
    id: 'inv_$name',
    name: name,
    category: cats.fallback,
    shelfZone: '其他',
    purchasedAt: purchasedAt,
    estimatedDays: estimatedDays,
  );
}

void main() {
  // 一个固定的"提醒时刻"参照点，避免测试依赖真实当前时间。
  final base = DateTime(2026, 7, 2, 18, 0);

  test('empty inventory yields empty result', () {
    expect(lowStockAt(base, [], 5), isEmpty);
  });

  test('item with plenty of days left is not included', () {
    final items = [
      _item('大米',
          purchasedAt: base.subtract(const Duration(days: 1)),
          estimatedDays: 30),
    ];
    expect(lowStockAt(base, items, 5), isEmpty);
  });

  test('item exactly at threshold is included', () {
    // 5 天前购入、能用 10 天 → 剩 5 天，正好等于阈值 5 → 属于"快没"
    final items = [
      _item('牛奶',
          purchasedAt: base.subtract(const Duration(days: 5)),
          estimatedDays: 10),
    ];
    expect(lowStockAt(base, items, 5).map((i) => i.name), ['牛奶']);
  });

  test('used-up item (remaining <= 0) is included', () {
    final items = [
      _item('鸡蛋',
          purchasedAt: base.subtract(const Duration(days: 20)),
          estimatedDays: 10),
    ];
    expect(lowStockAt(base, items, 5), hasLength(1));
  });

  test('estimatedDays = 0 is included immediately', () {
    final items = [_item('酸奶', purchasedAt: base, estimatedDays: 0)];
    expect(lowStockAt(base, items, 5), hasLength(1));
  });

  test('item becomes low only on a future day', () {
    // 今天买的 10 天物品：今天剩 10（充足），6 天后剩 4（低于阈值 5）
    final item = _item('牛奶', purchasedAt: base, estimatedDays: 10);
    expect(lowStockAt(base, [item], 5), isEmpty);
    expect(lowStockAt(base.add(const Duration(days: 6)), [item], 5),
        hasLength(1));
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$FLUTTER" test test/services/notification_service_test.dart
```

Expected: FAIL —— `Error: Couldn't resolve the package 'shopping_list/services/notification_service.dart'`（文件不存在）。

- [ ] **Step 3: 最小实现**

创建 `lib/services/notification_service.dart`：

```dart
import '../models/item.dart';

/// Items that will be low or out of stock at [moment]: projected remaining
/// days <= [thresholdDays]. Mirrors the math in [InventoryItem.statusFor]
/// (covers both StockStatus.low and StockStatus.empty).
List<InventoryItem> lowStockAt(
    DateTime moment, List<InventoryItem> inventory, int thresholdDays) {
  return inventory.where((item) {
    final elapsed = moment.difference(item.purchasedAt).inDays;
    final remaining = item.estimatedDays - elapsed;
    return remaining <= thresholdDays;
  }).toList();
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
"$FLUTTER" test test/services/notification_service_test.dart
```

Expected: `All tests passed!`（6 个）

- [ ] **Step 5: Commit**

```bash
git add lib/services/notification_service.dart test/services/notification_service_test.dart
git commit -m "feat: add lowStockAt projection for notification scheduling"
```

---### Task 4: `NotificationService` 类

系统交互层（插件初始化、权限、zonedSchedule），无单测——真机验证在 Task 10。

**Files:**
- Modify: `lib/services/notification_service.dart`

- [ ] **Step 1: 补上 imports 和 service 类**

把 `lib/services/notification_service.dart` 改成（保留已有的 `lowStockAt`，在文件头补 import、文件尾加类）：

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_strings.dart';
import '../models/item.dart';

/// Items that will be low or out of stock at [moment]: projected remaining
/// days <= [thresholdDays]. Mirrors the math in [InventoryItem.statusFor]
/// (covers both StockStatus.low and StockStatus.empty).
List<InventoryItem> lowStockAt(
    DateTime moment, List<InventoryItem> inventory, int thresholdDays) {
  return inventory.where((item) {
    final elapsed = moment.difference(item.purchasedAt).inDays;
    final remaining = item.estimatedDays - elapsed;
    return remaining <= thresholdDays;
  }).toList();
}

/// How many days ahead we pre-schedule (design spec 2026-07-02 §4.1).
const int kNotificationHorizonDays = 14;

/// iOS local notifications for restock reminders. Deterministic
/// pre-scheduling: every data change cancels all pending notifications and
/// re-schedules the next [kNotificationHorizonDays] days.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('timezone lookup failed, keeping default: $e');
    }
    await _plugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(
          // Permission is requested from the settings toggle (spec §4.4),
          // not at startup.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  /// Shows the system permission prompt (or returns the existing decision).
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    final granted =
        await _ios?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }

  /// Silent check — never shows a prompt.
  Future<bool> _hasPermission() async {
    final options = await _ios?.checkPermissions();
    return options?.isEnabled ?? false;
  }

  Future<void> reschedule({
    required List<InventoryItem> inventory,
    required AppSettings settings,
    required AppStrings strings,
  }) async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    if (!settings.restockReminderEnabled) return;
    if (!await _hasPermission()) return;

    final now = tz.TZDateTime.now(tz.local);
    for (int d = 0; d < kNotificationHorizonDays; d++) {
      final day = now.add(Duration(days: d));
      final fireAt = tz.TZDateTime(tz.local, day.year, day.month, day.day,
          settings.reminderHour, settings.reminderMinute);
      if (!fireAt.isAfter(now)) continue; // today's slot already passed
      final low =
          lowStockAt(fireAt, inventory, settings.reminderThresholdDays);
      if (low.isEmpty) continue;
      await _plugin.zonedSchedule(
        d, // one stable id per day-offset
        strings.notifRestockTitle,
        strings.notifRestockBody(
            low.length, low.map((i) => strings.data(i.name)).toList()),
        fireAt,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentBanner: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
```

API 版本注意（不同大版本略有差异，以能编译为准）：
- flutter_local_notifications v19+：`zonedSchedule` 的 `androidScheduleMode` 是必填命名参数（虽然本次只做 iOS 也必须传）。若装到的版本编译报 "no named parameter androidScheduleMode"，直接删掉该参数即可。
- `checkPermissions()` 返回 `NotificationsEnabledOptions?`，取 `.isEnabled`。若该方法不存在（老版本），改为保守返回 `true`（未授权时 iOS 系统会静默丢弃通知，行为仍正确），并加注释说明。
- flutter_timezone 新版 `getLocalTimezone()` 返回的可能是 `TimezoneInfo` 对象而非 `String`；若编译报类型错误，改成取 `.identifier`。

- [ ] **Step 2: 验证编译 + 既有测试不破**

```bash
"$FLUTTER" analyze && "$FLUTTER" test test/services/notification_service_test.dart
```

Expected: analyze 无错误；6 个测试仍全过（`lowStockAt` 行为未变）。

- [ ] **Step 3: Commit**

```bash
git add lib/services/notification_service.dart
git commit -m "feat: add NotificationService with deterministic 14-day pre-scheduling"
```

---

### Task 5: `backup.dart` 编解码（TDD）

**Files:**
- Create: `test/storage/backup_test.dart`
- Create: `lib/storage/backup.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/storage/backup_test.dart`：

```dart
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
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$FLUTTER" test test/storage/backup_test.dart
```

Expected: FAIL —— 找不到 `shopping_list/storage/backup.dart`。

- [ ] **Step 3: 实现**

创建 `lib/storage/backup.dart`：

```dart
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
  try {
    final categories =
        (root['categories'] as List).cast<Map>().map(categoryFromMap).toList();
    List<ShoppingItem> shopping(String key) => (root[key] as List)
        .cast<Map>()
        .map((m) => shoppingItemFromMap(m, categories))
        .toList();
    return AppData(
      shoppingSimple: shopping('shoppingSimple'),
      shoppingSmart: shopping('shoppingSmart'),
      inventory: (root['inventory'] as List)
          .cast<Map>()
          .map((m) => inventoryItemFromMap(m, categories))
          .toList(),
      budget:
          (root['budget'] as List).cast<Map>().map(budgetItemFromMap).toList(),
      categories: categories,
      settings: appSettingsFromMap(root['settings'] as Map),
      shelfZones: (root['shelfZones'] as List)
          .cast<Map>()
          .map(shelfZoneFromMap)
          .toList(),
      shelfCodeOrder: (root['shelfCodeOrder'] as List).cast<String>(),
    );
  } catch (e) {
    // Covers wrong types, missing keys (null casts), bad enum values, etc.
    throw FormatException('backup: malformed content: $e');
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
"$FLUTTER" test test/storage/backup_test.dart
```

Expected: `All tests passed!`（6 个）

- [ ] **Step 5: Commit**

```bash
git add lib/storage/backup.dart test/storage/backup_test.dart
git commit -m "feat: add JSON backup encode/decode with strict validation"
```

---

### Task 6: `AppRepository.replaceAll`（TDD）

**Files:**
- Modify: `test/storage/app_repository_test.dart`
- Modify: `lib/storage/app_repository.dart`

- [ ] **Step 1: 写失败测试**

在 `test/storage/app_repository_test.dart` 最后一个 `test(...)` 之后（`main` 的收尾 `}` 之前）加：

```dart
  test('replaceAll overwrites every collection', () async {
    final repo = AppRepository();
    await repo.init();
    await repo.load(lang: Lang.zh); // seeds sample data

    final categories = buildDefaultCategories();
    final replacement = AppData(
      shoppingSimple: [],
      shoppingSmart: [],
      inventory: [],
      budget: [BudgetItem(id: 'only', name: '替换', quantity: 2, unitPrice: 3.5)],
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
    expect(reloaded.settings.reminderHour, 6);
    expect(reloaded.settings.restockReminderEnabled, false);
    expect(reloaded.shelfCodeOrder, ['A1']);
  });
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$FLUTTER" test test/storage/app_repository_test.dart
```

Expected: FAIL —— `The method 'replaceAll' isn't defined for the class 'AppRepository'`。

- [ ] **Step 3: 实现**

在 `lib/storage/app_repository.dart` 的 `saveShelfCodeOrder`（文件末尾）之后加：

```dart
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
```

- [ ] **Step 4: 跑测试确认通过**

```bash
"$FLUTTER" test test/storage/app_repository_test.dart
```

Expected: `All tests passed!`（5 个）

- [ ] **Step 5: Commit**

```bash
git add lib/storage/app_repository.dart test/storage/app_repository_test.dart
git commit -m "feat: add AppRepository.replaceAll for backup import"
```

---

### Task 7: `main.dart` 接线（服务注入 + reschedule 钩子 + 备份回调）

**Files:**
- Modify: `lib/main.dart`

本任务结束时 SettingsScreen 还没接收新参数（Task 8），所以本任务**只加不改** SettingsScreen 的构造调用之外的部分——为避免中间态编译不过，Task 7 和 Task 8 合并为一个 commit 也可以；但优先按下面拆法做，Task 7 结尾用 analyze 验证（此时 `_buildBackupJson`/`_applyBackup`/权限回调尚未被引用，会有 unused_element 提示，属预期，Task 8 消掉）。

- [ ] **Step 1: imports + main() 注入服务**

`lib/main.dart` 头部加 import（保持现有 import 分组风格）：

```dart
import 'services/notification_service.dart';
import 'storage/backup.dart';
```

`main()` 改为：

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = AppRepository();
  try {
    await Hive.initFlutter();
    await repository.init();
  } catch (e) {
    debugPrint('Hive init failed, falling back to in-memory sample data: $e');
  }
  final notifications = NotificationService();
  try {
    await notifications.init();
  } catch (e) {
    debugPrint('Notification init failed, reminders disabled: $e');
  }
  final lang = await LanguageStore.load();
  runApp(ShoppingListApp(
    initialLanguage: lang,
    repository: repository,
    notifications: notifications,
  ));
}
```

- [ ] **Step 2: 把服务传到 AppShell**

`ShoppingListApp` 加字段（照 `repository` 的样子）：

```dart
  final AppLanguage initialLanguage;
  final AppRepository repository;
  final NotificationService notifications;
  const ShoppingListApp({
    super.key,
    required this.initialLanguage,
    required this.repository,
    required this.notifications,
  });
```

`build` 里 `home: AppShell(...)` 加 `notifications: widget.notifications,`。

`AppShell` 同样加：

```dart
  final AppLanguage language;
  final void Function(AppLanguage) onLanguageChanged;
  final AppRepository repository;
  final NotificationService notifications;
  const AppShell({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.repository,
    required this.notifications,
  });
```

- [ ] **Step 3: `_AppShellState` 加 reschedule 帮手，并接入三个触发点**

在 `AppRepository get _repo => widget.repository;` 之后加：

```dart
  AppStrings get _currentStrings {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    return resolveLang(widget.language, deviceLocale) == Lang.zh
        ? ZhStrings()
        : EnStrings();
  }

  void _rescheduleNotifications() => unawaited(widget.notifications
      .reschedule(
        inventory: _inventory,
        settings: _settings,
        strings: _currentStrings,
      )
      .catchError((e) => debugPrint('notification reschedule failed: $e')));
```

三个触发点（spec §4.3）：

1. `_persistInventory` 和 `_persistSettings` 从表达式体改成块体并追加调用：

```dart
  void _persistInventory() {
    unawaited(_repo
        .saveInventory(_inventory)
        .catchError((e) => debugPrint('save inventory failed: $e')));
    _rescheduleNotifications();
  }
```

```dart
  void _persistSettings() {
    unawaited(_repo
        .saveSettings(_settings)
        .catchError((e) => debugPrint('save settings failed: $e')));
    _rescheduleNotifications();
  }
```

（其余 6 个 `_persist*` 保持原样不动。）

2. `_loadData()` 末尾、`setState(...)` 块之后加一行：

```dart
    _rescheduleNotifications();
```

- [ ] **Step 4: 备份快照/应用回调**

在 `_AppShellState` 里（建议放在 `// ── Build ──` 分隔线之前）加：

```dart
  // ── 备份：导出快照 / 导入应用 ────────────────────────────────────────────────

  String _buildBackupJson() => encodeBackup(AppData(
        shoppingSimple: _shoppingSimple,
        shoppingSmart: _shopping,
        inventory: _inventory,
        budget: _budget,
        categories: _categories,
        settings: _settings,
        shelfZones: _shelfZones,
        shelfCodeOrder: _shelfCodeOrder,
      ));

  Future<void> _applyBackup(AppData data) async {
    try {
      await _repo.replaceAll(data);
    } catch (e) {
      // Same policy as all other persistence failures (spec 2026-06-30 §5):
      // keep the in-memory state, log the write error.
      debugPrint('backup import write failed: $e');
    }
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
    });
    _rescheduleNotifications();
  }
```

- [ ] **Step 5: 验证编译**

```bash
"$FLUTTER" analyze
```

Expected: 只有 `_buildBackupJson`/`_applyBackup` 的 unused_element 两条 info（Task 8 接上后消失），无 error。

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire NotificationService into app shell + backup snapshot/apply"
```

---

### Task 8: SettingsScreen —— 开关权限流程 + 导出/导入 UI

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/main.dart`（把三个新参数传给 SettingsScreen）

- [ ] **Step 1: SettingsScreen 加参数和 imports**

`lib/screens/settings_screen.dart` 头部加：

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../storage/app_repository.dart';
import '../storage/backup.dart';
import '../widgets/toast.dart';
```

`SettingsScreen` 加字段 + 构造参数（放在 `onReorderCategories` 之后）：

```dart
  final String Function() buildBackupJson;
  final Future<void> Function(AppData data) onImportBackup;
  final Future<bool> Function() requestNotificationPermission;
```

构造函数加：

```dart
    required this.buildBackupJson,
    required this.onImportBackup,
    required this.requestNotificationPermission,
```

- [ ] **Step 2: 同步外部 settings 变化（导入备份后设置页不能显示旧值）**

`_SettingsScreenState` 里 `initState` 之后加：

```dart
  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.settings, widget.settings)) {
      _settings = AppSettings(
        reminderThresholdDays: widget.settings.reminderThresholdDays,
        restockReminderEnabled: widget.settings.restockReminderEnabled,
        reminderHour: widget.settings.reminderHour,
        reminderMinute: widget.settings.reminderMinute,
      );
    }
  }
```

- [ ] **Step 3: 开关走权限流程**

`build` 里补货提醒的 `_switchRow` 改为：

```dart
              _switchRow(
                l.restockReminder,
                _settings.restockReminderEnabled,
                _onReminderToggle,
              ),
```

`_SettingsScreenState` 加方法：

```dart
  Future<void> _onReminderToggle(bool enabled) async {
    if (enabled) {
      final granted = await widget.requestNotificationPermission();
      if (!mounted) return;
      if (!granted) {
        // Leave the switch off; user must enable notifications in system
        // Settings first (spec §4.4).
        showAppToast(context, L10n.of(context).notifPermissionDenied);
        return;
      }
    }
    _update(AppSettings(
      reminderThresholdDays: _settings.reminderThresholdDays,
      restockReminderEnabled: enabled,
      reminderHour: _settings.reminderHour,
      reminderMinute: _settings.reminderMinute,
    ));
  }
```

- [ ] **Step 4: 导出/导入流程**

`build` 里数据段改为：

```dart
            _buildSection(l.sectionData, [
              _navRow(l.backupExport, onTap: _exportBackup),
              _navRow(l.importRestore, onTap: _importBackup),
            ]),
```

`_SettingsScreenState` 加两个方法：

```dart
  Future<void> _exportBackup() async {
    final l = L10n.of(context);
    try {
      final json = widget.buildBackupJson();
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/shopping_list_backup_'
          '${now.year}-${two(now.month)}-${two(now.day)}.json');
      await file.writeAsString(json);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'application/json')]),
      );
    } catch (e) {
      debugPrint('backup export failed: $e');
      if (mounted) showAppToast(context, l.exportFailedToast);
    }
  }

  Future<void> _importBackup() async {
    final l = L10n.of(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return; // user cancelled
    AppData data;
    try {
      data = decodeBackup(await File(path).readAsString());
    } catch (e) {
      debugPrint('backup decode failed: $e');
      if (mounted) showAppToast(context, l.importInvalidFile);
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.importConfirmTitle),
        content: Text(
          l.importConfirmMessage,
          style: const TextStyle(color: Color(0xFFE53935)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.importAction,
              style: const TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onImportBackup(data);
    if (mounted) showAppToast(context, l.importSuccessToast);
  }
```

share_plus API 注意：`SharePlus.instance.share(ShareParams(...))` 是 v11+ 的 API；如果装到的是 v10 及以下，改用 `await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')]);`。以能编译为准。

- [ ] **Step 5: `main.dart` 把新参数传进去**

`_AppShellState.build` 里 `SettingsScreen(` 的构造调用加：

```dart
              buildBackupJson: _buildBackupJson,
              onImportBackup: _applyBackup,
              requestNotificationPermission:
                  widget.notifications.requestPermission,
```

- [ ] **Step 6: 验证编译 + 全部测试**

```bash
"$FLUTTER" analyze && "$FLUTTER" test
```

Expected: analyze 无 issue（Task 7 的 unused_element 消失）；全部测试通过。

- [ ] **Step 7: Commit**

```bash
git add lib/screens/settings_screen.dart lib/main.dart
git commit -m "feat: wire settings toggle permission flow + backup export/import UI"
```

---

### Task 9: iOS AppDelegate —— 前台展示通知

**Files:**
- Modify: `ios/Runner/AppDelegate.swift`

- [ ] **Step 1: 设置 UNUserNotificationCenter delegate**

`ios/Runner/AppDelegate.swift` 全文改为：

```swift
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Let flutter_local_notifications present notifications while the app
    // is in the foreground.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add ios/Runner/AppDelegate.swift
git commit -m "feat(ios): present local notifications while app is in foreground"
```

（编译验证合并到 Task 10 的真机/模拟器构建。）

---

### Task 10: 收尾验证（自动 + 手动）

**Files:** 无新改动（若构建更新了 `ios/Podfile.lock` 等，单独 commit）

- [ ] **Step 1: 全量自动检查**

```bash
"$FLUTTER" analyze && "$FLUTTER" test
```

Expected: 无 issue，全部测试通过（≥ 17 个：既有 4 文件 + 新增 2 文件）。

- [ ] **Step 2: iOS 模拟器/真机构建**

```bash
"$FLUTTER" build ios --simulator
```

Expected: 构建成功。若 CocoaPods 报错，先 `cd ios && pod install`。构建产生的 `ios/Podfile.lock` / project.pbxproj 变化，单独 commit：

```bash
git add ios/Podfile ios/Podfile.lock
git commit -m "chore(ios): pod install for notification/backup plugins"
```

（注意 `ios/Runner.xcodeproj/project.pbxproj` 和 `ios/Runner/Info.plist` 有**属于别的工作的未提交改动**，不要顺手提交。若本次构建也改了它们，用 `git diff` 区分后再决定。）

- [ ] **Step 3: 手动验证（spec §7，在模拟器或真机上跑 app）**

通知（模拟器即可收本地通知）：
1. 设置 → 打开"补货提醒"→ 系统弹授权 → 允许；
2. 库存里加一个"预计 1 天"的物品；把提醒时间设为 2 分钟后；退到后台等 → 到点收到通知，文案是"有 N 件物品需要补货：…"；
3. 把所有库存改充足（或清空库存）→ 到点不响；
4. 关掉"补货提醒"开关 → 到点不响；
5. 拒绝授权路径：删 app 重装（或系统设置里关通知）→ 打开开关 → toast 提示"通知权限未开启"且开关保持关闭。

备份：
6. 设置 → 备份导出 → 分享面板存到"文件"；
7. 随便增删几条数据 → 导入恢复 → 选刚才的文件 → 红字确认框 → 导入 → 数据回到导出时的状态，toast"已恢复备份"；
8. 导入一个随便的 .json（非备份格式）→ toast"文件无效，无法导入"，数据不动；
9. 切到 English → 重复 6-7，界面文案是英文。

- [ ] **Step 4: 手动验证结果记录**

把每条结果（通过/问题）报给用户确认；有问题回到对应任务修。
