# 设计文档：Pro 一次性解锁（备份导出/导入恢复）

日期：2026-07-12
状态：已批准设计，待实施计划

## 1. 目标

把设置页里已经存在、但一直被硬编码关闭的两处"未来功能"接上真正的付费解锁：

1. **"数据"分组**（`lib/screens/settings_screen.dart` 的 `_kDataSectionEnabled = false`）——备份导出 / 导入恢复这两行。
2. **Pro 升级卡片**（同文件 `_proCardEnabled = false`，`_buildProCard`）——现有文案（"拍照识别配图 · 快捷加项组件 · 多设备同步备份"）描述的是一堆还不存在的功能，本次全部替换为"解锁备份导出/导入恢复"。

用户购买一次、永久解锁，不做订阅。

## 2. 关键决策（已与用户确认）

| 决策 | 选择 |
|---|---|
| 付费模式 | **一次性买断**（非消耗型内购），不做订阅 |
| 解锁范围 | 仅"数据"分组（备份导出、导入恢复）；Pro 卡片文案同步改为描述这个 |
| 技术方案 | Flutter 官方 `in_app_purchase` 插件直连 StoreKit，不引入 RevenueCat 等第三方服务——本 App 完全本地化（无账号/无后端），一次性单功能解锁不需要服务器端收据校验 |
| 商品 ID | `com.ffviii.shoppinglist.pro_unlock`（非消耗型，需在 App Store Connect 手动创建；本次实现前用户还没有 Apple Developer 账号，无法现在建） |
| 持久化 | 走 `AppRepository` 现有的公开读写模式（跟 `saveSettings`/`AppData.settings` 一样），新增 `AppData.isPro` 字段 + `AppRepository.saveIsPro(bool)` 方法，底层落到 `_metaBox` 的新键 `is_pro`（`_metaBox` 本身是私有的，`PurchaseService` 不直接碰它） |
| Pro 卡片入口 | 复用现有卡片，点击后跳转一个新的"购买 Pro"页面（价格从商店动态读取），页面里含"购买解锁"按钮和 App Store 强制要求的"恢复购买"入口 |

显式排除（YAGNI）：订阅/续费逻辑、服务器端收据校验、Android 内购（先只做 iOS，`in_app_purchase` 是跨平台插件，但本次不测 Android）、多档位定价、优惠码、免费试用。

## 3. 新依赖

- `in_app_purchase: ^3.2.0`（官方插件，iOS 走 StoreKit）

## 4. `lib/services/purchase_service.dart`（新文件）

```dart
class PurchaseService extends ChangeNotifier {
  static const kProProductId = 'com.ffviii.shoppinglist.pro_unlock';

  bool get isPro;                                  // 当前是否已解锁
  ProductDetails? get proProduct;                   // 从商店读到的商品信息（价格等），未加载完成时为 null

  void load(AppData data);                           // 用启动时已加载的 AppData 播种 isPro 初值（跟其他 *Notifier.load 同一套模式）
  Future<void> init(AppRepository repo);            // 启动时调用一次：监听 purchaseStream + 查询商品信息；repo 留着写回持久化
  Future<void> buy();                                // 发起购买
  Future<void> restorePurchases();                   // 恢复购买
  void dispose();                                     // 取消 purchaseStream 订阅
}
```

- `AppData` 新增字段 `bool isPro`，`AppRepository.load()` 里从 `_metaBox.get('is_pro')`（缺省 `false`）读出、填进去——和 `settings`/`shelfZones` 现在的读法一模一样。`AppRepository` 新增 `Future<void> saveIsPro(bool value) => _metaBox.put('is_pro', value);`（对照现有 `saveSettings`）。
- `main.dart` 的 `_loadData()` 里，`data = await _repo.load(...)` 之后跟其他 notifier 一样调 `_purchaseService.load(data)`，用缓存值同步初始化 `isPro`（不用等 StoreKit 往返）。
- `init()` 里 `InAppPurchase.instance.purchaseStream.listen(...)`：收到 `PurchaseStatus.purchased`/`restored` 且 `productID == kProProductId` 时，`repo.saveIsPro(true)`、`isPro = true`、`notifyListeners()`，并调用 `completePurchase()`（iOS 要求确认交易，否则会反复重放）。
- `queryProductDetails({kProProductId})` 在 `init()` 里发起一次，填充 `proProduct`；商店不可用（模拟器、无网）时静默失败，`proProduct` 保持 `null`，购买页面显示"暂时无法读取价格"而不是崩溃。
- 错误处理：`buy()`/`restorePurchases()` 遇到 `PurchaseStatus.error` 时不抛异常，只是不设置 `isPro`；调用方（购买页面）自己在按钮的 `onPressed` 里包一层，失败了弹 toast。

**可测性**：`isPro` 的读写、"收到 purchased 状态后置位"这套状态机可以用一个假的 purchase-stream（`StreamController`）单测，不需要真的连 StoreKit。

## 5. 接入点

- `main.dart`：`PurchaseService` 和现有四个 `*Notifier` 一样，在 `_AppShellState` 里创建、`initState` 里 `init(_repo)`、`_loadData()` 里 `load(data)`、监听变化触发 `setState`（同 `_onDomainChanged` 模式）。
- `settings_screen.dart`：
  - `_kDataSectionEnabled`/`_proCardEnabled` 两个写死的 `bool` 常量删除，改成读 `widget.purchaseService.isPro`（"数据"区显示条件、Pro 卡片显示条件互斥：`isPro` 为真显示"数据"区、隐藏 Pro 卡片；为假则反过来）。
  - Pro 卡片文案（`proDesc`/`proCta` 等 l10n 字符串）改写为描述备份导出/导入恢复。
  - 卡片包一层 `GestureDetector`，`onTap` 跳转新页面 `ProUpgradeScreen`。

## 6. `lib/screens/pro_upgrade_screen.dart`（新文件）

简单的一页：标题 + 功能说明（备份导出、导入恢复各一行）+ 价格文本（`purchaseService.proProduct?.price ?? '—'`)+"购买解锁"按钮（`onPressed: purchaseService.buy`）+ 底部"恢复购买"文字链接（`purchaseService.restorePurchases`）。购买/恢复成功后 `Navigator.pop`，设置页因为监听了 `PurchaseService` 会自动刷新显示"数据"区。

## 7. iOS 平台配置

- 无需改 `Info.plist`（内购不需要声明用途字符串）。
- App Store Connect 里创建非消耗型内购商品 `com.ffviii.shoppinglist.pro_unlock`——这一步需要用户先注册 Apple Developer Program 账号，本次实现之后用户自己去配置定价和文案；配置完成前，模拟器/未登录沙盒账号的真机上购买会失败（预期行为，不是 bug）。

## 8. 测试

- `test/services/purchase_service_test.dart`：用假的 `Stream<List<PurchaseDetails>>` 驱动，断言收到 purchased 状态后 `isPro` 变 `true` 且调用了 `repo.saveIsPro(true)`；断言 `load(data)` 能从 `AppData.isPro` 正确恢复初值。
- `test/screens/settings_screen_test.dart`（如尚不存在则新建）：`isPro=false` 时"数据"区不可见、Pro 卡片可见；`isPro=true` 时相反。
