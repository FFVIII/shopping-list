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

    final targetRect = _targetRect;
    if (targetRect == null) return widget.child;

    final size = MediaQuery.of(context).size;
    final rect = targetRect.intersect(Offset.zero & size);
    if (rect.width <= 0 || rect.height <= 0) return widget.child;

    final tooltipBelow = rect.top < size.height / 2;
    final stepText = switch (step) {
      TutorialStep.addItem => l.tutorialStepAddItem,
      TutorialStep.completeTrip => l.tutorialStepCompleteTrip,
      TutorialStep.viewInventory => l.tutorialStepViewInventory,
      // done and finalMessage both return earlier in build(), so this
      // branch is unreachable by construction.
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
