import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/storage/app_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('first load seeds default categories but leaves items empty', () async {
    final repo = AppRepository();
    await repo.init();

    final data = await repo.load(lang: Lang.zh);

    expect(data.categories, isNotEmpty);
    expect(data.shoppingSmart, isEmpty);
    expect(data.inventory, isEmpty);
    expect(data.budget, isEmpty);
    expect(data.budgetHistory, isEmpty);
    expect(data.shoppingSimple, isEmpty);
    expect(data.shelfCodeOrder, isEmpty);
    expect(data.settings.reminderThresholdDays, 5);
  });

  test(
    'seeds canonical (zh) category names regardless of load language',
    () async {
      final repo = AppRepository();
      await repo.init();

      // Even when first loaded in English, category names are stored as the
      // canonical Chinese; the UI localizes them at display time via l.data().
      // Persisting translated names used to freeze them and break switching the
      // UI language later.
      final data = await repo.load(lang: Lang.en);

      final produce = data.categories.findById('produce');
      expect(produce, isNotNull);
      expect(produce!.name, '蔬菜');
    },
  );

  test('second load does not reseed — preserves saved changes', () async {
    final repo1 = AppRepository();
    await repo1.init();
    final firstData = await repo1.load(lang: Lang.zh);

    final edited = [
      ...firstData.shoppingSimple,
      ShoppingItem(
        id: 'manual_1',
        name: '手动添加',
        category: firstData.categories.fallback,
        quantityLabel: '',
      ),
    ];
    await repo1.saveShoppingSimple(edited);

    final repo2 = AppRepository();
    await repo2.init();
    final secondData = await repo2.load(lang: Lang.zh);

    expect(secondData.shoppingSimple.map((i) => i.id), contains('manual_1'));
    // Sample data must not have been regenerated a second time.
    expect(secondData.categories.length, firstData.categories.length);
  });

  test('saveCategories/saveSettings/saveShelfCodeOrder round-trip', () async {
    final repo = AppRepository();
    await repo.init();
    final data = await repo.load(lang: Lang.zh);

    final newSettings = AppSettings(
      reminderThresholdDays: 2,
      restockReminderEnabled: false,
      reminderHour: 7,
      reminderMinute: 45,
    );
    await repo.saveSettings(newSettings);
    await repo.saveShelfCodeOrder(['货架A1', '货架B2']);

    final repo2 = AppRepository();
    await repo2.init();
    final reloaded = await repo2.load(lang: Lang.zh);

    expect(reloaded.settings.reminderThresholdDays, 2);
    expect(reloaded.settings.reminderHour, 7);
    expect(reloaded.shelfCodeOrder, ['货架A1', '货架B2']);
  });

  test('saveHistory persists and round-trips budget history entries', () async {
    final repo = AppRepository();
    await repo.init();
    await repo.load(lang: Lang.zh);

    final entry = BudgetHistoryEntry(
      id: 'hist_1',
      clearedAt: DateTime(2026, 7, 13, 9, 0),
      items: [BudgetHistoryLineItem(name: '牛奶', quantity: 2, unitPrice: 8.5)],
    );
    await repo.saveHistory([entry]);

    final repo2 = AppRepository();
    await repo2.init();
    final reloaded = await repo2.load(lang: Lang.zh);

    expect(reloaded.budgetHistory.single.id, 'hist_1');
    expect(reloaded.budgetHistory.single.items.single.name, '牛奶');
    expect(reloaded.budgetHistory.single.totalAmount, 17.0);
  });

  test('replaceAll overwrites every collection', () async {
    final repo = AppRepository();
    await repo.init();
    await repo.load(lang: Lang.zh); // seeds sample data

    final categories = buildDefaultCategories();
    final replacement = AppData(
      shoppingSimple: [],
      shoppingSmart: [],
      inventory: [],
      budget: [BudgetItem(id: 'only', name: '替换', quantity: 2, unitPrice: 3.5)],
      budgetHistory: [
        BudgetHistoryEntry(
          id: 'h1',
          clearedAt: DateTime(2026, 1, 1),
          items: [
            BudgetHistoryLineItem(name: '旧记录', quantity: 1, unitPrice: 1),
          ],
        ),
      ],
      categories: categories,
      settings: AppSettings(
        reminderThresholdDays: 1,
        restockReminderEnabled: false,
        reminderHour: 6,
        reminderMinute: 15,
      ),
      shelfCodeOrder: ['A1'],
    );
    await repo.replaceAll(replacement);

    final reloaded = await repo.load(lang: Lang.zh);
    expect(reloaded.shoppingSmart, isEmpty);
    expect(reloaded.inventory, isEmpty);
    expect(reloaded.budget.single.name, '替换');
    expect(reloaded.budgetHistory.single.id, 'h1');
    expect(reloaded.settings.reminderHour, 6);
    expect(reloaded.settings.restockReminderEnabled, false);
    expect(reloaded.shelfCodeOrder, ['A1']);
  });

  test('isPro persists across load calls and defaults to false', () async {
    final repo = AppRepository();
    await repo.init();

    expect(await repo.loadIsPro(), isFalse);

    await repo.saveIsPro(true);
    expect(await repo.loadIsPro(), isTrue);

    // Simulates an app restart against the same on-disk box.
    final repo2 = AppRepository();
    await repo2.init();
    expect(await repo2.loadIsPro(), isTrue);
  });
}
