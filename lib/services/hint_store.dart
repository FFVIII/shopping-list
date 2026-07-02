import 'package:shared_preferences/shared_preferences.dart';

/// Persists which hint banner ids the user has permanently dismissed.
/// Mirrors the pattern in `l10n/language_store.dart`.
class HintStore {
  static const _key = 'dismissed_hints';

  /// Ids of hint banners the user has closed. Empty if none yet.
  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  /// Overwrites the stored set with [dismissed] in full — callers pass the
  /// complete set they want persisted, not just the newly-added id.
  static Future<void> save(Set<String> dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, dismissed.toList());
  }
}
