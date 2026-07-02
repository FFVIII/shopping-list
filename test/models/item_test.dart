import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/models/item.dart';

void main() {
  group('generateId', () {
    test('never collides across rapid consecutive calls', () {
      // Simulates the exact failure mode being fixed: many ids requested
      // in the same tick, where DateTime.now() alone would be identical
      // for every call.
      final ids = List.generate(1000, (_) => generateId('cat'));
      expect(ids.toSet(), hasLength(1000));
    });

    test('starts with the given prefix', () {
      expect(generateId('bud'), startsWith('bud_'));
    });
  });
}
