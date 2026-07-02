# 设计文档：清空种子演示数据 + 三条永久关闭的教程提示条

日期：2026-07-02
状态：已批准设计，待实施计划

## 1. 目标

首次安装时，app 会种入一批演示商品（香蕉、牛奶、大米……）到清单/库存/记账里，让新用户打开就看到一堆跟自己无关的假数据。改为首次安装时这三块数据全部为空，只保留必需的默认分类结构。为弥补"一片空白不知道怎么用"的问题，在计划清单、库存、提醒三个页面各加一条可永久关闭的说明提示条（简单清单、记账模式、设置页因为足够直观，不加提示条，避免一上来信息过载）。

## 2. 关键决策（已与用户确认）

| 决策 | 选择 |
|---|---|
| 默认分类（果蔬/乳制品/肉类/粮油/日用品/其他 6 个） | **保留**——是必需的结构性配置，不是演示数据（代码里多处假设至少有"其他"兜底分类，删光会导致相关逻辑报错） |
| 清单（简单+计划）/库存/记账 | 首次安装**全部清空**为空列表 |
| 提示条覆盖范围 | 只加 3 条：计划清单、库存、提醒。简单清单、记账、设置页不加 |
| 提示条关闭的持久性 | **永久关闭**，写入本地存储（`shared_preferences`），包括把现有"计划清单"提示条从"仅本次会话内关闭"改成"永久关闭" |

显式排除（YAGNI）：不做首次启动全屏引导轮播、不给简单/记账模式加提示条、不做"重新显示所有提示"的设置项。

## 3. 清空种子数据

### 3.1 改动点

- `lib/storage/app_repository.dart` 的 `_seedInitialData()`：分类照常经由 `buildDefaultCategories()` 生成并保存；`_shoppingSmartBox`/`_inventoryBox`/`_budgetBox` 改成保存空列表 `<Map>[]`，不再调用 `buildSampleShopping`/`buildSampleInventory`/`buildSampleBudget`。
- `lib/main.dart` 的 `_AppShellState._buildFallbackData()`（Hive 初始化失败时的内存兜底路径）做同样改动，保持两条路径行为一致：分类走 `buildDefaultCategories()`，`shoppingSmart`/`inventory`/`budget` 都是空列表。

### 3.2 不动的部分

- `buildSampleShopping`/`buildSampleInventory`/`buildSampleBudget`（`lib/models/item.dart`）三个函数**保留不删**——测试文件（`test/models/item_test.dart` 的 `applyPurchase`/`reassignCategoryToFallback` 用例）还在用它们构造测试数据，仍是有价值的测试夹具（fixture）构造函数，只是不再被种子逻辑调用。
- `test/storage/app_repository_test.dart` 现有断言"首次安装有示例数据"（`shoppingSmart`/`inventory`/`budget` 均 `isNotEmpty`）需要改成断言这三个集合 `isEmpty`，同时保留"分类不为空"的断言。

## 4. 提示条机制

### 4.1 为什么需要新组件

现有"计划清单"页已经有一条提示（`_buildSmartHint()`/`smartHint` 字符串），但它是 `list_screen.dart` 内部的私有 widget（`_ListScreenState` 的一个方法），且关闭状态只是一个没有持久化的内存 `bool`（`_smartHintDismissed`），重启 app 就会重新出现。库存页（`inventory_screen.dart`）和提醒页（`reminder_screen.dart`）是另外两个独立的 Dart library，无法直接复用这个私有 widget。因此需要：

1. 一个**跨文件可复用**的公共提示条组件。
2. 一个**真正持久化**的"已关闭提示条"记录机制。

### 4.2 `lib/widgets/hint_banner.dart`（新文件）

```dart
class HintBanner extends StatelessWidget {
  final String text;
  final VoidCallback onDismiss;
  const HintBanner({super.key, required this.text, required this.onDismiss});
}
```

样式完全复用现有"计划清单"提示条的外观：浅品牌绿背景圆角容器、左侧灯泡图标、文字（12号字，行高1.4）、右侧可点击的关闭 X。这是纯展示组件，不关心持久化。

### 4.3 `lib/services/hint_store.dart`（新文件）

参照现有 `lib/l10n/language_store.dart` 的写法（同样基于 `shared_preferences`，本项目已有此依赖）：

```dart
class HintStore {
  static const _key = 'dismissed_hints';

  /// 已被用户永久关闭的提示条 id 集合。
  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  /// 保存完整的已关闭 id 集合（调用方传入包含新 id 的完整集合）。
  static Future<void> save(Set<String> dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, dismissed.toList());
  }
}
```

### 4.4 状态管理：`_AppShellState`（main.dart）

- 新增字段 `Set<String> _dismissedHints = {}`。
- 在现有的 `_loadData()` 异步加载流程里一并调用 `HintStore.load()`，随其他数据一起 `setState` 赋值（不阻塞、不增加新的 loading 状态，复用已有的一次性异步加载时机）。
- 新增方法：
  ```dart
  void _dismissHint(String id) {
    final updated = {..._dismissedHints, id};
    setState(() => _dismissedHints = updated);
    unawaited(HintStore.save(updated).catchError((e) => debugPrint('save dismissedHints failed: $e')));
  }
  ```
  错误处理策略与现有其他持久化保持一致（写失败仅记录日志，不打扰用户，见 spec 2026-06-30 §5）。
- 把 `dismissedHints: _dismissedHints` 和 `onDismissHint: _dismissHint` 传给 `ListScreen`、`InventoryScreen`、`ReminderScreen` 三个构造函数（各自新增这两个必填参数）。

### 4.5 三个提示条的接入

每个页面持有 `dismissedHints`/`onDismissHint` 后，用固定字符串 id 判断是否显示：

- **计划清单**（`list_screen.dart`）：现有位置是 `if (_isSmart) _buildSmartSubToggle()`（按货架/按分类切换）之后、`Expanded(...)` 列表内容之前（`if (_isSmart && !_smartHintDismissed) _buildSmartHint()`，约第 287 行）。删除 `_smartHintDismissed` 字段和 `_buildSmartHint()` 方法，原位置改为：
  ```dart
  if (_isSmart && !widget.dismissedHints.contains('smart_hint'))
    HintBanner(text: l.smartHint, onDismiss: () => widget.onDismissHint('smart_hint')),
  ```
  文案沿用现有 `l.smartHint`（"圆圈选中=将存入库存；点「完成购物」完成本次采购。"），不改文字，只改关闭的持久性。

- **库存**（`inventory_screen.dart`）：现有结构是 `if (!_batchMode) _buildSortToggle()` 之后、`Expanded(...)` 列表内容之前（约第 227-229 行）。在同一位置插入：
  ```dart
  if (!widget.dismissedHints.contains('inventory_hint'))
    HintBanner(text: l.inventoryHint, onDismiss: () => widget.onDismissHint('inventory_hint')),
  ```
  新增字符串 `l.inventoryHint`：
  - zh：`购买后的商品会自动出现在这里；快用完时会在「提醒」里提示补货。`
  - en：`Purchased items land here automatically; low stock shows up under Alerts.`

- **提醒**（`reminder_screen.dart`）：现有结构是 `_buildHeader(context)` 之后直接是 `Expanded(...)` 列表内容（约第 79-80 行，没有排序栏）。在两者之间插入：
  ```dart
  if (!widget.dismissedHints.contains('reminder_hint'))
    HintBanner(text: l.reminderHint, onDismiss: () => widget.onDismissHint('reminder_hint')),
  ```
  新增字符串 `l.reminderHint`：
  - zh：`库存快用完或已到期的商品会出现在这里，点「加入」放进购物清单。`
  - en：`Items running low or out show up here — tap Add to put them back on your list.`

简单清单、记账模式、设置页均不接入。

## 5. 测试

- `test/storage/app_repository_test.dart`：更新首次安装断言为"分类不为空，清单/库存/记账均为空"。
- `test/services/hint_store_test.dart`（新增）：`HintStore.load()`/`save()` 的往返测试。项目里没有现成的 `LanguageStore` 测试可参照（`test/l10n/app_language_test.dart` 只测纯函数 `resolveLang`），因此采用 Flutter 标准做法：测试开头 `SharedPreferences.setMockInitialValues({})` 模拟本地存储，断言：①未保存过时 `load()` 返回空集合；②`save({'a', 'b'})` 后 `load()` 能读到同样的两个 id；③`save()` 两次（先存 `{'a'}` 再存 `{'a','b'}`）后最终 `load()` 反映的是最后一次传入的完整集合（因为 `save` 语义是"整体覆盖"，不是增量合并——合并逻辑在调用方 `_dismissHint` 里完成）。
- 手动验证：全新安装 → 清单/库存/记账三个 tab 都是空的，分类选择器仍有 6 个默认分类可选；计划清单/库存/提醒三个页面顶部各出现一条提示；点击每条的关闭按钮后消失；完全重启 app 后三条都不再出现（验证真正持久化）。

## 6. 错误处理

与现有持久化策略一致：`HintStore.save()` 失败仅 `debugPrint` 记录，不影响用户当前操作、不重试、不弹提示。
