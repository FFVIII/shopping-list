# 设计文档：Budget 消费历史（Pro 专属）

日期：2026-07-13
状态：已批准设计，待实施计划
分支：仅 `dev`（Pro 专属功能，不进 `release-free`）

## 1. 背景

Budget 模式清空（`_confirmClearBudget`）会把当次记的账全部硬删除，没有留痕，用户无法回头查"上个月/这周花了多少钱、买了什么"。本设计给 Pro 用户加一个只读为主的消费历史：每次批量清空 Budget 列表时，把这次的商品明细和总额存一份快照，之后可以在设置页里查看、按需单条删除。

## 2. 关键决策（已与用户确认）

| 决策 | 选择 |
|---|---|
| 归属 | 仅 `dev` 分支，Pro 专属功能，跟 `PurchaseService.isPro` 挂钩，不进 `release-free` |
| 记录触发点 | 只有点批量 "Clear" 清空 Budget 列表时生成一条记录；单个商品的滑动删除不算 |
| 记录内容 | 每条记录 = 清空时间戳 + 当次商品快照（名称/数量/单价）+ 总金额 |
| 记录管理 | 可单条删除某次历史记录（删除前弹确认框），历史本身不能整体清空/编辑 |
| 展示 | 设置页新增入口 → 独立页面；顶部显示"本月共花 ¥xxx"汇总；下方按时间倒序列表，每条可展开看明细 |
| 备份/恢复 | 历史数据随现有备份导出/导入整体走（复用 `AppRepository.replaceAll`） |

显式排除（YAGNI）：跨月/跨年统计图表、按分类汇总、编辑历史记录内容、历史记录数量上限与自动清理、导出历史为单独文件。

## 3. 数据模型与存储

新增 `BudgetHistoryEntry`（`lib/models/item.dart`，紧邻 `BudgetItem`）：

```dart
class BudgetHistoryEntry {
  final String id;
  final DateTime clearedAt;
  final List<BudgetHistoryLineItem> items; // 快照，不再关联原 BudgetItem
  double get totalAmount => items.fold(0, (sum, i) => sum + i.lineTotal);
}

class BudgetHistoryLineItem {
  final String name;
  final int quantity;
  final double unitPrice;
  double get lineTotal => quantity * unitPrice;
}
```

存储沿用现有 Hive 模式（`lib/storage/hive_models.dart` 里 `BudgetItemHiveX`/`budgetItemFromMap` 的写法）：

- `lib/storage/hive_models.dart`：新增 `budgetHistoryEntryToMap`/`budgetHistoryEntryFromMap`。
- `lib/storage/app_repository.dart`：新增 `late Box _historyBox;`，在 `init()` 里以 `shopping_history`（或类似名）开 box；新增 `saveHistory(List<BudgetHistoryEntry>)`；`load()` 里读出并放进 `AppData`；`AppData` 构造加 `budgetHistory` 字段；`replaceAll()` 一并覆盖，确保备份/导入恢复覆盖到历史数据。

## 4. 状态与写入路径

`lib/state/shopping_list_notifier.dart`（`ShoppingListNotifier`）新增：

- `List<BudgetHistoryEntry> budgetHistory`（初始化时从 `AppData` 载入）
- `recordBudgetPurchase(List<BudgetItem> snapshot)`：若 `snapshot` 为空则直接返回（防御性判断，正常路径不会触发）；否则构造一条 `BudgetHistoryEntry`，插到 `budgetHistory` 头部，`notifyListeners()`，异步 `_repo.saveHistory(budgetHistory)`
- `deleteBudgetHistoryEntry(String id)`：从列表移除对应 id，`notifyListeners()`，异步持久化

`lib/screens/list_screen.dart` 的 `_confirmClearBudget()`：确认对话框返回 `true` 后，先调用 `widget.onRecordBudgetPurchase(widget.budgetItems)`，再调用原有的 `widget.onBatchDeleteBudget(...)`。`onRecordBudgetPurchase` 作为新的必需回调，从 `ListScreen` 构造函数一路穿到 `main.dart`，绑定到上面的 notifier 方法（跟 `onBatchDeleteBudget` 现有接线方式一致）。

## 5. UI

### 5.1 设置页入口

`lib/screens/settings_screen.dart` 里现有 `if (widget.purchaseService.isPro) [...]` 区块（约第 125 行，跟其他 Pro 专属设置项同一个门禁）内新增一行：

```dart
_navRow(l.spendingHistory, onTap: _openSpendingHistory),
```

`_openSpendingHistory()` 沿用 `_openShelfOrder`/`_openCategoryManage` 的写法，`Navigator.push` 到新页面，把 `budgetHistory` 数据和 `onDeleteBudgetHistoryEntry` 回调从 `main.dart` 一路传下来（跟 `categories`/`shelfZones` 现在的传法一致）。

### 5.2 `SpendingHistoryScreen`（新文件 `lib/screens/spending_history_screen.dart`）

- 顶部汇总条：过滤出 `clearedAt` 在当前自然月内的记录，求和显示"本月共花 ¥xxx"；本月无记录则显示 ¥0 而非隐藏（避免布局跳动）。
- 下方 `ListView`，`budgetHistory` 已按插入顺序（最新在前）展示，每行：日期（本地化格式）+ 该条 `totalAmount` + 展开箭头。
- 点击展开（`ExpansionTile` 或类似）显示该条 `items` 明细：名称 × 数量 @ 单价。
- 每行提供删除入口（滑动删除或行内图标），点击后弹确认对话框（复用 `clearBudget` 确认框的视觉风格：标题+消息+取消/删除两个按钮），确认后调用 `onDeleteBudgetHistoryEntry(entry.id)`。
- 空状态：无任何历史记录时显示居中的空状态提示文案（复用现有空状态组件风格）。

## 6. l10n

新增字符串（中英对照，放入 `lib/l10n/app_strings.dart`）：`spendingHistory`（设置页入口/页面标题）、`spendingHistoryMonthTotal(amount)`、`spendingHistoryEmpty`、`deleteHistoryEntryTitle`/`deleteHistoryEntryMessage`。

## 7. 测试

- Repository：`saveHistory`/`load` 往返测试，`replaceAll` 覆盖历史数据的测试。
- Notifier：`recordBudgetPurchase` 生成正确的记录和总额；传入空列表不生成记录；`deleteBudgetHistoryEntry` 精确移除对应记录且不影响其他记录。
- Widget（`SpendingHistoryScreen`）：渲染记录列表；展开显示明细；本月汇总金额计算正确；删除确认流程（取消不删、确认后从列表消失）；空状态展示。
- Widget（`SettingsScreen`）：非 Pro 时入口不可见，Pro 时可见并能跳转。

## 8. 与免费版分支的关系

按既定约定（`release-free`/`dev` 需同步免费功能），本功能是纯 Pro 付费点，仅存在于 `dev`，不需要、也不应该同步到 `release-free`。
