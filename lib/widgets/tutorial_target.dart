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
