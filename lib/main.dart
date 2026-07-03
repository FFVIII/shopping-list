import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'models/item.dart';
import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';
import 'l10n/l10n.dart';
import 'l10n/language_store.dart';
import 'services/tutorial_controller.dart';
import 'widgets/tutorial_overlay.dart';
import 'screens/list_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reminder_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'state/categories_notifier.dart';
import 'state/inventory_notifier.dart';
import 'state/settings_notifier.dart';
import 'state/shopping_list_notifier.dart';
import 'storage/app_repository.dart';
import 'storage/backup.dart';
import 'widgets/days_selector.dart';
import 'widgets/tutorial_target.dart';

part 'main.widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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
        builder: (context, child) => TutorialOverlay(child: child!),
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
  late bool _storageUnavailable = widget.storageInitFailed;

  late final ShoppingListNotifier _shoppingNotifier =
      ShoppingListNotifier(_repo);
  late final InventoryNotifier _inventoryNotifier = InventoryNotifier(_repo);
  late final CategoriesNotifier _categoriesNotifier =
      CategoriesNotifier(_repo);
  late final SettingsNotifier _settingsNotifier = SettingsNotifier(_repo);

  AppRepository get _repo => widget.repository;

  AppStrings get _currentStrings {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    return resolveLang(widget.language, deviceLocale) == Lang.zh
        ? ZhStrings()
        : EnStrings();
  }

  void _rescheduleNotifications() => unawaited(widget.notifications
      .reschedule(
        inventory: _inventoryNotifier.items,
        settings: _settingsNotifier.settings,
        strings: _currentStrings,
      )
      .catchError((e) => debugPrint('notification reschedule failed: $e')));

  void _onDomainChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _inventoryNotifier.afterPersist = _rescheduleNotifications;
    _settingsNotifier.afterPersist = _rescheduleNotifications;
    for (final n in [
      _shoppingNotifier,
      _inventoryNotifier,
      _categoriesNotifier,
      _settingsNotifier,
    ]) {
      n.addListener(_onDomainChanged);
    }
    TutorialController.instance.onSkipRequested = _skipTutorial;
    _loadData();
  }

  @override
  void dispose() {
    for (final n in [
      _shoppingNotifier,
      _inventoryNotifier,
      _categoriesNotifier,
      _settingsNotifier,
    ]) {
      n.removeListener(_onDomainChanged);
      n.dispose();
    }
    super.dispose();
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
    _shoppingNotifier.load(data);
    _inventoryNotifier.load(data);
    _categoriesNotifier.load(data);
    _settingsNotifier.load(data);
    setState(() {
      _loading = false;
      if (loadFailed) _storageUnavailable = true;
    });
    await TutorialController.instance.resolveInitialStep(
      dataIsEmpty: data.shoppingSmart.isEmpty &&
          data.inventory.isEmpty &&
          data.budget.isEmpty,
    );
    // Top up the 14-day pre-scheduled window in case the app hasn't been
    // opened for a while (spec §4.3).
    _rescheduleNotifications();
  }

  AppData _buildFallbackData(Lang lang) {
    // Keep canonical (zh) category names; display sites localize via l.data().
    final categories = buildDefaultCategories();
    return AppData(
      shoppingSimple: [],
      // Same as AppRepository._seedInitialData(): only the category
      // structure is real; items start empty. See design spec 2026-07-02 §3.
      shoppingSmart: [],
      inventory: [],
      budget: [],
      categories: categories,
      settings: AppSettings(),
      shelfZones: defaultShelfZones.toList(),
      shelfCodeOrder: [],
    );
  }

  // ── 教程：跳过时清理示例数据（跨域：清单 + 库存）──────────────────────────

  void _skipTutorial() {
    _shoppingNotifier.smart = _shoppingNotifier.smart
        .where((i) => !TutorialController.instance.isExampleItemName(i.name))
        .toList();
    _inventoryNotifier.items = _inventoryNotifier.items
        .where((i) => !TutorialController.instance.isExampleItemName(i.name))
        .toList();
    _shoppingNotifier.persistSmart();
    _inventoryNotifier.persistItems();
  }

  // ── 分类：删除 / 重排（跨域级联：清单 + 库存排序）─────────────────────────

  void _deleteCategory(String id) {
    if (id == kFallbackCategoryId) return; // never delete fallback
    reassignCategoryToFallback(
      categoryId: id,
      fallback: _categoriesNotifier.fallback,
      shopping: _shoppingNotifier.smart,
      shoppingSimple: _shoppingNotifier.simple,
      inventory: _inventoryNotifier.items,
    );
    _categoriesNotifier.removeCategory(id);
    _categoriesNotifier.persistCategories();
    _shoppingNotifier.persistSmart();
    _shoppingNotifier.persistSimple();
    _inventoryNotifier.persistItems();
  }

  void _reorderCategories(int oldIndex, int newIndex) {
    _categoriesNotifier.reorderCategoriesOnly(oldIndex, newIndex);
    // Keep "group by category" rendering consistent with the new order.
    int idx(Category c) =>
        _categoriesNotifier.categories.indexWhere((x) => x.id == c.id);
    _shoppingNotifier.smart
        .sort((a, b) => idx(a.category).compareTo(idx(b.category)));
    _inventoryNotifier.items
        .sort((a, b) => idx(a.category).compareTo(idx(b.category)));
    _categoriesNotifier.persistCategories();
    _shoppingNotifier.persistSmart();
    _inventoryNotifier.persistItems();
  }

  // ── 货架：重排顺序 → 同步重排清单/库存（跨域）───────────────────────────────

  // Ordered shelf codes: user-defined order first, then any unseen codes from
  // current smart items or inventory items appended alphabetically.
  List<String> get _orderedShelfCodes {
    final all = {
      ..._shoppingNotifier.smart
          .where((i) => i.shelfCode != null && i.shelfCode!.trim().isNotEmpty)
          .map((i) => i.shelfCode!.trim()),
      ..._inventoryNotifier.items
          .where((i) => i.shelfCode != null && i.shelfCode!.trim().isNotEmpty)
          .map((i) => i.shelfCode!.trim()),
    };
    final known = _categoriesNotifier.shelfCodeOrder.where(all.contains).toList();
    final unseen = (all.difference(known.toSet()).toList()..sort());
    return [...known, ...unseen];
  }

  void _reorderShelfCodes(int oldIndex, int newIndex) {
    final codes = _orderedShelfCodes;
    final code = codes.removeAt(oldIndex);
    codes.insert(newIndex, code);
    _categoriesNotifier.shelfCodeOrder = codes;
    _categoriesNotifier.persistShelfCodeOrder();
  }

  void _addShelfCode(String code) {
    if (code.isEmpty || _categoriesNotifier.shelfCodeOrder.contains(code)) return;
    _categoriesNotifier.shelfCodeOrder = [..._orderedShelfCodes, code];
    _categoriesNotifier.persistShelfCodeOrder();
  }

  void _deleteShelfCode(String code) {
    _categoriesNotifier.shelfCodeOrder =
        _orderedShelfCodes.where((c) => c != code).toList();
    _categoriesNotifier.persistShelfCodeOrder();
  }

  void _renameShelfCode(String oldCode, String newCode) {
    if (newCode.isEmpty || newCode == oldCode) return;
    _categoriesNotifier.shelfCodeOrder = _orderedShelfCodes
        .map((c) => c == oldCode ? newCode : c)
        .toList();
    _shoppingNotifier.renameShelfCodeInItems(oldCode, newCode);
    _categoriesNotifier.persistShelfCodeOrder();
    _shoppingNotifier.persistSmart();
  }

  void _reorderShelfZones(int oldIndex, int newIndex) {
    // onReorderItem already adjusts newIndex; no manual correction needed.
    _categoriesNotifier.reorderShelfZonesOnly(oldIndex, newIndex);
    // Sort.List is stable: items within the same zone keep their order.
    _shoppingNotifier.smart.sort((a, b) => _categoriesNotifier.shelfZones
        .orderIndexOf(a.shelfZone)
        .compareTo(_categoriesNotifier.shelfZones.orderIndexOf(b.shelfZone)));
    _inventoryNotifier.items.sort((a, b) => _categoriesNotifier.shelfZones
        .orderIndexOf(a.shelfZone)
        .compareTo(_categoriesNotifier.shelfZones.orderIndexOf(b.shelfZone)));
    _categoriesNotifier.persistShelfZones();
    _shoppingNotifier.persistSmart();
    _inventoryNotifier.persistItems();
  }

  // ── 清单：智能模式勾选 → 弹出天数 → 更新清单条目（需要 BuildContext）──────

  void _toggleShoppingItem(BuildContext context, String id) {
    final idx = _shoppingNotifier.smart.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    _showDaysSheet(context, _shoppingNotifier.smart[idx]);
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
        categories: _categoriesNotifier.categories,
        onConfirm: (days, name, quantity, shelfCode, category, zone) =>
            _shoppingNotifier.updateSmartItemFields(
          item.id,
          estimatedDays: days,
          name: name,
          quantity: quantity,
          shelfCode: shelfCode,
          category: category,
          zone: zone,
        ),
      ),
    );
  }

  // ── 清单 → 库存：批量标记买到 / 完成购物（跨域）─────────────────────────────

  void _batchMarkBought(List<String> ids) {
    for (final id in ids) {
      final idx = _shoppingNotifier.smart.indexWhere((i) => i.id == id);
      if (idx == -1) continue;
      final item = _shoppingNotifier.smart[idx];
      if (item.checked) continue;
      item.checked = true;
      item.addedToInventory = true;
      // Update or create inventory entry using category default days
      _inventoryNotifier.applyPurchaseFor(item, item.category.defaultDays);
    }
    _shoppingNotifier.persistSmart();
    _inventoryNotifier.persistItems();
  }

  void _completeTripSmart(List<String> selectedIds) {
    final selectedSet = selectedIds.toSet();
    final purchasedNames = _shoppingNotifier.smart
        .where((item) => selectedSet.contains(item.id))
        .map((item) => item.name)
        .toList();
    for (final item in _shoppingNotifier.smart) {
      if (!selectedSet.contains(item.id)) continue;
      _inventoryNotifier.applyPurchaseFor(
          item, item.estimatedDays ?? item.category.defaultDays);
    }
    _shoppingNotifier.smart.clear();
    _inventoryNotifier.persistItems();
    _shoppingNotifier.persistSmart();
    TutorialController.instance.onTripCompleted(purchasedNames);
  }

  // ── 提醒：加入 / 移出清单（跨域：读库存，写清单 + smartModeRequest）───────

  void _addToListFromReminder(InventoryItem inv) {
    if (_shoppingNotifier.addFromReminder(inv)) {
      setState(() => _smartModeRequest++);
    }
  }

  void _addAllToList() {
    final threshold = _settingsNotifier.settings.reminderThresholdDays;
    final toAdd = _inventoryNotifier.items
        .where((i) => i.statusFor(threshold) != StockStatus.sufficient)
        .where((i) => !_shoppingNotifier.smart
            .any((s) => !s.checked && sameProduct(s, i)))
        .toList();
    final added = _shoppingNotifier.addAllFromInventory(toAdd);
    if (added > 0) setState(() => _smartModeRequest++);
  }

  // ── 备份：导出快照 / 导入应用（跨域：全部数据）───────────────────────────────

  List<int> _buildBackupBytes() => encodeBackupExcel(AppData(
        shoppingSimple: _shoppingNotifier.simple,
        shoppingSmart: _shoppingNotifier.smart,
        inventory: _inventoryNotifier.items,
        budget: _shoppingNotifier.budget,
        categories: _categoriesNotifier.categories,
        settings: _settingsNotifier.settings,
        shelfZones: _categoriesNotifier.shelfZones,
        shelfCodeOrder: _categoriesNotifier.shelfCodeOrder,
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
    _shoppingNotifier.load(data);
    _inventoryNotifier.load(data);
    _categoriesNotifier.load(data);
    _settingsNotifier.load(data);
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
    final threshold = _settingsNotifier.settings.reminderThresholdDays;
    final reminderCount = _inventoryNotifier.items
        .where((i) => i.statusFor(threshold) != StockStatus.sufficient)
        .length;
    final shelfCodeOrder = _orderedShelfCodes;

    return Scaffold(
      body: Column(
        children: [
          if (_storageUnavailable) const _StorageWarningBanner(),
          Expanded(
            child: Builder(
              builder: (ctx) => _AnimatedTabContent(
                index: _tab,
                children: [
                  ListScreen(
                    simpleItems: _shoppingNotifier.simple,
                    smartItems: _shoppingNotifier.smart,
                    categories: _categoriesNotifier.categories,
                    onToggleSimple: _shoppingNotifier.toggleSimple,
                    onToggleSmart: (id) => _toggleShoppingItem(ctx, id),
                    onAddSimple: (name) => _shoppingNotifier.addSimple(
                        name, _categoriesNotifier.fallback),
                    onAddSmart: _shoppingNotifier.addSmart,
                    onDeleteSimple: _shoppingNotifier.deleteSimpleItem,
                    onDeleteSmart: _shoppingNotifier.deleteSmartItem,
                    onCompleteSimple: _shoppingNotifier.completeTripSimple,
                    onCompleteSmart: _completeTripSmart,
                    onReorderSimple: _shoppingNotifier.reorderSimple,
                    onReorderSmart: _shoppingNotifier.reorderSmart,
                    onRenameSimple: _shoppingNotifier.renameSimpleItem,
                    onEditSmart: _shoppingNotifier.editSmartItem,
                    budgetItems: _shoppingNotifier.budget,
                    onAddBudget: _shoppingNotifier.addBudgetItem,
                    onEditBudget: _shoppingNotifier.editBudgetItem,
                    onDeleteBudget: _shoppingNotifier.deleteBudgetItem,
                    onReorderBudget: _shoppingNotifier.reorderBudget,
                    onBatchDeleteSmart: _shoppingNotifier.batchDeleteSmart,
                    onBatchMarkBought: _batchMarkBought,
                    onBatchDeleteBudget: _shoppingNotifier.batchDeleteBudget,
                    smartModeRequest: _smartModeRequest,
                    shelfCodeOrder: shelfCodeOrder,
                  ),
                  InventoryScreen(
                    items: _inventoryNotifier.items,
                    categories: _categoriesNotifier.categories,
                    thresholdDays: threshold,
                    onAdd: _inventoryNotifier.addItem,
                    onRestock: _inventoryNotifier.restock,
                    onDelete: _inventoryNotifier.deleteItem,
                    onAddToShoppingList: _addToListFromReminder,
                    onReorder: _inventoryNotifier.reorder,
                    onEdit: _inventoryNotifier.editItem,
                    onBatchDelete: _inventoryNotifier.batchDelete,
                    onBatchAddToRestock: _shoppingNotifier.batchAddToRestock,
                    shelfCodeOrder: shelfCodeOrder,
                  ),
                  ReminderScreen(
                    inventoryItems: _inventoryNotifier.items,
                    thresholdDays: threshold,
                    onAddToList: _addToListFromReminder,
                    onRemoveFromList:
                        _shoppingNotifier.removeFromListByReminder,
                    onAddAll: _addAllToList,
                    activeListNames: _shoppingNotifier.smart
                        .where((s) => !s.checked)
                        .map((s) => s.name)
                        .toSet(),
                  ),
                  SettingsScreen(
                    settings: _settingsNotifier.settings,
                    onChanged: _settingsNotifier.update,
                    language: widget.language,
                    onLanguageChanged: widget.onLanguageChanged,
                    shelfZones: _categoriesNotifier.shelfZones,
                    onReorderShelfZones: _reorderShelfZones,
                    shelfCodeOrder: shelfCodeOrder,
                    onReorderShelfCodes: _reorderShelfCodes,
                    onAddShelfCode: _addShelfCode,
                    onDeleteShelfCode: _deleteShelfCode,
                    onRenameShelfCode: _renameShelfCode,
                    categories: _categoriesNotifier.categories,
                    onAddCategory: _categoriesNotifier.addCategory,
                    onEditCategory: _categoriesNotifier.editCategory,
                    onDeleteCategory: _deleteCategory,
                    onReorderCategories: _reorderCategories,
                    buildBackupBytes: _buildBackupBytes,
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
        onTap: (i) {
          setState(() => _tab = i);
          TutorialController.instance.onTabChanged(i);
        },
        reminderBadge: reminderCount,
      ),
    );
  }
}
