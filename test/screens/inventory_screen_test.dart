import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/l10n/app_strings.dart';
import 'package:shopping_list/l10n/l10n.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/screens/inventory_screen.dart';

// Characterization tests for InventoryScreen. Like ListScreen it takes plain
// data + callbacks, so it pumps in isolation without Hive. Tapping a card opens
// a detail sheet (not a direct callback), so these focus on rendering and the
// always-visible search filter.

Category _category(String id) => Category(
  id: id,
  name: id,
  color: const Color(0xFF000000),
  bgColor: const Color(0xFFFFFFFF),
  defaultDays: 7,
);

InventoryItem _inv(String id, String name, {String? shelfCode}) =>
    InventoryItem(
      id: id,
      name: name,
      category: _category('other'),
      shelfCode: shelfCode,
      quantityLabel: '1',
      purchasedAt: DateTime.now(),
      estimatedDays: 10,
    );

Future<void> _pumpInventory(
  WidgetTester tester, {
  List<InventoryItem> items = const [],
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
          home: InventoryScreen(
            items: items,
            categories: [_category('other')],
            thresholdDays: 5,
            onAdd: (_) {},
            onRestock: (_, _) {},
            onDelete: (_) {},
            onAddToShoppingList: (_) {},
            onReorder: (_, _, _, _) {},
            onEdit: (_, _, _, _, _) {},
            onBatchDelete: (_) {},
            onBatchAddToRestock: (_) {},
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
  testWidgets('renders each inventory item name', (tester) async {
    await _pumpInventory(tester, items: [_inv('a', '牛奶'), _inv('b', '鸡蛋')]);

    expect(find.text('牛奶'), findsOneWidget);
    expect(find.text('鸡蛋'), findsOneWidget);
  });

  testWidgets('search narrows the list to matching items', (tester) async {
    await _pumpInventory(tester, items: [_inv('a', '牛奶'), _inv('b', '鸡蛋')]);

    await tester.enterText(find.byType(TextField), '牛奶');
    await tester.pumpAndSettle();

    // The non-matching item is filtered out of the list entirely.
    expect(find.text('鸡蛋'), findsNothing);
    // The matching item's card survives. Match a Text widget specifically so
    // the search field's own EditableText (now holding '牛奶') is excluded.
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == '牛奶'),
      findsOneWidget,
    );
  });

  testWidgets(
    'search matches by shelf code (aisle), as the search hint promises',
    (tester) async {
      // The search hint says "Search items or aisle" — the filter must actually
      // match against shelfCode (the visible aisle value like "A1"), not just
      // the item name.
      await _pumpInventory(
        tester,
        items: [
          _inv('a', '牛奶', shelfCode: 'A1'),
          _inv('b', '鸡蛋', shelfCode: 'B2'),
        ],
      );

      await tester.enterText(find.byType(TextField), 'A1');
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == '牛奶'),
        findsOneWidget,
      );
      expect(find.text('鸡蛋'), findsNothing);
    },
  );

  testWidgets(
    'renders without layout exceptions at a large system text scale',
    (tester) async {
      await _pumpInventory(
        tester,
        items: [_inv('a', '牛奶'), _inv('b', '鸡蛋')],
        textScaler: const TextScaler.linear(3.0),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
