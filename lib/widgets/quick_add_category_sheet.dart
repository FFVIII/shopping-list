import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';

/// Minimal name+color sheet for creating a category inline, without leaving
/// the item add/edit flow that triggered it (unlike the full category
/// manage screen, which also asks for shelf zone and default days).
void showQuickAddCategorySheet(
  BuildContext context, {
  required List<String> existingNames,
  required void Function(String name, Color color) onSubmit,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _QuickAddCategorySheet(
      existingNames: existingNames,
      onSubmit: onSubmit,
    ),
  );
}

class _QuickAddCategorySheet extends StatefulWidget {
  final List<String> existingNames;
  final void Function(String name, Color color) onSubmit;

  const _QuickAddCategorySheet({
    required this.existingNames,
    required this.onSubmit,
  });

  @override
  State<_QuickAddCategorySheet> createState() =>
      _QuickAddCategorySheetState();
}

class _QuickAddCategorySheetState extends State<_QuickAddCategorySheet> {
  late final TextEditingController _nameCtrl = TextEditingController();
  Color _color = Category.palette.first;
  String? _errorText;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final duplicate = widget.existingNames
        .any((existing) => existing.toLowerCase() == name.toLowerCase());
    if (duplicate) {
      setState(() => _errorText = L10n.of(context).categoryNameDuplicate);
      return;
    }
    Navigator.pop(context);
    widget.onSubmit(name, _color);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.addCategoryTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            _label(l.categoryNameLabel),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              maxLength: 12,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: l.categoryNameLabel,
                hintStyle: const TextStyle(color: AppColors.textDisabled),
                errorText: _errorText,
                filled: true,
                fillColor: AppColors.fieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                counterStyle: const TextStyle(
                    fontSize: 10, color: AppColors.textDisabled),
                isDense: true,
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            _label(l.categoryColorLabel),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: Category.palette.map((c) {
                final sel = c.toARGB32() == _color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: sel
                          ? Border.all(color: AppColors.textPrimary, width: 2)
                          : null,
                    ),
                    child: sel
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _submit,
              child: Text(
                l.addToList,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
