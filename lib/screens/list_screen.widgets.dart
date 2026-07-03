part of 'list_screen.dart';

// ── Flat list entry for smart-mode drag ──────────────────────────────────────

class _FlatEntry {
  final String groupKey;
  final ShoppingItem? item;
  _FlatEntry.header(this.groupKey) : item = null;
  _FlatEntry.forItem(this.item, this.groupKey);
  bool get isHeader => item == null;
}

// ── Shared checkbox ───────────────────────────────────────────────────────────

class _Checkbox extends StatelessWidget {
  final bool checked;
  const _Checkbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? AppColors.brand : Colors.transparent,
        border: checked
            ? null
            : Border.all(color: AppColors.border, width: 1.5),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
          : null,
    );
  }
}

// ── Batch selection circle ────────────────────────────────────────────────────

class _SelectCircle extends StatelessWidget {
  final bool selected;
  const _SelectCircle({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.brand : Colors.transparent,
        border: selected
            ? null
            : Border.all(color: AppColors.border, width: 1.5),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
          : null,
    );
  }
}

// ── Mic Button ────────────────────────────────────────────────────────────────

class _MicButton extends StatefulWidget {
  final bool isListening;
  final bool available;
  final VoidCallback onTap;

  const _MicButton({
    required this.isListening,
    required this.available,
    required this.onTap,
  });

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isListening) {
      return GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                AppColors.danger,
                const Color(0xFFEF9A9A),
                _pulse.value,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded, size: 22, color: Colors.white),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.available ? widget.onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.09),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.mic_none_rounded,
          size: 22,
          color: widget.available ? AppColors.brand : AppColors.border,
        ),
      ),
    );
  }
}

// ── Segment Button (mode toggle) ──────────────────────────────────────────────

class _SegmentBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
              color: selected
                  ? AppColors.textPrimary
                  : const Color(0xFF8A8A8A),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// The white "thumb" behind a row of [_SegmentBtn]s. Slides to
/// [selectedIndex]'s slot (one of [count] equal segments) instead of each
/// button fading its own background in/out independently.
///
/// Must be a direct child of the enclosing [Stack] — [segmentWidth] is
/// resolved by the caller via an outer LayoutBuilder rather than one nested
/// in here, because a RenderObjectWidget like LayoutBuilder sitting between
/// Stack and this widget's [AnimatedPositioned] would break Positioned's
/// parent-data lookup (it needs Stack as its immediate render ancestor).
class _SegmentIndicator extends StatelessWidget {
  final int selectedIndex;
  final double segmentWidth;

  const _SegmentIndicator({
    required this.selectedIndex,
    required this.segmentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      left: segmentWidth * selectedIndex,
      width: segmentWidth,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Text Toggle Button (by-shelf / by-category) ───────────────────────────────

class _TextToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final SortDir? direction;

  const _TextToggleBtn(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.direction});

  @override
  Widget build(BuildContext context) => SortToggleButton(
      label: label, selected: selected, onTap: onTap, direction: direction);
}

// ── Rename Sheet ──────────────────────────────────────────────────────────────

class _RenameSheet extends StatefulWidget {
  final String initialName;
  final ValueChanged<String> onConfirm;

  const _RenameSheet({required this.initialName, required this.onConfirm});

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context);
    widget.onConfirm(name);
  }

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.rename,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              isDense: true,
            ),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 14),
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
                l.confirmEdit,
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

// ── Animated bottom bar switch ────────────────────────────────────────────────

/// Wraps the bottom bar that alternates between the smart/budget batch bars
/// and the normal add bar. [mode] identifies which one [child] currently is;
/// whenever it changes, the new bar fades + settles up into place instead of
/// hard-cutting in.
class _AnimatedBottomBar extends StatefulWidget {
  final int mode;
  final Widget child;

  const _AnimatedBottomBar({required this.mode, required this.child});

  @override
  State<_AnimatedBottomBar> createState() => _AnimatedBottomBarState();
}

class _AnimatedBottomBarState extends State<_AnimatedBottomBar>
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
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_AnimatedBottomBar old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) {
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
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
