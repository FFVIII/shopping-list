# 设计文档：交互式新手教程（替换静态提示条）

日期：2026-07-02
状态：已批准设计，待实施计划

## 1. 目标

刚刚上线的 3 条静态"提示条"（点了关闭就永久消失，不引导具体操作）不够直观。改为一个真正的交互式新手教程：首次安装、数据全空时自动开始，用高亮遮罩+提示气泡引导用户完成一次真实的"添加商品 → 完成购物存入库存 → 查看库存"全流程，教程创建的示例商品是真实数据，教程结束后由用户自己删除。

本设计**完全替换**上一阶段刚实现的 3 条提示条功能（`HintBanner`/`HintStore` 及其接入代码），不再保留。

## 2. 关键决策（已与用户确认）

| 决策 | 选择 |
|---|---|
| 与已有 3 条提示条的关系 | 完全替换，删除 `HintBanner`/`HintStore` 及三处接入代码 |
| 教程形式 | 引导式教练标记（coach mark）：高亮真实按钮/区域，用户自己动手完成每一步真实操作，教程创建真实数据 |
| 触发时机 | 首次安装（数据全空）时自动开始 |
| 教程深度 | 走完"添加到计划清单 → 完成购物存入库存 → 库存页看到该商品"三个逻辑步骤（提醒页只在最后一步用文字提及用途，不实际走） |
| 示例商品 | 固定用一个，商品名"鸡蛋（示例）" / "Egg (example)"，用户一看即知是教程数据 |
| 中途跳过 | 可以跳过，跳过时自动删除已生成的示例数据，教程状态标记为已结束 |
| 中途直接关闭 App（非跳过） | 教程进度持久化，下次打开从中断的步骤继续，已创建的示例数据保留 |
| 实现方式 | 自己写 spotlight 高亮遮罩组件，不引入第三方教程库 |

显式排除（YAGNI）：不做"从设置页重新开始教程"入口、不做多语言中途切换的特殊处理、教程完成后不自动清理示例商品（用户自己删）。

## 3. 真实操作流程（教程要引导用户完成的实际步骤）

现有代码的真实流程比"3 步"更细，教程要按这个真实顺序高亮：

1. **添加商品**：计划清单底部输入框已预填"鸡蛋（示例）"，高亮"+"按钮 → 用户点击 → 弹出添加商品的底部表单（分类/数量/货架码/预计天数）。
2. **确认添加**：高亮表单里的"加入清单"按钮 → 用户选好分类后点击 → 商品被加入 `_shopping`（计划清单）。
3. **完成购物**：高亮清单页头部的"完成购物"胶囊按钮 → 用户点击 → 弹出"完成购物"确认清单表单（商品默认已勾选）。
4. **确认完成购物**：高亮该表单里的"完成购物"确认按钮 → 用户点击 → `_completeTripSmart` 把商品存入 `_inventory`，清空 `_shopping`。
5. **查看库存**：高亮底部导航栏"库存"标签 → 用户点击切换到库存页 → 显示教程收尾提示："以后库存快用完时，「提醒」页会自动提示你补货"，用户点"知道了"结束教程。

## 4. 架构

### 4.1 `TutorialStep`（新枚举，位置待定，如 `lib/services/tutorial_store.dart` 同文件）

```dart
enum TutorialStep {
  addItem,          // 高亮 "+" 按钮
  confirmAddSheet,  // 高亮添加表单里的"加入清单"
  completeTrip,     // 高亮"完成购物"胶囊按钮
  confirmTripSheet, // 高亮完成购物表单里的确认按钮
  viewInventory,    // 高亮底部导航"库存"标签
  done,             // 教程结束/已跳过，不再显示任何东西
}
```

### 4.2 `TutorialStore`（新文件 `lib/services/tutorial_store.dart`）

持久化当前步骤，写法完全比照已有的 `LanguageStore`/（已删除的）`HintStore` 模式，但 `load()` 返回值是**可空**的，用 `null` 表示"从未存过任何值"（区分"全新安装、教程还没开始判定"和"已经判定过、当前就停在 `addItem` 这一步"这两种不同情况，调用方 `_AppShellState._loadData()` 需要这个区分来做 §4.5 的一次性判定）：

```dart
class TutorialStore {
  static const _key = 'tutorial_step';

  /// 返回 null 表示从未存过值（这台设备第一次触发这个判定逻辑）。
  static Future<TutorialStep?> load() async { ... }

  static Future<void> save(TutorialStep step) async { ... }
}
```

注意：这里的语义和已删除的 `HintStore` 不同——`HintStore` 存的是"哪些提示已关闭"的集合，这里存的是"当前该显示哪一步"的单一值，`done` 即代表教程已完成或已跳过。已经完整完成过一次首次安装引导流程的老用户（即那些在本次改动之前就已经装过 app、有真实数据的）不需要看到这个教程——见 §4.5 的"何时启动教程"逻辑。

### 4.3 `TutorialTarget`（新文件 `lib/widgets/tutorial_target.dart`）

```dart
class TutorialTarget extends StatelessWidget {
  final String id;      // 例如 'add_button'
  final Widget child;

  const TutorialTarget({super.key, required this.id, required this.child});

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: TutorialRegistry.keyFor(id), child: child);
  }
}

/// 全局单例：字符串 id → GlobalKey，供 TutorialOverlay 在渲染时查找目标的
/// 屏幕坐标（通过 key.currentContext.findRenderObject()）。
class TutorialRegistry {
  static final Map<String, GlobalKey> _keys = {};
  static GlobalKey keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey());
}
```

需要包一层 `TutorialTarget` 的 5 个位置：
- `list_screen.dart` 添加栏的 "+" 按钮容器（id: `add_button`）
- `list_screen.smart.dart` `_SmartAddSheet` 里的"加入清单"按钮（id: `confirm_add_button`）
- `list_screen.dart` 头部"完成购物"胶囊（id: `complete_trip_button`）
- `list_screen.smart.dart` `_CompleteTripSheet` 里的"完成购物"确认按钮（id: `confirm_trip_button`）
- `main.dart` 底部导航栏"库存"图标（id: `inventory_tab`）

### 4.4 `TutorialOverlay`（新文件 `lib/widgets/tutorial_overlay.dart`）

- 通过 `MaterialApp.builder` 包裹整个 `Navigator`，保证弹出的底部表单（`showModalBottomSheet`）之上依然能显示遮罩（表单本身也是通过根 `Navigator`/`Overlay` 弹出的，`builder` 包裹的位置在其之上）。
- 读取 `_AppShellState` 传下来的当前 `TutorialStep`；`step == done` 时整个 overlay 返回 `child` 本身（无任何遮罩）。
- 非 `done` 时：
  1. 用 `TutorialRegistry.keyFor(idForStep(step))` 拿到目标 `GlobalKey`。
  2. 每帧（`WidgetsBinding.addPostFrameCallback`）用 `key.currentContext?.findRenderObject() as RenderBox?` 计算目标在屏幕上的矩形（`localToGlobal` + `size`）。若目标当前不在树上（比如表单还没弹出），本步骤先不渲染遮罩，等下一帧目标出现后再渲染（轮询式，每帧检查，不需要额外定时器）。
  3. 渲染 4 个不透明矩形色块把目标矩形之外的区域全部盖住（上/下/左/右四条），中间的洞不放任何 widget，用户的点击自然穿透到洞下面的真实按钮。
  4. 在目标附近（视空间在上方还是下方决定气泡朝向）渲染一个提示气泡：文字 + 右上角小号"跳过"文字按钮。

### 4.5 状态管理：`_AppShellState`

- 新增字段 `TutorialStep _tutorialStep = TutorialStep.addItem;`，`_loadData()` 里和 `HintStore.load()`（已删除）同样的位置改为 `await TutorialStore.load()`。
- 新增 `_advanceTutorialIfNeeded()`：在 `_addSmart`、`_completeTripSmart` 这两个已有回调内部，操作完成后检查："本次是否是教程要等的那一步" → 是则 `setState` 推进 `_tutorialStep` 并 `TutorialStore.save()`。
  - `_addSmart`：新商品名是否等于教程商品名 `'鸡蛋（示例）'`（or `en.data` 后的 `'Egg (example)'`）且当前步骤是 `addItem`/`confirmAddSheet` → 推进到 `completeTrip`。
  - `_completeTripSmart`：本次完成购物的商品列表里是否包含该商品名，且当前步骤是 `completeTrip`/`confirmTripSheet` → 推进到 `viewInventory`。
- 新增 `_skipTutorial()`：删除 `_shopping`/`_inventory` 里名字匹配教程商品的所有条目（`setState` 更新 + 对应持久化方法），`_tutorialStep = TutorialStep.done`，`TutorialStore.save(TutorialStep.done)`。
- 新增 `_finishTutorial()`（库存页"知道了"按钮触发）：仅 `_tutorialStep = TutorialStep.done` + 持久化，不删除任何数据（真实数据保留）。
- 检测"用户手动删除了教程商品"：`_deleteSmartItem`/`_deleteInventoryItem` 里追加一个判断——如果删除的商品名等于教程商品名且教程未结束，直接 `_tutorialStep = TutorialStep.done`（悄悄结束，不提示）。
- 何时真正启动教程（避免"清空后重装的老用户"被误判成新手来强行弹教程）：这个判断只在 `TutorialStore` **从未存过值**（即 `SharedPreferences` 里完全没有 `tutorial_step` 这个 key，`load()` 内部能区分"没存过"和"存的就是 addItem"）的那一次 `_loadData()` 里做一次性判定：
  - 若此时 `_shopping`/`_inventory`/`_budget` 三者不是全空 → 说明这是一个在本功能上线前就已经有真实数据的老用户，直接把 `_tutorialStep` 设为 `done` 并立即持久化，教程永不显示。
  - 若三者全空 → 真正的全新安装，`_tutorialStep` 保持 `addItem`，正常持久化，开始显示教程。
  - 这个判定只发生这一次；此后不管 `_shopping`/`_inventory` 里有没有教程商品（教程进行中本来就会让 `_shopping` 非空），一律直接使用持久化的 `_tutorialStep` 继续渲染 overlay，不再重复检查"是否全空"。

### 4.6 l10n

新增字符串（`lib/l10n/app_strings.dart`，`AppStrings`/`ZhStrings`/`EnStrings` 各一份）：

| getter | zh | en |
|---|---|---|
| `tutorialExampleItemName` | 鸡蛋（示例） | Egg (example) |
| `tutorialStepAddItem` | 点击 + 把示例商品加入清单 | Tap + to add the example item to your list |
| `tutorialStepConfirmAdd` | 选好分类后，点击「加入清单」 | Pick a category, then tap "Add to list" |
| `tutorialStepCompleteTrip` | 买完了？点这里完成本次购物 | Done shopping? Tap here to finish |
| `tutorialStepConfirmTrip` | 确认后商品会自动存入库存 | Confirm to save it into inventory |
| `tutorialStepViewInventory` | 去库存看看刚刚买的东西吧 | Check your inventory for what you just bought |
| `tutorialFinalMessage` | 以后库存快用完时，「提醒」页会自动提示你补货 | When stock runs low, the Alerts tab will remind you to restock |
| `tutorialGotIt` | 知道了 | Got it |
| `tutorialSkip` | 跳过 | Skip |

## 5. 需要删除的文件/代码（替换旧提示条功能）

- 删除 `lib/services/hint_store.dart`、`test/services/hint_store_test.dart`
- 删除 `lib/widgets/hint_banner.dart`
- `lib/l10n/app_strings.dart`：删除 `inventoryHint`/`reminderHint`（`smartHint` 保留——不再被 UI 使用，但暂不清理无关的既有字符串，避免范围蔓延；若之后发现完全无引用可另行清理）
- `lib/main.dart`：删除 `_dismissedHints`/`_dismissHint`/`HintStore` 相关代码及三处构造参数传递
- `lib/screens/list_screen.dart`/`inventory_screen.dart`/`reminder_screen.dart`：删除 `dismissedHints`/`onDismissHint` 构造参数、`HintBanner` 渲染点、相关 import

## 6. 测试

- `test/services/tutorial_store_test.dart`（新增）：`TutorialStore.load()`/`save()` 往返测试，仿照已删除的 `hint_store_test.dart` 结构（mock `shared_preferences`）。
- 步骤推进的纯逻辑测试：给定 `_shopping`/`_inventory` 的前后状态和商品名，验证下一步计算是否正确（可以把推进逻辑抽成一个不依赖 `BuildContext` 的纯函数，例如 `nextTutorialStep(TutorialStep current, {required bool addedExampleItem, required bool completedExampleTrip})`，`_AppShellState` 调用它，测试直接测这个纯函数）。
- Widget 测试：pump 全空数据的 app，确认首帧后"+"按钮附近出现教程气泡；不强求覆盖完整 5 步点击（模拟底部表单弹出+定位遮罩在 widget test 里较脆弱），完整流程验证放到手动模拟器验证。
- 手动模拟器验证：全新安装 → 依次完成 5 次点击 → 确认气泡文案、遮罩位置、最终"知道了"收尾文案都正确；跳过按钮在不同步骤点击都能正确清理数据；教程进行到一半直接杀掉 App 进程，重新打开确认从同一步骤继续，且气泡指向的还是正确的目标（如果杀在一个 sheet 打开的中间，sheet 会话本身不会保留，重新打开后应停留在"打开该 sheet 之前"的步骤，重新引导用户点击那个入口按钮）。

## 7. 错误处理

- 与现有持久化策略一致：`TutorialStore.save()` 失败仅 `debugPrint` 记录，不重试、不打扰用户（教程 overlay 在内存里的 `_tutorialStep` 仍然正确前进，只是下次冷启动可能会重新从头开始——可接受的降级）。
- 找不到目标 `GlobalKey`（比如目标还没渲染出来，或者用户已经跳到了别的 tab 导致目标临时不在树上）：`TutorialOverlay` 本帧不渲染任何遮罩内容，静默跳过，等目标出现再渲染，不抛异常、不崩溃。
