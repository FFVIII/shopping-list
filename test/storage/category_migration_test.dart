import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/storage/app_repository.dart';

// Regression tests for the category-name localization bug: older builds
// persisted default category names translated into the install language
// (e.g. '果蔬' → 'Produce'), which froze them in that language because display
// translation is one-way (canonical zh → other). migrateDefaultCategoryNamesToCanonical
// restores the canonical names so l.data() can localize them again.

Category _cat(String id, String name) => Category(
      id: id,
      name: name,
      color: const Color(0xFF000000),
      bgColor: const Color(0xFFFFFFFF),
      shelfZone: '其他',
      defaultDays: 7,
    );

void main() {
  test('rewrites an English default name back to its zh canonical', () {
    final cats = [_cat('produce', 'Produce'), _cat('dairy', 'Dairy')];
    migrateDefaultCategoryNamesToCanonical(cats);
    expect(cats[0].name, '果蔬');
    expect(cats[1].name, '乳制品');
  });

  test('is a no-op when names are already canonical (idempotent)', () {
    final cats = [_cat('produce', '果蔬')];
    migrateDefaultCategoryNamesToCanonical(cats);
    expect(cats[0].name, '果蔬');
    // Running twice changes nothing further.
    migrateDefaultCategoryNamesToCanonical(cats);
    expect(cats[0].name, '果蔬');
  });

  test('leaves custom (non-default id) categories untouched', () {
    final cats = [_cat('custom_snacks', 'Snacks')];
    migrateDefaultCategoryNamesToCanonical(cats);
    expect(cats[0].name, 'Snacks');
  });

  test('leaves a user-renamed default untouched (name not the en default)', () {
    final cats = [_cat('produce', 'Veggies')];
    migrateDefaultCategoryNamesToCanonical(cats);
    expect(cats[0].name, 'Veggies');
  });
}
