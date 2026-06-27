import 'package:flutter/widgets.dart';
import 'app_strings.dart';
import 'app_language.dart';

/// Exposes the current [AppStrings] to the widget tree.
class L10n extends InheritedWidget {
  final AppStrings strings;
  final AppLanguage language;

  const L10n({
    super.key,
    required this.strings,
    required this.language,
    required super.child,
  });

  static AppStrings of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<L10n>();
    assert(w != null, 'No L10n found in context');
    return w!.strings;
  }

  static AppLanguage languageOf(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<L10n>();
    return w?.language ?? AppLanguage.system;
  }

  @override
  bool updateShouldNotify(L10n oldWidget) =>
      oldWidget.strings.runtimeType != strings.runtimeType;
}
