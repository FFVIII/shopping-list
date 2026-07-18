import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../l10n/l10n.dart';

/// Opens a small sheet listing the shelf codes already set up (via the
/// Aisle Order screen), so a shelf-code field can be filled by picking
/// instead of retyping the same location every time. Returns the tapped
/// code, or null if dismissed without picking one.
Future<String?> pickShelfCode(BuildContext context, List<String> codes) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ShelfCodePickerSheet(codes: codes),
  );
}

class _ShelfCodePickerSheet extends StatelessWidget {
  final List<String> codes;
  const _ShelfCodePickerSheet({required this.codes});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.shelfCodeFieldLabel,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: codes.map((code) {
              return GestureDetector(
                onTap: () => Navigator.pop(context, code),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
  }
}
