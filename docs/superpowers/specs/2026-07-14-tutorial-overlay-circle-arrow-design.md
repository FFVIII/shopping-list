# 设计文档：TutorialOverlay 改为"手绘圆圈 + 虚线箭头 + 文字"标注样式

日期：2026-07-14
状态：已批准设计，待实施计划

## 1. 背景

`TutorialOverlay`（[lib/widgets/tutorial_overlay.dart](../../../lib/widgets/tutorial_overlay.dart)）目前是一个不遮罩、不挡点击的"快速上手清单卡片"（commit `5128585`）。在这之前（commit `a428c27`）它是一个变暗+封锁背景的"聚光灯"式教练标记：四条不透明色块挖出目标控件所在的洞，旁边配一个纯文字提示气泡。

本设计把提示气泡本身的呈现方式换成参考截图里那种手绘涂鸦式标注：**手绘感椭圆描边框住目标控件 + 一条虚线弧形箭头 + 一行说明文字**。步骤推进逻辑（`TutorialController`/`TutorialStore`/`TutorialStep`，见 [2026-07-02 设计文档](2026-07-02-interactive-onboarding-tutorial-design.md)）完全不变，只重写 `TutorialOverlay` 的渲染部分，并恢复 `TutorialTarget`/`TutorialRegistry`。

## 2. 关键决策（已与用户确认）

| 决策 | 选择 |
|---|---|
| 背景是否变暗+封锁点击 | 是，恢复旧版行为（四条不透明色块挖空目标矩形） |
| 高亮目标的视觉形式 | 手绘风格椭圆/椓圆描边（不规则手绘感），不是贴合形状的圆角矩形 |
| 箭头 | 虚线弧形箭头，从文字气泡指向椭圆边缘 |
| 文字提示 | 保留一行说明文字（复用旧版 `tutorialStepAddItem` 等文案）+ "跳过"按钮 |
| `finalMessage`（全部完成）步骤 | 保持旧版原样：居中卡片 + 变暗背景，不加圆圈/箭头 |
| 手绘描边实现方式 | 纯 `CustomPainter` 手写路径模拟手绘感，不引入第三方 pub 包 |
| `quickStart*` 系列 l10n 字符串 | 不再被引用，删除 |

显式排除（YAGNI）：不做贴合目标形状的圆角矩形选项；不做手绘描边的随机化/动画（每次渲染同一目标形状固定，不需要每帧变化）。

## 3. 架构

### 3.1 恢复 `lib/widgets/tutorial_target.dart`

与旧版（commit `a428c27`）完全一致，原样恢复：

```dart
class TutorialTarget extends StatelessWidget {
  final String id;
  final Widget child;
  const TutorialTarget({super.key, required this.id, required this.child});

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: TutorialRegistry.keyFor(id), child: child);
}

class TutorialRegistry {
  TutorialRegistry._();
  static final Map<String, GlobalKey> _keys = {};
  static GlobalKey keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey());
}
```

### 3.2 `lib/main.dart` 接线

重新用 `TutorialTarget` 包住 5 个位置（id 沿用旧版，与 `TutorialOverlay` 的候选列表一一对应）：
- `list_screen.dart` 添加栏 "+" 按钮容器（`add_button`）
- `list_screen.smart.dart` `_SmartAddSheet` "加入清单"按钮（`confirm_add_button`）
- `list_screen.dart` 头部"完成购物"胶囊（`complete_trip_button`）
- `list_screen.smart.dart` `_CompleteTripSheet` "完成购物"确认按钮（`confirm_trip_button`）
- `main.dart` 底部导航栏"库存"图标（`inventory_tab`）

### 3.3 重写 `lib/widgets/tutorial_overlay.dart`

**目标矩形查找**：与旧版一致——`_candidateIds` 映射 + `_scheduleFrameCheck`（`addPostFrameCallback` 循环）+ `_findTargetRect()`（`localToGlobal` + `RenderBox.size`）。`step == done` 直接返回 `child`。

**`finalMessage` 步骤**：与旧版一致，`Positioned.fill` 变暗背景 + 居中 `_TutorialCard`（文案 + "知道了"按钮）。

**其余步骤（有 `targetRect`）**：

```
Stack
├── child
├── 四条不透明色块（挖空 targetRect，逻辑同旧版）
├── CustomPaint：手绘椭圆描边，包住 targetRect（比 targetRect 略大一圈的 padding）
├── CustomPaint：虚线弧形箭头，从气泡指向椭圆边缘
└── 文字气泡（说明文字 + 跳过按钮），位置逻辑同旧版
    （目标在屏幕上半部分 → 气泡放下方；否则放上方）
```

- **`_HandDrawnOvalPainter`**：接收目标矩形，画一个比矩形大一圈（比如上下左右各 +10px）的椭圆描边。用 4 段三次贝塞尔曲线（近似椭圆的 4 个象限）拼成路径，每段的控制点加一个固定的小幅偏移（非随机数，避免每帧抖动——用基于目标矩形尺寸算出的固定偏移即可），模拟手绘的不规则感。描边颜色用 `AppColors.brand`，线宽 2.5，`StrokeCap.round`。
- **`_DashedArrowPainter`**：接收起点（气泡边缘某点）和终点（椭圆边缘最近点），画一条二次贝塞尔曲线路径（起点、控制点取两点连线中点并垂直偏移出弧度、终点），用 `dashPath`（手写循环按固定间隔切分 `Path` 为短线段）画成虚线，终点画一个小三角形箭头（沿终点切线方向）。
- 气泡内容复用旧版 `_TutorialBubble`（文字 + 跳过按钮），不需要改动。

**删除**：`_QuickStartCard`、`_QuickStartRow`（不再使用）。

### 3.4 l10n（`lib/l10n/app_strings.dart`）

恢复以下 4 个字符串（取旧版原文案，中英文各一份）：

| getter | zh | en |
|---|---|---|
| `tutorialStepAddItem` | 点击 + 把示例商品加入清单 | Tap + to add the example item to your list |
| `tutorialStepCompleteTrip` | 买完了？点这里完成本次购物 | Done shopping? Tap here to finish |
| `tutorialStepViewInventory` | 去库存看看刚刚买的东西吧 | Check your inventory for what you just bought |
| `tutorialFinalMessage` | 以后库存快用完时，「提醒」页会自动提示你补货 | When stock runs low, the Alerts tab will remind you to restock |

删除不再被引用的字符串：`quickStartTitle`、`quickStartAllDone`、`quickStartAddItem`、`quickStartCompleteTrip`、`quickStartViewInventory`。`tutorialGotIt`/`tutorialSkip`/`tutorialExampleItemName` 保留（两版都用得到）。

## 4. 测试

- 手绘描边/虚线箭头是纯绘制逻辑，不写像素级快照测试（收益低、脆弱）；改为一个轻量单元测试验证 `_findTargetRect`/候选 id 优先级逻辑不回归（可复用旧版思路，若旧版本身没有对应测试则不必新增，靠手动验证）。
- 手动模拟器验证：全新安装 → 依次完成 5 次点击，确认每一步骑上椭圆圈住的是正确的目标控件、箭头指向合理、气泡文案正确；`finalMessage` 步骤显示居中卡片；跳过按钮在不同步骤都能正确清理数据并结束教程。

## 5. 错误处理

与旧版一致：找不到目标 `GlobalKey`（还没渲染出来）时，`TutorialOverlay` 本帧不渲染高亮内容，静默跳过，等目标出现再渲染。
