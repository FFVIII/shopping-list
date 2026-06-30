import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/drag_handle.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';

class ShelfOrderScreen extends StatelessWidget {
  final List<ShelfZone> shelfZones;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ShelfOrderScreen({
    super.key,
    required this.shelfZones,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          l.shelfOrder,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: shelfZones.length,
          buildDefaultDragHandles: false,
          onReorderItem: onReorder,
          proxyDecorator: (child, index, animation) => Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black26,
            child: child,
          ),
          itemBuilder: (ctx, i) {
            final zone = shelfZones[i];
            return Container(
              key: ValueKey('zone_${zone.name}'),
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: zone.dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.data(zone.name),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  DragHandle(index: i),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
