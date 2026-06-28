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
  String get modeSimple;
  String get modeSmart;
  String get byShelf;
  String get byCategory;
  String get purchasedSection;
  String itemCountChip(int n); // "3件" / "3"
  String get listEmptyTitle;
  String get listEmptySubtitle;
  String get listeningHint;
  String get smartAddHint;
  String get simpleAddHint;
  String addItemTitle(String name);
  String get chooseCategoryHint;
  String shelfZoneInline(String zoneDisplay); // "货架区：果蔬区" / "Aisle: Produce"
  String get addToList;
  String get rename;
  String get confirmEdit;
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
  String categoriesCount(int n); // "12类"
  String get shelfOrder;
  String get sectionReminder;
  String get restockReminder;
  String get reminderTimeLabel;
  String get advanceDays; // "提前天数"
  String get sectionData;
  String get backupExport;
  String get importRestore;
  String get appFooter; // "购物清单 v1.0 · 本地优先"
  String get language; // "语言" / "Language"
  String get languageSystem; // "跟随系统"
  String get languageZh; // "中文"
  String get languageEn; // "English"
  String labelForLanguage(/* AppLanguage */ Object lang); // trailing display

  // ── Enum + data lookups ──
  String category(Category c);
  String stockStatus(StockStatus s);
  String data(String canonical);
  String get scale1Day; // "1天" / "1d"
  String get scale1Week; // "1周" / "1wk"
  String get scale2Week; // "2周" / "2wk"
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
  @override String get modeSimple => '简单';
  @override String get modeSmart => '智能';
  @override String get byShelf => '按货架';
  @override String get byCategory => '按分类';
  @override String get purchasedSection => '已购';
  @override String itemCountChip(int n) => '$n件';
  @override String get listEmptyTitle => '清单是空的';
  @override String get listEmptySubtitle => '在下方输入要买的商品';
  @override String get listeningHint => '正在听，请说商品名称...';
  @override String get smartAddHint => '添加商品，选分类后入库...';
  @override String get simpleAddHint => '随手记，添加到清单...';
  @override String addItemTitle(String name) => '添加「$name」';
  @override String get chooseCategoryHint => '选择分类，方便按货架分组';
  @override String shelfZoneInline(String z) => '货架区：$z';
  @override String get addToList => '加入清单';
  @override String get rename => '重命名';
  @override String get confirmEdit => '确认修改';
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
  @override String get manageCategories => '管理分类';
  @override String categoriesCount(int n) => '$n类';
  @override String get shelfOrder => '货架顺序';
  @override String get sectionReminder => '提醒';
  @override String get restockReminder => '补货提醒';
  @override String get reminderTimeLabel => '提醒时间';
  @override String get advanceDays => '提前天数';
  @override String get sectionData => '数据';
  @override String get backupExport => '备份导出';
  @override String get importRestore => '导入恢复';
  @override String get appFooter => '购物清单 v1.0 · 本地优先';
  @override String get language => '语言';
  @override String get languageSystem => '跟随系统';
  @override String get languageZh => '中文';
  @override String get languageEn => 'English';
  @override String labelForLanguage(Object lang) =>
      lang == AppLanguage.zh ? '中文' : lang == AppLanguage.en ? 'English' : '跟随系统';
  @override String get scale1Day => '1天';
  @override String get scale1Week => '1周';
  @override String get scale2Week => '2周';

  @override String category(Category c) {
    switch (c) {
      case Category.produce:  return '果蔬';
      case Category.dairy:    return '乳制品';
      case Category.meat:     return '肉类';
      case Category.grain:    return '粮油';
      case Category.cleaning: return '清洁';
      case Category.beverage: return '饮料';
      case Category.other:    return '其他';
    }
  }

  @override String stockStatus(StockStatus s) {
    switch (s) {
      case StockStatus.sufficient: return '充足';
      case StockStatus.low:        return '快没';
      case StockStatus.empty:      return '用完';
    }
  }

  @override String data(String canonical) => canonical; // zh is canonical
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
  @override String get modeSimple => 'Simple';
  @override String get modeSmart => 'Smart';
  @override String get byShelf => 'By aisle';
  @override String get byCategory => 'By category';
  @override String get purchasedSection => 'Bought';
  @override String itemCountChip(int n) => '$n';
  @override String get listEmptyTitle => 'Your list is empty';
  @override String get listEmptySubtitle => 'Add items to buy below';
  @override String get listeningHint => 'Listening, say the item name...';
  @override String get smartAddHint => 'Add item, pick a category...';
  @override String get simpleAddHint => 'Jot it down, add to list...';
  @override String addItemTitle(String name) => 'Add "$name"';
  @override String get chooseCategoryHint => 'Pick a category to group by aisle';
  @override String shelfZoneInline(String z) => 'Aisle: $z';
  @override String get addToList => 'Add to list';
  @override String get rename => 'Rename';
  @override String get confirmEdit => 'Save';
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
  @override String get manageCategories => 'Manage categories';
  @override String categoriesCount(int n) => '$n';
  @override String get shelfOrder => 'Aisle order';
  @override String get sectionReminder => 'Reminders';
  @override String get restockReminder => 'Restock reminder';
  @override String get reminderTimeLabel => 'Reminder time';
  @override String get advanceDays => 'Lead days';
  @override String get sectionData => 'Data';
  @override String get backupExport => 'Backup & export';
  @override String get importRestore => 'Import & restore';
  @override String get appFooter => 'Shopping List v1.0 · Local-first';
  @override String get language => 'Language';
  @override String get languageSystem => 'Follow system';
  @override String get languageZh => '中文';
  @override String get languageEn => 'English';
  @override String labelForLanguage(Object lang) =>
      lang == AppLanguage.zh ? '中文' : lang == AppLanguage.en ? 'English' : 'Follow system';
  @override String get scale1Day => '1d';
  @override String get scale1Week => '1wk';
  @override String get scale2Week => '2wk';

  @override String category(Category c) {
    switch (c) {
      case Category.produce:  return 'Produce';
      case Category.dairy:    return 'Dairy';
      case Category.meat:     return 'Meat';
      case Category.grain:    return 'Grains';
      case Category.cleaning: return 'Cleaning';
      case Category.beverage: return 'Beverage';
      case Category.other:    return 'Other';
    }
  }

  @override String stockStatus(StockStatus s) {
    switch (s) {
      case StockStatus.sufficient: return 'Good';
      case StockStatus.low:        return 'Low';
      case StockStatus.empty:      return 'Out';
    }
  }

  @override String data(String canonical) => _enData[canonical] ?? canonical;
}

String _enDate(DateTime d) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${m[d.month - 1]} ${d.day}';
}

/// Canonical (zh) → English display for the fixed sample-data set,
/// shelf-zone display names, and the default reminder time.
const Map<String, String> _enData = {
  // shelf zones (DISPLAY ONLY — keys in code stay Chinese)
  '果蔬区': 'Produce',
  '冷藏/乳制品': 'Fridge / Dairy',
  '粮油区': 'Pantry',
  '日用品': 'Household',
  '其他': 'Other',
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
  // sample shelf codes
  '货架B3': 'Shelf B3',
  '货架B1': 'Shelf B1',
  '货架B2': 'Shelf B2',
  '冷柜C2': 'Fridge C2',
  '冷柜C1': 'Fridge C1',
  // default reminder time
  '每天 18:00': 'Daily 18:00',
};
