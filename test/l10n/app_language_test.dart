import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/l10n/app_language.dart';

void main() {
  group('resolveLang', () {
    test('system + zh locale → Lang.zh', () {
      expect(resolveLang(AppLanguage.system, const Locale('zh', 'CN')), Lang.zh);
    });
    test('system + en locale → Lang.en', () {
      expect(resolveLang(AppLanguage.system, const Locale('en', 'US')), Lang.en);
    });
    test('system + other locale → Lang.en (fallback)', () {
      expect(resolveLang(AppLanguage.system, const Locale('fr', 'FR')), Lang.en);
    });
    test('explicit zh always zh', () {
      expect(resolveLang(AppLanguage.zh, const Locale('en')), Lang.zh);
    });
    test('explicit en always en', () {
      expect(resolveLang(AppLanguage.en, const Locale('zh')), Lang.en);
    });
  });
}
