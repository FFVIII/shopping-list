import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/l10n/app_strings.dart';
import 'package:shopping_list/l10n/l10n.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/screens/list_screen.dart';

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

/// Pumps [ListScreen] wrapped in the minimum ancestors it needs (L10n +
/// MaterialApp) at an iPhone-sized surface. Every callback defaults to a
/// no-op; tests override only the ones they assert on.
Future<void> _pumpList(
  WidgetTester tester, {
  List<ShoppingItem> simpleItems = const [],
  void Function(String id)? onToggleSimple,
  void Function(String name)? onAddSimple,
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
          smartItems: const [],
          categories: [_category('other')],
          onToggleSimple: onToggleSimple ?? (_) {},
          onToggleSmart: (_) {},
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
          budgetItems: const [],
          onAddBudget: (_, _, _) {},
          onEditBudget: (_, _, _, _) {},
          onDeleteBudget: (_) {},
          onReorderBudget: (_) {},
          onBatchDeleteSmart: (_) {},
          onBatchMarkBought: (_) {},
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

    await tester.enterText(find.byType(TextField), '  面包  ');
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

    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    // The blank-name path shows a toast (Timer-backed); let it elapse so no
    // pending timer trips the test harness.
    await tester.pump(const Duration(seconds: 2));

    expect(added, isEmpty);
  });
}
