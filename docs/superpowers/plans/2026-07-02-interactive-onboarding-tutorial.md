# 交互式新手教程 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除上一阶段的静态提示条功能，改为一个真正交互的新手教程：首次安装、数据全空时自动开始，高亮真实按钮引导用户完成"添加示例商品 → 完成购物存入库存 → 查看库存"全流程，教程创建的是真实数据，用户自己删除。

**Architecture:** 单例 `TutorialController`（`ChangeNotifier`）维护当前 `TutorialStep`，持久化于 `TutorialStore`（仿照 `LanguageStore`）。`TutorialOverlay` 挂在 `MaterialApp.builder`（`Navigator` 外层，能盖住弹出的表单）上，监听单例、每帧轮询 `TutorialTarget` 注册的真实按钮位置，画四条不透明色块盖住目标之外的区域（中间留洞，真实点击穿透），配一个提示气泡。`_AppShellState` 在既有的数据变更回调里追加对单例方法的调用来推进步骤，不需要新增自己的 state 字段。

**Tech Stack:** Flutter/Dart，`shared_preferences`（已是现有依赖，无需新增）。

环境须知：
```
FLUTTER="/Users/ffviii/Computer Science | Coding/Flutter/flutter/bin/flutter"
cd "/Users/ffviii/Computer Science | Coding/Flutter/projects/shopping_list"
```
每次 commit 只 `git add` 本任务明确列出的文件，不要用 `git add -A`/`git add .`。

Spec: `docs/superpowers/specs/2026-07-02-interactive-onboarding-tutorial-design.md`

---

## 文件结构

| 文件 | 动作 | 职责 |
|---|---|---|
| `lib/services/hint_store.dart` | 删 | 上一阶段的提示条持久化，本次功能完全替换 |
| `test/services/hint_store_test.dart` | 删 | 对应测试 |
| `lib/widgets/hint_banner.dart` | 删 | 上一阶段的提示条展示组件 |
| `lib/services/tutorial_store.dart` | 建 | `TutorialStep` 枚举 + 持久化当前步骤 |
| `test/services/tutorial_store_test.dart` | 建 | 上面的往返测试 |
| `lib/services/tutorial_controller.dart` | 建 | 单例 `ChangeNotifier`，驱动步骤推进/跳过/结束 |
| `test/services/tutorial_controller_test.dart` | 建 | 纯逻辑测试，不依赖 BuildContext |
| `lib/widgets/tutorial_target.dart` | 建 | 给真实按钮注册可查找坐标的 id |
| `lib/widgets/tutorial_overlay.dart` | 建 | 高亮遮罩 + 提示气泡 + 收尾卡片 |
| `lib/l10n/app_strings.dart` | 改 | 删除 `inventoryHint`/`reminderHint`，新增 9 条教程字符串 |
| `lib/main.dart` | 改 | 删除提示条接线；新增 `MaterialApp.builder`、`_AppShellState` 各回调里的单例调用、底部导航 tab 切换回调、`_skipTutorial()` |
| `lib/main.widgets.dart` | 改 | 库存 tab 图标包一层 `TutorialTarget` |
| `lib/screens/list_screen.dart` | 改 | 删除提示条接线；新增 "+"/"完成购物" 按钮的 `TutorialTarget`；add-bar 预填示例商品名 |
| `lib/screens/list_screen.smart.dart` | 改 | 两个表单确认按钮包一层 `TutorialTarget` |
| `lib/screens/inventory_screen.dart` | 改 | 删除提示条接线 |
| `lib/screens/reminder_screen.dart` | 改 | 删除提示条接线 |

---

### Task 1: 删除上一阶段的提示条功能

**Files:**
- Delete: `lib/services/hint_store.dart`
- Delete: `test/services/hint_store_test.dart`
- Delete: `lib/widgets/hint_banner.dart`
- Modify: `lib/l10n/app_strings.dart`
- Modify: `lib/main.dart`
- Modify: `lib/screens/list_screen.dart`
- Modify: `lib/screens/inventory_screen.dart`
- Modify: `lib/screens/reminder_screen.dart`

- [ ] **Step 1: 删除文件**

```bash
rm lib/services/hint_store.dart test/services/hint_store_test.dart lib/widgets/hint_banner.dart
```

- [ ] **Step 2: `lib/l10n/app_strings.dart` —— 删除 `inventoryHint`/`reminderHint`**

抽象类里删除这一行（当前在 `addToInventoryBtn` 之后）：
```dart
  String get inventoryHint; // inventory-tab explanation banner
```
以及这一行（当前在 `reminderEmptySubtitle` 之后）：
```dart
  String get reminderHint; // reminder-tab explanation banner
```

`ZhStrings` 里删除：
```dart
  @override String get inventoryHint =>
      '购买后的商品会自动出现在这里；快用完时会在「提醒」里提示补货。';
```
和：
```dart
  @override String get reminderHint =>
      '库存快用完或已到期的商品会出现在这里，点「加入」放进购物清单。';
```

`EnStrings` 里删除：
```dart
  @override String get inventoryHint =>
      'Purchased items land here automatically; low stock shows up under Alerts.';
```
和：
```dart
  @override String get reminderHint =>
      'Items running low or out show up here — tap Add to put them back on your list.';
```

（`smartHint` 保留不动——教程文案不复用它，但它是已有 public getter，删除不在本任务范围内，避免打包无关改动。）

- [ ] **Step 3: `lib/main.dart` —— 删除提示条相关代码**

删除这一行 import：
```dart
import 'services/hint_store.dart';
```

删除这个字段（在 `late bool _storageUnavailable = widget.storageInitFailed;` 之后）：
```dart
  Set<String> _dismissedHints = {};
```

`_loadData()` 里删除这一行：
```dart
    final dismissedHints = await HintStore.load();
```
和 `setState` 块里的这一行：
```dart
      _dismissedHints = dismissedHints;
```

删除整个方法（包括它的分节注释）：
```dart
  // ── 提示条：永久关闭 ──────────────────────────────────────────────────────

  void _dismissHint(String id) {
    final updated = {..._dismissedHints, id};
    setState(() => _dismissedHints = updated);
    unawaited(HintStore.save(updated)
        .catchError((e) => debugPrint('save dismissedHints failed: $e')));
  }
```

`build()` 方法里，三处构造调用各删除两行 `dismissedHints:`/`onDismissHint:`（分别在 `ListScreen(`、`InventoryScreen(`、`ReminderScreen(` 构造里，每处形如）：
```dart
                    dismissedHints: _dismissedHints,
                    onDismissHint: _dismissHint,
```

- [ ] **Step 4: `lib/screens/list_screen.dart` —— 删除提示条相关代码**

删除这一行 import：
```dart
import '../widgets/hint_banner.dart';
```

删除这两个字段（在 `final int smartModeRequest;` 之后）：
```dart
  final Set<String> dismissedHints;
  final void Function(String id) onDismissHint;
```

构造函数里删除这两行（在 `required this.shelfCodeOrder,` 之后）：
```dart
    required this.dismissedHints,
    required this.onDismissHint,
```

`build()` 里删除这一段渲染（在 `if (_isBudget && _budgetBatchMode) _buildBudgetBatchSubBar(),` 之后，`const SizedBox(height: 4),` 之前）：
```dart
            if (_isSmart && !widget.dismissedHints.contains('smart_hint'))
              HintBanner(
                text: L10n.of(context).smartHint,
                onDismiss: () => widget.onDismissHint('smart_hint'),
              ),
```

- [ ] **Step 5: `lib/screens/inventory_screen.dart` —— 删除提示条相关代码**

删除这一行 import：
```dart
import '../widgets/hint_banner.dart';
```

删除这两个字段（在 `final void Function(List<InventoryItem> items) onBatchAddToRestock;` 之后）：
```dart
  final Set<String> dismissedHints;
  final void Function(String id) onDismissHint;
```

构造函数里删除这两行（在 `required this.onBatchAddToRestock,` 之后）：
```dart
    required this.dismissedHints,
    required this.onDismissHint,
```

`build()` 里删除这一段渲染（在 `if (!_batchMode) _buildSortToggle(),` 之后，`const SizedBox(height: 4),` 之前）：
```dart
            if (!widget.dismissedHints.contains('inventory_hint'))
              HintBanner(
                text: L10n.of(context).inventoryHint,
                onDismiss: () => widget.onDismissHint('inventory_hint'),
              ),
```

- [ ] **Step 6: `lib/screens/reminder_screen.dart` —— 删除提示条相关代码**

删除这一行 import：
```dart
import '../widgets/hint_banner.dart';
```

删除这两个字段（在 `final Set<String> activeListNames;` 之后）：
```dart
  final Set<String> dismissedHints;
  final void Function(String id) onDismissHint;
```

构造函数里删除这两行（在 `required this.activeListNames,` 之后）：
```dart
    required this.dismissedHints,
    required this.onDismissHint,
```

`build()` 里删除这一段渲染（在 `_buildHeader(context),` 之后，`Expanded(` 之前）：
```dart
            if (!dismissedHints.contains('reminder_hint'))
              HintBanner(
                text: L10n.of(context).reminderHint,
                onDismiss: () => onDismissHint('reminder_hint'),
              ),
```

- [ ] **Step 7: 验证**

```bash
"$FLUTTER" analyze
```
预期：出现多个"缺少必填参数"之类的报错（因为 `main.dart` 里三处构造调用暂时还没跟着改完，编译会失败——这是正常的，本任务只负责删除，Task 2-9 会陆续补上新教程的接线）。**这一步不要求 `flutter analyze` 干净**，只需要确认报错都是"预期内的缺参数"而不是别的意外错误（比如拼写错误、找不到文件）。

- [ ] **Step 8: Commit**

```bash
git add lib/services/hint_store.dart test/services/hint_store_test.dart lib/widgets/hint_banner.dart lib/l10n/app_strings.dart lib/main.dart lib/screens/list_screen.dart lib/screens/inventory_screen.dart lib/screens/reminder_screen.dart
git commit -m "refactor: remove static hint banners, replaced by interactive tutorial"
```

（这一步会产生一个暂时无法编译的中间状态提交，符合"删除功能 → 新增替代功能"两步走的计划节奏，Task 9 结束后代码会恢复可编译、可测试。）

---

### Task 2: `TutorialStore` + `TutorialStep`（TDD）

**Files:**
- Create: `lib/services/tutorial_store.dart`
- Create: `test/services/tutorial_store_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/services/tutorial_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load() returns null when nothing has been saved', () async {
    expect(await TutorialStore.load(), isNull);
  });

  test('save() then load() round-trips the same step', () async {
    await TutorialStore.save(TutorialStep.completeTrip);
    expect(await TutorialStore.load(), TutorialStep.completeTrip);
  });

  test('save() overwrites the previous step', () async {
    await TutorialStore.save(TutorialStep.addItem);
    await TutorialStore.save(TutorialStep.done);
    expect(await TutorialStore.load(), TutorialStep.done);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$FLUTTER" test test/services/tutorial_store_test.dart
```
Expected: FAIL —— 找不到 `shopping_list/services/tutorial_store.dart`。

- [ ] **Step 3: 实现**

创建 `lib/services/tutorial_store.dart`：

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Steps of the first-run interactive onboarding tutorial. See design spec
/// docs/superpowers/specs/2026-07-02-interactive-onboarding-tutorial-design.md.
enum TutorialStep {
  addItem,
  completeTrip,
  viewInventory,
  finalMessage,
  done,
}

/// Persists which [TutorialStep] the onboarding tutorial is currently on.
/// Mirrors the pattern in `l10n/language_store.dart`.
class TutorialStore {
  static const _key = 'tutorial_step';

  /// Returns null if nothing has ever been saved (first time this check
  /// runs on this device) — distinct from having explicitly saved
  /// [TutorialStep.addItem].
  static Future<TutorialStep?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key);
    if (index == null) return null;
    return TutorialStep.values[index];
  }

  static Future<void> save(TutorialStep step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, step.index);
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
"$FLUTTER" test test/services/tutorial_store_test.dart
```
Expected: `All tests passed!`（3 个）

- [ ] **Step 5: Commit**

```bash
git add lib/services/tutorial_store.dart test/services/tutorial_store_test.dart
git commit -m "feat: add TutorialStep enum and TutorialStore persistence"
```

---

### Task 3: `TutorialController`（单例，纯逻辑测试）

**Files:**
- Create: `lib/services/tutorial_controller.dart`
- Create: `test/services/tutorial_controller_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/services/tutorial_controller.dart';
import 'package:shopping_list/services/tutorial_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TutorialController.instance.step = TutorialStep.done;
    TutorialController.instance.onSkipRequested = null;
  });

  test('resolveInitialStep starts at addItem for a fresh, empty install',
      () async {
    await TutorialController.instance.resolveInitialStep(dataIsEmpty: true);
    expect(TutorialController.instance.step, TutorialStep.addItem);
  });

  test('resolveInitialStep marks done for an existing user with real data',
      () async {
    await TutorialController.instance.resolveInitialStep(dataIsEmpty: false);
    expect(TutorialController.instance.step, TutorialStep.done);
  });

  test('resolveInitialStep resumes a persisted in-progress step', () async {
    await TutorialStore.save(TutorialStep.completeTrip);
    await TutorialController.instance.resolveInitialStep(dataIsEmpty: true);
    expect(TutorialController.instance.step, TutorialStep.completeTrip);
  });

  test(
      'onItemAdded advances addItem -> completeTrip only for the example item',
      () async {
    TutorialController.instance.step = TutorialStep.addItem;
    TutorialController.instance.onItemAdded('香蕉');
    expect(TutorialController.instance.step, TutorialStep.addItem);
    TutorialController.instance
        .onItemAdded(TutorialController.exampleItemNameZh);
    expect(TutorialController.instance.step, TutorialStep.completeTrip);
  });

  test('onTripCompleted advances completeTrip -> viewInventory', () async {
    TutorialController.instance.step = TutorialStep.completeTrip;
    TutorialController.instance.onTripCompleted(['某其他商品']);
    expect(TutorialController.instance.step, TutorialStep.completeTrip);
    TutorialController.instance
        .onTripCompleted([TutorialController.exampleItemNameZh]);
    expect(TutorialController.instance.step, TutorialStep.viewInventory);
  });

  test('onTabChanged advances viewInventory -> finalMessage only for tab 1',
      () async {
    TutorialController.instance.step = TutorialStep.viewInventory;
    TutorialController.instance.onTabChanged(0);
    expect(TutorialController.instance.step, TutorialStep.viewInventory);
    TutorialController.instance.onTabChanged(1);
    expect(TutorialController.instance.step, TutorialStep.finalMessage);
  });

  test('finish() moves straight to done', () async {
    TutorialController.instance.step = TutorialStep.finalMessage;
    TutorialController.instance.finish();
    expect(TutorialController.instance.step, TutorialStep.done);
  });

  test('skip() calls onSkipRequested and moves to done', () async {
    var called = false;
    TutorialController.instance.step = TutorialStep.addItem;
    TutorialController.instance.onSkipRequested = () => called = true;
    TutorialController.instance.skip();
    expect(called, isTrue);
    expect(TutorialController.instance.step, TutorialStep.done);
  });

  test(
      'onItemDeleted silently ends the tutorial if the example item is removed',
      () async {
    TutorialController.instance.step = TutorialStep.completeTrip;
    TutorialController.instance.onItemDeleted('某其他商品');
    expect(TutorialController.instance.step, TutorialStep.completeTrip);
    TutorialController.instance
        .onItemDeleted(TutorialController.exampleItemNameZh);
    expect(TutorialController.instance.step, TutorialStep.done);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
"$FLUTTER" test test/services/tutorial_controller_test.dart
```
Expected: FAIL —— 找不到 `shopping_list/services/tutorial_controller.dart`。

- [ ] **Step 3: 实现**

创建 `lib/services/tutorial_controller.dart`：

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'tutorial_store.dart';

/// Drives the first-run interactive onboarding tutorial. A singleton so both
/// `_ShoppingListAppState` (renders the spotlight overlay above the
/// Navigator) and `_AppShellState` (owns the real shopping/inventory data
/// whose mutations advance the tutorial) can react to the same state
/// without threading it through widget constructors.
class TutorialController extends ChangeNotifier {
  TutorialController._();
  static final TutorialController instance = TutorialController._();

  /// Safe default before the real value is loaded: don't show anything.
  TutorialStep step = TutorialStep.done;

  /// Set by `_AppShellState.initState()`. The overlay's "skip" button calls
  /// this so the owner of the real data can clean up the example item; the
  /// overlay itself never touches shopping/inventory state directly.
  VoidCallback? onSkipRequested;

  static const exampleItemNameZh = '鸡蛋（示例）';
  static const exampleItemNameEn = 'Egg (example)';

  bool isExampleItemName(String name) =>
      name == exampleItemNameZh || name == exampleItemNameEn;

  /// Called once after `_AppShellState._loadData()` finishes loading.
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
    if (step == TutorialStep.viewInventory && tabIndex == 1) {
      _setStep(TutorialStep.finalMessage);
    }
  }

  /// User manually deleted the example item before finishing: end silently.
  void onItemDeleted(String name) {
    if (step != TutorialStep.done && isExampleItemName(name)) {
      _setStep(TutorialStep.done);
    }
  }

  /// "Got it" button: normal completion, doesn't touch any data.
  void finish() => _setStep(TutorialStep.done);

  /// "Skip" button: clean up first, then end.
  void skip() {
    onSkipRequested?.call();
    _setStep(TutorialStep.done);
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
"$FLUTTER" test test/services/tutorial_controller_test.dart
```
Expected: `All tests passed!`（9 个）

- [ ] **Step 5: Commit**

```bash
git add lib/services/tutorial_controller.dart test/services/tutorial_controller_test.dart
git commit -m "feat: add TutorialController singleton driving tutorial step advancement"
```

---

### Task 4: `TutorialTarget` / `TutorialRegistry`

**Files:**
- Create: `lib/widgets/tutorial_target.dart`

- [ ] **Step 1: 实现**

```dart
import 'package:flutter/widgets.dart';

/// Wraps a real widget so [TutorialOverlay] can look up its on-screen
/// position by a stable string [id], without the wrapped widget needing to
/// know anything about the tutorial.
class TutorialTarget extends StatelessWidget {
  final String id;
  final Widget child;

  const TutorialTarget({super.key, required this.id, required this.child});

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: TutorialRegistry.keyFor(id), child: child);
  }
}

/// Global id -> GlobalKey registry backing [TutorialTarget].
class TutorialRegistry {
  TutorialRegistry._();
  static final Map<String, GlobalKey> _keys = {};

  static GlobalKey keyFor(String id) =>
      _keys.putIfAbsent(id, () => GlobalKey());
}
```

- [ ] **Step 2: 验证**

```bash
"$FLUTTER" analyze lib/widgets/tutorial_target.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/tutorial_target.dart
git commit -m "feat: add TutorialTarget/TutorialRegistry for locating real widgets"
```

---

### Task 5: l10n 教程字符串

**Files:**
- Modify: `lib/l10n/app_strings.dart`

- [ ] **Step 1: 抽象类**

在 `abstract class AppStrings` 结尾（`String get scale2Week;` 之后，闭合 `}` 之前）插入：

```dart

  // ── Onboarding tutorial ──
  String get tutorialExampleItemName; // 固定示例商品名
  String get tutorialStepAddItem;
  String get tutorialStepCompleteTrip;
  String get tutorialStepViewInventory;
  String get tutorialFinalMessage;
  String get tutorialGotIt;
  String get tutorialSkip;
```

- [ ] **Step 2: `ZhStrings`**

在 `ZhStrings` 结尾（`@override String data(String canonical) => canonical; // zh is canonical` 之后，闭合 `}` 之前）插入：

```dart

  @override String get tutorialExampleItemName => '鸡蛋（示例）';
  @override String get tutorialStepAddItem => '点击 + 把示例商品加入清单';
  @override String get tutorialStepCompleteTrip => '买完了？点这里完成本次购物';
  @override String get tutorialStepViewInventory => '去库存看看刚刚买的东西吧';
  @override String get tutorialFinalMessage =>
      '以后库存快用完时，「提醒」页会自动提示你补货';
  @override String get tutorialGotIt => '知道了';
  @override String get tutorialSkip => '跳过';
```

- [ ] **Step 3: `EnStrings`**

在 `EnStrings` 结尾（`@override String data(String canonical) => _enData[canonical] ?? canonical;` 之后，闭合 `}` 之前）插入：

```dart

  @override String get tutorialExampleItemName => 'Egg (example)';
  @override String get tutorialStepAddItem => 'Tap + to add the example item to your list';
  @override String get tutorialStepCompleteTrip => 'Done shopping? Tap here to finish';
  @override String get tutorialStepViewInventory => 'Check your inventory for what you just bought';
  @override String get tutorialFinalMessage =>
      'When stock runs low, the Alerts tab will remind you to restock';
  @override String get tutorialGotIt => 'Got it';
  @override String get tutorialSkip => 'Skip';
```

- [ ] **Step 4: 验证**

```bash
"$FLUTTER" analyze lib/l10n/app_strings.dart
```
Expected: `No issues found!`（漏掉任何一个 override 都会因为 `AppStrings` 是 abstract class 而编译失败）

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart
git commit -m "feat: add onboarding tutorial l10n strings"
```

---

### Task 6: `TutorialOverlay` 高亮遮罩组件

**Files:**
- Create: `lib/widgets/tutorial_overlay.dart`

- [ ] **Step 1: 实现**

```dart
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/tutorial_controller.dart';
import '../services/tutorial_store.dart';
import '../theme/app_colors.dart';
import 'tutorial_target.dart';

/// Renders the coach-mark spotlight for the first-run onboarding tutorial.
/// Wraps the app's Navigator output via `MaterialApp.builder` so the overlay
/// stays on top of modal bottom sheets, which are pushed as routes on that
/// same Navigator.
class TutorialOverlay extends StatefulWidget {
  final Widget child;
  const TutorialOverlay({super.key, required this.child});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  static const Map<TutorialStep, List<String>> _candidateIds = {
    TutorialStep.addItem: ['confirm_add_button', 'add_button'],
    TutorialStep.completeTrip: ['confirm_trip_button', 'complete_trip_button'],
    TutorialStep.viewInventory: ['inventory_tab'],
  };

  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    TutorialController.instance.addListener(_onControllerChanged);
    _scheduleFrameCheck();
  }

  @override
  void dispose() {
    TutorialController.instance.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleFrameCheck();
  }

  void _scheduleFrameCheck() {
    if (TutorialController.instance.step == TutorialStep.done) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rect = _findTargetRect();
      if (rect != _targetRect) {
        setState(() => _targetRect = rect);
      }
      _scheduleFrameCheck();
    });
  }

  Rect? _findTargetRect() {
    final ids = _candidateIds[TutorialController.instance.step];
    if (ids == null) return null;
    for (final id in ids) {
      final renderObject =
          TutorialRegistry.keyFor(id).currentContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.attached) {
        final topLeft = renderObject.localToGlobal(Offset.zero);
        return topLeft & renderObject.size;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final step = TutorialController.instance.step;
    if (step == TutorialStep.done) return widget.child;

    final l = L10n.of(context);

    if (step == TutorialStep.finalMessage) {
      return Stack(children: [
        widget.child,
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
            child: Center(
              child: _TutorialCard(
                text: l.tutorialFinalMessage,
                buttonLabel: l.tutorialGotIt,
                onPressed: TutorialController.instance.finish,
              ),
            ),
          ),
        ),
      ]);
    }

    final rect = _targetRect;
    if (rect == null) return widget.child;

    final size = MediaQuery.of(context).size;
    final tooltipBelow = rect.top < size.height / 2;
    final stepText = switch (step) {
      TutorialStep.addItem => l.tutorialStepAddItem,
      TutorialStep.completeTrip => l.tutorialStepCompleteTrip,
      TutorialStep.viewInventory => l.tutorialStepViewInventory,
      _ => '',
    };
    const barColor = Colors.black54;

    return Stack(children: [
      widget.child,
      // Four opaque bars around the target rect: they intercept taps so
      // only the hole in the middle (the real widget underneath) is
      // reachable, while everything else is dimmed and blocked.
      Positioned(
        left: 0,
        top: 0,
        right: 0,
        height: rect.top,
        child: Container(color: barColor),
      ),
      Positioned(
        left: 0,
        top: rect.bottom,
        right: 0,
        bottom: 0,
        child: Container(color: barColor),
      ),
      Positioned(
        left: 0,
        top: rect.top,
        width: rect.left,
        height: rect.height,
        child: Container(color: barColor),
      ),
      Positioned(
        left: rect.right,
        top: rect.top,
        right: 0,
        height: rect.height,
        child: Container(color: barColor),
      ),
      Positioned(
        left: 16,
        right: 16,
        top: tooltipBelow ? rect.bottom + 12 : null,
        bottom: tooltipBelow ? null : size.height - rect.top + 12,
        child: _TutorialBubble(
          text: stepText,
          skipLabel: l.tutorialSkip,
          onSkip: TutorialController.instance.skip,
        ),
      ),
    ]);
  }
}

class _TutorialBubble extends StatelessWidget {
  final String text;
  final String skipLabel;
  final VoidCallback onSkip;

  const _TutorialBubble({
    required this.text,
    required this.skipLabel,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSkip,
              behavior: HitTestBehavior.opaque,
              child: Text(
                skipLabel,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialCard extends StatelessWidget {
  final String text;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _TutorialCard({
    required this.text,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15, height: 1.5, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: onPressed,
              child: Text(
                buttonLabel,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 验证**

```bash
"$FLUTTER" analyze lib/widgets/tutorial_overlay.dart
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/tutorial_overlay.dart
git commit -m "feat: add TutorialOverlay spotlight rendering"
```

---

### Task 7: 接入 `MaterialApp.builder` + `_AppShellState` 回调

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 新增 import**

在 `import 'l10n/language_store.dart';` 之后（原 `import 'services/hint_store.dart';` 已在 Task 1 删除）插入：
```dart
import 'services/tutorial_controller.dart';
import 'widgets/tutorial_overlay.dart';
```

- [ ] **Step 2: `MaterialApp` 加 `builder`**

`_ShoppingListAppState.build()` 里的 `MaterialApp(...)` 构造，当前在 `dialogTheme: const DialogThemeData(backgroundColor: Colors.white),` 之后紧接 `),` 然后是 `home: AppShell(`。改成在 `theme:` 块结束、`home:` 开始之前插入 `builder`：

```dart
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.brand,
            primary: AppColors.brand,
            surface: AppColors.scaffoldBg,
          ),
          scaffoldBackgroundColor: AppColors.scaffoldBg,
          dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
        ),
        builder: (context, child) => TutorialOverlay(child: child!),
        home: AppShell(
```

- [ ] **Step 3: `_AppShellState.initState()`**

当前：
```dart
  @override
  void initState() {
    super.initState();
    _loadData();
  }
```
改为：
```dart
  @override
  void initState() {
    super.initState();
    TutorialController.instance.onSkipRequested = _skipTutorial;
    _loadData();
  }
```

- [ ] **Step 4: `_loadData()` 接入 `resolveInitialStep`**

当前（Task 1 删除 `HintStore`/`_dismissedHints` 相关两行之后）：
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
      if (loadFailed) _storageUnavailable = true;
    });
    // Top up the 14-day pre-scheduled window in case the app hasn't been
    // opened for a while (spec §4.3).
    _rescheduleNotifications();
  }
```
改为在 `setState` 之后、`_rescheduleNotifications()` 之前插入一行：
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
      if (loadFailed) _storageUnavailable = true;
    });
    await TutorialController.instance.resolveInitialStep(
      dataIsEmpty: data.shoppingSmart.isEmpty &&
          data.inventory.isEmpty &&
          data.budget.isEmpty,
    );
    // Top up the 14-day pre-scheduled window in case the app hasn't been
    // opened for a while (spec §4.3).
    _rescheduleNotifications();
  }
```

- [ ] **Step 5: `_addSmart` 推进步骤**

当前：
```dart
  void _addSmart(String name, String quantityLabel, String? shelfCode, int estimatedDays, Category category, String shelfZone) {
    setState(() {
      _shopping.add(ShoppingItem(
        id: generateId('u'),
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
改为在 `_persistShoppingSmart();` 之后追加一行：
```dart
  void _addSmart(String name, String quantityLabel, String? shelfCode, int estimatedDays, Category category, String shelfZone) {
    setState(() {
      _shopping.add(ShoppingItem(
        id: generateId('u'),
        name: name,
        category: category,
        quantityLabel: quantityLabel.isEmpty ? '1件' : quantityLabel,
        shelfZone: shelfZone,
        shelfCode: shelfCode,
        estimatedDays: estimatedDays,
      ));
    });
    _persistShoppingSmart();
    TutorialController.instance.onItemAdded(name);
  }
```

- [ ] **Step 6: `_completeTripSmart` 推进步骤**

当前：
```dart
  void _completeTripSmart(List<String> selectedIds) {
    final selectedSet = selectedIds.toSet();
    setState(() {
      // Work on a mutable copy so new entries are visible to subsequent lookups
      var inv = List<InventoryItem>.from(_inventory);
      for (final item in _shopping) {
        if (!selectedSet.contains(item.id)) continue;
        inv = applyPurchase(
          inventory: inv,
          item: item,
          estimatedDays: item.estimatedDays ?? item.category.defaultDays,
          newId: generateId('inv'),
          now: DateTime.now(),
        );
      }
      _inventory = inv;
      _shopping.clear();
    });
    _persistInventory();
    _persistShoppingSmart();
  }
```
改为：
```dart
  void _completeTripSmart(List<String> selectedIds) {
    final selectedSet = selectedIds.toSet();
    final purchasedNames = _shopping
        .where((item) => selectedSet.contains(item.id))
        .map((item) => item.name)
        .toList();
    setState(() {
      // Work on a mutable copy so new entries are visible to subsequent lookups
      var inv = List<InventoryItem>.from(_inventory);
      for (final item in _shopping) {
        if (!selectedSet.contains(item.id)) continue;
        inv = applyPurchase(
          inventory: inv,
          item: item,
          estimatedDays: item.estimatedDays ?? item.category.defaultDays,
          newId: generateId('inv'),
          now: DateTime.now(),
        );
      }
      _inventory = inv;
      _shopping.clear();
    });
    _persistInventory();
    _persistShoppingSmart();
    TutorialController.instance.onTripCompleted(purchasedNames);
  }
```
（`purchasedNames` 必须在 `setState` 清空 `_shopping` **之前**收集，顺序很重要。）

- [ ] **Step 7: `_deleteSmartItem` / `_deleteInventoryItem` 检测手动删除示例商品**

当前：
```dart
  void _deleteSmartItem(String id) {
    setState(() => _shopping.removeWhere((i) => i.id == id));
    _persistShoppingSmart();
  }
```
改为：
```dart
  void _deleteSmartItem(String id) {
    final idx = _shopping.indexWhere((i) => i.id == id);
    final name = idx == -1 ? null : _shopping[idx].name;
    setState(() => _shopping.removeWhere((i) => i.id == id));
    _persistShoppingSmart();
    if (name != null) TutorialController.instance.onItemDeleted(name);
  }
```

当前：
```dart
  void _deleteInventoryItem(String id) {
    setState(() => _inventory = _inventory.where((i) => i.id != id).toList());
    _persistInventory();
  }
```
改为：
```dart
  void _deleteInventoryItem(String id) {
    final idx = _inventory.indexWhere((i) => i.id == id);
    final name = idx == -1 ? null : _inventory[idx].name;
    setState(() => _inventory = _inventory.where((i) => i.id != id).toList());
    _persistInventory();
    if (name != null) TutorialController.instance.onItemDeleted(name);
  }
```

- [ ] **Step 8: 底部导航 tab 切换推进步骤**

当前：
```dart
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        reminderBadge: reminderCount,
      ),
```
改为：
```dart
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        onTap: (i) {
          setState(() => _tab = i);
          TutorialController.instance.onTabChanged(i);
        },
        reminderBadge: reminderCount,
      ),
```

- [ ] **Step 9: 新增 `_skipTutorial()`**

在 `_persistShelfCodeOrder()` 方法之后（Task 1 已删除的 `_dismissHint` 原来所在位置）插入：
```dart
  // ── 教程：跳过时清理示例数据 ────────────────────────────────────────────────

  void _skipTutorial() {
    setState(() {
      _shopping = _shopping
          .where((i) => !TutorialController.instance.isExampleItemName(i.name))
          .toList();
      _inventory = _inventory
          .where((i) => !TutorialController.instance.isExampleItemName(i.name))
          .toList();
    });
    _persistShoppingSmart();
    _persistInventory();
  }
```

- [ ] **Step 10: 验证**

```bash
"$FLUTTER" analyze
```
预期：`lib/main.dart` 不再报错；`ListScreen`/`InventoryScreen`/`ReminderScreen` 三处构造调用因为 Task 1 已经删掉了多余参数，此时应该已经不报错了（因为这三个 Widget 类本身在 Task 1 也删掉了这两个字段）。如果还有报错，检查是不是 Task 1 的删除没有做干净。

- [ ] **Step 11: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire TutorialController into AppShell data callbacks and MaterialApp"
```

---

### Task 8: 真实按钮包一层 `TutorialTarget`

**Files:**
- Modify: `lib/screens/list_screen.dart`
- Modify: `lib/screens/list_screen.smart.dart`
- Modify: `lib/main.widgets.dart`

- [ ] **Step 1: `list_screen.dart` —— import**

在 `import '../widgets/toast.dart';` 之后（原 `import '../widgets/hint_banner.dart';` 已在 Task 1 删除）插入：
```dart
import '../widgets/tutorial_target.dart';
```

- [ ] **Step 2: `list_screen.dart` —— "+" 按钮**

当前（`_buildAddBar` 方法内）：
```dart
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _submitAdd(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
```
改为：
```dart
          const SizedBox(width: 10),
          TutorialTarget(
            id: 'add_button',
            child: GestureDetector(
              onTap: () => _submitAdd(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ),
```

- [ ] **Step 3: `list_screen.dart` —— "完成购物" 头部按钮**

当前：
```dart
          if ((_isSmart && widget.smartItems.isNotEmpty) ||
              (!_isSmart && !_isBudget && widget.simpleItems.isNotEmpty))
            GestureDetector(
              onTap: _confirmCompleteTrip,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l.completeTrip,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else if (_isBudget && widget.budgetItems.isNotEmpty)
```
改为（只包住 `if` 分支这一个 `GestureDetector`，`else if` 分支不动）：
```dart
          if ((_isSmart && widget.smartItems.isNotEmpty) ||
              (!_isSmart && !_isBudget && widget.simpleItems.isNotEmpty))
            TutorialTarget(
              id: 'complete_trip_button',
              child: GestureDetector(
                onTap: _confirmCompleteTrip,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.completeTrip,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          else if (_isBudget && widget.budgetItems.isNotEmpty)
```

- [ ] **Step 4: `list_screen.smart.dart` —— `_CompleteTripSheet` 确认按钮**

当前：
```dart
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onConfirm(_selected.toList());
                },
                child: Text(
                  l.completeTrip,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
```
改为：
```dart
            TutorialTarget(
              id: 'confirm_trip_button',
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onConfirm(_selected.toList());
                  },
                  child: Text(
                    l.completeTrip,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
```

- [ ] **Step 5: `list_screen.smart.dart` —— `_SmartAddSheet` 确认按钮**

当前：
```dart
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  final shelf = _shelfCtrl.text.trim();
                  Navigator.pop(context);
                  widget.onConfirm(
                    _selectedCategory,
                    _selectedZone,
                    _qtyCtrl.text.trim(),
                    shelf.isEmpty ? null : shelf,
                    _days,
                  );
                },
                child: Text(
                  l.addToList,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
```
改为：
```dart
            TutorialTarget(
              id: 'confirm_add_button',
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final shelf = _shelfCtrl.text.trim();
                    Navigator.pop(context);
                    widget.onConfirm(
                      _selectedCategory,
                      _selectedZone,
                      _qtyCtrl.text.trim(),
                      shelf.isEmpty ? null : shelf,
                      _days,
                    );
                  },
                  child: Text(
                    l.addToList,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
```

- [ ] **Step 6: `main.widgets.dart` —— 库存 tab 图标**

`main.widgets.dart` 是 `part of 'main.dart'`，import 只能写在 `main.dart` 里。在 `lib/main.dart` 的 `import 'widgets/days_selector.dart';`（当前的最后一行 import，Task 7 已经在它上方插入过 `tutorial_controller.dart`/`tutorial_overlay.dart`）之后插入一行：
```dart
import 'widgets/tutorial_target.dart';
```

`main.widgets.dart` 里 `_BottomNav.build()` 当前：
```dart
              _NavItem(
                icon: Icons.format_list_bulleted_rounded,
                label: l.navList,
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2_rounded,
                label: l.navInventory,
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.notifications_outlined,
```
改为（只包住 index:1 的库存项）：
```dart
              _NavItem(
                icon: Icons.format_list_bulleted_rounded,
                label: l.navList,
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              TutorialTarget(
                id: 'inventory_tab',
                child: _NavItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                  label: l.navInventory,
                  index: 1,
                  currentIndex: currentIndex,
                  onTap: onTap,
                ),
              ),
              _NavItem(
                icon: Icons.notifications_outlined,
```

- [ ] **Step 7: 验证**

```bash
"$FLUTTER" analyze
```
Expected: 无新增问题（只有 baseline 的 3 个既有警告：`list_screen.budget.dart:46:11`、`list_screen.simple.dart:55:39` 的 `invalid_use_of_protected_member`，以及 `test/storage/app_repository_test.dart:76:11` 的 `unused_local_variable`）。

- [ ] **Step 8: Commit**

```bash
git add lib/screens/list_screen.dart lib/screens/list_screen.smart.dart lib/main.dart lib/main.widgets.dart
git commit -m "feat: wrap real add/complete-trip/inventory-tab buttons with TutorialTarget"
```

---

### Task 9: 示例商品名预填

**Files:**
- Modify: `lib/screens/list_screen.dart`

- [ ] **Step 1: 新增字段 + `didChangeDependencies`**

`_ListScreenState` 里，在 `final _nameFocus = FocusNode();` 之后插入：
```dart
  bool _tutorialPrefilled = false;
```

在 `didUpdateWidget` 方法之后（`_initSpeech` 之前）插入新方法：
```dart
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tutorialPrefilled &&
        TutorialController.instance.step == TutorialStep.addItem &&
        _nameCtrl.text.isEmpty) {
      _nameCtrl.text = L10n.of(context).tutorialExampleItemName;
      _tutorialPrefilled = true;
    }
  }
```

- [ ] **Step 2: import**

在 `import '../widgets/tutorial_target.dart';`（Task 8 加的）之后插入：
```dart
import '../services/tutorial_controller.dart';
import '../services/tutorial_store.dart';
```

- [ ] **Step 3: 验证**

```bash
"$FLUTTER" analyze lib/screens/list_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/list_screen.dart
git commit -m "feat: prefill example item name in add-bar during tutorial's addItem step"
```

---

### Task 10: 收尾验证

**Files:** 无代码改动

- [ ] **Step 1: 全量自动检查**

```bash
"$FLUTTER" analyze && "$FLUTTER" test
```
预期：无新增分析问题（只剩 baseline 的 3 个既有警告）；全部测试通过。如果 `test/widget_test.dart` 出现 hang 或超时，检查 `TutorialOverlay` 的每帧轮询（`addPostFrameCallback` 递归重新调度）是否被某处误用了 `pumpAndSettle()`（教程的持续轮询永远不会让待处理帧数归零，`pumpAndSettle()` 会一直等下去）——本计划新增的两个测试文件都不涉及 pump 真实 widget 树，不受影响；若之后有人新增覆盖 `TutorialOverlay` 的 widget 测试，必须用手动 `pump()` 循环，不能用 `pumpAndSettle()`。

- [ ] **Step 2: 模拟器手动验证**

先卸载重装以强制触发全新安装的种子数据（`<UDID>` 替换为实际已启动的模拟器 UDID）：
```bash
xcrun simctl uninstall <UDID> com.ffviii.shoppinglist
```
然后运行 `"$FLUTTER" run -d <UDID>`，依次验证：
1. 首次打开，计划清单 tab 顶部出现高亮遮罩，"+"按钮被点亮，输入框已预填"鸡蛋（示例）"，提示气泡文案正确。
2. 点击 "+"，弹出添加表单，表单内"加入清单"按钮被点亮，点击后表单关闭，商品出现在计划清单里。
3. 头部"完成购物"按钮被点亮，点击后弹出确认表单，表单内"完成购物"确认按钮被点亮，点击后表单关闭，计划清单变空。
4. 底部导航"库存"图标被点亮，点击切换到库存页后，屏幕中央出现收尾提示卡片，文案提到"提醒"页的作用，点击"知道了"后卡片消失，之后不再出现任何教程遮罩。
5. 在库存页能看到"鸡蛋（示例）"这条真实数据，可以像其他商品一样手动删除它。
6. 完全重启 App（杀掉进程，不是切后台），确认教程不会重新出现（因为已经是 `done`）。
7. 用另一台全新安装（或再次卸载重装），走到教程中间某一步时点击提示气泡右上角"跳过"，确认：当前已生成的示例商品从清单/库存里消失，教程遮罩不再出现。
8. 用另一台全新安装，走到教程中间某一步时**直接杀掉 App 进程**（不是跳过），重新打开，确认遮罩恢复到中断前的同一步骤，且高亮的还是正确的目标（如果杀在某个表单弹出的中途，表单本身不会保留，重新打开后应该停在"表单还没弹出、高亮入口按钮"的状态）。
9. 切换到英文，确认教程气泡/收尾卡片/预填商品名都是英文（"Egg (example)"等）。

- [ ] **Step 3: 向用户报告验证结果**

如发现问题，回到对应任务修复。
