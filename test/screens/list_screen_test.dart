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
  VoidCallback? onCompleteSimple,
  void Function(List<String> ids)? onCompleteSmart,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    L10n(
      strings: ZhStrings(),
      language: AppLanguage.zh,
      child: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
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
            onCompleteSimple: onCompleteSimple ?? () {},
            onCompleteSmart: onCompleteSmart ?? (_) {},
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
            onAddCategory: (_, _, _, _) => _category('new'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('simple mode renders each pending item name', (tester) async {
    await _pumpList(
      tester,
      simpleItems: [_simple('a', '牛奶'), _simple('b', '鸡蛋')],
    );

    expect(find.text('牛奶'), findsOneWidget);
    expect(find.text('鸡蛋'), findsOneWidget);
  });

  testWidgets('tapping a pending item calls onToggleSimple with its id', (
    tester,
  ) async {
    String? toggled;
    await _pumpList(
      tester,
      simpleItems: [_simple('a', '牛奶')],
      onToggleSimple: (id) => toggled = id,
    );

    await tester.tap(find.text('牛奶'));
    expect(toggled, 'a');
  });

  testWidgets(
    'submitting the add bar calls onAddSimple with the trimmed name',
    (tester) async {
      final added = <String>[];
      await _pumpList(tester, onAddSimple: added.add);

      await tester.enterText(find.byType(TextField), '  面包  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(added, ['面包']);
      // Field clears after a successful add.
      expect(find.text('  面包  '), findsNothing);
    },
  );

  testWidgets('submitting a blank name does not call onAddSimple', (
    tester,
  ) async {
    final added = <String>[];
    await _pumpList(tester, onAddSimple: added.add);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(seconds: 2));

    expect(added, isEmpty);
  });

  testWidgets(
    'pressing the keyboard done key on a blank field just dismisses it, '
    'no "enter a name" toast',
    (tester) async {
      // Regression test: the add bar's onSubmitted used to call the same
      // validation path as the "+" button, so pressing the keyboard's return
      // key with nothing typed (i.e. just trying to close the keyboard) would
      // pop the "enter an item name" toast. It should now silently unfocus.
      await _pumpList(tester);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(seconds: 2));

      expect(find.text(ZhStrings().addItemNameRequired), findsNothing);
    },
  );

  testWidgets('tapping the + button with a blank name shows the toast', (
    tester,
  ) async {
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
    },
  );

  // ── Smart mode (reached via the mode toggle; '计划' = modeSmart in zh) ────────

  testWidgets('switching to smart mode renders smart item names', (
    tester,
  ) async {
    await _pumpList(tester, smartItems: [_smart('a', '牛奶'), _smart('b', '鸡蛋')]);

    await tester.tap(find.text('计划'));
    await tester.pumpAndSettle();

    expect(find.text('牛奶'), findsOneWidget);
    expect(find.text('鸡蛋'), findsOneWidget);
  });

  testWidgets('tapping a smart item calls onToggleSmart with its id', (
    tester,
  ) async {
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

  testWidgets('batch-selecting a smart item and tapping "Mark bought" calls '
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

  testWidgets('switching to budget mode renders budget item names', (
    tester,
  ) async {
    await _pumpList(
      tester,
      budgetItems: [_budget('a', '牛奶'), _budget('b', '鸡蛋')],
    );

    await tester.tap(find.text('记账'));
    await tester.pumpAndSettle();

    expect(find.text('牛奶'), findsOneWidget);
    expect(find.text('鸡蛋'), findsOneWidget);
  });

  // ── Dynamic Type / text scaling ──────────────────────────────────────────

  testWidgets(
    'renders without layout exceptions at a large system text scale',
    (tester) async {
      await _pumpList(
        tester,
        // Checked so the "Clear" header pill actually renders — otherwise
        // this wouldn't exercise the header-pill overflow fix at all.
        simpleItems: [_simple('a', '牛奶', checked: true)],
        smartItems: [_smart('b', '鸡蛋')],
        budgetItems: [_budget('c', '面包')],
        textScaler: const TextScaler.linear(3.0),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('记账'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('计划'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the header action pill hugs the right edge, not the row midpoint',
    (tester) async {
      // Regression test: wrapping the header title in Expanded and the pill
      // in Flexible (both flex:1, with nothing else flexible between them)
      // makes them split the whole row 50/50 instead of "title takes what's
      // left after the pill's own natural width" — the pill ends up stuck
      // around the row's midpoint instead of hugging the right edge.
      await _pumpList(
          tester, simpleItems: [_simple('a', '牛奶', checked: true)]);

      final screenWidth = tester
          .getTopRight(find.byType(MaterialApp))
          .dx;
      final pillRight = tester.getTopRight(find.text('清空')).dx;

      expect(pillRight, greaterThan(screenWidth * 0.7));
    },
  );

  // ── Trip-completion celebration ──────────────────────────────────────────

  testWidgets(
    'completing a simple-mode trip shows the completion celebration',
    (tester) async {
      var completed = false;
      await _pumpList(
        tester,
        simpleItems: [_simple('a', '牛奶', checked: true)],
        onCompleteSimple: () => completed = true,
      );

      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZhStrings().delete));
      await tester.pump();

      expect(completed, isTrue);
      expect(find.text(ZhStrings().tripCompletedCelebration), findsOneWidget);
    },
  );

  testWidgets(
    'the "Clear" button is hidden in simple mode until something is checked',
    (tester) async {
      // Regression test: the button used to show (and be tappable, opening a
      // "0 bought item(s)" dialog that did nothing useful) as soon as the
      // list had any items at all, checked or not.
      await _pumpList(tester, simpleItems: [_simple('a', '牛奶')]);
      expect(find.text('清空'), findsNothing);
    },
  );

  testWidgets(
    'completing a smart-mode trip shows the completion celebration',
    (tester) async {
      List<String>? completedIds;
      await _pumpList(
        tester,
        smartItems: [_smart('a', '牛奶')],
        onCompleteSmart: (ids) => completedIds = ids,
      );

      await tester.tap(find.text('计划'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZhStrings().addToInventoryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(
          ElevatedButton, ZhStrings().addToInventoryButton));
      await tester.pump();

      expect(completedIds, ['a']);
      expect(find.text(ZhStrings().tripCompletedCelebration), findsOneWidget);
    },
  );

  testWidgets(
    'the add-to-inventory sheet stays on screen and its Save button is '
    'reachable with many items', (tester) async {
      // Regression test: with enough items the sheet's content used to grow
      // taller than the screen with nothing capping it, pushing the header
      // off the top and leaving no way to scroll down to the Save button.
      final many = List.generate(30, (i) => _smart('id$i', 'item$i'));
      await _pumpList(tester, smartItems: many);

      await tester.tap(find.text('计划'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZhStrings().addToInventoryButton));
      await tester.pumpAndSettle();

      final screenHeight =
          tester.getBottomRight(find.byType(MaterialApp)).dy;
      final titleTop = tester
          .getTopLeft(find.text(ZhStrings().addToInventoryButton).last)
          .dy;
      // The header must not be pushed above the visible screen.
      expect(titleTop, greaterThanOrEqualTo(0));

      final saveButton = find.widgetWithText(
          ElevatedButton, ZhStrings().addToInventoryButton);
      final buttonBottom = tester.getBottomRight(saveButton).dy;
      // The Save button must be within the visible screen, not off the
      // bottom edge.
      expect(buttonBottom, lessThanOrEqualTo(screenHeight));

      await tester.tap(saveButton);
      await tester.pump();
      expect(find.text(ZhStrings().tripCompletedCelebration), findsOneWidget);
    },
  );

  // ── Budget add-expense sheet ──────────────────────────────────────────────

  testWidgets(
    'opening the add-expense sheet after typing a name focuses price, not '
    'quantity', (tester) async {
      await _pumpList(tester);

      await tester.tap(find.text('记账'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '牛奶');
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      final focused = tester.widgetList<TextField>(find.byType(TextField)).where(
          (w) => w.focusNode?.hasFocus ?? false);
      expect(focused, hasLength(1));
      expect(focused.single.decoration?.hintText, ZhStrings().currencySymbol);
    },
  );
}
