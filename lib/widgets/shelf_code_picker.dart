import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import '../theme/app_colors.dart';
import '../l10n/l10n.dart';

/// Shows a Cancel/Save sheet (matching the Reminder-time / Category
/// pickers elsewhere in the app) with a scroll wheel listing the shelf
/// codes already set up via the Aisle Order screen. Returns the picked
/// code, or null if dismissed without saving.
Future<String?> pickShelfCode(BuildContext context, List<String> codes) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ShelfCodePickerSheet(codes: codes),
  );
}

class _ShelfCodePickerSheet extends StatefulWidget {
  final List<String> codes;
  const _ShelfCodePickerSheet({required this.codes});

  @override
  State<_ShelfCodePickerSheet> createState() => _ShelfCodePickerSheetState();
}

class _ShelfCodePickerSheetState extends State<_ShelfCodePickerSheet> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel,
                      style: const TextStyle(
                          fontSize: 17, color: AppColors.textMuted)),
                ),
                Text(l.shelfCodeFieldLabel,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, widget.codes[_index]),
                  child: Text(l.save,
                      style: const TextStyle(
                          fontSize: 17,
                          color: AppColors.brand,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 216,
            child: CupertinoPicker(
              itemExtent: 40,
              onSelectedItemChanged: (i) => _index = i,
              children: widget.codes
                  .map((code) => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            l.data(code),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 19, color: AppColors.textPrimary),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
