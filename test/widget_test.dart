import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/main.dart';
import 'package:shopping_list/l10n/app_language.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ShoppingListApp(initialLanguage: AppLanguage.zh));
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('库存'), findsOneWidget);
    expect(find.text('购物'), findsOneWidget);
  });
}
