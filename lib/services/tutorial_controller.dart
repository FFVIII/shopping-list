import 'dart:async';
import 'package:flutter/foundation.dart';
import 'tutorial_store.dart';

/// Drives the first-run interactive onboarding tutorial. A singleton so both
/// `_ShoppingListAppState` (renders the spotlight overlay above the
/// Navigator) and `_AppShellState` (owns the real shopping/inventory data
/// whose mutations advance the tutorial) can react to the same state
/// without threading it through widget constructors.
class TutorialController extends ChangeNotifier {
  TutorialController._();
  static final TutorialController instance = TutorialController._();

  /// Safe default before the real value is loaded: don't show anything.
  TutorialStep step = TutorialStep.done;

  /// Set by `_AppShellState.initState()`. The overlay's "skip" button calls
  /// this so the owner of the real data can clean up the example item; the
  /// overlay itself never touches shopping/inventory state directly.
  VoidCallback? onSkipRequested;

  static const exampleItemNameZh = '鸡蛋（示例）';
  static const exampleItemNameEn = 'Egg (example)';

  bool isExampleItemName(String name) =>
      name == exampleItemNameZh || name == exampleItemNameEn;

  /// Called once after `_AppShellState._loadData()` finishes loading.
  Future<void> resolveInitialStep({required bool dataIsEmpty}) async {
    final stored = await TutorialStore.load();
    if (stored != null) {
      step = stored;
    } else {
      step = dataIsEmpty ? TutorialStep.addItem : TutorialStep.done;
      unawaited(TutorialStore.save(step));
    }
    notifyListeners();
  }

  void _setStep(TutorialStep s) {
    if (step == s) return;
    step = s;
    notifyListeners();
    unawaited(TutorialStore.save(s)
        .catchError((e) => debugPrint('tutorial save failed: $e')));
  }

  Timer? _itemAddedTimer;

  void onItemAdded(String name) {
    if (step == TutorialStep.addItem && isExampleItemName(name)) {
      _setStep(TutorialStep.itemAdded);
      // Briefly circle the item that was just created, then move on to
      // circling the "complete trip" button — no tap needed to continue,
      // since the item sits inside a ReorderableListView and isn't safely
      // tappable as a tutorial target (see TutorialRectReporter's doc).
      _itemAddedTimer?.cancel();
      _itemAddedTimer = Timer(const Duration(seconds: 2), () {
        if (step == TutorialStep.itemAdded) _setStep(TutorialStep.completeTrip);
      });
    }
  }

  void onTripCompleted(Iterable<String> purchasedNames) {
    if (step == TutorialStep.completeTrip &&
        purchasedNames.any(isExampleItemName)) {
      _setStep(TutorialStep.viewInventory);
    }
  }

  void onTabChanged(int tabIndex) {
    if (step == TutorialStep.viewInventory && tabIndex == 1) {
      _setStep(TutorialStep.finalMessage);
    }
  }

  /// User manually deleted the example item before finishing: end silently.
  void onItemDeleted(String name) {
    if (step != TutorialStep.done && isExampleItemName(name)) {
      _itemAddedTimer?.cancel();
      _setStep(TutorialStep.done);
    }
  }

  /// "Got it" button: normal completion, doesn't touch any data.
  void finish() {
    _itemAddedTimer?.cancel();
    _setStep(TutorialStep.done);
  }

  /// "Skip" button: clean up first, then end.
  void skip() {
    _itemAddedTimer?.cancel();
    onSkipRequested?.call();
    _setStep(TutorialStep.done);
  }
}
