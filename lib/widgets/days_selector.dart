import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../l10n/l10n.dart';
import '../utils/day_input.dart';

/// Horizontal chip row for selecting a number of days.
/// Preset chips: 3, 5, 7, 14, 30. Last chip is an inline custom text field.
/// Manages its own display state; reports every valid change via [onChanged].
class DaysSelector extends StatefulWidget {
  final int initialDays;
  final ValueChanged<int> onChanged;

  const DaysSelector({
    super.key,
    required this.initialDays,
    required this.onChanged,
  });

  @override
  State<DaysSelector> createState() => _DaysSelectorState();
}

class _DaysSelectorState extends State<DaysSelector> {
  static const _presets = [3, 5, 7, 14, 30];

  late int _selectedDays;
  bool _usingCustom = false;
  bool _overflow = false;
  final _customCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDays = widget.initialDays;
    if (!_presets.contains(_selectedDays)) {
      _usingCustom = true;
      _customCtrl.text = '$_selectedDays';
    }
  }

  @override
  void didUpdateWidget(covariant DaysSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDays != widget.initialDays) {
      _selectedDays = widget.initialDays;
      _usingCustom = !_presets.contains(_selectedDays);
      _customCtrl.text = _usingCustom ? '$_selectedDays' : '';
      _overflow = false;
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _selectPreset(int d) {
    setState(() {
      _selectedDays = d;
      _usingCustom = false;
      _overflow = false;
      _customCtrl.clear();
    });
    widget.onChanged(d);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._presets.map((d) {
                final sel = !_usingCustom && _selectedDays == d;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _selectPreset(d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.brand : AppColors.fieldBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l.days(d),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppColors.textChip,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // Custom inline chip
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                decoration: BoxDecoration(
                  color: _usingCustom ? AppColors.brand : AppColors.fieldBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: _customCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _usingCustom
                              ? Colors.white
                              : AppColors.textChip,
                        ),
                        decoration: InputDecoration(
                          hintText: l.customDaysLabel,
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: _usingCustom
                                ? Colors.white70
                                : AppColors.textDisabled,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        onChanged: (v) {
                          final result = parseDaysInput(v, _customCtrl);
                          if (result == null) {
                            setState(() => _usingCustom = v.trim().isNotEmpty);
                            return;
                          }
                          setState(() {
                            _usingCustom = true;
                            _overflow = result.overflow;
                            _selectedDays = result.value;
                          });
                          widget.onChanged(result.value);
                        },
                        onSubmitted: (v) {
                          final result = parseDaysInput(v, _customCtrl);
                          if (result == null) return;
                          setState(() {
                            _selectedDays = result.value;
                            _usingCustom = true;
                            _overflow = false;
                          });
                          widget.onChanged(result.value);
                        },
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      l.dayUnit,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _usingCustom ? Colors.white : AppColors.textChip,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_overflow) ...[
          const SizedBox(height: 6),
          Text(
            l.customDaysMaxHint,
            style: const TextStyle(fontSize: 12, color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}
