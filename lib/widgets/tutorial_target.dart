import 'package:flutter/widgets.dart';

/// Wraps a real widget so [TutorialOverlay] can look up its on-screen
/// position by a stable string [id], without the wrapped widget needing to
/// know anything about the tutorial.
class TutorialTarget extends StatelessWidget {
  final String id;
  final Widget child;

  const TutorialTarget({super.key, required this.id, required this.child});

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: TutorialRegistry.keyFor(id), child: child);
  }
}

/// Global id -> GlobalKey registry backing [TutorialTarget].
class TutorialRegistry {
  TutorialRegistry._();
  static final Map<String, GlobalKey> _keys = {};

  static GlobalKey keyFor(String id) =>
      _keys.putIfAbsent(id, () => GlobalKey());
}

/// Like [TutorialTarget], but safe to use inside a widget a list (e.g.
/// `ReorderableListView`) may transiently duplicate during drag/reorder
/// animations — a real [GlobalKey], as [TutorialTarget] uses, must be
/// unique across the whole Element tree at all times, which a duplicated
/// subtree would violate. This instead self-reports its on-screen rect into
/// [TutorialRectRegistry] every frame while mounted, without needing any
/// single Element to be identified from outside; if two instances briefly
/// share an id (e.g. the dragged item and its ghost proxy), they just both
/// report the same rect — last write wins, no crash.
class TutorialRectReporter extends StatefulWidget {
  final String id;
  final Widget child;

  const TutorialRectReporter({
    super.key,
    required this.id,
    required this.child,
  });

  @override
  State<TutorialRectReporter> createState() => _TutorialRectReporterState();
}

class _TutorialRectReporterState extends State<TutorialRectReporter> {
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  void _poll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_active) return;
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox && renderObject.attached) {
        final topLeft = renderObject.localToGlobal(Offset.zero);
        TutorialRectRegistry.report(widget.id, topLeft & renderObject.size);
      }
      _poll();
    });
  }

  @override
  void dispose() {
    _active = false;
    TutorialRectRegistry.clear(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Id -> last-reported Rect registry backing [TutorialRectReporter].
class TutorialRectRegistry {
  TutorialRectRegistry._();
  static final Map<String, Rect> _rects = {};

  static void report(String id, Rect rect) => _rects[id] = rect;
  static void clear(String id) => _rects.remove(id);
  static Rect? rectFor(String id) => _rects[id];
}
