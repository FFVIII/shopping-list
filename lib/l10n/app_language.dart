import 'dart:ui';

/// User-facing language *setting* (what's stored & shown in Settings).
enum AppLanguage { system, zh, en }

/// Effective language actually used to pick strings.
enum Lang { zh, en }

/// Resolve the effective [Lang] from the user's setting and a device locale.
/// `system` follows the device: zh* → zh, everything else → en.
Lang resolveLang(AppLanguage setting, Locale deviceLocale) {
  switch (setting) {
    case AppLanguage.zh:
      return Lang.zh;
    case AppLanguage.en:
      return Lang.en;
    case AppLanguage.system:
      return deviceLocale.languageCode == 'zh' ? Lang.zh : Lang.en;
  }
}
