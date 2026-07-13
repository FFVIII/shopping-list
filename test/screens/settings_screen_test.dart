import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/l10n/app_strings.dart';
import 'package:shopping_list/l10n/l10n.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/screens/settings_screen.dart';
import 'package:shopping_list/services/purchase_service.dart';

Future<void> _pumpSettings(WidgetTester tester,
    {required bool isPro}) async {
  final purchaseService = PurchaseService()..isPro = isPro;

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
          requestNotificationPermission: () async => true,
          purchaseService: purchaseService,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Data section hidden and Pro card shown when not purchased',
      (tester) async {
    await _pumpSettings(tester, isPro: false);

    expect(find.text(ZhStrings().sectionData), findsNothing);
    expect(find.text(ZhStrings().proUpgrade), findsOneWidget);
  });

  testWidgets('Data section shown and Pro card hidden once purchased',
      (tester) async {
    await _pumpSettings(tester, isPro: true);

    expect(find.text(ZhStrings().sectionData), findsOneWidget);
    expect(find.text(ZhStrings().proUpgrade), findsNothing);
  });
}
