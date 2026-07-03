import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A dismissible lightbulb-icon hint banner. Callers own the "has this been
/// dismissed" state (see [HintStore]) — this widget is purely presentational
/// and always renders when built; the caller decides whether to build it.
class HintBanner extends StatelessWidget {
  final String text;
  final VoidCallback onDismiss;

  const HintBanner({super.key, required this.text, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: Color(0xFF4B6B4D)),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  size: 16, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
