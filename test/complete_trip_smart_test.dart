import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/l10n/app_strings.dart';
import 'package:shopping_list/main.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/services/notification_service.dart';
import 'package:shopping_list/storage/app_repository.dart';
import 'package:shopping_list/storage/hive_models.dart';

// Regression test for the "complete trip" flow in the Plan/smart list:
// unselected items must remain in the smart list, not be wiped along with
// the purchased ones (the confirmation sheet's own copy promises this).
void main() {
  late Directory tempDir;
  late AppRepository repository;

  setUp(() async {
    // Skip the first-run onboarding tutorial overlay (index 4 = done) so it
    // doesn't intercept taps meant for the underlying screen.
    SharedPreferences.setMockInitialValues({'tutorial_step': 4});
    tempDir = await Directory.systemTemp.createTemp('hive_trip_test_');
    Hive.init(tempDir.path);

    // Pre-seed categories so the repository sees this as an already-set-up
    // install (categoriesBox non-empty) — otherwise AppRepository.load()
    // treats it as a first install and overwrites shopping_smart with an
    // empty list, wiping the smart items seeded below.
    final category = buildDefaultCategories().first; // 'produce' / 果蔬
    final categoriesBox = await Hive.openBox('categories');
    await categoriesBox.put(
        'items', buildDefaultCategories().map((c) => c.toMap()).toList());
    await categoriesBox.close();

    // Pre-seed three smart/plan items before the app's own repository.load()
    // reads them back, so the trip-completion flow has something to select
    // from. Two purchased items avoids the single-item-purchased toast (and
    // its pending timer), which isn't what this test is about.
    final box = await Hive.openBox('shopping_smart');
    await box.put('items', [
      ShoppingItem(
        id: 'buy_this_1',
        name: '苹果',
        category: category,
        quantityLabel: '2',
        shelfZone: category.shelfZone,
        estimatedDays: 7,
      ).toMap(),
      ShoppingItem(
        id: 'buy_this_2',
        name: '香蕉',
        category: category,
        quantityLabel: '3',
        shelfZone: category.shelfZone,
        estimatedDays: 7,
      ).toMap(),
      ShoppingItem(
        id: 'keep_this',
        name: '牛奶',
        category: category,
        quantityLabel: '1',
        shelfZone: category.shelfZone,
        estimatedDays: 7,
      ).toMap(),
    ]);
    await box.close();

    repository = AppRepository();
    await repository.init();
    await repository.load(lang: Lang.zh);
  });

  tearDown(() {
    // The confirm-trip tap triggers real (unawaited) Hive writes, which may
    // still be in flight here. `Hive.deleteFromDisk()` waits on those boxes
    // closing, but tearDown runs inside the same fake-async zone as the test
    // body, where that real I/O never advances — it hangs indefinitely. Each
    // test gets its own throwaway temp directory, so skip Hive's own
    // close-all-boxes bookkeeping and just delete the directory directly.
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets(
      'completing a trip keeps unselected items in the smart list',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ShoppingListApp(
        initialLanguage: AppLanguage.zh,
        repository: repository,
        notifications: NotificationService(),
      ),
    );

    for (var i = 0;
        i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final l = ZhStrings();

    // Switch to Plan/smart mode. The mode-toggle segment button shares its
    // label with the screen's header title, so target the GestureDetector
    // that wraps the segment's text instead of the ambiguous Text finder.
    await tester.tap(find.ancestor(
        of: find.text(l.modeSmart), matching: find.byType(GestureDetector)));
    await tester.pumpAndSettle();

    expect(find.text('苹果'), findsOneWidget);
    expect(find.text('香蕉'), findsOneWidget);
    expect(find.text('牛奶'), findsOneWidget);

    // Open the complete-trip confirmation sheet.
    await tester.tap(find.text(l.addToInventoryButton));
    await tester.pumpAndSettle();

    // Both items start selected; deselect '牛奶' (keep_this) so only '苹果'
    // (buy_this) is marked as purchased. '牛奶' also appears in the list
    // behind the sheet, so target the sheet's modal-route copy explicitly.
    await tester.tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.text('牛奶')));
    await tester.pumpAndSettle();

    // Confirming triggers real Hive writes (persistSmart/persistItems), which
    // fake-async pumping can't wait out — bridge with runAsync like the
    // initial load does.
    await tester.tap(
        find.widgetWithText(ElevatedButton, l.addToInventoryButton));
    await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    // The purchased items are gone from the Plan list, but the unselected
    // one must still be there for next time — this is the regression check:
    // the old code called smart.clear() unconditionally and would have
    // wiped '牛奶' too.
    expect(find.text('苹果'), findsNothing);
    expect(find.text('香蕉'), findsNothing);
    expect(find.text('牛奶'), findsOneWidget);
  });
}
