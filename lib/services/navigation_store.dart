import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last-viewed bottom-nav tab and List-screen mode so a full
/// app restart reopens where the user left off, instead of always starting
/// on List/Jot. Mirrors the pattern in `l10n/language_store.dart`.
class NavigationStore {
  static const _tabKey = 'nav_tab';
  static const _listModeKey = 'nav_list_mode';

  static Future<int> loadTab() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_tabKey) ?? 0;
  }

  static Future<void> saveTab(int tab) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tabKey, tab);
  }

  static Future<int> loadListMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_listModeKey) ?? 0;
  }

  static Future<void> saveListMode(int modeIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_listModeKey, modeIndex);
  }
}
