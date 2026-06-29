import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'models/item.dart';
import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';
import 'l10n/l10n.dart';
import 'l10n/language_store.dart';
import 'screens/list_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reminder_screen.dart';
import 'screens/settings_screen.dart';

part 'main.widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final lang = await LanguageStore.load();
  runApp(ShoppingListApp(initialLanguage: lang));
}

class ShoppingListApp extends StatefulWidget {
  final AppLanguage initialLanguage;
  const ShoppingListApp({super.key, required this.initialLanguage});

  @override
  State<ShoppingListApp> createState() => _ShoppingListAppState();
}

class _ShoppingListAppState extends State<ShoppingListApp> {
  late AppLanguage _language = widget.initialLanguage;

  void _setLanguage(AppLanguage lang) {
    setState(() => _language = lang);
    LanguageStore.save(lang);
  }

  @override
  Widget build(BuildContext context) {
    final deviceLocale =
        WidgetsBinding.instance.platformDispatcher.locale;
    final lang = resolveLang(_language, deviceLocale);
    final AppStrings strings = lang == Lang.zh ? ZhStrings() : EnStrings();

    return L10n(
      strings: strings,
      language: _language,
      child: MaterialApp(
        title: strings.shoppingListTitle,
        debugShowCheckedModeBanner: false,
        locale: lang == Lang.zh ? const Locale('zh') : const Locale('en'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.brand,
            primary: AppColors.brand,
            surface: AppColors.scaffoldBg,
          ),
          scaffoldBackgroundColor: AppColors.scaffoldBg,
        ),
        home: AppShell(
          language: _language,
          onLanguageChanged: _setLanguage,
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  final AppLanguage language;
  final void Function(AppLanguage) onLanguageChanged;
  const AppShell({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  int _smartModeRequest = 0;
  late List<ShoppingItem> _shoppingSimple;
  late List<ShoppingItem> _shopping;
  late List<InventoryItem> _inventory;
  late List<BudgetItem> _budget;
  late AppSettings _settings;
  late List<ShelfZone> _shelfZones;
  late List<Category> _categories;

  @override
  void initState() {
    super.initState();
    _shoppingSimple = [];
    _categories = buildDefaultCategories();
    // Seed default category names in the active language (English if resolved
    // to en). After seeding, names are plain user-editable strings.
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final lang = resolveLang(widget.language, deviceLocale);
    if (lang == Lang.en) {
      final en = EnStrings();
      for (final c in _categories) {
        c.name = en.data(c.name);
      }
    }
    _shopping = buildSampleShopping(_categories);
    _inventory = buildSampleInventory(_categories);
    _budget = buildSampleBudget();
    _settings = AppSettings();
    _shelfZones = defaultShelfZones.toList();
  }

  // ── 分类：增 / 改 / 删 / 重排 ─────────────────────────────────────────────────

  Category _addCategory(String name, Color color, String shelfZone, int defaultDays) {
    final cat = Category(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      color: color,
      bgColor: Category.tintOf(color),
      shelfZone: shelfZone,
      defaultDays: defaultDays,
    );
    setState(() {
      _categories = [..._categories, cat];
    });
    return cat;
  }

  void _editCategory(
    String id,
    String name,
    Color color,
    String shelfZone,
    int defaultDays,
  ) {
    setState(() {
      final cat = _categories.findById(id);
      if (cat == null) return;
      cat
        ..name = name
        ..color = color
        ..bgColor = Category.tintOf(color)
        ..shelfZone = shelfZone
        ..defaultDays = defaultDays;
      _categories = List<Category>.from(_categories);
    });
  }

  void _deleteCategory(String id) {
    if (id == kFallbackCategoryId) return; // never delete fallback
    setState(() {
      final fallback = _categories.fallback;
      // Reassign any items using the deleted category to the fallback.
      for (final s in _shopping) {
        if (s.category.id == id) s.category = fallback;
      }
      for (final s in _shoppingSimple) {
        if (s.category.id == id) s.category = fallback;
      }
      for (final inv in _inventory) {
        if (inv.category.id == id) inv.category = fallback;
      }
      _categories = _categories.where((c) => c.id != id).toList();
      _shopping = List<ShoppingItem>.from(_shopping);
      _shoppingSimple = List<ShoppingItem>.from(_shoppingSimple);
      _inventory = List<InventoryItem>.from(_inventory);
    });
  }

  void _reorderCategories(int oldIndex, int newIndex) {
    setState(() {
      final cat = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, cat);
      _categories = List<Category>.from(_categories);
      // Keep "group by category" rendering consistent with the new order.
      int idx(Category c) => _categories.indexWhere((x) => x.id == c.id);
      _shopping.sort((a, b) => idx(a.category).compareTo(idx(b.category)));
      _inventory.sort((a, b) => idx(a.category).compareTo(idx(b.category)));
      _shopping = List<ShoppingItem>.from(_shopping);
      _inventory = List<InventoryItem>.from(_inventory);
    });
  }

  // ── 货架：重排顺序 → 同步重排清单/库存 ────────────────────────────────────────

  void _reorderShelfZones(int oldIndex, int newIndex) {
    setState(() {
      // onReorderItem already adjusts newIndex; no manual correction needed.
      final zone = _shelfZones.removeAt(oldIndex);
      _shelfZones.insert(newIndex, zone);
      // Sort.List is stable: items within the same zone keep their order.
      _shopping.sort((a, b) => _shelfZones
          .orderIndexOf(a.shelfZone)
          .compareTo(_shelfZones.orderIndexOf(b.shelfZone)));
      _inventory.sort((a, b) => _shelfZones
          .orderIndexOf(a.shelfZone)
          .compareTo(_shelfZones.orderIndexOf(b.shelfZone)));
      _shopping = List<ShoppingItem>.from(_shopping);
      _inventory = List<InventoryItem>.from(_inventory);
    });
  }

  // ── 清单：记账模式增 / 改 / 删 ───────────────────────────────────────────────

  void _addBudgetItem(String name, int quantity, double unitPrice) {
    setState(() {
      _budget = [
        ..._budget,
        BudgetItem(
          id: 'bud_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          quantity: quantity,
          unitPrice: unitPrice,
        ),
      ];
    });
  }

  void _editBudgetItem(
      String id, String name, int quantity, double unitPrice) {
    setState(() {
      final idx = _budget.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _budget[idx]
        ..name = name
        ..quantity = quantity
        ..unitPrice = unitPrice;
      _budget = List<BudgetItem>.from(_budget);
    });
  }

  void _deleteBudgetItem(String id) {
    setState(() => _budget = _budget.where((i) => i.id != id).toList());
  }

  // ── 清单：简单模式添加（无分类）────────────────────────────────────────────

  void _addSimple(String name) {
    setState(() {
      _shoppingSimple.add(ShoppingItem(
        id: 's_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: _categories.fallback,
        quantityLabel: '',
        shelfZone: '其他',
      ));
    });
  }

  // ── 清单：智能模式添加（带分类）────────────────────────────────────────────

  void _addSmart(String name, Category category, String shelfZone) {
    setState(() {
      _shopping.add(ShoppingItem(
        id: 'u_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: category,
        quantityLabel: '1件',
        shelfZone: shelfZone,
      ));
    });
  }

  // ── 清单：简单模式勾选（只标记，不入库存）──────────────────────────────────

  void _toggleSimple(String id) {
    setState(() {
      final idx = _shoppingSimple.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _shoppingSimple[idx].checked = !_shoppingSimple[idx].checked;
    });
  }

  // ── 清单：智能模式勾选 → 弹出天数 → 入库存 ──────────────────────────────

  void _toggleShoppingItem(BuildContext context, String id) {
    final idx = _shopping.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final item = _shopping[idx];

    if (!item.checked) {
      _showDaysSheet(context, item);
    } else {
      setState(() {
        _shopping[idx].checked = false;
        _shopping[idx].addedToInventory = false;
      });
    }
  }

  void _showDaysSheet(BuildContext context, ShoppingItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DaysSheet(
        item: item,
        initialDays: item.category.defaultDays,
        categories: _categories,
        onConfirm: (days, name, quantity, shelfCode, category, zone) =>
            _confirmPurchase(item, days, name, quantity, shelfCode, category, zone),
      ),
    );
  }

  void _confirmPurchase(
    ShoppingItem shoppingItem,
    int estimatedDays,
    String name,
    String quantity,
    String? shelfCode,
    Category category,
    String zone,
  ) {
    setState(() {
      // Update shopping item fields with any edits
      final idx = _shopping.indexWhere((i) => i.id == shoppingItem.id);
      if (idx != -1) {
        _shopping[idx]
          ..checked = true
          ..addedToInventory = true
          ..name = name
          ..quantityLabel = quantity
          ..shelfCode = shelfCode
          ..category = category
          ..shelfZone = zone;
      }

      // Update or add inventory entry using the (possibly edited) data
      final invIdx = _inventory.indexWhere((i) => i.name == shoppingItem.name);
      if (invIdx != -1) {
        _inventory[invIdx]
          ..purchasedAt = DateTime.now()
          ..estimatedDays = estimatedDays
          ..name = name
          ..quantityLabel = quantity
          ..shelfCode = shelfCode
          ..category = category
          ..shelfZone = zone;
        _inventory = List<InventoryItem>.from(_inventory);
      } else {
        _inventory = [
          ..._inventory,
          InventoryItem(
            id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            category: category,
            shelfZone: zone,
            shelfCode: shelfCode,
            quantityLabel: quantity,
            purchasedAt: DateTime.now(),
            estimatedDays: estimatedDays,
          ),
        ];
      }
    });
  }

  // ── 清单：拖动排序（简单模式）────────────────────────────────────────────

  void _reorderSimple(int oldIndex, int newIndex) {
    setState(() {
      final pending = _shoppingSimple.where((i) => !i.checked).toList();
      final done = _shoppingSimple.where((i) => i.checked).toList();
      // onReorderItem already adjusts newIndex; no manual correction needed
      final item = pending.removeAt(oldIndex);
      pending.insert(newIndex, item);
      _shoppingSimple = [...pending, ...done];
    });
  }

  // ── 清单：拖动排序（智能模式，支持跨组）─────────────────────────────────

  void _reorderSmart(
    String movedId,
    String? newShelfZone,
    Category? newCategory,
    List<String> orderedIds,
  ) {
    setState(() {
      final idx = _shopping.indexWhere((i) => i.id == movedId);
      if (idx != -1) {
        if (newShelfZone != null) _shopping[idx].shelfZone = newShelfZone;
        if (newCategory != null) _shopping[idx].category = newCategory;
      }
      _shopping = orderedIds
          .map((id) => _shopping.firstWhere((i) => i.id == id))
          .toList();
    });
  }

  // ── 清单：删除 ────────────────────────────────────────────────────────────

  void _deleteSimpleItem(String id) {
    setState(() => _shoppingSimple.removeWhere((i) => i.id == id));
  }

  void _deleteSmartItem(String id) {
    setState(() => _shopping.removeWhere((i) => i.id == id));
  }

  void _batchDeleteSmart(List<String> ids) {
    final idSet = ids.toSet();
    setState(() => _shopping = _shopping.where((i) => !idSet.contains(i.id)).toList());
  }

  void _batchDeleteBudget(List<String> ids) {
    final idSet = ids.toSet();
    setState(() => _budget = _budget.where((i) => !idSet.contains(i.id)).toList());
  }

  void _reorderBudget(int oldIndex, int newIndex) {
    setState(() {
      final item = _budget.removeAt(oldIndex);
      _budget.insert(newIndex, item);
    });
  }

  void _batchMarkBought(List<String> ids) {
    setState(() {
      for (final id in ids) {
        final idx = _shopping.indexWhere((i) => i.id == id);
        if (idx == -1) continue;
        final item = _shopping[idx];
        if (item.checked) continue;
        _shopping[idx].checked = true;
        _shopping[idx].addedToInventory = true;
        // Update or create inventory entry using category default days
        final days = item.category.defaultDays;
        final invIdx = _inventory.indexWhere((i) => i.name == item.name);
        if (invIdx != -1) {
          _inventory[invIdx].purchasedAt = DateTime.now();
          _inventory[invIdx].estimatedDays = days;
          _inventory[invIdx].quantityLabel = item.quantityLabel;
          if (item.shelfCode != null) _inventory[invIdx].shelfCode = item.shelfCode;
        } else {
          _inventory = [
            ..._inventory,
            InventoryItem(
              id: 'inv_${DateTime.now().millisecondsSinceEpoch}_$id',
              name: item.name,
              category: item.category,
              shelfZone: item.shelfZone,
              shelfCode: item.shelfCode,
              quantityLabel: item.quantityLabel,
              purchasedAt: DateTime.now(),
              estimatedDays: days,
            ),
          ];
        }
      }
    });
  }

  // ── 清单：重命名 ──────────────────────────────────────────────────────────

  void _renameSimpleItem(String id, String newName) {
    setState(() {
      final idx = _shoppingSimple.indexWhere((i) => i.id == id);
      if (idx != -1) _shoppingSimple[idx].name = newName;
    });
  }

  void _editSmartItem(
    String id,
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
    String shelfZone,
  ) {
    setState(() {
      final idx = _shopping.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _shopping[idx]
        ..name = name
        ..quantityLabel = quantityLabel
        ..shelfCode = shelfCode
        ..category = category
        ..shelfZone = shelfZone;
      _shopping = List<ShoppingItem>.from(_shopping);
    });
  }

  // ── 清单：完成购物（清掉已勾，留下未买到的）──────────────────────────────

  void _completeTripSimple() {
    setState(() => _shoppingSimple.removeWhere((i) => i.checked));
  }

  void _completeTripSmart() {
    setState(() => _shopping.removeWhere((i) => i.checked));
  }

  // ── 提醒：加入清单 ────────────────────────────────────────────────────────

  void _addToListFromReminder(InventoryItem inv) {
    if (_shopping.any((s) => s.name == inv.name && !s.checked)) return;
    setState(() {
      _shopping = [
        ..._shopping,
        ShoppingItem(
          id: 'r_${DateTime.now().millisecondsSinceEpoch}',
          name: inv.name,
          category: inv.category,
          quantityLabel: '1件',
          shelfZone: inv.shelfZone,
          shelfCode: inv.shelfCode,
        ),
      ];
      _smartModeRequest++;
    });
  }

  // ── 提醒：从清单移除（取消加入）──────────────────────────────────────────────

  void _removeFromListByReminder(InventoryItem inv) {
    setState(() {
      _shopping = _shopping
          .where((s) => !(s.name == inv.name && !s.checked))
          .toList();
    });
  }

  // ── 库存 CRUD ──────────────────────────────────────────────────────────────

  void _addInventoryItem(InventoryItem item) {
    setState(() => _inventory = [..._inventory, item]);
  }

  void _restockInventoryItem(String id, int days) {
    setState(() {
      final idx = _inventory.indexWhere((i) => i.id == id);
      if (idx != -1) {
        _inventory[idx].purchasedAt = DateTime.now();
        _inventory[idx].estimatedDays = days;
        _inventory = List<InventoryItem>.from(_inventory);
      }
    });
  }

  void _deleteInventoryItem(String id) {
    setState(() => _inventory = _inventory.where((i) => i.id != id).toList());
  }

  void _batchDeleteInventory(List<String> ids) {
    final idSet = ids.toSet();
    setState(() => _inventory = _inventory.where((i) => !idSet.contains(i.id)).toList());
  }

  void _batchAddToRestock(List<InventoryItem> items) {
    setState(() {
      for (final inv in items) {
        if (_shopping.any((s) => s.name == inv.name && !s.checked)) continue;
        _shopping = [
          ..._shopping,
          ShoppingItem(
            id: 'shop_${DateTime.now().millisecondsSinceEpoch}_${inv.id}',
            name: inv.name,
            category: inv.category,
            shelfZone: inv.shelfZone,
            shelfCode: inv.shelfCode,
            quantityLabel: inv.quantityLabel,
          ),
        ];
      }
    });
  }

  void _editInventoryItem(
    String id,
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
    String shelfZone,
  ) {
    setState(() {
      final idx = _inventory.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _inventory[idx]
        ..name = name
        ..quantityLabel = quantityLabel
        ..shelfCode = shelfCode
        ..category = category
        ..shelfZone = shelfZone;
      _inventory = List<InventoryItem>.from(_inventory);
    });
  }

  void _reorderInventory(
      String movedId, String newZone, List<String> orderedIds) {
    setState(() {
      final idx = _inventory.indexWhere((i) => i.id == movedId);
      if (idx != -1) _inventory[idx].shelfZone = newZone;
      _inventory = orderedIds
          .map((id) => _inventory.firstWhere((i) => i.id == id))
          .toList();
    });
  }

  void _addAllToList() {
    final threshold = _settings.reminderThresholdDays;
    final toAdd = _inventory
        .where((i) => i.statusFor(threshold) != StockStatus.sufficient)
        .where((i) => !_shopping.any((s) => s.name == i.name && !s.checked))
        .toList();
    if (toAdd.isEmpty) return;
    final base = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      final newItems = <ShoppingItem>[];
      for (var idx = 0; idx < toAdd.length; idx++) {
        final inv = toAdd[idx];
        newItems.add(ShoppingItem(
          id: 'r_${base}_$idx',
          name: inv.name,
          category: inv.category,
          quantityLabel: '1件',
          shelfZone: inv.shelfZone,
          shelfCode: inv.shelfCode,
        ));
      }
      _shopping = [..._shopping, ...newItems];
      _smartModeRequest++;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final threshold = _settings.reminderThresholdDays;
    final reminderCount = _inventory
        .where((i) => i.statusFor(threshold) != StockStatus.sufficient)
        .length;

    return Scaffold(
      body: Builder(
        builder: (ctx) => IndexedStack(
          index: _tab,
          children: [
            ListScreen(
              simpleItems: _shoppingSimple,
              smartItems: _shopping,
              categories: _categories,
              onToggleSimple: _toggleSimple,
              onToggleSmart: (id) => _toggleShoppingItem(ctx, id),
              onAddSimple: _addSimple,
              onAddSmart: _addSmart,
              onDeleteSimple: _deleteSimpleItem,
              onDeleteSmart: _deleteSmartItem,
              onCompleteSimple: _completeTripSimple,
              onCompleteSmart: _completeTripSmart,
              onReorderSimple: _reorderSimple,
              onReorderSmart: _reorderSmart,
              onRenameSimple: _renameSimpleItem,
              onEditSmart: _editSmartItem,
              budgetItems: _budget,
              onAddBudget: _addBudgetItem,
              onEditBudget: _editBudgetItem,
              onDeleteBudget: _deleteBudgetItem,
              onReorderBudget: _reorderBudget,
              onBatchDeleteSmart: _batchDeleteSmart,
              onBatchMarkBought: _batchMarkBought,
              onBatchDeleteBudget: _batchDeleteBudget,
              smartModeRequest: _smartModeRequest,
            ),
            InventoryScreen(
              items: _inventory,
              categories: _categories,
              thresholdDays: threshold,
              onAdd: _addInventoryItem,
              onRestock: _restockInventoryItem,
              onDelete: _deleteInventoryItem,
              onAddToShoppingList: _addToListFromReminder,
              onReorder: _reorderInventory,
              onEdit: _editInventoryItem,
              onBatchDelete: _batchDeleteInventory,
              onBatchAddToRestock: _batchAddToRestock,
            ),
            ReminderScreen(
              inventoryItems: _inventory,
              thresholdDays: threshold,
              onAddToList: _addToListFromReminder,
              onRemoveFromList: _removeFromListByReminder,
              onAddAll: _addAllToList,
              activeListNames: _shopping
                  .where((s) => !s.checked)
                  .map((s) => s.name)
                  .toSet(),
            ),
            SettingsScreen(
              settings: _settings,
              onChanged: (s) => setState(() => _settings = s),
              language: widget.language,
              onLanguageChanged: widget.onLanguageChanged,
              shelfZones: _shelfZones,
              onReorderShelfZones: _reorderShelfZones,
              categories: _categories,
              onAddCategory: _addCategory,
              onEditCategory: _editCategory,
              onDeleteCategory: _deleteCategory,
              onReorderCategories: _reorderCategories,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        reminderBadge: reminderCount,
      ),
    );
  }
}
