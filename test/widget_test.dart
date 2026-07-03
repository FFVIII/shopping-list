import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/main.dart';
import 'package:shopping_list/services/notification_service.dart';
import 'package:shopping_list/storage/app_repository.dart';

void main() {
  late Directory tempDir;
  late AppRepository repository;

  setUp(() async {
    // _loadData() now also calls TutorialController.resolveInitialStep(),
    // which reads TutorialStore (backed by shared_preferences) — mock it so
    // the platform channel call doesn't throw MissingPluginException.
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('hive_widget_test_');
    Hive.init(tempDir.path);
    repository = AppRepository();
    await repository.init();
    // Pre-seed so the widget's own AppRepository.load() call (made from
    // _loadData() during the test) hits the fast already-seeded path rather
    // than performing the slower first-install writes.
    await repository.load(lang: Lang.zh);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('App smoke test (zh): renders bottom nav labels',
      (WidgetTester tester) async {
    // Use a tall iPhone-sized surface so the list content does not overflow
    // the default 800x600 test viewport.
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ShoppingListApp(
        initialLanguage: AppLanguage.zh,
        repository: repository,
        // Never init()ed in tests: reschedule() no-ops without touching
        // platform channels.
        notifications: NotificationService(),
      ),
    );
    // _loadData() awaits AppRepository.load(), which performs real dart:io
    // file I/O (Hive's VM backend). That never progresses inside
    // flutter_test's fake-async pump loop, so a plain pumpAndSettle() hangs
    // forever. runAsync opens a real-time window so the in-flight I/O can
    // complete; pump() then applies the resulting setState.
    for (var i = 0;
        i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

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
      ShoppingListApp(
        initialLanguage: AppLanguage.en,
        repository: repository,
        notifications: NotificationService(),
      ),
    );
    for (var i = 0;
        i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    expect(find.text('List'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
