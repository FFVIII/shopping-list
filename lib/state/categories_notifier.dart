import 'dart:async';

import 'package:flutter/material.dart';

import '../models/item.dart';
import '../storage/app_repository.dart';

/// Owns categories, shelf zones, and shelf-code order. Shelf-code CRUD needs
/// to read the live shopping list (to compute unseen codes), and category
/// delete/reorder cascade into the shopping-list and inventory sort order —
/// those cross-domain steps live in `_AppShellState`, which mutates the
/// public lists here directly before calling the matching `persist*` method.
class CategoriesNotifier extends ChangeNotifier {
  CategoriesNotifier(this._repo);

  final AppRepository _repo;

  List<Category> categories = [];
  List<String> shelfCodeOrder = [];

  Category get fallback => categories.fallback;

  void load(AppData data) {
    categories = data.categories;
    shelfCodeOrder = data.shelfCodeOrder;
    notifyListeners();
  }

  void persistCategories() {
    notifyListeners();
    unawaited(
      _repo
          .saveCategories(categories)
          .catchError((e) => debugPrint('save categories failed: $e')),
    );
  }

  void persistShelfCodeOrder() {
    notifyListeners();
    unawaited(
      _repo
          .saveShelfCodeOrder(shelfCodeOrder)
          .catchError((e) => debugPrint('save shelfCodeOrder failed: $e')),
    );
  }

  Category addCategory(String name, Color color, int defaultDays) {
    final cat = Category(
      id: generateId('cat'),
      name: name,
      color: color,
      bgColor: Category.tintOf(color),
      defaultDays: defaultDays,
    );
    categories = [...categories, cat];
    persistCategories();
    return cat;
  }

  void editCategory(String id, String name, Color color, int defaultDays) {
    final cat = categories.findById(id);
    if (cat == null) return;
    cat
      ..name = name
      ..color = color
      ..bgColor = Category.tintOf(color)
      ..defaultDays = defaultDays;
    persistCategories();
  }

  // ── 供协调层（跨域级联）调用的纯变更方法：不在此处持久化 ───────────────────

  void removeCategory(String id) {
    categories = categories.where((c) => c.id != id).toList();
  }

  void reorderCategoriesOnly(int oldIndex, int newIndex) {
    final cat = categories.removeAt(oldIndex);
    categories.insert(newIndex, cat);
  }
}
