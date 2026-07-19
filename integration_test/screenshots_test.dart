// App Store screenshot capture. Seeds realistic sample data directly into
// Hive (bypassing the UI, since we just need the data to exist — not to test
// how it got there), then screenshots four screens: Jot, Budget, Plan and
// Inventory. Run via `fastlane screenshots` (see ios/fastlane/Fastfile),
// which drives this on each target simulator and pulls the PNGs out of the
// app's sandbox afterward.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/main.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/services/notification_service.dart';
import 'package:shopping_list/storage/app_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture App Store screenshots', (tester) async {
    await Hive.initFlutter();
    final repo = AppRepository();
    await repo.init();

    final categories = buildDefaultCategories();
    Category byId(String id) => categories.firstWhere((c) => c.id == id);
    final dairy = byId('dairy');
    final produce = byId('produce');
    final grain = byId('grain');
    final household = byId('household');

    await repo.saveCategories(categories);

    await repo.saveShoppingSimple([
      ShoppingItem(
        id: 'sim1',
        name: 'Milk',
        category: dairy,
        quantityLabel: '2',
      ),
      ShoppingItem(
        id: 'sim2',
        name: 'Bananas',
        category: produce,
        quantityLabel: '6',
      ),
      ShoppingItem(
        id: 'sim3',
        name: 'Bread',
        category: grain,
        quantityLabel: '1',
      ),
      ShoppingItem(
        id: 'sim4',
        name: 'Paper towels',
        category: household,
        quantityLabel: '2',
        checked: true,
      ),
      ShoppingItem(
        id: 'sim5',
        name: 'Eggs',
        category: dairy,
        quantityLabel: '12',
        checked: true,
      ),
    ]);

    await repo.saveShoppingSmart([
      ShoppingItem(
        id: 'sm1',
        name: 'Chicken breast',
        category: byId('meat'),
        quantityLabel: '1',
        shelfCode: 'B2',
        estimatedDays: 5,
      ),
      ShoppingItem(
        id: 'sm2',
        name: 'Rice',
        category: grain,
        quantityLabel: '1',
        shelfCode: 'A1',
        estimatedDays: 30,
      ),
      ShoppingItem(
        id: 'sm3',
        name: 'Olive oil',
        category: grain,
        quantityLabel: '1',
        shelfCode: 'A3',
        estimatedDays: 60,
      ),
      ShoppingItem(
        id: 'sm4',
        name: 'Yogurt',
        category: dairy,
        quantityLabel: '4',
        shelfCode: 'C1',
        estimatedDays: 10,
      ),
    ]);

    await repo.saveBudget([
      BudgetItem(id: 'b1', name: 'Milk', quantity: 2, unitPrice: 3.49),
      BudgetItem(id: 'b2', name: 'Bananas', quantity: 6, unitPrice: 0.29),
      BudgetItem(
        id: 'b3',
        name: 'Chicken breast',
        quantity: 1,
        unitPrice: 8.99,
      ),
      BudgetItem(id: 'b4', name: 'Bread', quantity: 1, unitPrice: 2.99),
      BudgetItem(id: 'b5', name: 'Olive oil', quantity: 1, unitPrice: 12.5),
    ]);

    final now = DateTime.now();
    await repo.saveInventory([
      InventoryItem(
        id: 'inv1',
        name: 'Rice',
        category: grain,
        shelfCode: 'A1',
        quantityLabel: '1',
        purchasedAt: now.subtract(const Duration(days: 5)),
        estimatedDays: 30,
      ),
      InventoryItem(
        id: 'inv2',
        name: 'Milk',
        category: dairy,
        shelfCode: 'C1',
        quantityLabel: '1',
        purchasedAt: now.subtract(const Duration(days: 6)),
        estimatedDays: 7,
      ),
      InventoryItem(
        id: 'inv3',
        name: 'Paper towels',
        category: household,
        shelfCode: 'D2',
        quantityLabel: '2',
        purchasedAt: now.subtract(const Duration(days: 20)),
        estimatedDays: 45,
      ),
      InventoryItem(
        id: 'inv4',
        name: 'Olive oil',
        category: grain,
        shelfCode: 'A3',
        quantityLabel: '1',
        purchasedAt: now.subtract(const Duration(days: 10)),
        estimatedDays: 60,
      ),
    ]);

    final notifications = NotificationService();
    try {
      await notifications.init();
    } catch (_) {
      // No-op in the simulator environment used for screenshots.
    }

    final repaintKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: repaintKey,
        child: ShoppingListApp(
          initialLanguage: AppLanguage.en,
          repository: repo,
          notifications: notifications,
          storageAvailable: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> shoot(String name) async {
      await tester.pumpAndSettle();
      final boundary =
          repaintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: tester.view.devicePixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory('${dir.path}/screenshots');
      await outDir.create(recursive: true);
      await File(
        '${outDir.path}/$name.png',
      ).writeAsBytes(byteData!.buffer.asUint8List());
    }

    // Jot mode is the default tab/mode on launch.
    await shoot('01_jot');

    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();
    await shoot('02_budget');

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    await shoot('03_plan');

    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    await shoot('04_inventory');

    // `flutter test` uninstalls the app (and its sandboxed container, where
    // the screenshots above were just written) the instant this test
    // finishes. Hold the line long enough for the host-side fastlane lane to
    // `simctl get_app_container` + copy the files out before that teardown.
    // ignore: avoid_print
    print('SCREENSHOTS_READY');
    await Future.delayed(const Duration(seconds: 45));
  });
}
