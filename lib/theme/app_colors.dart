import 'package:flutter/material.dart';

/// 全局 UI 通用色（品牌、文字、背景、分隔线等）。
///
/// 注意：分类色、库存状态色、货架色等领域语义色定义在 `models/item.dart`
/// （`Category.color/bgColor`、`StockStatus.color/bgColor`、`kShelfZones`），
/// 不在此处重复。
class AppColors {
  AppColors._();

  // 品牌
  static const brand = Color(0xFF4CAF50);

  // 状态
  static const danger = Color(0xFFE53935);

  // 文字
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B6B6B);
  static const textMuted = Color(0xFF9E9E9E);
  static const textDisabled = Color(0xFFBDBDBD);
  static const textChip = Color(0xFF424242);

  // 背景 / 分隔
  static const scaffoldBg = Color(0xFFF2F2ED);
  static const fieldBg = Color(0xFFF5F5F0);
  static const divider = Color(0xFFE0E0E0);
  static const border = Color(0xFFD0D0D0);

  // 阴影
  static const shadow = Color(0x09000000);
}
