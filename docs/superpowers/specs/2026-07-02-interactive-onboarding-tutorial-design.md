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

### 4.0 架构调整说明（相对早期草案的修正）

写实施计划前逐行核对真实代码后，发现两个早期草案没考虑到的约束，做了如下调整：

1. **遮罩必须挂在 `MaterialApp.builder` 上，而不是 `_AppShellState.build()` 内部**——`showModalBottomSheet` 弹出的表单是作为新路由插入到 `Navigator` 的 `Overlay` 里的，会盖在 `_AppShellState` 返回的整个 `Scaffold` 之上。只有包在 `MaterialApp(builder: ...)` 这一层（在 `_ShoppingListAppState` 里，`Navigator` 外面）的内容，才能保证在弹出的表单之上还能看到遮罩。但教程状态目前设计是在 `_AppShellState` 里维护，`_ShoppingListAppState` 拿不到——为避免把状态硬提到另一个 State 或做大量参数穿透，改成一个**单例 `ChangeNotifier`**（`TutorialController.instance`），`_ShoppingListAppState`（渲染遮罩）和 `_AppShellState`（真实数据变化时推进步骤）各自直接引用同一个单例，不需要互相持有对方的引用。
2. **合并冗余步骤**——原来的"高亮某按钮"和"高亮同一个操作在弹出表单里的确认按钮"其实是同一个逻辑步骤的两个不同"当前应该高亮谁"的候选目标，不需要单独的步骤枚举值区分。改为每个步骤对应一个**候选目标 id 列表**（按优先级排列），遮罩渲染时依次尝试，用第一个已经挂载在树上的目标——这样"表单还没弹出"和"表单已经弹出"这两种情况自然地用同一个步骤覆盖，不需要额外的步骤转换。

### 4.1 `TutorialStep`（新枚举，`lib/services/tutorial_store.dart`）

```dart
enum TutorialStep {
  addItem,       // 高亮 add_button，若 confirm_add_button 已挂载则优先高亮它
  completeTrip,  // 高亮 complete_trip_button，若 confirm_trip_button 已挂载则优先高亮它
  viewInventory, // 高亮 inventory_tab
  finalMessage,  // 无高亮目标，居中显示收尾文案 + "知道了"
  done,          // 教程结束/已跳过，不渲染任何东西
}
```

### 4.2 `TutorialStore`（新文件 `lib/services/tutorial_store.dart`）

持久化当前步骤，写法比照已有的 `LanguageStore` 模式，但 `load()` 返回值是**可空**的，用 `null` 表示"从未存过任何值"（用来区分"全新安装、还没做过一次性判定"和"已经判定过、当前就停在 `addItem` 这一步"）：

```dart
class TutorialStore {
  static const _key = 'tutorial_step';

  /// 返回 null 表示从未存过值（这台设备第一次触发这个判定逻辑）。
  static Future<TutorialStep?> load() async { ... }

  static Future<void> save(TutorialStep step) async { ... }
}
```

### 4.3 `TutorialController`（新文件 `lib/services/tutorial_controller.dart`，单例 `ChangeNotifier`）

```dart
class TutorialController extends ChangeNotifier {
  TutorialController._();
  static final TutorialController instance = TutorialController._();

  TutorialStep step = TutorialStep.done; // 数据加载完成前的安全默认值：不显示

  /// 由 _AppShellState 在 initState 里赋值，供 overlay 的"跳过"按钮调用，
  /// 用来清理真实数据（overlay 本身不持有 _shopping/_inventory）。
  VoidCallback? onSkipRequested;

  static const exampleItemNameZh = '鸡蛋（示例）';
  static const exampleItemNameEn = 'Egg (example)';

  bool isExampleItemName(String name) =>
      name == exampleItemNameZh || name == exampleItemNameEn;

  /// _AppShellState._loadData() 加载完数据后调用一次。
  Future<void> resolveInitialStep({required bool dataIsEmpty}) async {
    final stored = await TutorialStore.load();
    if (stored != null) {
      step = stored;
    } else {
      step = dataIsEmpty ? TutorialStep.addItem : TutorialStep.done;
      unawaited(TutorialStore.save(step));
    }
    notifyListeners();
  }

  void _setStep(TutorialStep s) {
    if (step == s) return;
    step = s;
    notifyListeners();
    unawaited(TutorialStore.save(s)
        .catchError((e) => debugPrint('tutorial save failed: $e')));
  }

  void onItemAdded(String name) {
    if (step == TutorialStep.addItem && isExampleItemName(name)) {
      _setStep(TutorialStep.completeTrip);
    }
  }

  void onTripCompleted(Iterable<String> purchasedNames) {
    if (step == TutorialStep.completeTrip &&
        purchasedNames.any(isExampleItemName)) {
      _setStep(TutorialStep.viewInventory);
    }
  }

  void onTabChanged(int tabIndex) {
    if (step == TutorialStep.viewInventory && tabIndex == 1 /* Inventory */) {
      _setStep(TutorialStep.finalMessage);
    }
  }

  /// 用户手动删掉了示例商品（教程未结束时）：悄悄结束，不提示。
  void onItemDeleted(String name) {
    if (step != TutorialStep.done && isExampleItemName(name)) {
      _setStep(TutorialStep.done);
    }
  }

  /// "知道了"按钮：正常结束，不清理数据。
  void finish() => _setStep(TutorialStep.done);

  /// "跳过"按钮：先清理数据，再结束。
  void skip() {
    onSkipRequested?.call();
    _setStep(TutorialStep.done);
  }
}
```

### 4.4 `TutorialTarget`（新文件 `lib/widgets/tutorial_target.dart`）

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

/// 全局注册表：字符串 id → GlobalKey，供 TutorialOverlay 查找目标的屏幕坐标。
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

### 4.5 `TutorialOverlay`（新文件 `lib/widgets/tutorial_overlay.dart`）

- 在 `_ShoppingListAppState.build()` 里通过 `MaterialApp(builder: (context, child) => TutorialOverlay(child: child!))` 包裹（`child` 是 `Navigator` 渲染出的内容，包含所有弹出的表单），确保遮罩始终盖在最上层。
- 内部用 `AnimatedBuilder`/手动 `addListener` 监听 `TutorialController.instance`，读取 `.step`。`step == done` 时直接返回 `child`，不做任何多余渲染。
- 每个非 `done`/`finalMessage` 步骤对应一个**候选目标 id 列表**（按优先级）：
  - `addItem` → `['confirm_add_button', 'add_button']`
  - `completeTrip` → `['confirm_trip_button', 'complete_trip_button']`
  - `viewInventory` → `['inventory_tab']`
- 每帧（`SchedulerBinding.instance.addPostFrameCallback`，只要 overlay 处于非 `done` 状态就持续重新调度下一帧）依次用 `TutorialRegistry.keyFor(id).currentContext?.findRenderObject() as RenderBox?` 检查候选列表里第一个已挂载的目标，用 `localToGlobal` + `size` 算出它的屏幕矩形。一个都没挂载（比如表单还没弹出）则本帧不渲染任何高亮内容，只显示原本的 `child`，静默等下一帧。
- 找到矩形后：渲染 4 个不透明矩形色块把目标矩形之外的区域盖住（上/下/左/右四条），中间的洞不放任何 widget，用户的点击自然穿透到洞下面的真实按钮；在目标附近渲染一个提示气泡（文字 + 右上角"跳过"按钮，调用 `TutorialController.instance.skip()`）。
- `finalMessage` 步骤：不找目标，直接在屏幕中央渲染一个卡片：收尾文案 + "知道了"按钮（调用 `TutorialController.instance.finish()`），背景用同样的不透明色块整体盖住（此时没有"洞"，因为不需要用户操作底层任何真实控件）。

### 4.6 状态管理：`_AppShellState`

`_AppShellState` 不需要新增任何 field 来存教程步骤（步骤存在 `TutorialController.instance` 单例里，overlay 直接监听它）。只需要在既有回调里补一行调用：

- `initState()`：`TutorialController.instance.onSkipRequested = _skipTutorial;`
- `_loadData()`：数据 setState 完成后，`await TutorialController.instance.resolveInitialStep(dataIsEmpty: data.shoppingSmart.isEmpty && data.inventory.isEmpty && data.budget.isEmpty);`（用刚加载出来的 `data`，而不是重新读 `_shopping` 等 state 字段，二者此时应一致，但直接用局部变量更直接）。
- `_addSmart(...)`：在已有逻辑跑完之后，追加 `TutorialController.instance.onItemAdded(name);`。
- `_completeTripSmart(selectedIds)`：需要知道本次完成购物、真正被写入库存的商品名单——在函数体内收集 `for` 循环里 `item.name`（`selectedSet.contains(item.id)` 为真的那些），循环结束后调用 `TutorialController.instance.onTripCompleted(purchasedNames);`。
- `_deleteSmartItem(id)`/`_deleteInventoryItem(id)`：删除前找到该 id 对应的 `name`，删除后调用 `TutorialController.instance.onItemDeleted(name);`（找不到该 id 就不调用）。
- 底部导航 `onTap: (i) => setState(() => _tab = i)` 追加 `TutorialController.instance.onTabChanged(i);`。
- 新增 `_skipTutorial()`：从 `_shopping`/`_inventory` 里删除商品名匹配 `TutorialController.instance.isExampleItemName` 的条目（`setState` + 对应持久化方法），不需要再手动设置步骤——`TutorialController.skip()` 自己会调 `onSkipRequested` 后再置 `done`。

### 4.7 教程内容页面的两处配合改动

- `list_screen.dart` 的 `_ListScreenState`：add-bar 的 `TextField`（`_nameCtrl`）需要在 `didChangeDependencies()` 里，若 `TutorialController.instance.step == TutorialStep.addItem` 且文本框当前为空且尚未预填过（一个 `bool _tutorialPrefilled` 标记，防止用户清空后被重新填回去），把文本设为 `L10n.of(context).tutorialExampleItemName`。
- `_SmartAddSheetState`（`list_screen.smart.dart`）：不需要特殊改动——分类默认已经是 `widget.categories.first`，用户不需要额外选择就能点"加入清单"。

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

- `test/services/tutorial_store_test.dart`（新增）：`TutorialStore.load()`/`save()` 往返测试，仿照已删除的 `hint_store_test.dart` 结构（mock `shared_preferences`），另外验证"从未存过值"时返回 `null`（区别于存了 `TutorialStep.addItem` 时返回该值本身）。
- `test/services/tutorial_controller_test.dart`（新增）：`TutorialController` 不依赖 `BuildContext`，可以直接实例化/操作单例测试：
  - `resolveInitialStep(dataIsEmpty: true)` 在从未存过值时 → `step == addItem`。
  - `resolveInitialStep(dataIsEmpty: false)` 在从未存过值时 → `step == done`（老用户不显示教程）。
  - 依次调用 `onItemAdded`/`onTripCompleted`/`onTabChanged`/`finish()`，验证 `step` 按 `addItem → completeTrip → viewInventory → finalMessage → done` 正确推进，且传入不匹配教程商品名的调用不会误推进。
  - `skip()` 调用 `onSkipRequested` 且最终 `step == done`。
  - 每个测试开始前需重置单例状态（`TutorialController.instance.step = TutorialStep.done;` 或提供一个仅测试用的 reset，视实现方便而定）。
- Widget 测试：pump 全空数据的 app，确认首帧后"+"按钮附近出现教程气泡；不强求覆盖完整 5 步点击（模拟底部表单弹出+定位遮罩在 widget test 里较脆弱），完整流程验证放到手动模拟器验证。
- 手动模拟器验证：全新安装 → 依次完成 5 次点击 → 确认气泡文案、遮罩位置、最终"知道了"收尾文案都正确；跳过按钮在不同步骤点击都能正确清理数据；教程进行到一半直接杀掉 App 进程，重新打开确认从同一步骤继续，且气泡指向的还是正确的目标（如果杀在一个 sheet 打开的中间，sheet 会话本身不会保留，重新打开后应停留在"打开该 sheet 之前"的步骤，重新引导用户点击那个入口按钮）。

## 7. 错误处理

- 与现有持久化策略一致：`TutorialStore.save()` 失败仅 `debugPrint` 记录，不重试、不打扰用户（`TutorialController.instance.step` 在内存里仍然正确前进，只是下次冷启动可能会重新从头开始——可接受的降级）。
- 找不到目标 `GlobalKey`（比如目标还没渲染出来，或者用户已经跳到了别的 tab 导致目标临时不在树上）：`TutorialOverlay` 本帧不渲染任何遮罩内容，静默跳过，等目标出现再渲染，不抛异常、不崩溃。
