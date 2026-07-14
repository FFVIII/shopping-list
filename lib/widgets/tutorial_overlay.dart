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
  bool _polling = false;

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
    if (_polling || TutorialController.instance.step == TutorialStep.done) {
      return;
    }
    _polling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _polling = false;
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
    // Widen the spotlight hole slightly past the target's exact bounds so a
    // highlighted button's own drop shadow isn't clipped by the dimming bars
    // sitting right at its edge.
    final rect = targetRect.inflate(6);

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
          stepNumber: step.index + 1,
          totalSteps: _candidateIds.length,
          // Point the arrow at the target's horizontal center, clamped so
          // it never slips off the edge of the (near full-width) bubble.
          arrowDx: (rect.center.dx - 16).clamp(24.0, size.width - 16 * 2 - 24),
          pointUp: tooltipBelow,
        ),
      ),
    ]);
  }
}

class _TutorialBubble extends StatelessWidget {
  final String text;
  final String skipLabel;
  final VoidCallback onSkip;
  final int stepNumber;
  final int totalSteps;
  final double arrowDx;
  final bool pointUp;

  const _TutorialBubble({
    required this.text,
    required this.skipLabel,
    required this.onSkip,
    required this.stepNumber,
    required this.totalSteps,
    required this.arrowDx,
    required this.pointUp,
  });

  static const _arrowWidth = 16.0;
  static const _arrowHeight = 8.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$stepNumber/$totalSteps',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDisabled,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onSkip,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.fieldBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          skipLabel,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: arrowDx - _arrowWidth / 2,
            top: pointUp ? -_arrowHeight + 1 : null,
            bottom: pointUp ? null : -_arrowHeight + 1,
            child: CustomPaint(
              size: const Size(_arrowWidth, _arrowHeight),
              painter: _BubbleArrowPainter(pointUp: pointUp),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleArrowPainter extends CustomPainter {
  final bool pointUp;
  const _BubbleArrowPainter({required this.pointUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path();
    if (pointUp) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleArrowPainter oldDelegate) =>
      oldDelegate.pointUp != pointUp;
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              minimumSize: const Size(double.infinity, 46),
            ),
            onPressed: onPressed,
            child: Text(
              buttonLabel,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
