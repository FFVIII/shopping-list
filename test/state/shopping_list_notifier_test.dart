import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/state/shopping_list_notifier.dart';
import 'package:shopping_list/storage/app_repository.dart';

void main() {
  late Directory tempDir;
  late AppRepository repo;
  late ShoppingListNotifier notifier;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    repo = AppRepository();
    await repo.init();
    final data = await repo.load(lang: Lang.zh);
    notifier = ShoppingListNotifier(repo)..load(data);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('recordBudgetPurchase creates an entry with the correct snapshot and total',
      () {
    final snapshot = [
      BudgetItem(id: 'b1', name: '牛奶', quantity: 2, unitPrice: 8.5),
      BudgetItem(id: 'b2', name: '鸡蛋', quantity: 1, unitPrice: 12.0),
    ];

    notifier.recordBudgetPurchase(snapshot);

    expect(notifier.budgetHistory.length, 1);
    final entry = notifier.budgetHistory.single;
    expect(entry.items.length, 2);
    expect(entry.items[0].name, '牛奶');
    expect(entry.totalAmount, 2 * 8.5 + 1 * 12.0);
  });

  test('recordBudgetPurchase inserts the newest entry at the head of the list',
      () {
    notifier.recordBudgetPurchase(
        [BudgetItem(id: 'b1', name: '第一次', quantity: 1, unitPrice: 1)]);
    notifier.recordBudgetPurchase(
        [BudgetItem(id: 'b2', name: '第二次', quantity: 1, unitPrice: 1)]);

    expect(notifier.budgetHistory.length, 2);
    expect(notifier.budgetHistory.first.items.single.name, '第二次');
    expect(notifier.budgetHistory.last.items.single.name, '第一次');
  });

  test('recordBudgetPurchase with an empty snapshot does not create an entry',
      () {
    notifier.recordBudgetPurchase(const []);

    expect(notifier.budgetHistory, isEmpty);
  });

  test('deleteBudgetHistoryEntry removes only the matching entry', () {
    notifier.recordBudgetPurchase(
        [BudgetItem(id: 'b1', name: '保留', quantity: 1, unitPrice: 1)]);
    notifier.recordBudgetPurchase(
        [BudgetItem(id: 'b2', name: '删除', quantity: 1, unitPrice: 1)]);
    final toDelete = notifier.budgetHistory
        .firstWhere((e) => e.items.single.name == '删除');

    notifier.deleteBudgetHistoryEntry(toDelete.id);

    expect(notifier.budgetHistory.length, 1);
    expect(notifier.budgetHistory.single.items.single.name, '保留');
  });
}
