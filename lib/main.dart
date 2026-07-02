import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
import 'services/notification_service.dart';
import 'storage/app_repository.dart';
import 'storage/backup.dart';
import 'widgets/days_selector.dart';

part 'main.widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = AppRepository();
  bool storageAvailable = true;
  try {
    await Hive.initFlutter();
    await repository.init();
  } catch (e) {
    debugPrint('Hive init failed, falling back to in-memory sample data: $e');
    storageAvailable = false;
  }
  final notifications = NotificationService();
  try {
    await notifications.init();
  } catch (e) {
    debugPrint('Notification init failed, reminders disabled: $e');
  }
  final lang = await LanguageStore.load();
  runApp(ShoppingListApp(
    initialLanguage: lang,
    repository: repository,
    notifications: notifications,
    storageAvailable: storageAvailable,
  ));
}

class ShoppingListApp extends StatefulWidget {
  final AppLanguage initialLanguage;
  final AppRepository repository;
  final NotificationService notifications;
  final bool storageAvailable;
  const ShoppingListApp({
    super.key,
    required this.initialLanguage,
    required this.repository,
    required this.notifications,
    this.storageAvailable = true,
  });

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
          dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
        ),
        home: AppShell(
          language: _language,
          onLanguageChanged: _setLanguage,
          repository: widget.repository,
          notifications: widget.notifications,
          storageInitFailed: !widget.storageAvailable,
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  final AppLanguage language;
  final void Function(AppLanguage) onLanguageChanged;
  final AppRepository repository;
  final NotificationService notifications;
  final bool storageInitFailed;
  const AppShell({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.repository,
    required this.notifications,
    this.storageInitFailed = false,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  int _smartModeRequest = 0;
  bool _loading = true;
  late List<ShoppingItem> _shoppingSimple;
  late List<ShoppingItem> _shopping;
  late List<InventoryItem> _inventory;
  late List<BudgetItem> _budget;
  late AppSettings _settings;
  late List<ShelfZone> _shelfZones;
  List<String> _shelfCodeOrder = [];
  late List<Category> _categories;
  late bool _storageUnavailable = widget.storageInitFailed;

  AppRepository get _repo => widget.repository;

  AppStrings get _currentStrings {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    return resolveLang(widget.language, deviceLocale) == Lang.zh
        ? ZhStrings()
        : EnStrings();
  }

  void _rescheduleNotifications() => unawaited(widget.notifications
      .reschedule(
        inventory: _inventory,
        settings: _settings,
        strings: _currentStrings,
      )
      .catchError((e) => debugPrint('notification reschedule failed: $e')));

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final lang = resolveLang(widget.language, deviceLocale);
    AppData data;
    bool loadFailed = false;
    try {
      data = await _repo.load(lang: lang);
    } catch (e) {
      debugPrint('Failed to load persisted data, falling back to in-memory sample data: $e');
      data = _buildFallbackData(lang);
      loadFailed = true;
    }
    if (!mounted) return;
    setState(() {
      _shoppingSimple = data.shoppingSimple;
      _shopping = data.shoppingSmart;
      _inventory = data.inventory;
      _budget = data.budget;
      _categories = data.categories;
      _settings = data.settings;
      _shelfZones = data.shelfZones;
      _shelfCodeOrder = data.shelfCodeOrder;
      _loading = false;
      if (loadFailed) _storageUnavailable = true;
    });
    // Top up the 14-day pre-scheduled window in case the app hasn't been
    // opened for a while (spec §4.3).
    _rescheduleNotifications();
  }

  AppData _buildFallbackData(Lang lang) {
    final categories = buildDefaultCategories();
    if (lang == Lang.en) {
      final en = EnStrings();
      for (final c in categories) {
        c.name = en.data(c.name);
      }
    }
    return AppData(
      shoppingSimple: [],
      shoppingSmart: buildSampleShopping(categories),
      inventory: buildSampleInventory(categories),
      budget: buildSampleBudget(),
      categories: categories,
      settings: AppSettings(),
      shelfZones: defaultShelfZones.toList(),
      shelfCodeOrder: [],
    );
  }

  // ── Persistence: one helper per persisted collection, called after the ──
  // matching field is mutated. Fire-and-forget: write failures are logged,
  // not surfaced to the user (see design spec §5).
  void _persistShoppingSimple() => unawaited(_repo
      .saveShoppingSimple(_shoppingSimple)
      .catchError((e) => debugPrint('save shoppingSimple failed: $e')));
  void _persistShoppingSmart() => unawaited(_repo
      .saveShoppingSmart(_shopping)
      .catchError((e) => debugPrint('save shoppingSmart failed: $e')));
  void _persistInventory() {
    unawaited(_repo
        .saveInventory(_inventory)
        .catchError((e) => debugPrint('save inventory failed: $e')));
    _rescheduleNotifications();
  }
  void _persistBudget() => unawaited(_repo
      .saveBudget(_budget)
      .catchError((e) => debugPrint('save budget failed: $e')));
  void _persistCategories() => unawaited(_repo
      .saveCategories(_categories)
      .catchError((e) => debugPrint('save categories failed: $e')));
  void _persistSettings() {
    unawaited(_repo
        .saveSettings(_settings)
        .catchError((e) => debugPrint('save settings failed: $e')));
    _rescheduleNotifications();
  }
  void _persistShelfZones() => unawaited(_repo
      .saveShelfZones(_shelfZones)
      .catchError((e) => debugPrint('save shelfZones failed: $e')));
  void _persistShelfCodeOrder() => unawaited(_repo
      .saveShelfCodeOrder(_shelfCodeOrder)
      .catchError((e) => debugPrint('save shelfCodeOrder failed: $e')));

  // ── 分类：增 / 改 / 删 / 重排 ─────────────────────────────────────────────────

  Category _addCategory(String name, Color color, String shelfZone, int defaultDays) {
    final cat = Category(
      id: generateId('cat'),
      name: name,
      color: color,
      bgColor: Category.tintOf(color),
      shelfZone: shelfZone,
      defaultDays: defaultDays,
    );
    setState(() {
      _categories = [..._categories, cat];
    });
    _persistCategories();
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
    _persistCategories();
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
    _persistCategories();
    _persistShoppingSmart();
    _persistShoppingSimple();
    _persistInventory();
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
    _persistCategories();
    _persistShoppingSmart();
    _persistInventory();
  }

  // ── 货架：重排顺序 → 同步重排清单/库存 ────────────────────────────────────────

  // Ordered shelf codes: user-defined order first, then any unseen codes from
  // current smart items appended alphabetically.
  List<String> get _orderedShelfCodes {
    final all = _shopping
        .where((i) => i.shelfCode != null && i.shelfCode!.trim().isNotEmpty)
        .map((i) => i.shelfCode!.trim())
        .toSet();
    final known = _shelfCodeOrder.where(all.contains).toList();
    final unseen = (all.difference(known.toSet()).toList()..sort());
    return [...known, ...unseen];
  }

  void _reorderShelfCodes(int oldIndex, int newIndex) {
    setState(() {
      final codes = _orderedShelfCodes;
      final code = codes.removeAt(oldIndex);
      codes.insert(newIndex, code);
      _shelfCodeOrder = codes;
    });
    _persistShelfCodeOrder();
  }

  void _addShelfCode(String code) {
    if (code.isEmpty || _shelfCodeOrder.contains(code)) return;
    setState(() => _shelfCodeOrder = [..._orderedShelfCodes, code]);
    _persistShelfCodeOrder();
  }

  void _deleteShelfCode(String code) {
    setState(() => _shelfCodeOrder = _orderedShelfCodes.where((c) => c != code).toList());
    _persistShelfCodeOrder();
  }

  void _renameShelfCode(String oldCode, String newCode) {
    if (newCode.isEmpty || newCode == oldCode) return;
    setState(() {
      _shelfCodeOrder = _orderedShelfCodes
          .map((c) => c == oldCode ? newCode : c)
          .toList();
      for (final item in _shopping) {
        if (item.shelfCode == oldCode) item.shelfCode = newCode;
      }
    });
    _persistShelfCodeOrder();
    _persistShoppingSmart();
  }

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
    _persistShelfZones();
    _persistShoppingSmart();
    _persistInventory();
  }

  // ── 清单：记账模式增 / 改 / 删 ───────────────────────────────────────────────

  void _addBudgetItem(String name, int quantity, double unitPrice) {
    setState(() {
      _budget = [
        ..._budget,
        BudgetItem(
          id: generateId('bud'),
          name: name,
          quantity: quantity,
          unitPrice: unitPrice,
        ),
      ];
    });
    _persistBudget();
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
    _persistBudget();
  }

  void _deleteBudgetItem(String id) {
    setState(() => _budget = _budget.where((i) => i.id != id).toList());
    _persistBudget();
  }

  // ── 清单：简单模式添加（无分类）────────────────────────────────────────────

  void _addSimple(String name) {
    setState(() {
      _shoppingSimple.add(ShoppingItem(
        id: generateId('s'),
        name: name,
        category: _categories.fallback,
        quantityLabel: '',
        shelfZone: '其他',
      ));
    });
    _persistShoppingSimple();
  }

  // ── 清单：智能模式添加（带分类）────────────────────────────────────────────

  void _addSmart(String name, String quantityLabel, String? shelfCode, int estimatedDays, Category category, String shelfZone) {
    setState(() {
      _shopping.add(ShoppingItem(
        id: generateId('u'),
        name: name,
        category: category,
        quantityLabel: quantityLabel.isEmpty ? '1件' : quantityLabel,
        shelfZone: shelfZone,
        shelfCode: shelfCode,
        estimatedDays: estimatedDays,
      ));
    });
    _persistShoppingSmart();
  }

  // ── 清单：简单模式勾选（只标记，不入库存）──────────────────────────────────

  void _toggleSimple(String id) {
    setState(() {
      final idx = _shoppingSimple.indexWhere((i) => i.id == id);
      if (idx == -1) return;
      _shoppingSimple[idx].checked = !_shoppingSimple[idx].checked;
    });
    _persistShoppingSimple();
  }

  // ── 清单：智能模式勾选 → 弹出天数 → 入库存 ──────────────────────────────

  void _toggleShoppingItem(BuildContext context, String id) {
    final idx = _shopping.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    _showDaysSheet(context, _shopping[idx]);
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
        initialDays: item.estimatedDays ?? item.category.defaultDays,
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
      final idx = _shopping.indexWhere((i) => i.id == shoppingItem.id);
      if (idx != -1) {
        _shopping[idx]
          ..estimatedDays = estimatedDays
          ..name = name
          ..quantityLabel = quantity
          ..shelfCode = shelfCode
          ..category = category
          ..shelfZone = zone;
      }
    });
    _persistShoppingSmart();
  }

  // ── 清单：拖动排序（简单模式）────────────────────────────────────────────

  void _reorderSimple(List<String> orderedIds) {
    setState(() {
      _shoppingSimple = orderedIds
          .map((id) => _shoppingSimple.firstWhere((i) => i.id == id))
          .toList();
    });
    _persistShoppingSimple();
  }

  // ── 清单：拖动排序（智能模式，支持跨组）─────────────────────────────────

  void _reorderSmart(
    String movedId,
    String? newShelfZone,
    Category? newCategory,
    List<String> orderedIds,
    String? newShelfCode,
  ) {
    setState(() {
      final idx = _shopping.indexWhere((i) => i.id == movedId);
      if (idx != -1) {
        if (newShelfZone != null) _shopping[idx].shelfZone = newShelfZone;
        if (newCategory != null) _shopping[idx].category = newCategory;
        // newShelfCode non-null means shelf-mode drag: "" = clear code, else set
        if (newShelfCode != null) {
          _shopping[idx].shelfCode = newShelfCode.isEmpty ? null : newShelfCode;
        }
      }
      _shopping = orderedIds
          .map((id) => _shopping.firstWhere((i) => i.id == id))
          .toList();
    });
    _persistShoppingSmart();
  }

  // ── 清单：删除 ────────────────────────────────────────────────────────────

  void _deleteSimpleItem(String id) {
    setState(() => _shoppingSimple.removeWhere((i) => i.id == id));
    _persistShoppingSimple();
  }

  void _deleteSmartItem(String id) {
    setState(() => _shopping.removeWhere((i) => i.id == id));
    _persistShoppingSmart();
  }

  void _batchDeleteSmart(List<String> ids) {
    final idSet = ids.toSet();
    setState(() => _shopping = _shopping.where((i) => !idSet.contains(i.id)).toList());
    _persistShoppingSmart();
  }

  void _batchDeleteBudget(List<String> ids) {
    final idSet = ids.toSet();
    setState(() => _budget = _budget.where((i) => !idSet.contains(i.id)).toList());
    _persistBudget();
  }

  void _reorderBudget(List<String> orderedIds) {
    setState(() {
      _budget = orderedIds
          .map((id) => _budget.firstWhere((i) => i.id == id))
          .toList();
    });
    _persistBudget();
  }

  // ── 商品身份匹配：优先按来源库存 id，回退按名字 ──────────────────────────
  // （历史数据、手动新增的清单项没有 sourceInventoryId，只能靠名字兜底；
  //  见 code review 反馈 #4：纯名字匹配在重命名/同名场景下会认错商品）

  bool _sameProduct(ShoppingItem s, InventoryItem inv) =>
      s.sourceInventoryId != null
          ? s.sourceInventoryId == inv.id
          : s.name == inv.name;

  int _inventoryIndexForShoppingItem(
      List<InventoryItem> inventory, ShoppingItem item) {
    if (item.sourceInventoryId != null) {
      final idx = inventory.indexWhere((i) => i.id == item.sourceInventoryId);
      if (idx != -1) return idx;
    }
    return inventory.indexWhere((i) => i.name == item.name);
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
        final invIdx = _inventoryIndexForShoppingItem(_inventory, item);
        if (invIdx != -1) {
          _inventory[invIdx].purchasedAt = DateTime.now();
          _inventory[invIdx].estimatedDays = days;
          _inventory[invIdx].quantityLabel = item.quantityLabel;
          if (item.shelfCode != null) _inventory[invIdx].shelfCode = item.shelfCode;
        } else {
          _inventory = [
            ..._inventory,
            InventoryItem(
              id: generateId('inv'),
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
    _persistShoppingSmart();
    _persistInventory();
  }

  // ── 清单：重命名 ──────────────────────────────────────────────────────────

  void _renameSimpleItem(String id, String newName) {
    setState(() {
      final idx = _shoppingSimple.indexWhere((i) => i.id == id);
      if (idx != -1) _shoppingSimple[idx].name = newName;
    });
    _persistShoppingSimple();
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
    _persistShoppingSmart();
  }

  // ── 清单：完成购物（清掉已勾，留下未买到的）──────────────────────────────

  void _completeTripSimple() {
    setState(() => _shoppingSimple.removeWhere((i) => i.checked));
    _persistShoppingSimple();
  }

  void _completeTripSmart(List<String> selectedIds) {
    final selectedSet = selectedIds.toSet();
    setState(() {
      // Work on a mutable copy so new entries are visible to subsequent lookups
      final inv = List<InventoryItem>.from(_inventory);
      for (final item in _shopping) {
        if (!selectedSet.contains(item.id)) continue;
        final days = item.estimatedDays ?? item.category.defaultDays;
        final invIdx = _inventoryIndexForShoppingItem(inv, item);
        if (invIdx != -1) {
          inv[invIdx]
            ..purchasedAt = DateTime.now()
            ..estimatedDays = days
            ..quantityLabel = item.quantityLabel;
          if (item.shelfCode != null) inv[invIdx].shelfCode = item.shelfCode;
        } else {
          inv.add(InventoryItem(
            id: generateId('inv'),
            name: item.name,
            category: item.category,
            shelfZone: item.shelfZone,
            shelfCode: item.shelfCode,
            quantityLabel: item.quantityLabel,
            purchasedAt: DateTime.now(),
            estimatedDays: days,
          ));
        }
      }
      _inventory = inv;
      _shopping.clear();
    });
    _persistInventory();
    _persistShoppingSmart();
  }

  // ── 提醒：加入清单 ────────────────────────────────────────────────────────

  void _addToListFromReminder(InventoryItem inv) {
    if (_shopping.any((s) => !s.checked && _sameProduct(s, inv))) return;
    setState(() {
      _shopping = [
        ..._shopping,
        ShoppingItem(
          id: generateId('r'),
          name: inv.name,
          category: inv.category,
          quantityLabel: '1件',
          shelfZone: inv.shelfZone,
          shelfCode: inv.shelfCode,
          sourceInventoryId: inv.id,
        ),
      ];
      _smartModeRequest++;
    });
    _persistShoppingSmart();
  }

  // ── 提醒：从清单移除（取消加入）──────────────────────────────────────────────

  void _removeFromListByReminder(InventoryItem inv) {
    setState(() {
      _shopping = _shopping
          .where((s) => !(!s.checked && _sameProduct(s, inv)))
          .toList();
    });
    _persistShoppingSmart();
  }

  // ── 库存 CRUD ──────────────────────────────────────────────────────────────

  void _addInventoryItem(InventoryItem item) {
    setState(() => _inventory = [..._inventory, item]);
    _persistInventory();
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
    _persistInventory();
  }

  void _deleteInventoryItem(String id) {
    setState(() => _inventory = _inventory.where((i) => i.id != id).toList());
    _persistInventory();
  }

  void _batchDeleteInventory(List<String> ids) {
    final idSet = ids.toSet();
    setState(() => _inventory = _inventory.where((i) => !idSet.contains(i.id)).toList());
    _persistInventory();
  }

  void _batchAddToRestock(List<InventoryItem> items) {
    setState(() {
      for (final inv in items) {
        if (_shopping.any((s) => !s.checked && _sameProduct(s, inv))) continue;
        _shopping = [
          ..._shopping,
          ShoppingItem(
            id: generateId('shop'),
            name: inv.name,
            category: inv.category,
            shelfZone: inv.shelfZone,
            shelfCode: inv.shelfCode,
            quantityLabel: inv.quantityLabel,
            sourceInventoryId: inv.id,
          ),
        ];
      }
    });
    _persistShoppingSmart();
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
    _persistInventory();
  }

  void _reorderInventory(String movedId, String? newZone,
      Category? newCategory, List<String> orderedIds) {
    setState(() {
      final idx = _inventory.indexWhere((i) => i.id == movedId);
      if (idx != -1) {
        if (newZone != null) _inventory[idx].shelfZone = newZone;
        if (newCategory != null) _inventory[idx].category = newCategory;
      }
      _inventory = orderedIds
          .map((id) => _inventory.firstWhere((i) => i.id == id))
          .toList();
    });
    _persistInventory();
  }

  void _addAllToList() {
    final threshold = _settings.reminderThresholdDays;
    final toAdd = _inventory
        .where((i) => i.statusFor(threshold) != StockStatus.sufficient)
        .where((i) => !_shopping.any((s) => !s.checked && _sameProduct(s, i)))
        .toList();
    if (toAdd.isEmpty) return;
    setState(() {
      final newItems = <ShoppingItem>[];
      for (var idx = 0; idx < toAdd.length; idx++) {
        final inv = toAdd[idx];
        newItems.add(ShoppingItem(
          id: generateId('r'),
          name: inv.name,
          category: inv.category,
          quantityLabel: '1件',
          shelfZone: inv.shelfZone,
          shelfCode: inv.shelfCode,
          sourceInventoryId: inv.id,
        ));
      }
      _shopping = [..._shopping, ...newItems];
      _smartModeRequest++;
    });
    _persistShoppingSmart();
  }

  // ── 备份：导出快照 / 导入应用 ────────────────────────────────────────────────

  String _buildBackupJson() => encodeBackup(AppData(
        shoppingSimple: _shoppingSimple,
        shoppingSmart: _shopping,
        inventory: _inventory,
        budget: _budget,
        categories: _categories,
        settings: _settings,
        shelfZones: _shelfZones,
        shelfCodeOrder: _shelfCodeOrder,
      ));

  Future<void> _applyBackup(AppData data) async {
    try {
      await _repo.replaceAll(data);
    } catch (e) {
      // Same policy as all other persistence failures (spec 2026-06-30 §5):
      // keep the in-memory state, log the write error.
      debugPrint('backup import write failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _shoppingSimple = data.shoppingSimple;
      _shopping = data.shoppingSmart;
      _inventory = data.inventory;
      _budget = data.budget;
      _categories = data.categories;
      _settings = data.settings;
      _shelfZones = data.shelfZones;
      _shelfCodeOrder = data.shelfCodeOrder;
    });
    _rescheduleNotifications();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final threshold = _settings.reminderThresholdDays;
    final reminderCount = _inventory
        .where((i) => i.statusFor(threshold) != StockStatus.sufficient)
        .length;
    final shelfCodeOrder = _orderedShelfCodes;

    return Scaffold(
      body: Column(
        children: [
          if (_storageUnavailable) const _StorageWarningBanner(),
          Expanded(
            child: Builder(
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
                    shelfCodeOrder: shelfCodeOrder,
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
                    onChanged: (s) {
                      setState(() => _settings = s);
                      _persistSettings();
                    },
                    language: widget.language,
                    onLanguageChanged: widget.onLanguageChanged,
                    shelfZones: _shelfZones,
                    onReorderShelfZones: _reorderShelfZones,
                    shelfCodeOrder: shelfCodeOrder,
                    onReorderShelfCodes: _reorderShelfCodes,
                    onAddShelfCode: _addShelfCode,
                    onDeleteShelfCode: _deleteShelfCode,
                    onRenameShelfCode: _renameShelfCode,
                    categories: _categories,
                    onAddCategory: _addCategory,
                    onEditCategory: _editCategory,
                    onDeleteCategory: _deleteCategory,
                    onReorderCategories: _reorderCategories,
                    buildBackupJson: _buildBackupJson,
                    onImportBackup: _applyBackup,
                    requestNotificationPermission:
                        widget.notifications.requestPermission,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        reminderBadge: reminderCount,
      ),
    );
  }
}
