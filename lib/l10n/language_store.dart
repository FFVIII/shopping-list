import 'package:shared_preferences/shared_preferences.dart';
import 'app_language.dart';

/// Loads/saves the chosen [AppLanguage] using shared_preferences.
class LanguageStore {
  static const _key = 'app_language';

  static Future<AppLanguage> load() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_key)) {
      case 'zh':
        return AppLanguage.zh;
      case 'en':
        return AppLanguage.en;
      default:
        return AppLanguage.system;
    }
  }

  static Future<void> save(AppLanguage lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang.name); // 'system' | 'zh' | 'en'
  }
}
