import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../l10n/l10n.dart';
import 'anchored_picker.dart';

/// Shows a small popup, anchored to [anchorContext] (pass a context scoped
/// to the tapped icon, e.g. via a [Builder]), listing the shelf codes
/// already set up via the Aisle Order screen — so a shelf-code field can
/// be filled by picking instead of retyping the same location every time.
/// Returns the tapped code, or null if dismissed without picking one.
Future<String?> pickShelfCode(BuildContext anchorContext, List<String> codes) {
  return showAnchoredPicker<String>(
    anchorContext,
    builder: (ctx) {
      final l = L10n.of(ctx);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.shelfCodeFieldLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: codes.map((code) {
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.fieldBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l.data(code),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    },
  );
}
