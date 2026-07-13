import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/l10n/app_strings.dart';
import 'package:shopping_list/l10n/l10n.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/screens/list_screen.dart';
import 'package:shopping_list/widgets/drag_handle.dart';

// Characterization tests for ListScreen's default (simple) mode. The screen
// takes plain data + callbacks, so it can be pumped in isolation without Hive
// or platform channels (voice input is compiled off via _voiceInputEnabled).
// These lock in the add/toggle wiring before any future split of the
// 969-line list_screen.dart.

Category _category(String id) => Category(
      id: id,
      name: id,
      color: const Color(0xFF000000),
      bgColor: const Color(0xFFFFFFFF),
      shelfZone: '其他',
      defaultDays: 7,
    );

ShoppingItem _simple(String id, String name, {bool checked = false}) =>
    ShoppingItem(
      id: id,
      name: name,
      category: _category('other'),
      quantityLabel: '1',
      shelfZone: '其他',
      checked: checked,
    );

ShoppingItem _smart(String id, String name) => ShoppingItem(
      id: id,
      name: name,
      category: _category('other'),
      quantityLabel: '1',
      shelfZone: '其他',
      estimatedDays: 7,
    );

BudgetItem _budget(String id, String name) =>
    BudgetItem(id: id, name: name, quantity: 1, unitPrice: 10);

/// Pumps [ListScreen] wrapped in the minimum ancestors it needs (L10n +
/// MaterialApp) at an iPhone-sized surface. Every callback defaults to a
/// no-op; tests override only the ones they assert on.
Future<void> _pumpList(
  WidgetTester tester, {
  List<ShoppingItem> simpleItems = const [],
  List<ShoppingItem> smartItems = const [],
  List<BudgetItem> budgetItems = const [],
  void Function(String id)? onToggleSimple,
  void Function(String id)? onToggleSmart,
  void Function(String name)? onAddSimple,
  void Function(List<String> ids)? onBatchDeleteSimple,
  void Function(List<String> ids)? onBatchMarkBought,
}) async {
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    L10n(
      strings: ZhStrings(),
      language: AppLanguage.zh,
      child: MaterialApp(
        home: ListScreen(
          simpleItems: simpleItems,
          smartItems: smartItems,
          categories: [_category('other')],
          onToggleSimple: onToggleSimple ?? (_) {},
          onToggleSmart: onToggleSmart ?? (_) {},
          onAddSimple: onAddSimple ?? (_) {},
          onAddSmart: (_, _, _, _, _, _) {},
          onDeleteSimple: (_) {},
          onDeleteSmart: (_) {},
          onCompleteSimple: () {},
          onCompleteSmart: (_) {},
          onReorderSimple: (_) {},
          onReorderSmart: (_, _, _, _, _) {},
          onRenameSimple: (_, _) {},
          onEditSmart: (_, _, _, _, _, _) {},
          budgetItems: budgetItems,
          onAddBudget: (_, _, _) {},
          onEditBudget: (_, _, _, _) {},
          onDeleteBudget: (_) {},
          onReorderBudget: (_) {},
          onBatchDeleteSimple: onBatchDeleteSimple ?? (_) {},
          onBatchDeleteSmart: (_) {},
          onBatchMarkBought: onBatchMarkBought ?? (_) {},
          onBatchDeleteBudget: (_) {},
          smartModeRequest: 0,
          shelfCodeOrder: const [],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('simple mode renders each pending item name', (tester) async {
    await _pumpList(tester, simpleItems: [
      _simple('a', '牛奶'),
      _simple('b', '鸡蛋'),
    ]);

    expect(find.text('牛奶'), findsOneWidget);
    expect(find.text('鸡蛋'), findsOneWidget);
  });

  testWidgets('tapping a pending item calls onToggleSimple with its id',
      (tester) async {
    String? toggled;
    await _pumpList(
      tester,
      simpleItems: [_simple('a', '牛奶')],
      onToggleSimple: (id) => toggled = id,
    );

    await tester.tap(find.text('牛奶'));
    expect(toggled, 'a');
  });

  testWidgets('submitting the add bar calls onAddSimple with the trimmed name',
      (tester) async {
    final added = <String>[];
    await _pumpList(tester, onAddSimple: added.add);

    await tester.enterText(find.byKey(const Key('list_add_bar_field')), '  面包  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(added, ['面包']);
    // Field clears after a successful add.
    expect(find.text('  面包  '), findsNothing);
  });

  testWidgets('submitting a blank name does not call onAddSimple',
      (tester) async {
    final added = <String>[];
    await _pumpList(tester, onAddSimple: added.add);

    await tester.enterText(find.byKey(const Key('list_add_bar_field')), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(seconds: 2));

    expect(added, isEmpty);
  });

  testWidgets(
      'pressing the keyboard done key on a blank field just dismisses it, '
      'no "enter a name" toast', (tester) async {
    // Regression test: the add bar's onSubmitted used to call the same
    // validation path as the "+" button, so pressing the keyboard's return
    // key with nothing typed (i.e. just trying to close the keyboard) would
    // pop the "enter an item name" toast. It should now silently unfocus.
    await _pumpList(tester);

    await tester.tap(find.byKey(const Key('list_add_bar_field')));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text(ZhStrings().addItemNameRequired), findsNothing);
  });

  testWidgets('tapping the + button with a blank name shows the toast',
      (tester) async {
    // The explicit add button is a deliberate action, unlike the keyboard's
    // return key, so it should still validate and show the toast.
    await _pumpList(tester);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();

    expect(find.text(ZhStrings().addItemNameRequired), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
      'batch-selecting a simple item and deleting it calls onBatchDeleteSimple',
      (tester) async {
    List<String>? deletedIds;
    await _pumpList(
      tester,
      simpleItems: [_simple('a', '牛奶')],
      onBatchDeleteSimple: (ids) => deletedIds = ids,
    );

    // Tap the row's drag handle to enter batch mode with this item selected.
    await tester.tap(find.byType(DragHandle));
    await tester.pump();

    expect(find.text(ZhStrings().selectedCount(1)), findsOneWidget);

    await tester.tap(find.text(ZhStrings().delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ZhStrings().delete).last);
    await tester.pumpAndSettle();

    expect(deletedIds, ['a']);
  });

  // ── Smart mode (reached via the mode toggle; '计划' = modeSmart in zh) ────────

  testWidgets('switching to smart mode renders smart item names',
      (tester) async {
    await _pumpList(tester, smartItems: [
      _smart('a', '牛奶'),
      _smart('b', '鸡蛋'),
    ]);

    await tester.tap(find.text('计划'));
    await tester.pumpAndSettle();

    expect(find.text('牛奶'), findsOneWidget);
    expect(find.text('鸡蛋'), findsOneWidget);
  });

  testWidgets('tapping a smart item calls onToggleSmart with its id',
      (tester) async {
    String? toggled;
    await _pumpList(
      tester,
      smartItems: [_smart('a', '牛奶')],
      onToggleSmart: (id) => toggled = id,
    );

    await tester.tap(find.text('计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('牛奶'));

    expect(toggled, 'a');
  });

  testWidgets(
      'batch-selecting a smart item and tapping "Mark bought" calls '
      'onBatchMarkBought', (tester) async {
    List<String>? markedIds;
    await _pumpList(
      tester,
      smartItems: [_smart('a', '牛奶')],
      onBatchMarkBought: (ids) => markedIds = ids,
    );

    await tester.tap(find.text('计划'));
    await tester.pumpAndSettle();

    // Tap the row's drag handle to enter batch mode with this item selected.
    await tester.tap(find.byType(DragHandle));
    await tester.pump();

    expect(find.text(ZhStrings().batchMarkBought), findsOneWidget);

    await tester.tap(find.text(ZhStrings().batchMarkBought));
    await tester.pump();

    expect(markedIds, ['a']);
  });

  // ── Budget mode ('记账' = budgetMode in zh) ──────────────────────────────────

  testWidgets('switching to budget mode renders budget item names',
      (tester) async {
    await _pumpList(tester, budgetItems: [
      _budget('a', '牛奶'),
      _budget('b', '鸡蛋'),
    ]);

    await tester.tap(find.text('记账'));
    await tester.pumpAndSettle();

    expect(find.text('牛奶'), findsOneWidget);
    expect(find.text('鸡蛋'), findsOneWidget);
  });

  // ── Search ────────────────────────────────────────────────────────────────

  testWidgets('searching in simple mode filters to matching items',
      (tester) async {
    await _pumpList(tester, simpleItems: [
      _simple('a', '牛奶'),
      _simple('b', '鸡蛋'),
    ]);

    await tester.enterText(find.byKey(const Key('list_search_field')), '牛');
    await tester.pump();

    expect(find.text('牛奶'), findsOneWidget);
    expect(find.text('鸡蛋'), findsNothing);
  });

  testWidgets('clearing the simple-mode search restores the full list',
      (tester) async {
    await _pumpList(tester, simpleItems: [
      _simple('a', '牛奶'),
      _simple('b', '鸡蛋'),
    ]);

    await tester.enterText(find.byKey(const Key('list_search_field')), '牛');
    await tester.pump();
    expect(find.text('鸡蛋'), findsNothing);

    await tester.enterText(find.byKey(const Key('list_search_field')), '');
    await tester.pump();

    expect(find.text('牛奶'), findsOneWidget);
    expect(find.text('鸡蛋'), findsOneWidget);
  });

  testWidgets('searching in simple mode with no matches shows the no-results state',
      (tester) async {
    await _pumpList(tester, simpleItems: [_simple('a', '牛奶')]);

    await tester.enterText(
        find.byKey(const Key('list_search_field')), '不存在的东西');
    await tester.pump();

    expect(find.text('牛奶'), findsNothing);
    expect(find.text(ZhStrings().searchNoResults('不存在的东西')), findsOneWidget);
  });

  testWidgets('searching in smart mode filters to matching items',
      (tester) async {
    await _pumpList(tester, smartItems: [
      _smart('a', '牛奶'),
      _smart('b', '鸡蛋'),
    ]);

    await tester.tap(find.text('计划'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('list_search_field')), '蛋');
    await tester.pump();

    expect(find.text('鸡蛋'), findsOneWidget);
    expect(find.text('牛奶'), findsNothing);
  });

  testWidgets('searching in budget mode filters to matching items',
      (tester) async {
    await _pumpList(tester, budgetItems: [
      _budget('a', '牛奶'),
      _budget('b', '鸡蛋'),
    ]);

    await tester.tap(find.text('记账'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('list_search_field')), '蛋');
    await tester.pump();

    expect(find.text('鸡蛋'), findsOneWidget);
    expect(find.text('牛奶'), findsNothing);
  });
}
