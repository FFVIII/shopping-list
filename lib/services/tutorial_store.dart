import 'package:shared_preferences/shared_preferences.dart';

/// Steps of the first-run interactive onboarding tutorial. See design spec
/// docs/superpowers/specs/2026-07-02-interactive-onboarding-tutorial-design.md.
enum TutorialStep {
  addItem,
  completeTrip,
  viewInventory,
  finalMessage,
  done,
}

/// Persists which [TutorialStep] the onboarding tutorial is currently on.
/// Mirrors the pattern in `l10n/language_store.dart`.
class TutorialStore {
  static const _key = 'tutorial_step';

  /// Returns null if nothing has ever been saved (first time this check
  /// runs on this device) — distinct from having explicitly saved
  /// [TutorialStep.addItem].
  static Future<TutorialStep?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key);
    if (index == null) return null;
    return TutorialStep.values[index];
  }

  static Future<void> save(TutorialStep step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, step.index);
  }
}
