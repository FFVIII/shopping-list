import 'package:flutter/material.dart';

/// Shows a small popup menu anchored to [anchorContext]'s render box —
/// appearing right next to whatever was tapped, not as a full-width
/// bottom sheet. [builder] receives the popup's own BuildContext; call
/// `Navigator.pop(context, value)` from inside it to close and return a
/// value (or pop with no value to dismiss without picking anything).
Future<T?> showAnchoredPicker<T>(
  BuildContext anchorContext, {
  required WidgetBuilder builder,
  double maxWidth = 260,
}) {
  final button = anchorContext.findRenderObject() as RenderBox;
  final overlay =
      Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
  final topRight =
      button.localToGlobal(Offset(button.size.width, 0), ancestor: overlay);
  final bottomLeft =
      button.localToGlobal(Offset(0, button.size.height), ancestor: overlay);
  final position = RelativeRect.fromRect(
    Rect.fromPoints(bottomLeft, topRight),
    Offset.zero & overlay.size,
  );
  return showMenu<T>(
    context: anchorContext,
    position: position,
    constraints: BoxConstraints(maxWidth: maxWidth),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    // Material 3 tints elevated surfaces like menus by default, which reads
    // as an off-white/gray here — every other sheet in the app is flat
    // white, so match that instead of the theme default.
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    items: [
      PopupMenuItem<T>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: Builder(builder: builder),
      ),
    ],
  );
}
