import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/l10n/app_strings.dart';
import 'package:shopping_list/l10n/l10n.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/screens/settings_screen.dart';

Future<void> _pumpSettings(
  WidgetTester tester, {
  Future<bool> Function()? requestNotificationPermission,
}) async {
  await tester.pumpWidget(
    L10n(
      strings: ZhStrings(),
      language: AppLanguage.zh,
      child: MaterialApp(
        home: SettingsScreen(
          settings: AppSettings(),
          onChanged: (_) {},
          language: AppLanguage.zh,
          onLanguageChanged: (_) {},
          shelfZones: defaultShelfZones,
          onReorderShelfZones: (_, _) {},
          shelfCodeOrder: const [],
          onReorderShelfCodes: (_, _) {},
          onAddShelfCode: (_) {},
          onDeleteShelfCode: (_) {},
          onRenameShelfCode: (_, _) {},
          categories: buildDefaultCategories(),
          onAddCategory: (name, color, zone, days) => buildDefaultCategories().fallback,
          onEditCategory: (_, _, _, _, _) {},
          onDeleteCategory: (_) {},
          onReorderCategories: (_, _) {},
          buildBackupBytes: () => <int>[],
          onImportBackup: (_) async {},
          requestNotificationPermission:
              requestNotificationPermission ?? () async => true,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
      'turning on the restock reminder shows the primer dialog before any '
      'system permission request', (tester) async {
    var requested = false;
    await _pumpSettings(tester, requestNotificationPermission: () async {
      requested = true;
      return true;
    });

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text(ZhStrings().notifPrimerTitle), findsOneWidget);
    expect(find.text(ZhStrings().notifPrimerMessage), findsOneWidget);
    // The dialog is up; the real permission request hasn't fired yet.
    expect(requested, isFalse);
  });

  testWidgets(
      'confirming the primer dialog requests the system notification '
      'permission', (tester) async {
    var requested = false;
    await _pumpSettings(tester, requestNotificationPermission: () async {
      requested = true;
      return true;
    });

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ZhStrings().notifPrimerConfirm));
    await tester.pumpAndSettle();

    expect(requested, isTrue);
  });

  testWidgets(
      'dismissing the primer dialog never requests the system permission',
      (tester) async {
    var requested = false;
    await _pumpSettings(tester, requestNotificationPermission: () async {
      requested = true;
      return true;
    });

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ZhStrings().cancel));
    await tester.pumpAndSettle();

    expect(requested, isFalse);
    expect(find.text(ZhStrings().notifPrimerTitle), findsNothing);
  });
}
