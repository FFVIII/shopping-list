# Tutorial Overlay: Hand-Drawn Circle + Arrow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current "quick-start checklist card" `TutorialOverlay` with a dimmed/blocking spotlight overlay that circles the real on-screen target with a hand-drawn oval outline, connects it to a text bubble with a dashed curved arrow, and keeps the existing centered card for the final "all done" step.

**Architecture:** Restore `TutorialTarget`/`TutorialRegistry` (removed when the checklist card replaced the old spotlight) so the overlay can look up each step's target `Rect` on screen. Re-wrap the 5 real buttons/tabs with `TutorialTarget`. Rewrite `TutorialOverlay` to render the old dim-and-block bars plus two new `CustomPainter`s (hand-drawn oval, dashed arrow) instead of the checklist card. Restore the 4 per-step l10n strings the checklist card didn't need, and drop the `quickStart*` strings the new design doesn't need. `TutorialController`/`TutorialStore`/`TutorialStep` (the step-advancement logic) are untouched.

**Tech Stack:** Flutter/Dart, no new dependencies — hand-drawn stroke and dashed arrow are done with `Canvas`/`Path` primitives (`dart:math` for the arrowhead angle).

---

## File Structure

- Create: `lib/widgets/tutorial_target.dart` — `TutorialTarget` widget + `TutorialRegistry` (id → `GlobalKey`), restored verbatim from git history (commit `a428c27`).
- Modify: `lib/widgets/tutorial_overlay.dart` — full rewrite of the rendering logic; keeps `TutorialOverlay`/`_TutorialOverlayState` class names and the `_TutorialBubble`/`_TutorialCard` helper widgets, drops `_QuickStartCard`/`_QuickStartRow`, adds `_HandDrawnOvalPainter`/`_DashedArrowPainter`.
- Modify: `lib/main.dart` — add `tutorial_target.dart` import.
- Modify: `lib/main.widgets.dart` — wrap the inventory `_NavItem` with `TutorialTarget(id: 'inventory_tab')`.
- Modify: `lib/screens/list_screen.dart` — add `tutorial_target.dart` import.
- Modify: `lib/screens/list_screen.header.dart` — wrap the add button (`add_button`) and the complete-trip button (`complete_trip_button`) with `TutorialTarget`.
- Modify: `lib/screens/list_screen.sheets.dart` — wrap the `_CompleteTripSheet` confirm button (`confirm_trip_button`) and the `_SmartAddSheet` confirm button (`confirm_add_button`) with `TutorialTarget`.
- Modify: `lib/l10n/app_strings.dart` — remove `quickStartTitle`/`quickStartAllDone`/`quickStartAddItem`/`quickStartCompleteTrip`/`quickStartViewInventory` (abstract getters + zh/en implementations); add `tutorialStepAddItem`/`tutorialStepCompleteTrip`/`tutorialStepViewInventory`/`tutorialFinalMessage` (abstract getters + zh/en implementations).

---

### Task 1: Restore `TutorialTarget`/`TutorialRegistry`

**Files:**
- Create: `lib/widgets/tutorial_target.dart`

- [ ] **Step 1: Create the file**

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

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/widgets/tutorial_target.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/tutorial_target.dart
git commit -m "feat: restore TutorialTarget/TutorialRegistry for overlay target lookup"
```

---

### Task 2: Wrap the 5 real targets with `TutorialTarget`

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/main.widgets.dart:389-396`
- Modify: `lib/screens/list_screen.dart`
- Modify: `lib/screens/list_screen.header.dart:81-103` (complete-trip button), `lib/screens/list_screen.header.dart:236-255` (add button)
- Modify: `lib/screens/list_screen.sheets.dart:108-126` (`_CompleteTripSheet` confirm), `lib/screens/list_screen.sheets.dart:333-358` (`_SmartAddSheet` confirm)

- [ ] **Step 1: Add the import to `lib/main.dart`**

Find:
```dart
import 'widgets/days_selector.dart';
```
Replace with:
```dart
import 'widgets/days_selector.dart';
import 'widgets/tutorial_target.dart';
```

- [ ] **Step 2: Wrap the inventory nav item in `lib/main.widgets.dart`**

Find:
```dart
              _NavItem(
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2_rounded,
                label: l.navInventory,
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
```
Replace with:
```dart
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
```

- [ ] **Step 3: Add the import to `lib/screens/list_screen.dart`**

Find:
```dart
import '../widgets/toast.dart';
import '../services/tutorial_controller.dart';
```
Replace with:
```dart
import '../widgets/toast.dart';
import '../widgets/tutorial_target.dart';
import '../services/tutorial_controller.dart';
```

- [ ] **Step 4: Wrap the complete-trip button in `lib/screens/list_screen.header.dart`**

Find:
```dart
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: GestureDetector(
                onTap: _confirmCompleteTrip,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _isSmart ? AppColors.brand : AppColors.danger,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _isSmart ? l.addToInventoryButton : l.clearBudget,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (_isBudget && widget.budgetItems.isNotEmpty)
```
Replace with:
```dart
            TutorialTarget(
              id: 'complete_trip_button',
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: GestureDetector(
                  onTap: _confirmCompleteTrip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _isSmart ? AppColors.brand : AppColors.danger,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isSmart ? l.addToInventoryButton : l.clearBudget,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (_isBudget && widget.budgetItems.isNotEmpty)
```

- [ ] **Step 5: Wrap the add button in `lib/screens/list_screen.header.dart`**

Find:
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
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
```
Replace with:
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
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ),
```

- [ ] **Step 6: Wrap the `_CompleteTripSheet` confirm button in `lib/screens/list_screen.sheets.dart`**

Find:
```dart
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onConfirm(_selected.toList());
              },
              child: Text(
                l.addToInventoryButton,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Smart Add Sheet ───────────────────────────────────────────────────────────
```
Replace with:
```dart
            const SizedBox(height: 16),
            TutorialTarget(
              id: 'confirm_trip_button',
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onConfirm(_selected.toList());
                },
                child: Text(
                  l.addToInventoryButton,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Smart Add Sheet ───────────────────────────────────────────────────────────
```

- [ ] **Step 7: Wrap the `_SmartAddSheet` confirm button in `lib/screens/list_screen.sheets.dart`**

Find:
```dart
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
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
          ],
```
Replace with:
```dart
            const SizedBox(height: 12),
            TutorialTarget(
              id: 'confirm_add_button',
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 48),
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
          ],
```

- [ ] **Step 8: Verify it compiles**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add lib/main.dart lib/main.widgets.dart lib/screens/list_screen.dart lib/screens/list_screen.header.dart lib/screens/list_screen.sheets.dart
git commit -m "feat: wrap add/complete-trip/inventory-tab buttons with TutorialTarget"
```

---

### Task 3: Update l10n strings and rewrite `TutorialOverlay`

These two files are tightly coupled — the new overlay code uses the l10n
getters this task adds, and the old overlay code uses the getters this task
removes — so they land in one task/commit to avoid a non-compiling
intermediate state.

**Files:**
- Modify: `lib/l10n/app_strings.dart`
- Modify: `lib/widgets/tutorial_overlay.dart` (full rewrite)

- [ ] **Step 1: Swap the abstract getters**

Find (around line 198):
```dart
  // ── Onboarding tutorial ──
  String get tutorialExampleItemName; // 固定示例商品名
  String get quickStartTitle;
  String get quickStartAllDone;
  String get quickStartAddItem;
  String get quickStartCompleteTrip;
  String get quickStartViewInventory;
  String get tutorialGotIt;
  String get tutorialSkip;
```
Replace with:
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

- [ ] **Step 2: Swap the zh implementations**

Find (around line 411):
```dart
  @override String get tutorialExampleItemName => '鸡蛋（示例）';
  @override String get quickStartTitle => '快速上手';
  @override String get quickStartAllDone => '搞定！';
  @override String get quickStartAddItem => '添加第一件商品';
  @override String get quickStartCompleteTrip => '完成一次购物';
  @override String get quickStartViewInventory => '查看库存';
  @override String get tutorialGotIt => '知道了';
  @override String get tutorialSkip => '跳过';
```
Replace with:
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

- [ ] **Step 3: Swap the en implementations**

Find (around line 634):
```dart
  @override String get tutorialExampleItemName => 'Egg (example)';
  @override String get quickStartTitle => 'Quick start';
  @override String get quickStartAllDone => 'All done!';
  @override String get quickStartAddItem => 'Add your first item';
  @override String get quickStartCompleteTrip => 'Complete a shopping trip';
  @override String get quickStartViewInventory => 'Check your inventory';
  @override String get tutorialGotIt => 'Got it';
  @override String get tutorialSkip => 'Skip';
```
Replace with:
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

- [ ] **Step 4: Replace the entire contents of `lib/widgets/tutorial_overlay.dart`**

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/tutorial_controller.dart';
import '../services/tutorial_store.dart';
import '../theme/app_colors.dart';
import 'tutorial_target.dart';

/// Renders the coach-mark spotlight for the first-run onboarding tutorial: a
/// hand-drawn oval outline circles the real on-screen target, a dashed arrow
/// connects it to a text bubble, and four opaque bars dim + block everything
/// outside the target. Wraps the app's Navigator output via
/// `MaterialApp.builder` so the overlay stays on top of modal bottom sheets,
/// which are pushed as routes on that same Navigator.
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

  /// Vertical gap between the target and the tooltip bubble, and between
  /// the target and the arrow's starting point.
  static const double _bubbleGap = 28;

  /// How much bigger the hand-drawn oval is than the real target rect.
  static const double _ovalPadding = 10;

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

    final oval = rect.inflate(_ovalPadding);
    final anchorX = rect.center.dx.clamp(32.0, size.width - 32.0);
    final arrowStart = Offset(
      anchorX,
      tooltipBelow ? rect.bottom + _bubbleGap : rect.top - _bubbleGap,
    );
    final arrowEnd = tooltipBelow ? oval.bottomCenter : oval.topCenter;

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
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _HandDrawnOvalPainter(oval)),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _DashedArrowPainter(start: arrowStart, end: arrowEnd),
          ),
        ),
      ),
      Positioned(
        left: 16,
        right: 16,
        top: tooltipBelow ? rect.bottom + _bubbleGap : null,
        bottom: tooltipBelow ? null : size.height - rect.top + _bubbleGap,
        child: _TutorialBubble(
          text: stepText,
          skipLabel: l.tutorialSkip,
          onSkip: TutorialController.instance.skip,
        ),
      ),
    ]);
  }
}

/// Hand-drawn-style oval outline around a tutorial target. Two overlapping
/// strokes — one plain, one slightly offset and rotated — approximate the
/// look of someone circling the target twice with a pen.
class _HandDrawnOvalPainter extends CustomPainter {
  final Rect oval;
  const _HandDrawnOvalPainter(this.oval);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(oval, paint);

    canvas.save();
    canvas.translate(oval.center.dx, oval.center.dy);
    canvas.rotate(0.05);
    canvas.translate(-oval.center.dx, -oval.center.dy);
    canvas.drawOval(oval.translate(2, -2).deflate(1.5), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HandDrawnOvalPainter oldDelegate) =>
      oldDelegate.oval != oval;
}

/// Dashed curved arrow connecting the tooltip bubble to the hand-drawn oval,
/// with a small filled triangular arrowhead at [end].
class _DashedArrowPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  const _DashedArrowPainter({required this.start, required this.end});

  static const double _dashLength = 6;
  static const double _gapLength = 5;
  static const double _arrowSize = 8;
  static const double _bowAmount = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final bowSign = end.dx >= start.dx ? 1.0 : -1.0;
    final control = mid + Offset(_bowAmount * bowSign, 0);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    _drawDashed(canvas, path, paint);
    _drawArrowHead(canvas, path, paint);
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _gapLength;
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.last;
    final tangent = metric.getTangentForOffset(metric.length);
    if (tangent == null) return;

    final tip = tangent.position;
    final angle = tangent.angle;
    final p1 = tip -
        Offset(math.cos(angle - 0.5), math.sin(angle - 0.5)) * _arrowSize;
    final p2 = tip -
        Offset(math.cos(angle + 0.5), math.sin(angle + 0.5)) * _arrowSize;

    final fillPaint = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close(),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedArrowPainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
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

- [ ] **Step 5: Verify no other references to the removed getters remain**

Run: `grep -rn "quickStart" lib/`
Expected: no output.

- [ ] **Step 6: Verify it compiles**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Run the existing test suite**

Run: `flutter test`
Expected: all tests pass, including `test/services/tutorial_controller_test.dart` and `test/services/tutorial_store_test.dart` (untouched by this change — they test step-advancement logic, not rendering)

- [ ] **Step 8: Commit**

```bash
git add lib/l10n/app_strings.dart lib/widgets/tutorial_overlay.dart
git commit -m "feat: replace quick-start checklist card with hand-drawn circle+arrow spotlight"
```

---

### Task 4: Manual verification

This is a purely visual rendering change — `flutter analyze`/`flutter test` confirm the code compiles and the step-advancement logic still works, but they can't confirm the oval/arrow/dimming actually look right on a device. Hand off to the user for on-device verification (matches how this project's onboarding tutorial has always been validated — see the "手动模拟器验证" section of `docs/superpowers/specs/2026-07-02-interactive-onboarding-tutorial-design.md`).

- [ ] **Step 1: Reset the tutorial state so it triggers again**

The tutorial only auto-starts when local storage is empty. Either uninstall/reinstall the app on the test device/simulator, or clear the app's local storage (Hive box + `shared_preferences`) before the next launch.

- [ ] **Step 2: Walk through all 3 steps + final message on a real device**

Check for each of the 3 steps (add item, complete trip, view inventory):
- The hand-drawn oval circles the correct real button/tab.
- The dashed arrow visibly connects the oval to the text bubble, with an arrowhead pointing at the oval.
- Everything outside the oval is dimmed and taps outside it don't do anything; tapping inside the oval (the real button) still works.
- The bubble's "跳过/Skip" button ends the tutorial and cleans up the example item.

Then check the final step:
- Centered card with the closing message and "知道了/Got it" button, dimmed background, no oval/arrow.

- [ ] **Step 3: Report back**

Confirm with the user whether the visuals match expectations, or note anything (oval size, arrow curve, dimming) that needs a follow-up tweak.
