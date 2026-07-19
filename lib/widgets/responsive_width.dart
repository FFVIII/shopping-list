import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Caps the app's content to a comfortable phone-like width and centers it,
/// instead of letting the phone-first layout stretch full-bleed across an
/// iPad screen. Wraps the whole [MaterialApp] (below its internal
/// Navigator), so every screen, pushed route, dialog, and modal sheet gets
/// the same capped/centered treatment for free.
class ResponsiveWidth extends StatelessWidget {
  static const double maxContentWidth = 500;

  final Widget child;
  const ResponsiveWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.scaffoldBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      ),
    );
  }
}
