# 设计文档：真实补货通知（iOS）+ 备份导出/导入恢复

日期：2026-07-02
状态：已批准设计，待实施计划

## 1. 目标

两个独立但都属于"把已有承诺兑现"的功能：

1. **补货通知**：设置页已有"补货提醒"开关和提醒时间（`AppSettings.restockReminderEnabled` / `reminderHour` / `reminderMinute`），但目前没有任何通知依赖，设了也不会响。本设计接入 iOS 本地通知，让"每天 HH:mm 提醒补货"真正生效。
2. **备份导出/导入**：设置页"数据"分组里已有"备份导出"和"导入恢复"两行（`lib/screens/settings_screen.dart` `_buildSection(l.sectionData, ...)`），目前是死的。本设计让用户能把全部数据导出为 JSON 文件、并从 JSON 文件整体恢复。

## 2. 关键决策（已与用户确认）

| 决策 | 选择 |
|---|---|
| 通知策略 | **有需要才提醒**：到点只有存在"快没/用完"物品时才发通知，库存充足时保持安静 |
| 通知实现机制 | **确定性预排**（方案 A）：库存消耗纯粹由 `purchasedAt + estimatedDays` 决定，可提前算出未来每天的低库存集合；每次数据变化时取消全部待发通知并重排未来 14 天 |
| 平台范围 | 先只做 iOS；Android 配置（通知渠道、exact alarm 权限）留到以后 |
| 导入策略 | **完全覆盖**：导入前弹确认框警告"将替换当前全部数据"，确认后用备份整体替换 |
| 备份格式 | 单个 JSON 文件，复用 `lib/storage/hive_models.dart` 现有 `toMap`/`fromMap`（输出已全部是 JSON 安全的基本类型） |

显式排除（YAGNI）：Android 通知配置、BGTaskScheduler 后台计算、自动定期备份、iCloud 同步、导入合并模式、通知点击跳转特定页面。

## 3. 新依赖

- `flutter_local_notifications` + `timezone`（zonedSchedule 必需）
- `share_plus`（导出走系统分享面板）
- `file_picker`（导入选文件）
- `path_provider`（导出前写临时文件）

## 4. 补货通知（iOS）

### 4.1 为什么是"确定性预排"

iOS 本地通知是预约制，到点响铃时不运行 app 代码，无法现场判断"今天有没有东西快用完"。但本 app 的库存状态是纯函数：`daysRemaining = estimatedDays - (now - purchasedAt).inDays`，且数据只在 app 内变化。所以可以在每次数据变化时用纯 Dart 预算未来 14 天、每天提醒时刻的低库存物品清单，只给有内容的那些天预约通知。iOS 允许 64 条待发本地通知，14 条绰绰有余。

备选方案 BGTaskScheduler（后台唤醒现算）被排除：iOS 后台任务调度不可靠、复杂度高一个量级；固定每日重复通知被排除：无法做到"没东西快用完就不响"。

### 4.2 `lib/services/notification_service.dart`（新文件）

```dart
class NotificationService {
  Future<void> init();                 // 初始化插件 + 时区（启动时调用一次）
  Future<bool> requestPermission();    // 请求 iOS 授权，返回是否同意
  Future<void> reschedule({
    required List<InventoryItem> inventory,
    required AppSettings settings,
    required AppStrings strings,
  });
}
```

`reschedule` 逻辑：
1. `cancelAll()`；
2. 若 `settings.restockReminderEnabled == false` 或未授权，直接返回；
3. 对未来 14 天的每一天 d（含今天，但仅当今天的提醒时刻还没过）：算出该天提醒时刻会处于"快没/用完"（复用 `statusFor(settings.reminderThresholdDays)` 的投影版本）的物品；
4. 集合非空的天，用 `zonedSchedule` 预约一条通知，文案形如"有 3 件物品需要补货：牛奶、鸡蛋、大米"（最多列 3 个名字，超出加"等"；中英文走现有 `AppStrings`，新增 2 条字符串）。

**可测性**：第 3 步抽成纯函数 `List<InventoryItem> lowStockOn(DateTime day, List<InventoryItem> inventory, int thresholdDays)`（放在 service 文件里的顶层函数），单测覆盖。

### 4.3 接入点（`lib/main.dart`）

- `_persistInventory()` 和 `_persistSettings()` 是所有库存/设置变化的汇聚点，在这两处顺带调用 `reschedule()`；
- app 启动 `_loadData()` 完成后也调一次（防止用户很久没打开、14 天预排已耗尽）；
- 通知服务实例在 `main()` 里创建并传入（与 `AppRepository` 同样的注入方式）。

### 4.4 权限时机

- 设置页打开"补货提醒"开关时调用 `requestPermission()`；被拒则开关弹回 off 并 toast 提示去系统设置开启；
- 启动时若开关已开，只静默检查授权状态（不弹系统弹窗），有权限就正常预排。

### 4.5 iOS 平台配置

- `ios/Runner/AppDelegate.swift`：设置 `UNUserNotificationCenter.current().delegate`，让通知在 app 前台时也能显示；
- 不需要改 `Info.plist`（本地通知无需声明权限描述）。

## 5. 备份导出 / 导入恢复

### 5.1 `lib/storage/backup.dart`（新文件）

```dart
String encodeBackup(AppData data);        // → JSON 字符串
AppData decodeBackup(String json, ...);   // 校验失败抛 FormatException
```

JSON 结构：

```json
{
  "format": "shopping_list_backup",
  "version": 1,
  "exportedAt": "2026-07-02T18:00:00",
  "categories": [...],
  "shoppingSimple": [...],
  "shoppingSmart": [...],
  "inventory": [...],
  "budget": [...],
  "settings": {...},
  "shelfZones": [...],
  "shelfCodeOrder": [...]
}
```

八个数据段全部复用 `hive_models.dart` 的 `toMap`/`fromMap`。解码顺序：先 categories，再用它解析 shopping/inventory（现有 `fromMap` 已带 categoryId → Category 的回接和 fallback 兜底）。校验：`format` 字段必须匹配、`version` 必须 ≤ 当前支持版本、缺段或类型不对抛 `FormatException`。

### 5.2 导出流程（设置页"备份导出"）

1. 用当前内存状态组装 `AppData` → `encodeBackup`；
2. 写入临时目录文件 `shopping_list_backup_2026-07-02.json`（`path_provider`）；
3. 弹系统分享面板（`share_plus`），用户可存到"文件"、AirDrop、发微信等。

### 5.3 导入流程（设置页"导入恢复"）

1. `file_picker` 选文件（限 .json）；
2. 读取 + `decodeBackup`；解析失败 → 弹"文件无效"提示，结束；
3. 成功 → 弹确认框，红字警告"将覆盖当前全部数据，此操作不可撤销"；
4. 确认 → `AppRepository.replaceAll(AppData)`（新方法，内部挨个调用已有的 8 个 save）→ 刷新 `_AppShellState` 内存状态 → `reschedule()` 通知。

### 5.4 UI 接线

设置页两行 `_navRow(l.backupExport)` / `_navRow(l.importRestore)` 补上 `onTap`。导出/导入的回调按现有模式由 `_AppShellState` 下发（数据和 repository 都在那里）。

## 6. 错误处理

- 通知：授权被拒 → 开关弹回 + 提示；预排本身失败（理论罕见）→ `debugPrint`，不打扰用户（与持久化写失败同一策略，见 2026-06-30 spec §5）。
- 导出：写临时文件或分享面板失败 → toast 提示导出失败。
- 导入：任何解析/校验失败 → "文件无效"提示，现有数据不动；只有全部校验通过后才落盘，不存在半成品状态。

## 7. 测试

- **单测**：
  - `backup.dart`：encode → decode 往返一致；坏输入（非 JSON、format 不对、version 过高、缺字段）抛 `FormatException` 且不产生部分结果；
  - `lowStockOn(...)`：边界——当天刚好等于阈值、`estimatedDays = 0`、已用完的物品、未来某天才变低的物品、空库存。
- **手动验证**（真机/模拟器）：
  1. 开开关 → 系统弹授权 → 允许后加一个 1 天后用完的库存 → 把提醒时间设到几分钟后 → 收到通知，文案正确；
  2. 库存全部充足时到点不响；关掉开关后到点不响；
  3. 导出 → 分享面板存到"文件"→ 改乱 app 数据 → 导入该文件 → 数据完整恢复；
  4. 导入一个随便的非备份 .json → 提示文件无效，数据不动。
