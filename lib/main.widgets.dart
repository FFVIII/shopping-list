part of 'main.dart';

// ── Days + Edit Sheet (merged) ────────────────────────────────────────────────

class _DaysSheet extends StatefulWidget {
  final ShoppingItem item;
  final int initialDays;
  final List<Category> categories;
  final List<String> shelfCodeOrder;
  final Category Function(
    String name,
    Color color,
    String shelfZone,
    int defaultDays,
  )
  onAddCategory;
  final void Function(
    int days,
    String name,
    String quantity,
    String? shelfCode,
    Category category,
    String zone,
  )
  onConfirm;
  // True if no other smart-list item currently shares this shelf code —
  // i.e. changing it away would remove that aisle group from the By-aisle
  // view. Used to confirm with the user before silently collapsing a group.
  final bool Function(String shelfCode) isOnlyItemInAisle;

  const _DaysSheet({
    required this.item,
    required this.initialDays,
    required this.categories,
    required this.shelfCodeOrder,
    required this.onAddCategory,
    required this.onConfirm,
    required this.isOnlyItemInAisle,
  });

  @override
  State<_DaysSheet> createState() => _DaysSheetState();
}

class _DaysSheetState extends State<_DaysSheet> {
  late int _days;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _shelfCtrl;
  late Category _category;
  late String _zone;

  // See lib/l10n/canonical_edit.dart: seeded items store canonical Chinese
  // text, so the fields are pre-filled with the translated display text and
  // resolved back to the raw value on submit if left untouched.
  bool _textsInitialized = false;
  late String _nameDisplay;
  late String _qtyDisplay;
  late String _shelfDisplay;

  @override
  void initState() {
    super.initState();
    _days = widget.initialDays;
    _nameCtrl = TextEditingController();
    _qtyCtrl = TextEditingController();
    _shelfCtrl = TextEditingController();
    _category = widget.item.category;
    _zone = widget.item.shelfZone;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_textsInitialized) {
      final l = L10n.of(context);
      _nameDisplay = canonicalDisplay(l, widget.item.name);
      _qtyDisplay = canonicalDisplay(l, widget.item.quantityLabel);
      _shelfDisplay = canonicalDisplay(l, widget.item.shelfCode ?? '');
      _nameCtrl.text = _nameDisplay;
      _qtyCtrl.text = _qtyDisplay;
      _shelfCtrl.text = _shelfDisplay;
      _textsInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _shelfCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final typedName = _nameCtrl.text.trim();
    if (typedName.isEmpty) return;
    final name = resolveCanonicalEdit(
      typedName,
      _nameDisplay,
      widget.item.name,
    );
    final typedShelf = _shelfCtrl.text.trim();
    final shelf = resolveCanonicalEdit(
      typedShelf,
      _shelfDisplay,
      widget.item.shelfCode ?? '',
    );
    final qty = resolveCanonicalEdit(
      _qtyCtrl.text.trim(),
      _qtyDisplay,
      widget.item.quantityLabel,
    );

    final oldCode = widget.item.shelfCode;
    if (oldCode != null &&
        oldCode.isNotEmpty &&
        shelf != oldCode &&
        widget.isOnlyItemInAisle(oldCode)) {
      final l = L10n.of(context);
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.shelfGroupWillDisappearTitle),
          content: Text(l.shelfGroupWillDisappearMessage(l.data(oldCode))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.save),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    Navigator.pop(context);
    widget.onConfirm(
      _days,
      name,
      qty,
      shelf.isEmpty ? null : shelf,
      _category,
      _zone,
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
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
    final daysParts = l.estimatedDaysSelected(_days).split(RegExp(r'\d+'));
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
            // ── Header ────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title + category share one Flexible so the Save pill sits
                // hard against the right edge, matching the inventory detail
                // sheet's header. The FittedBox scales the pair down together
                // at large text sizes instead of overflowing.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.editItem,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        CategoryPickerField(
                          categories: widget.categories,
                          selected: _category,
                          onAddCategory: widget.onAddCategory,
                          onChanged: (cat) => setState(() {
                            _category = cat;
                            _zone = cat.shelfZone;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _confirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l.save,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Name + Qty row ───────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel(l.productNameHint),
                      TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(fontSize: 15),
                        maxLength: 30,
                        decoration: fieldDecoration(''),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel(l.quantityFieldLabel),
                      TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 10,
                        style: const TextStyle(fontSize: 15),
                        decoration: fieldDecoration('1'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Shelf code ─────────────────────────────────────────────────
            _fieldLabel(l.shelfCodeFieldLabel),
            TextField(
              controller: _shelfCtrl,
              maxLength: 20,
              style: const TextStyle(fontSize: 15),
              decoration: fieldDecoration('').copyWith(
                suffixIcon: widget.shelfCodeOrder.isEmpty
                    ? null
                    : Builder(
                        builder: (iconContext) => IconButton(
                          icon: const Icon(
                            Icons.inventory_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () async {
                            final picked = await pickShelfCode(
                              iconContext,
                              widget.shelfCodeOrder,
                            );
                            if (picked != null) {
                              setState(() => _shelfCtrl.text = picked);
                            }
                          },
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            // ── Days section ──────────────────────────────────────────────
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                children: [
                  TextSpan(text: daysParts[0]),
                  TextSpan(
                    text: '$_days',
                    style: const TextStyle(color: AppColors.brand),
                  ),
                  TextSpan(text: daysParts[1]),
                ],
              ),
            ),
            const SizedBox(height: 6),
            DaysSelector(
              initialDays: _days,
              onChanged: (d) => setState(() => _days = d),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Storage warning banner ────────────────────────────────────────────────────

class _StorageWarningBanner extends StatelessWidget {
  const _StorageWarningBanner();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        color: AppColors.danger,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.storageUnavailableBanner,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated tab content ──────────────────────────────────────────────────────

/// Wraps the bottom-tab IndexedStack with a fade + settle-up transition that
/// plays whenever [index] changes, instead of the instant hard-cut IndexedStack
/// gives you on its own. Keeps IndexedStack itself (all tabs stay mounted, so
/// each tab's own scroll position / search text / batch-mode selection survive
/// switching away and back) — only the *reveal* of the newly-visible tab is
/// animated.
class _AnimatedTabContent extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _AnimatedTabContent({required this.index, required this.children});

  @override
  State<_AnimatedTabContent> createState() => _AnimatedTabContentState();
}

class _AnimatedTabContentState extends State<_AnimatedTabContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0, // no flash on first render
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_AnimatedTabContent old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: IndexedStack(index: widget.index, children: widget.children),
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int reminderBadge;
  final bool inventoryDot;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    this.reminderBadge = 0,
    this.inventoryDot = false,
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
        child: Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.format_list_bulleted_rounded,
                label: l.navList,
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              TutorialTarget(
                id: 'inventory_tab',
                child: _NavItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                  label: l.navInventory,
                  index: 1,
                  currentIndex: currentIndex,
                  onTap: onTap,
                  dot: inventoryDot,
                ),
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
  final bool dot;

  const _NavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badge = 0,
    this.dot = false,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _selected
                        ? green.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    _selected ? (activeIcon ?? icon) : icon,
                    size: 26,
                    color: _selected ? green : inactive,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: 0,
                    right: 4,
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
                if (dot)
                  Positioned(
                    top: 4,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: _selected ? FontWeight.w600 : FontWeight.normal,
                color: _selected ? green : inactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
