import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/l10n/app_strings.dart';
import 'package:shopping_list/l10n/l10n.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/screens/spending_history_screen.dart';

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<BudgetHistoryEntry> budgetHistory,
  void Function(String id)? onDeleteEntry,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    L10n(
      strings: ZhStrings(),
      language: AppLanguage.zh,
      child: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: MaterialApp(
          home: SpendingHistoryScreen(
            budgetHistory: budgetHistory,
            onDeleteEntry: onDeleteEntry ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the empty state when there is no history', (tester) async {
    await _pumpScreen(tester, budgetHistory: const []);

    expect(find.text(ZhStrings().spendingHistoryEmpty), findsOneWidget);
  });

  testWidgets('sums only current-month entries into the month total banner', (
    tester,
  ) async {
    final now = DateTime.now();
    final thisMonth = BudgetHistoryEntry(
      id: 'h1',
      clearedAt: now,
      items: [BudgetHistoryLineItem(name: '本月', quantity: 1, unitPrice: 10)],
    );
    final lastYear = BudgetHistoryEntry(
      id: 'h2',
      clearedAt: DateTime(2020, 1, 1),
      items: [BudgetHistoryLineItem(name: '旧的', quantity: 1, unitPrice: 999)],
    );

    await _pumpScreen(tester, budgetHistory: [thisMonth, lastYear]);

    expect(
      find.text(ZhStrings().spendingHistoryMonthTotal(ZhStrings().money(10))),
      findsOneWidget,
    );
  });

  testWidgets('tapping an entry expands it to show line items', (tester) async {
    final entry = BudgetHistoryEntry(
      id: 'h1',
      clearedAt: DateTime(2026, 7, 13, 9, 0),
      items: [BudgetHistoryLineItem(name: '牛奶', quantity: 2, unitPrice: 8.5)],
    );
    await _pumpScreen(tester, budgetHistory: [entry]);

    expect(find.text('牛奶 × 2'), findsNothing);
    await tester.tap(find.byKey(const Key('history_h1')));
    await tester.pumpAndSettle();
    expect(find.text('牛奶 × 2'), findsOneWidget);
  });

  testWidgets('canceling the delete dialog keeps the entry', (tester) async {
    final entry = BudgetHistoryEntry(
      id: 'h1',
      clearedAt: DateTime(2026, 7, 13, 9, 0),
      items: [BudgetHistoryLineItem(name: '牛奶', quantity: 1, unitPrice: 1)],
    );
    var deleted = false;
    await _pumpScreen(
      tester,
      budgetHistory: [entry],
      onDeleteEntry: (_) => deleted = true,
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text(ZhStrings().deleteHistoryEntryTitle), findsOneWidget);
    await tester.tap(find.text(ZhStrings().cancel));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
  });

  testWidgets('confirming the delete dialog calls onDeleteEntry with the id', (
    tester,
  ) async {
    final entry = BudgetHistoryEntry(
      id: 'h1',
      clearedAt: DateTime(2026, 7, 13, 9, 0),
      items: [BudgetHistoryLineItem(name: '牛奶', quantity: 1, unitPrice: 1)],
    );
    String? deletedId;
    await _pumpScreen(
      tester,
      budgetHistory: [entry],
      onDeleteEntry: (id) => deletedId = id,
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ZhStrings().delete));
    await tester.pumpAndSettle();

    expect(deletedId, 'h1');
  });

  testWidgets(
    'shows a zero month total when history exists but none is from this month',
    (tester) async {
      final lastYear = BudgetHistoryEntry(
        id: 'h2',
        clearedAt: DateTime(2020, 1, 1),
        items: [BudgetHistoryLineItem(name: '旧的', quantity: 1, unitPrice: 999)],
      );

      await _pumpScreen(tester, budgetHistory: [lastYear]);

      expect(
        find.text(ZhStrings().spendingHistoryMonthTotal(ZhStrings().money(0))),
        findsOneWidget,
      );
      expect(find.text(ZhStrings().spendingHistoryEmpty), findsNothing);
    },
  );

  testWidgets(
    'renders without layout exceptions at a large system text scale',
    (tester) async {
      final entries = [
        BudgetHistoryEntry(
          id: 'h1',
          clearedAt: DateTime(2026, 7, 13, 9, 0),
          items: [
            BudgetHistoryLineItem(name: '牛奶', quantity: 2, unitPrice: 8.5),
          ],
        ),
        BudgetHistoryEntry(
          id: 'h2',
          clearedAt: DateTime(2026, 6, 1, 8, 30),
          items: [
            BudgetHistoryLineItem(name: '鸡蛋', quantity: 1, unitPrice: 12.99),
          ],
        ),
      ];

      await _pumpScreen(
        tester,
        budgetHistory: entries,
        textScaler: const TextScaler.linear(3.0),
      );

      expect(tester.takeException(), isNull);
    },
  );
}
