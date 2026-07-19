import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/l10n/app_strings.dart';
import 'package:shopping_list/l10n/l10n.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/screens/list_screen.dart';
import 'package:shopping_list/services/purchase_service.dart';
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
  defaultDays: 7,
);

ShoppingItem _simple(String id, String name, {bool checked = false}) =>
    ShoppingItem(
      id: id,
      name: name,
      category: _category('other'),
      quantityLabel: '1',
      checked: checked,
    );

ShoppingItem _smart(String id, String name, {String? shelfCode}) =>
    ShoppingItem(
      id: id,
      name: name,
      category: _category('other'),
      quantityLabel: '1',
      shelfCode: shelfCode,
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
  void Function(List<String> ids)? onBatchDeleteSmart,
  VoidCallback? onCompleteSimple,
  void Function(List<String> ids)? onCompleteSmart,
  void Function(List<BudgetItem> snapshot)? onRecordBudgetPurchase,
  void Function(List<String> ids)? onBatchDeleteBudget,
  void Function(String, Category?, List<String>, String?)? onReorderSmart,
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
            onAddSmart: (_, _, _, _, _, {unitPrice}) {},
            onDeleteSimple: (_) {},
            onDeleteSmart: (_) {},
            onCompleteSimple: onCompleteSimple ?? () {},
            onCompleteSmart: onCompleteSmart ?? (_) {},
            onReorderSimple: (_) {},
            onReorderSmart: onReorderSmart ?? (_, _, _, _) {},
            onRenameSimple: (_, _) {},
            onEditSmart: (_, _, _, _, _, {unitPrice}) {},
            budgetItems: budgetItems,
            onAddBudget: (_, _, _) {},
            onEditBudget: (_, _, _, _) {},
            onDeleteBudget: (_) {},
            onReorderBudget: (_) {},
            onRecordBudgetPurchase: onRecordBudgetPurchase ?? (_) {},
            onBatchDeleteSimple: onBatchDeleteSimple ?? (_) {},
            onBatchDeleteSmart: onBatchDeleteSmart ?? (_) {},
            onBatchDeleteBudget: onBatchDeleteBudget ?? (_) {},
            smartModeRequest: 0,
            shelfCodeOrder: const [],
            onAddCategory: (_, _, _) => _category('new'),
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

  testWidgets(
    'batch-selecting a smart item and deleting it calls onBatchDeleteSmart',
    (tester) async {
      List<String>? deletedIds;
      await _pumpList(
        tester,
        smartItems: [_smart('a', '牛奶')],
        onBatchDeleteSmart: (ids) => deletedIds = ids,
      );

      await tester.tap(find.text('计划'));
      await tester.pumpAndSettle();

      // Tap the row's drag handle to enter batch mode with this item
      // selected. The smart batch bar (unlike simple/budget) doesn't show
      // a "selected N" count label, so there's nothing to assert there.
      await tester.tap(find.byType(DragHandle));
      await tester.pump();

      await tester.tap(find.text(ZhStrings().delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZhStrings().delete).last);
      await tester.pumpAndSettle();

      expect(deletedIds, ['a']);
    },
  );

  testWidgets(
    'Save in batch mode only commits the selection — it does NOT purchase; '
    'only Add writes to inventory',
    (tester) async {
      // Save persists "which items are checked" into the trip-selection and
      // exits batch mode. It must not call onCompleteSmart (no inventory
      // write). Only the later Add button does that, reading whatever Save
      // committed.
      List<String>? completedIds;
      await _pumpList(
        tester,
        smartItems: [_smart('a', '牛奶'), _smart('b', '鸡蛋')],
        onCompleteSmart: (ids) => completedIds = ids,
      );

      await tester.tap(find.text('计划'));
      await tester.pumpAndSettle();

      // Enter batch mode (both selected), deselect b, then Save.
      await tester.tap(find.byType(DragHandle).first);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_rounded).last);
      await tester.pump();
      await tester.tap(find.text(ZhStrings().batchSave));
      await tester.pump();

      // Save purchased nothing and left batch mode.
      expect(completedIds, isNull);
      expect(find.text(ZhStrings().batchSave), findsNothing);

      // Now Add completes the trip using exactly what Save committed (just a).
      await tester.tap(find.text(ZhStrings().addToInventoryButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ElevatedButton, ZhStrings().addToInventoryButton),
      );
      await tester.pump();

      expect(completedIds, ['a']);
      await tester.pump(const Duration(milliseconds: 1600));
    },
  );

  testWidgets(
    'deselecting an item in batch mode survives exiting and re-entering '
    'batch mode',
    (tester) async {
      // Regression test: _enterSmartBatchWithItem used to unconditionally
      // reset _smartSelected to "everything selected" every time batch mode
      // was entered, silently reselecting anything the user had deselected
      // and then exited (via Cancel) without acting on.
      await _pumpList(
        tester,
        smartItems: [_smart('a', '牛奶'), _smart('b', '鸡蛋')],
      );

      await tester.tap(find.text('计划'));
      await tester.pumpAndSettle();

      // Enter batch mode — both items start selected.
      await tester.tap(find.byType(DragHandle).first);
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));

      // Deselect the second item, then exit via Cancel.
      await tester.tap(find.byIcon(Icons.check_rounded).last);
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tap(find.text(ZhStrings().cancel));
      await tester.pump();

      // Re-enter batch mode — the deselection must have survived.
      await tester.tap(find.byType(DragHandle).first);
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    },
  );

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

  testWidgets(
    'confirming Clear Budget records the snapshot before batch-deleting',
    (tester) async {
      final recorded = <BudgetItem>[];
      final deletedIds = <String>[];
      final calls = <String>[];
      await _pumpList(
        tester,
        budgetItems: [_budget('b1', '牛奶')],
        onRecordBudgetPurchase: (items) {
          calls.add('record');
          recorded.addAll(items);
        },
        onBatchDeleteBudget: (ids) {
          calls.add('delete');
          deletedIds.addAll(ids);
        },
      );

      // Switch to budget mode and trigger the clear-budget confirm dialog.
      await tester.tap(find.text(ZhStrings().budgetMode));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZhStrings().clearBudget));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZhStrings().delete));
      await tester.pumpAndSettle();

      expect(calls, ['record', 'delete']);

      expect(recorded.single.id, 'b1');
      expect(deletedIds, ['b1']);
    },
  );

  // Regression test for the Pro-gating fix in `main.dart`: the "Spending
  // History" *viewer* on the Settings screen is Pro-gated
  // (`if (widget.purchaseService.isPro) ...`), but until this fix,
  // `_AppShellState` wired `onRecordBudgetPurchase` straight to
  // `_shoppingNotifier.recordBudgetPurchase` with no Pro check at all — so a
  // free user's Budget clears were still recorded to Hive (and later, backup
  // exports), just invisibly. This test mirrors the exact closure `main.dart`
  // now passes as `onRecordBudgetPurchase`:
  //
  //   onRecordBudgetPurchase: (snapshot) {
  //     if (_purchaseService.isPro) {
  //       _shoppingNotifier.recordBudgetPurchase(snapshot);
  //     }
  //   },
  //
  // using a real `PurchaseService` (which defaults to `isPro == false`) in
  // place of `_shoppingNotifier.recordBudgetPurchase`, so it exercises the
  // real gating logic without needing the full `main.dart` app tree (which
  // pulls in Hive, platform channels, and the first-run tutorial overlay).
  testWidgets(
    'free user (isPro == false): clearing Budget does not record history',
    (tester) async {
      final purchaseService = PurchaseService();
      expect(purchaseService.isPro, isFalse);
      final recorded = <BudgetItem>[];
      final deletedIds = <String>[];

      await _pumpList(
        tester,
        budgetItems: [_budget('b1', '牛奶')],
        onRecordBudgetPurchase: (snapshot) {
          if (purchaseService.isPro) {
            recorded.addAll(snapshot);
          }
        },
        onBatchDeleteBudget: (ids) => deletedIds.addAll(ids),
      );

      await tester.tap(find.text(ZhStrings().budgetMode));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZhStrings().clearBudget));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZhStrings().delete));
      await tester.pumpAndSettle();

      // The clear itself still happens (batch-delete is not Pro-gated)...
      expect(deletedIds, ['b1']);
      // ...but nothing was recorded to history for the free user.
      expect(recorded, isEmpty);
    },
  );

  testWidgets('Pro user (isPro == true): clearing Budget records history', (
    tester,
  ) async {
    final purchaseService = PurchaseService()..isPro = true;
    final recorded = <BudgetItem>[];

    await _pumpList(
      tester,
      budgetItems: [_budget('b1', '牛奶')],
      onRecordBudgetPurchase: (snapshot) {
        if (purchaseService.isPro) {
          recorded.addAll(snapshot);
        }
      },
    );

    await tester.tap(find.text(ZhStrings().budgetMode));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ZhStrings().clearBudget));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ZhStrings().delete));
    await tester.pumpAndSettle();

    expect(recorded.single.id, 'b1');
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
      await _pumpList(tester, simpleItems: [_simple('a', '牛奶', checked: true)]);

      final screenWidth = tester.getTopRight(find.byType(MaterialApp)).dx;
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

  testWidgets('completing a smart-mode trip calls onCompleteSmart and shows a '
      'confirmation toast', (tester) async {
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
    await tester.tap(
      find.widgetWithText(ElevatedButton, ZhStrings().addToInventoryButton),
    );
    await tester.pump();

    expect(completedIds, ['a']);
    expect(find.text(ZhStrings().addedToInventoryCelebration), findsOneWidget);
    // The toast has its own dismiss Timer — let it fire before teardown.
    await tester.pump(const Duration(milliseconds: 1600));
  });

  testWidgets(
    'Plan "N left" tracks how many items are selected, not how many exist',
    (tester) async {
      await _pumpList(
        tester,
        smartItems: [_smart('a', '牛奶'), _smart('b', '鸡蛋')],
      );
      await tester.tap(find.text('计划'));
      await tester.pumpAndSettle();

      // Both selected by default → "还差 2 件".
      expect(find.textContaining('还差 2 件'), findsOneWidget);

      // Deselect one row's checkmark → count drops to 1, even though both
      // items are still in the list.
      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('还差 1 件'), findsOneWidget);
      expect(find.textContaining('还差 2 件'), findsNothing);

      // Deselect the other → 0 left. Plan mode shows "还差 0 件", NOT the
      // Simple-mode "买齐啦" celebration (items are still in the list).
      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('还差 0 件'), findsOneWidget);
      expect(find.textContaining('买齐啦'), findsNothing);
    },
  );

  testWidgets(
    'dragging the last item out of an aisle warns the group will vanish, and '
    'declining leaves the item put',
    (tester) async {
      String? movedCode;
      await _pumpList(
        tester,
        smartItems: [
          _smart('a', '牛奶', shelfCode: 'A1'),
          _smart('b', '鸡蛋', shelfCode: 'B2'),
        ],
        onReorderSmart: (id, cat, ids, code) => movedCode = code,
      );
      await tester.tap(find.text('计划'));
      await tester.pumpAndSettle();

      // Drag 牛奶 (sole item of aisle A1) down into the B2 group.
      final handle = find.byType(DragHandle).first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveBy(const Offset(0, 160));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();

      // The aisle-will-vanish warning must appear, and declining it must not
      // push the move through to the parent.
      expect(
        find.text(ZhStrings().shelfGroupWillDisappearTitle),
        findsOneWidget,
      );
      await tester.tap(find.text(ZhStrings().cancel));
      await tester.pumpAndSettle();
      expect(movedCode, isNull);
    },
  );

  testWidgets(
    'unchecking an item on the Plan list before tapping Add keeps it out of '
    'the trip',
    (tester) async {
      // Regression test: _confirmCompleteTrip used to unconditionally
      // re-add every item id to _tripSelected right before opening the
      // confirm sheet, silently re-selecting anything the user had just
      // deselected via the row's own checkmark circle.
      List<String>? completedIds;
      await _pumpList(
        tester,
        smartItems: [_smart('a', '牛奶'), _smart('b', '鸡蛋')],
        onCompleteSmart: (ids) => completedIds = ids,
      );

      await tester.tap(find.text('计划'));
      await tester.pumpAndSettle();

      // Both items start checked (selected) by default — uncheck the first.
      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text(ZhStrings().addToInventoryButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ElevatedButton, ZhStrings().addToInventoryButton),
      );
      await tester.pump();

      expect(completedIds, ['b']);
      // The toast has its own dismiss Timer — let it fire before teardown.
      await tester.pump(const Duration(milliseconds: 1600));
    },
  );

  testWidgets(
    'a deselected item stays unchecked after a sibling item is purchased '
    'and the list rebuilds',
    (tester) async {
      // Regression test: after confirming a trip, the code used to collapse
      // _tripSelected down to just the purchased ids. Once the parent
      // rebuilt with those items removed, didUpdateWidget's "any id present
      // but missing from _tripSelected must be new, default-select it"
      // logic couldn't tell a deselected leftover item apart from a truly
      // new one, and silently re-checked it.
      await _pumpList(
        tester,
        smartItems: [_smart('a', '牛奶'), _smart('b', '鸡蛋')],
      );

      await tester.tap(find.text('计划'));
      await tester.pumpAndSettle();

      // Uncheck '牛奶' (a) — only '鸡蛋' (b) stays selected.
      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pumpAndSettle();

      // Simulate 'b' having been purchased and removed elsewhere (e.g. via
      // the confirm sheet), causing the parent to rebuild ListScreen with
      // an updated smartItems list — this is what triggers didUpdateWidget.
      // Already in smart mode from above (state carries over across pumps).
      await _pumpList(tester, smartItems: [_smart('a', '牛奶')]);
      await tester.pumpAndSettle();

      // 'a' must still be unchecked — not silently re-selected.
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    },
  );

  testWidgets(
    'the add-to-inventory sheet stays on screen and its Save button is '
    'reachable with many items',
    (tester) async {
      // Regression test: with enough items the sheet's content used to grow
      // taller than the screen with nothing capping it, pushing the header
      // off the top and leaving no way to scroll down to the Save button.
      final many = List.generate(30, (i) => _smart('id$i', 'item$i'));
      await _pumpList(tester, smartItems: many);

      await tester.tap(find.text('计划'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZhStrings().addToInventoryButton));
      await tester.pumpAndSettle();

      final screenHeight = tester.getBottomRight(find.byType(MaterialApp)).dy;
      final titleTop = tester
          .getTopLeft(find.text(ZhStrings().addToInventoryButton).last)
          .dy;
      // The header must not be pushed above the visible screen.
      expect(titleTop, greaterThanOrEqualTo(0));

      final saveButton = find.widgetWithText(
        ElevatedButton,
        ZhStrings().addToInventoryButton,
      );
      final buttonBottom = tester.getBottomRight(saveButton).dy;
      // The Save button must be within the visible screen, not off the
      // bottom edge.
      expect(buttonBottom, lessThanOrEqualTo(screenHeight));

      await tester.tap(saveButton);
      await tester.pump();
      expect(
        find.text(ZhStrings().addedToInventoryCelebration),
        findsOneWidget,
      );
      // The toast has its own dismiss Timer — let it fire before teardown.
      await tester.pump(const Duration(milliseconds: 1600));
    },
  );

  // ── Budget add-expense sheet ──────────────────────────────────────────────

  testWidgets(
    'opening the add-expense sheet after typing a name focuses price, not '
    'quantity',
    (tester) async {
      await _pumpList(tester);

      await tester.tap(find.text('记账'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '牛奶');
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      final focused = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((w) => w.focusNode?.hasFocus ?? false);
      expect(focused, hasLength(1));
      expect(focused.single.decoration?.hintText, ZhStrings().currencySymbol);
    },
  );
}
