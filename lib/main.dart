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
  late List<ShoppingItem> _shoppingSimple;
  late List<ShoppingItem> _shopping;
  late List<InventoryItem> _inventory;
  late List<BudgetItem> _budget;
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _shoppingSimple = [];
    _shopping = buildSampleShopping();
    _inventory = buildSampleInventory();
    _budget = buildSampleBudget();
    _settings = AppSettings();
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
        category: Category.other,
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
        initialDays: _defaultDays(item.category),
        onConfirm: (days) => _confirmPurchase(item, days),
      ),
    );
  }

  void _confirmPurchase(ShoppingItem shoppingItem, int estimatedDays) {
    setState(() {
      // Mark shopping item as checked
      final idx =
          _shopping.indexWhere((i) => i.id == shoppingItem.id);
      if (idx != -1) {
        _shopping[idx].checked = true;
        _shopping[idx].addedToInventory = true;
      }

      // Update or add inventory entry
      final invIdx =
          _inventory.indexWhere((i) => i.name == shoppingItem.name);
      if (invIdx != -1) {
        // Reset the timer and refresh quantity / shelf from the purchase
        _inventory[invIdx].purchasedAt = DateTime.now();
        _inventory[invIdx].estimatedDays = estimatedDays;
        _inventory[invIdx].quantityLabel = shoppingItem.quantityLabel;
        if (shoppingItem.shelfCode != null) {
          _inventory[invIdx].shelfCode = shoppingItem.shelfCode;
        }
        _inventory = List<InventoryItem>.from(_inventory);
      } else {
        _inventory = [
          ..._inventory,
          InventoryItem(
            id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
            name: shoppingItem.name,
            category: shoppingItem.category,
            shelfZone: shoppingItem.shelfZone,
            shelfCode: shoppingItem.shelfCode,
            quantityLabel: shoppingItem.quantityLabel,
            purchasedAt: DateTime.now(),
            estimatedDays: estimatedDays,
          ),
        ];
      }
    });
  }

  int _defaultDays(Category category) {
    switch (category) {
      case Category.produce:  return 7;
      case Category.dairy:    return 7;
      case Category.meat:     return 5;
      case Category.grain:    return 30;
      case Category.cleaning: return 30;
      case Category.beverage: return 14;
      case Category.other:    return 7;
    }
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
    final needRestock = _inventory
        .where((i) => i.statusFor(threshold) != StockStatus.sufficient)
        .toList();
    for (final inv in needRestock) {
      _addToListFromReminder(inv);
    }
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
            ),
            InventoryScreen(
              items: _inventory,
              thresholdDays: threshold,
              onAdd: _addInventoryItem,
              onRestock: _restockInventoryItem,
              onDelete: _deleteInventoryItem,
              onAddToShoppingList: _addToListFromReminder,
              onReorder: _reorderInventory,
              onEdit: _editInventoryItem,
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
