import 'package:flutter/material.dart';

/// Shared upper bound for every "how many days" input in the app (default
/// use-days, reset timer, reminder lead time).
const int kMaxDays = 1000;

/// Result of parsing a days-input field: the clamped value, and whether the
/// raw input exceeded the max (so the caller can show a warning).
class DaysInputResult {
  final int value;
  final bool overflow;
  const DaysInputResult(this.value, this.overflow);
}

/// Parses [raw] as a positive day count, clamped to `[1, maxDays]`. If the
/// parsed value exceeds [maxDays], rewrites [controller] with the clamped
/// value so the field can't display an out-of-range number. Returns null if
/// [raw] isn't a valid positive integer.
DaysInputResult? parseDaysInput(
  String raw,
  TextEditingController controller, {
  int maxDays = kMaxDays,
}) {
  final n = int.tryParse(raw.trim());
  if (n == null || n <= 0) return null;
  final overflow = n > maxDays;
  final clamped = n.clamp(1, maxDays);
  if (overflow) {
    controller.text = '$clamped';
    controller.selection = TextSelection.collapsed(offset: '$clamped'.length);
  }
  return DaysInputResult(clamped, overflow);
}
