import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The app-wide filled/rounded TextField style shared by every add/edit
/// sheet — light gray fill, no visible border, rounded corners.
InputDecoration fieldDecoration(String hint, {double verticalPadding = 12}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textDisabled),
      filled: true,
      fillColor: AppColors.fieldBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: verticalPadding,
      ),
      isDense: true,
      counterStyle: const TextStyle(
        fontSize: 10,
        color: AppColors.textDisabled,
      ),
    );
