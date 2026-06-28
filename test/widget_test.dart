import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/main.dart';
import 'package:shopping_list/l10n/app_language.dart';

void main() {
  testWidgets('App smoke test (zh): renders bottom nav labels',
      (WidgetTester tester) async {
    // Use a tall iPhone-sized surface so the list content does not overflow
    // the default 800x600 test viewport.
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ShoppingListApp(initialLanguage: AppLanguage.zh),
    );
    await tester.pump();

    // The four bottom-nav labels for the zh locale.
    expect(find.text('清单'), findsOneWidget);
    expect(find.text('库存'), findsOneWidget);
    expect(find.text('提醒'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('App smoke test (en): renders bottom nav labels',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ShoppingListApp(initialLanguage: AppLanguage.en),
    );
    await tester.pump();

    expect(find.text('List'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
