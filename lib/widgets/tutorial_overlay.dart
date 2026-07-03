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
