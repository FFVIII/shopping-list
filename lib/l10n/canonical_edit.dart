import 'app_strings.dart';

/// Text to show in an editable field for a canonical (raw-stored) value —
/// translated for display, e.g. "香蕉" → "Banana" in English. Seeded sample
/// items and default categories store their name/quantity/shelf-code as
/// canonical Chinese tokens; [AppStrings.data] is the only thing that
/// translates them for display.
String canonicalDisplay(AppStrings l, String raw) => l.data(raw);

/// What to save from an editable canonical field: if the user left the
/// translated display text untouched, keep the original raw value instead
/// of the typed (translated) text. Otherwise a canonical item would get
/// permanently overwritten with its English display string the first time
/// someone opens and re-saves it without changing anything — breaking the
/// data() lookup and showing the English text even in Chinese.
String resolveCanonicalEdit(String typed, String display, String raw) =>
    typed == display ? raw : typed;
