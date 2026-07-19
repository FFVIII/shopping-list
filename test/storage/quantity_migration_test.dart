import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/storage/app_repository.dart';

// Quantities used to be free text with a unit ("2件"); they are now plain
// numbers. migrateQuantityLabelsToDigits strips any non-digits from existing
// persisted labels so old data matches the digits-only input.

Category _cat() => Category(
  id: 'other',
  name: '其他',
  color: const Color(0xFF000000),
  bgColor: const Color(0xFFFFFFFF),
  defaultDays: 7,
);

ShoppingItem _shop(String qty) =>
    ShoppingItem(id: 's', name: 'x', category: _cat(), quantityLabel: qty);

InventoryItem _inv(String qty) => InventoryItem(
  id: 'i',
  name: 'x',
  category: _cat(),
  quantityLabel: qty,
  purchasedAt: DateTime.now(),
  estimatedDays: 7,
);

void main() {
  test('strips units from shopping and inventory quantity labels', () {
    final shop = [_shop('2件'), _shop('500g')];
    final inv = [_inv('3盒')];
    migrateQuantityLabelsToDigits(shop, inv);
    expect(shop[0].quantityLabel, '2');
    expect(shop[1].quantityLabel, '500');
    expect(inv[0].quantityLabel, '3');
  });

  test('leaves already-numeric and empty labels unchanged (idempotent)', () {
    final shop = [_shop('4'), _shop('')];
    migrateQuantityLabelsToDigits(shop, const []);
    expect(shop[0].quantityLabel, '4');
    expect(shop[1].quantityLabel, '');
    // Second run changes nothing.
    migrateQuantityLabelsToDigits(shop, const []);
    expect(shop[0].quantityLabel, '4');
  });
}
