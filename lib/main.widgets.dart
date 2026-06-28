part of 'main.dart';

// ── Days Sheet ────────────────────────────────────────────────────────────────

class _DaysSheet extends StatefulWidget {
  final ShoppingItem item;
  final int initialDays;
  final void Function(int days) onConfirm;

  const _DaysSheet({
    required this.item,
    required this.initialDays,
    required this.onConfirm,
  });

  @override
  State<_DaysSheet> createState() => _DaysSheetState();
}

class _DaysSheetState extends State<_DaysSheet> {
  late int _days;

  @override
  void initState() {
    super.initState();
    _days = widget.initialDays;
  }

  void _confirm() {
    Navigator.pop(context);
    widget.onConfirm(_days);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.boughtTitle(l.data(widget.item.name)),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            l.estimatedDaysQuestion,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [3, 5, 7, 14, 30].map((d) {
              final sel = _days == d;
              return GestureDetector(
                onTap: () => setState(() => _days = d),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.brand
                        : AppColors.fieldBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.days(d),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppColors.textChip,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.brand,
              inactiveTrackColor: AppColors.divider,
              thumbColor: AppColors.brand,
              overlayColor: AppColors.brand.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _days.toDouble().clamp(1, 60),
              min: 1,
              max: 60,
              divisions: 59,
              label: l.days(_days),
              onChanged: (v) => setState(() => _days = v.round()),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _confirm,
              child: Text(
                l.recordToInventory(_days),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int reminderBadge;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    this.reminderBadge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.format_list_bulleted_rounded,
                label: l.navList,
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2_rounded,
                label: l.navInventory,
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications_rounded,
                label: l.navReminder,
                index: 2,
                currentIndex: currentIndex,
                onTap: onTap,
                badge: reminderBadge,
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: l.navSettings,
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int badge;

  const _NavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badge = 0,
  });

  bool get _selected => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    const green = AppColors.brand;
    const inactive = AppColors.textMuted;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: _selected
                        ? green.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _selected ? (activeIcon ?? icon) : icon,
                    size: 22,
                    color: _selected ? green : inactive,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    _selected ? FontWeight.w600 : FontWeight.normal,
                color: _selected ? green : inactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
