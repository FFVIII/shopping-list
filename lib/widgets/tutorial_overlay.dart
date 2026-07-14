import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/tutorial_controller.dart';
import '../services/tutorial_store.dart';
import '../theme/app_colors.dart';

/// Renders the "quick start" checklist card for the first-run onboarding
/// flow. A plain floating card — no dimming, no blocking taps, no tracking
/// of other widgets' on-screen position — so the user can freely use the
/// app while it's up. Wraps the app's Navigator output via
/// `MaterialApp.builder` so the card stays on top of modal bottom sheets,
/// which are pushed as routes on that same Navigator.
class TutorialOverlay extends StatefulWidget {
  final Widget child;
  const TutorialOverlay({super.key, required this.child});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  @override
  void initState() {
    super.initState();
    TutorialController.instance.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    TutorialController.instance.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final step = TutorialController.instance.step;
    if (step == TutorialStep.done) return widget.child;

    final l = L10n.of(context);
    final allDone = step == TutorialStep.finalMessage;
    // addItem/completeTrip/viewInventory are indices 0/1/2; each step's
    // index is how many of the 3 tasks are already checked off.
    final checkedCount = allDone ? 3 : step.index;

    return Stack(children: [
      widget.child,
      Positioned(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 76,
        child: _QuickStartCard(
          title: allDone ? l.quickStartAllDone : l.quickStartTitle,
          items: [
            l.quickStartAddItem,
            l.quickStartCompleteTrip,
            l.quickStartViewInventory,
          ],
          checkedCount: checkedCount,
          actionLabel: allDone ? l.tutorialGotIt : l.tutorialSkip,
          onAction: allDone
              ? TutorialController.instance.finish
              : TutorialController.instance.skip,
        ),
      ),
    ]);
  }
}

class _QuickStartCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final int checkedCount;
  final String actionLabel;
  final VoidCallback onAction;

  const _QuickStartCard({
    required this.title,
    required this.items,
    required this.checkedCount,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onAction,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.fieldBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _QuickStartRow(label: items[i], checked: i < checkedCount),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickStartRow extends StatelessWidget {
  final String label;
  final bool checked;

  const _QuickStartRow({required this.label, required this.checked});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          checked ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 18,
          color: checked ? AppColors.brand : AppColors.textDisabled,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: checked ? AppColors.textDisabled : AppColors.textPrimary,
              decoration: checked ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.textDisabled,
            ),
          ),
        ),
      ],
    );
  }
}
