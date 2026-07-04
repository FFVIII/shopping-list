import '../models/item.dart';
import 'app_language.dart';

/// All user-visible text. One implementation per language.
/// `data()` translates *canonical data tokens* (sample product names,
/// quantity labels, shelf codes, shelf-zone display, default reminder time).
/// Unknown strings (user-entered) pass through unchanged.
abstract class AppStrings {
  // ── Bottom nav ──
  String get navList;
  String get navInventory;
  String get navReminder;
  String get navSettings;

  // ── List screen ──
  String get shoppingListTitle;
  String listSubtitlePending(int remaining, DateTime date);
  String listSubtitleDone(DateTime date);
  String get completeTrip;
  String get completeTripTitle; // "完成购物？" / "Finish shopping?"
  String completeTripMessage(int bought); // explains what completing does
  String get tripInventoryHint; // sheet hint about saving to inventory
  String get cancel; // "取消" / "Cancel"
  String get smartHint; // smart-mode explanation banner
  String get modeSimple;
  String get modeSmart;
  String get budgetMode; // "记账" / "Budget"
  String get unitPriceFieldLabel; // "单价" / "Unit price"
  String get budgetTotalLabel; // "合计" / "Total"
  String budgetCount(int n); // "共 N 项" / "N items"
  String get addBudgetTitle; // "记一笔" / "Add expense"
  String get editBudgetTitle; // "编辑记录" / "Edit expense"
  String get clearBudget; // "清空" / "Clear"
  String get clearBudgetTitle; // "清空记账？" / "Clear expenses?"
  String clearBudgetMessage(int count); // explains what clearing does
  String get budgetAddHint; // add-bar hint
  String get budgetEmptyTitle;
  String get budgetEmptySubtitle;
  String get save; // "保存" / "Save"
  String get currencySymbol; // "¥" / "$"
  String money(double v); // "¥12.50" / "$12.50"
  String get byShelf;
  String get byCategory;
  String get sortByName;  // "按名字" / "By name"
  String get sortByPrice; // "按金钱" / "By price"
  String get sortByCategory; // "按品类" / "By type"
  String get sortByExpiry;   // "按到期" / "By expiry"
  String get sortByLastTime; // "按上次" / "By last"
  String expiryLabel(String date);   // "到期: 7/10" / "Expires: 7/10"
  String lastBoughtLabel(String date); // "上次: 7/3" / "Last: 7/3"
  String get untaggedShelf; // "未标记" / "Untagged"
  String get pendingSection; // "待购" / "To buy"
  String get purchasedSection;
  String itemCountChip(int n); // "3件" / "3"
  String get listEmptyTitle;
  String get listEmptySubtitle;
  String get listeningHint;
  String get micPermissionDenied; // toast shown when mic tapped w/o permission
  String get addItemNameRequired; // toast shown when "+" tapped with empty name
  String get deleteConfirmMessage; // batch-delete confirmation dialog body
  String get smartAddHint;
  String get simpleAddHint;
  String addItemTitle(String name);
  String shelfZoneInline(String zoneDisplay); // "货架区：果蔬区" / "Aisle: Produce"
  String get addToList;
  String get rename;
  String get confirmEdit;
  String get editItem; // "编辑商品" / "Edit item"
  String editItemTitle(String name); // "编辑「鸡蛋」" / 'Edit "Eggs"'
  String get quantityFieldLabel; // "数量" / "Quantity"
  String get shelfCodeFieldLabel; // "货架码" / "Shelf code"
  String get shelfCodeFieldHint; // example placeholder, e.g. "货架B1" / "Shelf B1"
  String get recordedBadge; // "已记" / "Logged"
  String itemMeta(String quantity, String? shelfCode); // "1串 · 货架B3"

  // ── Days sheet (main.dart) ──
  String boughtTitle(String name);
  String get estimatedDaysQuestion;
  String days(int n); // "7天" / "7 days"
  String recordToInventory(int n);

  // ── Inventory screen ──
  String get inventoryTitle;
  String inventorySummary(int total, int restock);
  String get searchHint;
  String get inventoryEmptyTitle;
  String get inventoryEmptyTitleQuery; // uses query
  String inventoryNoResults(String query);
  String get inventoryEmptySubtitle;
  String get inventoryEmptySubtitleQuery;
  String get addManually;
  String get usedUp; // "已用完" / "Used up"
  String daysRemainingLong(int n); // "还剩约 N 天" / "About N days left"
  String daysShort(int n); // "N天"
  String daysShortApprox(int n); // "约N天" / "~N days"
  String get resetTimerSection; // "重新购买，重置计时"
  String resetTimer(int n); // "重置计时（N天）"
  String get addToRestockList; // "加入补货清单"
  String get deleteFromInventory; // "从库存删除"
  String get addToInventoryTitle; // "添加到库存"
  String get productNameHint; // "商品名称"
  String get categoryLabel; // "分类"
  String get estimatedUseDays; // "预计使用天数"
  String estimatedDaysSelected(int n); // "预计能用 N 天"
  String get addToInventoryBtn; // "加入库存"

  // ── Reminder screen ──
  String get reminderTitle;
  String reminderSummary(int restock, int expiring);
  String get addAll;
  String get sectionRestock; // "该补货"
  String get sectionExpiringSoon; // "即将用完"
  String get reminderEmptyTitle; // "库存都很充足"
  String get reminderEmptySubtitle; // "没有需要补货的商品"
  String get usedUpNeedRestock; // "已用完，需要补货"
  String daysLeftApprox(int n); // "还剩约N天" / "~N days left"
  String get add; // "加入" / "Add"
  String get alreadyInList; // "已在清单" / "In list"
  String get addedToListToast; // "已加入清单" / "Added to list"
  String get removedFromListToast; // "已从清单移除" / "Removed from list"
  String addedAllToListToast(int n); // "已加入 N 件到清单" / "Added N items"
  String get allAlreadyInList; // "都已在清单了" / "All already in list"

  // ── Settings screen ──
  String get settingsTitle;
  String get proUpgrade;
  String get proDesc;
  String get proCta;
  String get sectionCategoryShelf;
  String get manageCategories;
  String get addCategoryTitle;
  String get editCategoryTitle;
  String get categoryNameLabel;
  String get categoryColorLabel;
  String get shelfZoneLabel;
  String get defaultDaysLabel;
  String get delete;
  String get undo;
  String itemDeletedToast(String name); // e.g. "已删除 "牛奶"" / 'Deleted "Milk"'
  String deleteCategoryTitle(String name);
  String get deleteCategoryMessage;
  String categoriesCount(int n); // "12类"
  String get shelfOrder;
  String get noShelfCodes;
  String get addShelfCodeTitle;
  String get shelfCodeNameLabel;
  String get shelfCodeNameHint;
  String deleteShelfCodeTitle(String code);
  String get deleteShelfCodeMessage;
  String get sectionReminder;
  String get restockReminder;
  String get reminderTimeLabel;
  String reminderTimeDisplay(int hour, int minute);
  String get advanceDays; // "提前天数"
  String get customDaysLabel;  // "自定义" / "Custom"
  String get dayUnit;          // "天" / "d"
  String get saveChangesTitle; // "保存修改？" / "Save changes?"
  String get discardChanges;   // "不保存" / "Discard"
  String get savedToast;       // "已保存" / "Saved"
  String get restockToast;     // "计时已重置" / "Timer reset"
  String get customDaysMaxHint; // "最多 1000 天" / "Max 1000 days"
  String get sectionData;
  String get backupExport;
  String get importRestore;

  // ── Notifications & backup ──
  String get notifRestockTitle;                       // "该补货了" / "Time to restock"
  String notifRestockBody(int count, List<String> names); // 最多列 3 个名字
  String get notifPermissionDenied; // 开关打开但授权被拒时的 toast
  String get importConfirmTitle;    // "导入备份？" / "Import backup?"
  String get importConfirmMessage;  // 覆盖警告
  String get importAction;          // "导入" / "Import"
  String get importInvalidFile;     // "文件无效，无法导入"
  String get importSuccessToast;    // "已恢复备份"
  String get exportFailedToast;     // "导出失败"
  String get storageUnavailableBanner; // shown when local storage failed to initialize
  String get appFooter; // "购物清单 v1.0.0"
  String get language; // "语言" / "Language"
  String get languageSystem; // "跟随系统"
  String get languageZh; // "中文"
  String get languageEn; // "English"
  String labelForLanguage(/* AppLanguage */ Object lang); // trailing display

  // ── Batch operations ──
  String get batchEdit;         // "编辑" / "Edit"
  String get selectAll;         // "全选" / "Select all"
  String get batchMarkBought;   // "勾选已购" / "Mark bought"
  String get batchAddToRestock; // "加入补货" / "Add to restock"
  String selectedCount(int n);  // "已选 N 件" / "N selected"

  // ── Enum + data lookups ──
  String stockStatus(StockStatus s);
  String data(String canonical);

  // ── Onboarding tutorial ──
  String get tutorialExampleItemName; // 固定示例商品名
  String get tutorialStepAddItem;
  String get tutorialStepCompleteTrip;
  String get tutorialStepViewInventory;
  String get tutorialFinalMessage;
  String get tutorialGotIt;
  String get tutorialSkip;
}

class ZhStrings extends AppStrings {
  @override String get navList => '清单';
  @override String get navInventory => '库存';
  @override String get navReminder => '提醒';
  @override String get navSettings => '设置';

  @override String get shoppingListTitle => '购物清单';
  @override String listSubtitlePending(int r, DateTime d) => '还差 $r 件 · ${_zhDate(d)}';
  @override String listSubtitleDone(DateTime d) => '今天买齐啦 🎉 · ${_zhDate(d)}';
  @override String get completeTrip => '完成购物';
  @override String get completeTripTitle => '完成购物？';
  @override String completeTripMessage(int bought) =>
      '已买到的 $bought 件会从清单移除，未买到的会保留在清单里。';
  @override String get tripInventoryHint =>
      '购买后将保存到库存，取消勾选则不保存。';
  @override String get cancel => '取消';
  @override String get smartHint =>
      '圆圈选中=将存入库存；点「完成购物」完成本次采购。';
  @override String get modeSimple => '简单';
  @override String get modeSmart => '计划';
  @override String get budgetMode => '记账';
  @override String get unitPriceFieldLabel => '单价';
  @override String get budgetTotalLabel => '合计';
  @override String budgetCount(int n) => '共 $n 项';
  @override String get addBudgetTitle => '记一笔';
  @override String get editBudgetTitle => '编辑记录';
  @override String get clearBudget => '清空';
  @override String get clearBudgetTitle => '清空记账？';
  @override String clearBudgetMessage(int count) => '将删除全部 $count 条记账记录，开始新一轮记账。此操作无法撤销。';
  @override String get budgetAddHint => '记一笔花费…';
  @override String get budgetEmptyTitle => '还没有记账';
  @override String get budgetEmptySubtitle => '在下方记一笔花费';
  @override String get save => '保存';
  @override String get currencySymbol => '¥';
  @override String money(double v) => '¥${v.toStringAsFixed(2)}';
  @override String get byShelf => '按货架';
  @override String get byCategory => '按分类';
  @override String get sortByName => '按名字';
  @override String get sortByPrice => '按金钱';
  @override String get sortByCategory => '按品类';
  @override String get sortByExpiry => '按到期';
  @override String get sortByLastTime => '按上次';
  @override String expiryLabel(String date) => '到期: $date';
  @override String lastBoughtLabel(String date) => '上次: $date';
  @override String get untaggedShelf => '未标记';
  @override String get pendingSection => '待购';
  @override String get purchasedSection => '已购';
  @override String itemCountChip(int n) => '$n件';
  @override String get listEmptyTitle => '清单是空的';
  @override String get listEmptySubtitle => '在下方输入要买的商品';
  @override String get listeningHint => '正在听，请说商品名称...';
  @override String get micPermissionDenied => '没有麦克风/语音识别权限，请在系统设置中开启';
  @override String get addItemNameRequired => '请先输入商品名称';
  @override String get deleteConfirmMessage => '确定要删除吗？此操作无法撤销。';
  @override String get smartAddHint => '添加商品，选分类后入库...';
  @override String get simpleAddHint => '随手记，添加到清单...';
  @override String addItemTitle(String name) => '添加「$name」';
  @override String shelfZoneInline(String z) => '货架区：$z';
  @override String get addToList => '加入清单';
  @override String get rename => '重命名';
  @override String get confirmEdit => '确认修改';
  @override String get editItem => '编辑商品';
  @override String editItemTitle(String name) => '编辑「$name」';
  @override String get quantityFieldLabel => '数量';
  @override String get shelfCodeFieldLabel => '货架码';
  @override String get shelfCodeFieldHint => '货架B1';
  @override String get recordedBadge => '已记';
  @override String itemMeta(String q, String? code) => code != null ? '$q · $code' : q;

  @override String boughtTitle(String name) => '「$name」买到了！';
  @override String get estimatedDaysQuestion => '预计能用几天？';
  @override String days(int n) => '$n天';
  @override String recordToInventory(int n) => '记录到库存（$n天）';

  @override String get inventoryTitle => '库存';
  @override String inventorySummary(int t, int r) => '$t件常备 · $r件需补货';
  @override String get searchHint => '搜索商品或货架';
  @override String get inventoryEmptyTitle => '库存还是空的';
  @override String get inventoryEmptyTitleQuery => '';
  @override String inventoryNoResults(String q) => '没有找到「$q」';
  @override String get inventoryEmptySubtitle => '先从清单购买并记录到库存';
  @override String get inventoryEmptySubtitleQuery => '试试其他关键词';
  @override String get addManually => '手动添加商品';
  @override String get usedUp => '已用完';
  @override String daysRemainingLong(int n) => '还剩约 $n 天';
  @override String daysShort(int n) => '$n天';
  @override String daysShortApprox(int n) => '约$n天';
  @override String get resetTimerSection => '重新购买，重置计时';
  @override String resetTimer(int n) => '重置计时（$n天）';
  @override String get addToRestockList => '加入补货清单';
  @override String get deleteFromInventory => '从库存删除';
  @override String get addToInventoryTitle => '添加到库存';
  @override String get productNameHint => '商品名称';
  @override String get categoryLabel => '分类';
  @override String get estimatedUseDays => '预计使用天数';
  @override String get addToInventoryBtn => '加入库存';
  @override String estimatedDaysSelected(int n) => '预计能用 $n 天';

  @override String get reminderTitle => '提醒';
  @override String reminderSummary(int r, int e) => '$r件该补货 · $e件即将用完';
  @override String get addAll => '全部加入';
  @override String get sectionRestock => '该补货';
  @override String get sectionExpiringSoon => '即将用完';
  @override String get reminderEmptyTitle => '库存都很充足';
  @override String get reminderEmptySubtitle => '没有需要补货的商品';
  @override String get usedUpNeedRestock => '已用完，需要补货';
  @override String daysLeftApprox(int n) => '还剩约$n天';
  @override String get add => '加入';
  @override String get alreadyInList => '已在清单';
  @override String get addedToListToast => '已加入清单';
  @override String get removedFromListToast => '已从清单移除';
  @override String addedAllToListToast(int n) => '已加入 $n 件到清单';
  @override String get allAlreadyInList => '都已在清单了';

  @override String get settingsTitle => '设置';
  @override String get proUpgrade => '升级 Pro';
  @override String get proDesc => '拍照识别配图 · 快捷加项组件 · 多设备同步备份';
  @override String get proCta => '查看 Pro 功能 →';
  @override String get sectionCategoryShelf => '分类与货架';
  @override String get manageCategories => '商品分类';
  @override String get addCategoryTitle => '新建分类';
  @override String get editCategoryTitle => '编辑分类';
  @override String get categoryNameLabel => '分类名称';
  @override String get categoryColorLabel => '颜色';
  @override String get shelfZoneLabel => '所属货架';
  @override String get defaultDaysLabel => '默认使用天数';
  @override String get delete => '删除';
  @override String get undo => '撤销';
  @override String itemDeletedToast(String name) => '已删除"$name"';
  @override String deleteCategoryTitle(String name) => '删除「$name」？';
  @override String get deleteCategoryMessage => '使用此分类的商品会改派到「其他」。';
  @override String categoriesCount(int n) => '$n类';
  @override String get shelfOrder => '货架顺序';
  @override String get noShelfCodes => '暂无货架码';
  @override String get addShelfCodeTitle => '新建货架码';
  @override String get shelfCodeNameLabel => '货架码';
  @override String get shelfCodeNameHint => '如：货架B1';
  @override String deleteShelfCodeTitle(String code) => '删除「$code」？';
  @override String get deleteShelfCodeMessage => '从顺序列表中移除此货架码。';

  @override String get sectionReminder => '提醒';
  @override String get restockReminder => '补货提醒';
  @override String get reminderTimeLabel => '提醒时间';
  @override String reminderTimeDisplay(int h, int m) =>
      '每天 ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  @override String get advanceDays => '提前天数';
  @override String get customDaysLabel => '自定义';
  @override String get dayUnit => '天';
  @override String get saveChangesTitle => '保存修改？';
  @override String get discardChanges => '不保存';
  @override String get savedToast => '已保存';
  @override String get restockToast => '计时已重置';
  @override String get customDaysMaxHint => '最多 1000 天';
  @override String get sectionData => '数据';
  @override String get backupExport => '备份导出';
  @override String get importRestore => '导入恢复';
  @override String get notifRestockTitle => '该补货了';
  @override String notifRestockBody(int count, List<String> names) {
    final shown = names.take(3).join('、');
    final suffix = count > 3 ? ' 等' : '';
    return '有 $count 件物品需要补货：$shown$suffix';
  }
  @override String get notifPermissionDenied => '通知权限未开启，请在系统设置中允许通知';
  @override String get importConfirmTitle => '导入备份？';
  @override String get importConfirmMessage =>
      '将覆盖当前全部数据（清单、库存、记账、分类、设置），此操作不可撤销。';
  @override String get importAction => '导入';
  @override String get importInvalidFile => '文件无效，无法导入';
  @override String get importSuccessToast => '已恢复备份';
  @override String get exportFailedToast => '导出失败';
  @override String get storageUnavailableBanner => '存储初始化失败，当前的修改不会被保存';
  @override String get appFooter => '购物清单 v1.0.1';
  @override String get language => '语言';
  @override String get languageSystem => '跟随系统';
  @override String get languageZh => '中文';
  @override String get languageEn => 'English';
  @override String labelForLanguage(Object lang) =>
      lang == AppLanguage.zh ? '中文' : lang == AppLanguage.en ? 'English' : '跟随系统';

  @override String get batchEdit => '编辑';
  @override String get selectAll => '全选';
  @override String get batchMarkBought => '勾选已购';
  @override String get batchAddToRestock => '加入补货';
  @override String selectedCount(int n) => '已选 $n 件';

  @override String stockStatus(StockStatus s) {
    switch (s) {
      case StockStatus.sufficient: return '充足';
      case StockStatus.low:        return '快没';
      case StockStatus.empty:      return '用完';
    }
  }

  @override String data(String canonical) => canonical; // zh is canonical

  @override String get tutorialExampleItemName => '鸡蛋（示例）';
  @override String get tutorialStepAddItem => '点击 + 把示例商品加入清单';
  @override String get tutorialStepCompleteTrip => '买完了？点这里完成本次购物';
  @override String get tutorialStepViewInventory => '去库存看看刚刚买的东西吧';
  @override String get tutorialFinalMessage =>
      '以后库存快用完时，「提醒」页会自动提示你补货';
  @override String get tutorialGotIt => '知道了';
  @override String get tutorialSkip => '跳过';
}

String _zhDate(DateTime d) => '${d.month}月${d.day}日';

class EnStrings extends AppStrings {
  @override String get navList => 'List';
  @override String get navInventory => 'Inventory';
  @override String get navReminder => 'Alerts';
  @override String get navSettings => 'Settings';

  @override String get shoppingListTitle => 'Shopping List';
  @override String listSubtitlePending(int r, DateTime d) => '$r left · ${_enDate(d)}';
  @override String listSubtitleDone(DateTime d) => 'All done 🎉 · ${_enDate(d)}';
  @override String get completeTrip => 'Done';
  @override String get completeTripTitle => 'Finish shopping?';
  @override String completeTripMessage(int bought) =>
      '$bought bought item(s) will be removed from the list; unbought ones stay.';
  @override String get tripInventoryHint =>
      'Unchecked items won\'t be saved to inventory.';
  @override String get cancel => 'Cancel';
  @override String get smartHint =>
      'Circles mark items to save to inventory. Tap \'Done\' to finish shopping.';
  @override String get modeSimple => 'Simple';
  @override String get modeSmart => 'Plan';
  @override String get budgetMode => 'Budget';
  @override String get unitPriceFieldLabel => 'Unit price';
  @override String get budgetTotalLabel => 'Total';
  @override String budgetCount(int n) => '$n items';
  @override String get addBudgetTitle => 'Add expense';
  @override String get editBudgetTitle => 'Edit expense';
  @override String get clearBudget => 'Clear';
  @override String get clearBudgetTitle => 'Clear expenses?';
  @override String clearBudgetMessage(int count) =>
      'This will delete all $count recorded expenses and start a new round. This cannot be undone.';
  @override String get budgetAddHint => 'Add an expense…';
  @override String get budgetEmptyTitle => 'No expenses yet';
  @override String get budgetEmptySubtitle => 'Add an expense below';
  @override String get save => 'Save';
  @override String get currencySymbol => '\$';
  @override String money(double v) => '\$${v.toStringAsFixed(2)}';
  @override String get byShelf => 'By aisle';
  @override String get byCategory => 'By category';
  @override String get sortByName => 'By name';
  @override String get sortByPrice => 'By price';
  @override String get sortByCategory => 'By type';
  @override String get sortByExpiry => 'By expiry';
  @override String get sortByLastTime => 'By last';
  @override String expiryLabel(String date) => 'Expires: $date';
  @override String lastBoughtLabel(String date) => 'Last: $date';
  @override String get untaggedShelf => 'Untagged';
  @override String get pendingSection => 'To buy';
  @override String get purchasedSection => 'Bought';
  @override String itemCountChip(int n) => '$n';
  @override String get listEmptyTitle => 'Your list is empty';
  @override String get listEmptySubtitle => 'Add items to buy below';
  @override String get listeningHint => 'Listening, say the item name...';
  @override String get micPermissionDenied =>
      'No microphone/speech recognition permission. Please enable it in Settings.';
  @override String get addItemNameRequired => 'Please enter an item name first';
  @override String get deleteConfirmMessage =>
      'Are you sure you want to delete? This cannot be undone.';
  @override String get smartAddHint => 'Add item, pick a category...';
  @override String get simpleAddHint => 'Jot it down, add to list...';
  @override String addItemTitle(String name) => 'Add "$name"';
  @override String shelfZoneInline(String z) => 'Aisle: $z';
  @override String get addToList => 'Add to list';
  @override String get rename => 'Rename';
  @override String get confirmEdit => 'Save';
  @override String get editItem => 'Edit item';
  @override String editItemTitle(String name) => 'Edit "$name"';
  @override String get quantityFieldLabel => 'Quantity';
  @override String get shelfCodeFieldLabel => 'Shelf code';
  @override String get shelfCodeFieldHint => 'Shelf B1';
  @override String get recordedBadge => 'Logged';
  @override String itemMeta(String q, String? code) => code != null ? '$q · $code' : q;

  @override String boughtTitle(String name) => '"$name" bought!';
  @override String get estimatedDaysQuestion => 'How long will it last?';
  @override String days(int n) => '$n days';
  @override String recordToInventory(int n) => 'Save to inventory ($n days)';

  @override String get inventoryTitle => 'Inventory';
  @override String inventorySummary(int t, int r) => '$t stocked · $r to restock';
  @override String get searchHint => 'Search items or aisle';
  @override String get inventoryEmptyTitle => 'Inventory is empty';
  @override String get inventoryEmptyTitleQuery => '';
  @override String inventoryNoResults(String q) => 'No results for "$q"';
  @override String get inventoryEmptySubtitle => 'Buy from your list and log it here';
  @override String get inventoryEmptySubtitleQuery => 'Try another keyword';
  @override String get addManually => 'Add item manually';
  @override String get usedUp => 'Used up';
  @override String daysRemainingLong(int n) => 'About $n days left';
  @override String daysShort(int n) => '${n}d';
  @override String daysShortApprox(int n) => '~${n}d';
  @override String get resetTimerSection => 'Repurchase, reset the timer';
  @override String resetTimer(int n) => 'Reset timer ($n days)';
  @override String get addToRestockList => 'Add to restock list';
  @override String get deleteFromInventory => 'Delete from inventory';
  @override String get addToInventoryTitle => 'Add to inventory';
  @override String get productNameHint => 'Item name';
  @override String get categoryLabel => 'Category';
  @override String get estimatedUseDays => 'Estimated days of use';
  @override String get addToInventoryBtn => 'Add to inventory';
  @override String estimatedDaysSelected(int n) => 'Will last $n days';

  @override String get reminderTitle => 'Alerts';
  @override String reminderSummary(int r, int e) => '$r to restock · $e running low';
  @override String get addAll => 'Add all';
  @override String get sectionRestock => 'Restock now';
  @override String get sectionExpiringSoon => 'Running low';
  @override String get reminderEmptyTitle => 'Everything is well stocked';
  @override String get reminderEmptySubtitle => 'Nothing needs restocking';
  @override String get usedUpNeedRestock => 'Used up, needs restocking';
  @override String daysLeftApprox(int n) => '~$n days left';
  @override String get add => 'Add';
  @override String get alreadyInList => 'In list';
  @override String get addedToListToast => 'Added to list';
  @override String get removedFromListToast => 'Removed from list';
  @override String addedAllToListToast(int n) => 'Added $n items to list';
  @override String get allAlreadyInList => 'All already in list';

  @override String get settingsTitle => 'Settings';
  @override String get proUpgrade => 'Upgrade to Pro';
  @override String get proDesc => 'Photo recognition · Quick-add widget · Multi-device sync';
  @override String get proCta => 'See Pro features →';
  @override String get sectionCategoryShelf => 'Categories & aisles';
  @override String get manageCategories => 'Product categories';
  @override String get addCategoryTitle => 'New category';
  @override String get editCategoryTitle => 'Edit category';
  @override String get categoryNameLabel => 'Name';
  @override String get categoryColorLabel => 'Color';
  @override String get shelfZoneLabel => 'Aisle';
  @override String get defaultDaysLabel => 'Default days';
  @override String get delete => 'Delete';
  @override String get undo => 'Undo';
  @override String itemDeletedToast(String name) => 'Deleted "$name"';
  @override String deleteCategoryTitle(String name) => 'Delete "$name"?';
  @override String get deleteCategoryMessage =>
      'Items in this category will be reassigned to "Other".';
  @override String categoriesCount(int n) => '$n';
  @override String get shelfOrder => 'Aisle order';
  @override String get noShelfCodes => 'No shelf codes yet';
  @override String get addShelfCodeTitle => 'New shelf code';
  @override String get shelfCodeNameLabel => 'Shelf code';
  @override String get shelfCodeNameHint => 'e.g. Aisle B1';
  @override String deleteShelfCodeTitle(String code) => 'Remove "$code"?';
  @override String get deleteShelfCodeMessage => 'Removes this code from the order list.';

  @override String get sectionReminder => 'Reminders';
  @override String get restockReminder => 'Restock reminder';
  @override String get reminderTimeLabel => 'Reminder time';
  @override String reminderTimeDisplay(int h, int m) =>
      'Daily ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  @override String get advanceDays => 'Lead days';
  @override String get customDaysLabel => 'Custom';
  @override String get dayUnit => 'days';
  @override String get saveChangesTitle => 'Save changes?';
  @override String get discardChanges => 'Discard';
  @override String get savedToast => 'Saved';
  @override String get restockToast => 'Timer reset';
  @override String get customDaysMaxHint => 'Max 1000 days';
  @override String get sectionData => 'Data';
  @override String get backupExport => 'Backup & export';
  @override String get importRestore => 'Import & restore';
  @override String get notifRestockTitle => 'Time to restock';
  @override String notifRestockBody(int count, List<String> names) {
    final shown = names.take(3).join(', ');
    final suffix = count > 3 ? '…' : '';
    return count == 1
        ? '1 item needs restocking: $shown'
        : '$count items need restocking: $shown$suffix';
  }
  @override String get notifPermissionDenied =>
      'Notifications are off. Enable them in system Settings.';
  @override String get importConfirmTitle => 'Import backup?';
  @override String get importConfirmMessage =>
      'This will replace ALL current data (lists, inventory, expenses, categories, settings). This cannot be undone.';
  @override String get importAction => 'Import';
  @override String get importInvalidFile => 'Invalid backup file';
  @override String get importSuccessToast => 'Backup restored';
  @override String get exportFailedToast => 'Export failed';
  @override String get storageUnavailableBanner =>
      'Storage failed to start — your changes won\'t be saved';
  @override String get appFooter => 'Shopping List v1.0.1';
  @override String get language => 'Language';
  @override String get languageSystem => 'Follow system';
  @override String get languageZh => '中文';
  @override String get languageEn => 'English';
  @override String labelForLanguage(Object lang) =>
      lang == AppLanguage.zh ? '中文' : lang == AppLanguage.en ? 'English' : 'Follow system';

  @override String get batchEdit => 'Edit';
  @override String get selectAll => 'Select all';
  @override String get batchMarkBought => 'Mark bought';
  @override String get batchAddToRestock => 'Add to restock';
  @override String selectedCount(int n) => '$n selected';

  @override String stockStatus(StockStatus s) {
    switch (s) {
      case StockStatus.sufficient: return 'Good';
      case StockStatus.low:        return 'Low';
      case StockStatus.empty:      return 'Out';
    }
  }

  @override String data(String canonical) => _enData[canonical] ?? canonical;

  @override String get tutorialExampleItemName => 'Egg (example)';
  @override String get tutorialStepAddItem => 'Tap + to add the example item to your list';
  @override String get tutorialStepCompleteTrip => 'Done shopping? Tap here to finish';
  @override String get tutorialStepViewInventory => 'Check your inventory for what you just bought';
  @override String get tutorialFinalMessage =>
      'When stock runs low, the Alerts tab will remind you to restock';
  @override String get tutorialGotIt => 'Got it';
  @override String get tutorialSkip => 'Skip';
}

String _enDate(DateTime d) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${m[d.month - 1]} ${d.day}';
}

/// Canonical (zh) → English display for the fixed sample-data set,
/// shelf-zone display names, the default reminder time, and generic
/// data-layer defaults (e.g. the fallback quantity label).
const Map<String, String> _enData = {
  // generic defaults (not sample-data specific — used whenever the app
  // itself picks a value, e.g. quantity left blank by the user)
  '1件': '1 item',
  // shelf zones (DISPLAY ONLY — keys in code stay Chinese)
  '果蔬区': 'Produce',
  '冷藏': 'Fridge',
  '粮油区': 'Pantry',
  '日用品': 'Household',
  '其他': 'Other',
  // default category names (used only to seed names when app starts in en)
  '果蔬': 'Produce',
  '乳制品': 'Dairy',
  '肉类': 'Meat',
  '粮油': 'Grains',
  // sample product names
  '香蕉': 'Banana',
  '番茄': 'Tomato',
  '藻菜': 'Greens',
  '牛奶': 'Milk',
  '鸡蛋': 'Eggs',
  '洗洁精': 'Dish soap',
  '大米': 'Rice',
  '酸奶': 'Yogurt',
  // sample quantity labels
  '1串': '1 bunch',
  '6个': '6 pcs',
  '1把': '1 bunch',
  '2盒': '2 boxes',
  '1打': '1 dozen',
  '1瓶': '1 bottle',
  '1袋': '1 bag',
  '4杯': '4 cups',
  // sample shelf codes
  '货架B3': 'Shelf B3',
  '货架B1': 'Shelf B1',
  '货架B2': 'Shelf B2',
  '货架D1': 'Shelf D1',
  '货架E2': 'Shelf E2',
  '冷柜C2': 'Fridge C2',
  '冷柜C1': 'Fridge C1',
  '冷柜C3': 'Fridge C3',
};
