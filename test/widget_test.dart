import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ShoppingListApp());
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('库存'), findsOneWidget);
    expect(find.text('购物'), findsOneWidget);
  });
}
