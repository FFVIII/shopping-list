# Pro 一次性解锁付费墙 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 `in_app_purchase` 接一个非消耗型（一次性买断）内购，解锁设置页里现在被硬编码隐藏的"数据"分组（备份导出/导入恢复），并把已经存在但文案不符、从未接上跳转的 Pro 升级卡片改造成真正的购买入口。

**Architecture:** 新增 `PurchaseService`（`ChangeNotifier`，和现有 `SettingsNotifier` 等四个 notifier 同一套接线方式）封装 `in_app_purchase`；购买状态 `isPro` 通过 `AppRepository` 新增的两个方法持久化到已有的 `_metaBox`（跟 `saveSettings` 同款写法），**不**放进 `AppData`/`replaceAll`，因为恢复购买的判定应该来自 Apple 账号而不是备份文件——如果放进备份数据里，导入别人的备份会把你的购买状态覆盖掉，这是需要避免的。

**Tech Stack:** Flutter, `in_app_purchase` 插件（iOS StoreKit），Hive（已有）。

---

## 参考：本次涉及的既有代码

- `lib/storage/app_repository.dart` — `saveSettings`/`saveShelfZones` 等方法在第 189-196 行，都是 `_metaBox.put(...)` 的一行式写法；`class AppRepository` 结尾在第 210 行附近。
- `lib/state/settings_notifier.dart` — `ChangeNotifier` 接入 `AppRepository` 的范本，`load(AppData)`/`update`/`persist` 三个方法。
- `lib/main.dart`：
  - 第 149 行 `class _AppShellState`，第 155-160 行四个 `late final XxxNotifier` 字段。
  - 第 183-198 行 `initState`：四个 notifier 的 `addListener(_onDomainChanged)`。
  - 第 214-243 行 `_loadData()`：`await _repo.load(...)` 后依次调用每个 notifier 的 `.load(data)`。
  - 第 572-593 行：`SettingsScreen(...)` 构造调用。
- `lib/screens/settings_screen.dart`：
  - 第 21-23 行 `_kDataSectionEnabled` 常量。
  - 第 82 行 `_proCardEnabled` 常量。
  - 第 127-130 行：Pro 卡片渲染条件。
  - 第 164-171 行左右：`_buildSection(l.sectionData, [...])` 的渲染条件。
  - 第 203-278 行：`_buildProCard(AppStrings l)`。
- `lib/l10n/app_strings.dart`：`abstract class AppStrings`（第 8-192 行）、`class ZhStrings`（193-387）、`class EnStrings`（388-639）；现有 `proUpgrade`/`proDesc`/`proCta` 在 119-121（声明）、301-303（zh）、499-501（en）。

---

### Task 1: 添加 `in_app_purchase` 依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 加依赖**

在 `pubspec.yaml` 的 `dependencies:` 块里，`file_picker: ^10.3.0` 那一行下面加一行：

```yaml
  in_app_purchase: ^3.2.0
```

- [ ] **Step 2: 拉取依赖**

Run: `flutter pub get`
Expected: 输出里出现 `+ in_app_purchase 3.2.x`，无报错。

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add in_app_purchase dependency"
```

---

### Task 2: `AppRepository` 新增 `loadIsPro`/`saveIsPro`

**Files:**
- Modify: `lib/storage/app_repository.dart:195-196`（紧跟在 `saveShelfCodeOrder` 后面加）
- Test: `test/storage/app_repository_test.dart`

- [ ] **Step 1: 写失败的测试**

打开 `test/storage/app_repository_test.dart`，在文件末尾 `main()` 的闭合 `}` 之前（即最后一个 `test(...)` 块之后）加：

```dart
  test('isPro persists across load calls and defaults to false', () async {
    final repo = AppRepository();
    await repo.init();

    expect(await repo.loadIsPro(), isFalse);

    await repo.saveIsPro(true);
    expect(await repo.loadIsPro(), isTrue);

    // Simulates an app restart against the same on-disk box.
    final repo2 = AppRepository();
    await repo2.init();
    expect(await repo2.loadIsPro(), isTrue);
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/storage/app_repository_test.dart`
Expected: FAIL，报错里包含 `The method 'loadIsPro' isn't defined for the type 'AppRepository'`（编译期错误，因为方法还不存在）。

- [ ] **Step 3: 实现**

打开 `lib/storage/app_repository.dart`，在第 195-196 行 `saveShelfCodeOrder` 方法后面加：

```dart
  /// Purchase entitlement — intentionally NOT part of [AppData]/[replaceAll]:
  /// restoring a backup from another install must not overwrite whether
  /// *this* Apple ID has purchased Pro.
  Future<bool> loadIsPro() async =>
      _metaBox.get('is_pro') as bool? ?? false;

  Future<void> saveIsPro(bool value) => _metaBox.put('is_pro', value);
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/storage/app_repository_test.dart`
Expected: PASS，全部测试通过（含新加的这条）。

- [ ] **Step 5: Commit**

```bash
git add lib/storage/app_repository.dart test/storage/app_repository_test.dart
git commit -m "feat: add isPro persistence to AppRepository"
```

---

### Task 3: `PurchaseService`

**Files:**
- Create: `lib/services/purchase_service.dart`
- Test: `test/services/purchase_service_test.dart`

`PurchaseService` 把 `purchaseStream` 的来源和"确认交易"的调用都做成可注入参数（构造函数默认接到真实的 `InAppPurchase.instance`），这样测试完全不用碰平台插件通道，只驱动一个假的 `Stream<List<PurchaseDetails>>`。

- [ ] **Step 1: 写失败的测试**

创建 `test/services/purchase_service_test.dart`：

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shopping_list/services/purchase_service.dart';
import 'package:shopping_list/storage/app_repository.dart';

PurchaseDetails _purchase(PurchaseStatus status, {String? productId}) {
  return PurchaseDetails(
    purchaseID: 'test_purchase',
    productID: productId ?? PurchaseService.kProProductId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'test',
    ),
    transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
    status: status,
    // Explicit rather than relying on the package's default, so this test
    // doesn't silently start asserting nothing if that default ever changes.
  )..pendingCompletePurchase = true;
}

void main() {
  late Directory tempDir;
  late AppRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    repo = AppRepository();
    await repo.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('starts with the cached isPro value from the repo', () async {
    await repo.saveIsPro(true);
    final controller = StreamController<List<PurchaseDetails>>.broadcast();
    final service = PurchaseService(
      purchaseStream: controller.stream,
      completePurchase: (_) async {},
    );

    await service.init(repo);

    expect(service.isPro, isTrue);
    await controller.close();
    service.dispose();
  });

  test('a purchased update for the pro product sets isPro and persists it',
      () async {
    final controller = StreamController<List<PurchaseDetails>>.broadcast();
    final completed = <PurchaseDetails>[];
    final service = PurchaseService(
      purchaseStream: controller.stream,
      completePurchase: (p) async => completed.add(p),
    );

    await service.init(repo);
    expect(service.isPro, isFalse);

    controller.add([_purchase(PurchaseStatus.purchased)]);
    // Let the stream's listener microtask run.
    await Future<void>.delayed(Duration.zero);

    expect(service.isPro, isTrue);
    expect(await repo.loadIsPro(), isTrue);
    expect(completed, hasLength(1));

    await controller.close();
    service.dispose();
  });

  test('a purchase update for a different product is ignored', () async {
    final controller = StreamController<List<PurchaseDetails>>.broadcast();
    final service = PurchaseService(
      purchaseStream: controller.stream,
      completePurchase: (_) async {},
    );

    await service.init(repo);
    controller.add([_purchase(PurchaseStatus.purchased, productId: 'other')]);
    await Future<void>.delayed(Duration.zero);

    expect(service.isPro, isFalse);

    await controller.close();
    service.dispose();
  });

  test('an error status does not set isPro and records lastError', () async {
    final controller = StreamController<List<PurchaseDetails>>.broadcast();
    final service = PurchaseService(
      purchaseStream: controller.stream,
      completePurchase: (_) async {},
    );

    await service.init(repo);
    controller.add([_purchase(PurchaseStatus.error)]);
    await Future<void>.delayed(Duration.zero);

    expect(service.isPro, isFalse);
    expect(service.lastError, isNotNull);

    await controller.close();
    service.dispose();
  });
}
```

注意顶部还需要 `import 'dart:async';`（`StreamController` 在这里）——请在 `import 'dart:io';` 前面加这一行。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/services/purchase_service_test.dart`
Expected: FAIL，报错 `Target of URI doesn't exist: 'package:shopping_list/services/purchase_service.dart'`（文件还没建）。

- [ ] **Step 3: 实现**

创建 `lib/services/purchase_service.dart`：

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../storage/app_repository.dart';

/// Owns the one-time "Pro" unlock purchase (backup export/import restore).
///
/// Deliberately does NOT persist [isPro] through [AppData]/`replaceAll` —
/// restoring a backup from another install must not silently grant or
/// revoke the entitlement tied to *this* Apple ID.
class PurchaseService extends ChangeNotifier {
  static const kProProductId = 'com.ffviii.shoppinglist.pro_unlock';

  PurchaseService({
    Stream<List<PurchaseDetails>>? purchaseStream,
    Future<void> Function(PurchaseDetails)? completePurchase,
  })  : _purchaseStream =
            purchaseStream ?? InAppPurchase.instance.purchaseStream,
        _completePurchase =
            completePurchase ?? InAppPurchase.instance.completePurchase;

  final Stream<List<PurchaseDetails>> _purchaseStream;
  final Future<void> Function(PurchaseDetails) _completePurchase;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  late AppRepository _repo;

  bool isPro = false;
  ProductDetails? proProduct;
  String? lastError;

  Future<void> init(AppRepository repo) async {
    _repo = repo;
    isPro = await repo.loadIsPro();
    notifyListeners();
    _subscription = _purchaseStream.listen(_handlePurchaseUpdate);
    unawaited(_loadProduct());
  }

  Future<void> _loadProduct() async {
    try {
      final response =
          await InAppPurchase.instance.queryProductDetails({kProProductId});
      if (response.productDetails.isNotEmpty) {
        proProduct = response.productDetails.first;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('PurchaseService: failed to query product details: $e');
    }
  }

  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      // Safe to skip entirely (including completePurchase) for anything
      // that isn't the Pro product — this app only ever sells the one.
      if (purchase.productID != kProProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          isPro = true;
          await _repo.saveIsPro(true);
          notifyListeners();
          break;
        case PurchaseStatus.error:
          lastError = purchase.error?.message ?? 'purchase failed';
          notifyListeners();
          break;
        case PurchaseStatus.pending:
        case PurchaseStatus.canceled:
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _completePurchase(purchase);
      }
    }
  }

  Future<void> buy() async {
    final product = proProduct;
    if (product == null) return;
    lastError = null;
    await InAppPurchase.instance
        .buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }

  Future<void> restorePurchases() async {
    lastError = null;
    await InAppPurchase.instance.restorePurchases();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/services/purchase_service_test.dart`
Expected: PASS，4 个测试全部通过。

- [ ] **Step 5: Commit**

```bash
git add lib/services/purchase_service.dart test/services/purchase_service_test.dart
git commit -m "feat: add PurchaseService for the one-time Pro unlock"
```

---

### Task 4: l10n 字符串

**Files:**
- Modify: `lib/l10n/app_strings.dart`

- [ ] **Step 1: 抽象类新增声明**

在第 119-121 行（`String get proUpgrade;` / `proDesc` / `proCta` 三行）后面加：

```dart
  String get proScreenTitle;      // "解锁 Pro" / "Unlock Pro"
  String get proBuyButton;        // "购买解锁" / "Unlock now"
  String get proRestoreButton;    // "恢复购买" / "Restore purchases"
  String get proPriceUnavailable; // "价格加载中…" / "Loading price…"
  String get proPurchaseSuccessToast; // "已解锁 Pro！" / "Pro unlocked!"
  String get proPurchaseFailedToast;  // "购买失败，请重试" / "Purchase failed, try again"
```

- [ ] **Step 2: `ZhStrings` 实现**

第 302 行 `proDesc` 内容改掉（旧文案描述的功能都不存在），并在第 303 行 `proCta` 后面加新字符串：

```dart
  @override String get proDesc => '解锁备份导出与导入恢复';
  @override String get proCta => '查看详情 →';
  @override String get proScreenTitle => '解锁 Pro';
  @override String get proBuyButton => '购买解锁';
  @override String get proRestoreButton => '恢复购买';
  @override String get proPriceUnavailable => '价格加载中…';
  @override String get proPurchaseSuccessToast => '已解锁 Pro！';
  @override String get proPurchaseFailedToast => '购买失败，请重试';
```

（`proCta` 原文是 `'查看 Pro 功能 →'`，这里顺手改成更贴切的"查看详情 →"，因为它现在链接到的是一个具体的购买页而不是抽象的"功能列表"。）

- [ ] **Step 3: `EnStrings` 实现**

同样位置（第 500-501 行 `proDesc`/`proCta`）：

```dart
  @override String get proDesc => 'Unlock backup export & import restore';
  @override String get proCta => 'See details →';
  @override String get proScreenTitle => 'Unlock Pro';
  @override String get proBuyButton => 'Unlock now';
  @override String get proRestoreButton => 'Restore purchases';
  @override String get proPriceUnavailable => 'Loading price…';
  @override String get proPurchaseSuccessToast => 'Pro unlocked!';
  @override String get proPurchaseFailedToast => 'Purchase failed, please try again';
```

- [ ] **Step 4: 验证没有漏掉抽象成员**

Run: `flutter analyze lib/l10n/app_strings.dart`
Expected: `No issues found!`（如果 `ZhStrings`/`EnStrings` 漏实现某个新声明的 getter，这里会报 `missing_implementations` 编译错误）。

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart
git commit -m "feat: add l10n strings for the Pro upgrade screen"
```

---

### Task 5: `ProUpgradeScreen`

**Files:**
- Create: `lib/screens/pro_upgrade_screen.dart`

- [ ] **Step 1: 创建页面**

```dart
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/purchase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/toast.dart';

class ProUpgradeScreen extends StatefulWidget {
  final PurchaseService purchaseService;

  const ProUpgradeScreen({super.key, required this.purchaseService});

  @override
  State<ProUpgradeScreen> createState() => _ProUpgradeScreenState();
}

class _ProUpgradeScreenState extends State<ProUpgradeScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.purchaseService.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.purchaseService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() => _busy = false);
    final l = L10n.of(context);
    if (widget.purchaseService.isPro) {
      showAppToast(context, l.proPurchaseSuccessToast);
      Navigator.pop(context);
      return;
    }
    if (widget.purchaseService.lastError != null) {
      showAppToast(context, l.proPurchaseFailedToast);
    }
  }

  Future<void> _buy() async {
    setState(() => _busy = true);
    await widget.purchaseService.buy();
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    await widget.purchaseService.restorePurchases();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final product = widget.purchaseService.proProduct;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(l.proScreenTitle,
            style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.proDesc,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: (_busy || product == null) ? null : _buy,
                  child: Text(
                    product != null
                        ? '${l.proBuyButton} · ${product.price}'
                        : l.proPriceUnavailable,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(l.proRestoreButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 验证编译**

Run: `flutter analyze lib/screens/pro_upgrade_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/pro_upgrade_screen.dart
git commit -m "feat: add ProUpgradeScreen"
```

---

### Task 6: 接入 `main.dart`

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 加 import**

在第 27 行 `import 'widgets/tutorial_target.dart';` 后面加：

```dart
import 'services/purchase_service.dart';
```

- [ ] **Step 2: 新增字段**

在第 155-160 行四个 `late final XxxNotifier` 字段后面加：

```dart
  late final PurchaseService _purchaseService = PurchaseService();
```

- [ ] **Step 3: 接入监听 + 初始化**

在第 183-198 行的 `initState` 里，找到这段循环：

```dart
    for (final n in [
      _shoppingNotifier,
      _inventoryNotifier,
      _categoriesNotifier,
      _settingsNotifier,
    ]) {
      n.addListener(_onDomainChanged);
    }
```

把 `_purchaseService` 加进这个列表，以及 `dispose()` 里那份一模一样的列表（两处都要加）：

```dart
    for (final n in [
      _shoppingNotifier,
      _inventoryNotifier,
      _categoriesNotifier,
      _settingsNotifier,
      _purchaseService,
    ]) {
      n.addListener(_onDomainChanged);
    }
```

`dispose()` 方法里（第 200-212 行附近）同样的列表也要加 `_purchaseService`：

```dart
    for (final n in [
      _shoppingNotifier,
      _inventoryNotifier,
      _categoriesNotifier,
      _settingsNotifier,
      _purchaseService,
    ]) {
      n.removeListener(_onDomainChanged);
      n.dispose();
    }
```

- [ ] **Step 4: 在 `_loadData()` 里初始化**

在 `_loadData()`（第 214-243 行）里，`if (!mounted) return;` 那行之后、`_shoppingNotifier.load(data);` 之前加：

```dart
    unawaited(_purchaseService.init(_repo));
```

（`unawaited` 已经在文件顶部 `import 'dart:async';`，不需要新加 import。）

- [ ] **Step 5: 传给 `SettingsScreen`**

在第 572-593 行 `SettingsScreen(...)` 构造调用里加一行（放在 `requestNotificationPermission:` 那行后面）：

```dart
                    purchaseService: _purchaseService,
```

- [ ] **Step 6: 验证编译**

Run: `flutter analyze lib/main.dart`
Expected: 这一步会报错，因为 `SettingsScreen` 构造函数还没有 `purchaseService` 这个具名参数——这是预期的，Task 7 会加上。跳过这一步的"必须通过"要求，继续往下做。

- [ ] **Step 7: Commit**

先不要单独 commit——这一步和 Task 7 是同一个逻辑改动的两半（`main.dart` 传参 + `SettingsScreen` 接参），分开 commit 会有一个提交编译不过。留到 Task 7 结束后一起提交。

---

### Task 7: `settings_screen.dart` 接入付费判断

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: 加 import**

在文件顶部 import 列表里加：

```dart
import '../services/purchase_service.dart';
import 'pro_upgrade_screen.dart';
```

- [ ] **Step 2: 删除两个写死的常量**

删除第 21-23 行：

```dart
// Backup/restore is a planned paid-tier feature; hide the section until
// that gating lands instead of shipping it free.
const bool _kDataSectionEnabled = false;
```

删除第 82 行（`_SettingsScreenState` 类内部）：

```dart
  // Temporarily hidden — not ready to sell Pro yet. Flip back on when it is.
  static const bool _proCardEnabled = false;
```

- [ ] **Step 3: `SettingsScreen` 构造函数加参数**

在 `class SettingsScreen extends StatefulWidget` 的字段列表里（`requestNotificationPermission` 那个字段附近）加：

```dart
  final PurchaseService purchaseService;
```

在构造函数参数列表里（`required this.requestNotificationPermission,` 后面）加：

```dart
    required this.purchaseService,
```

- [ ] **Step 4: 替换 Pro 卡片显示条件，并接上点击跳转**

原来（第 127-130 行左右）：

```dart
            if (_proCardEnabled) ...[
              const SizedBox(height: 4),
              _buildProCard(l),
            ],
```

改成：

```dart
            if (!widget.purchaseService.isPro) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProUpgradeScreen(purchaseService: widget.purchaseService),
                  ),
                ),
                child: _buildProCard(l),
              ),
            ],
```

- [ ] **Step 5: 替换"数据"分组显示条件**

找到原来的：

```dart
            if (_kDataSectionEnabled) ...[
              const SizedBox(height: 16),
              _buildSection(l.sectionData, [
                _navRow(l.backupExport, onTap: _exportBackup),
                _navRow(l.importRestore, onTap: _importBackup),
              ]),
            ],
```

改成：

```dart
            if (widget.purchaseService.isPro) ...[
              const SizedBox(height: 16),
              _buildSection(l.sectionData, [
                _navRow(l.backupExport, onTap: _exportBackup),
                _navRow(l.importRestore, onTap: _importBackup),
              ]),
            ],
```

- [ ] **Step 6: 在 `main.dart` 里补上刚才漏的参数（回到 Task 6 Step 5 的调用点）**

确认 `main.dart` 里 `SettingsScreen(...)` 构造调用已经有 `purchaseService: _purchaseService,`（Task 6 Step 5 已经加过）。

- [ ] **Step 7: 全量验证**

Run: `flutter analyze`
Expected: 输出里只剩下这个仓库里本来就有的、跟本次改动无关的那条 `test/storage/app_repository_test.dart:81` 的 `unused_local_variable` 警告；不应该再有别的错误或警告。

Run: `flutter test`
Expected: 全部测试通过（数量比改动前多，因为 Task 2/3 各加了新测试）。

- [ ] **Step 8: Commit**

```bash
git add lib/main.dart lib/screens/settings_screen.dart
git commit -m "feat: gate the Data section and wire up the Pro upgrade card"
```

---

### Task 8: `settings_screen.dart` 显示条件的 widget 测试

**Files:**
- Create: `test/screens/settings_screen_test.dart`

`PurchaseService` 的 `isPro` 是公开可写字段，测试里不需要调用 `init()`（不碰 Hive/`InAppPurchase` 单例），直接 `PurchaseService()..isPro = true/false` 就行。

- [ ] **Step 1: 写失败的测试**

创建 `test/screens/settings_screen_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/l10n/app_language.dart';
import 'package:shopping_list/l10n/app_strings.dart';
import 'package:shopping_list/l10n/l10n.dart';
import 'package:shopping_list/models/item.dart';
import 'package:shopping_list/screens/settings_screen.dart';
import 'package:shopping_list/services/purchase_service.dart';

Future<void> _pumpSettings(WidgetTester tester,
    {required bool isPro}) async {
  final purchaseService = PurchaseService()..isPro = isPro;

  await tester.pumpWidget(
    L10n(
      strings: ZhStrings(),
      language: AppLanguage.zh,
      child: MaterialApp(
        home: SettingsScreen(
          settings: AppSettings(),
          onChanged: (_) {},
          language: AppLanguage.zh,
          onLanguageChanged: (_) {},
          shelfZones: defaultShelfZones,
          onReorderShelfZones: (_, _) {},
          shelfCodeOrder: const [],
          onReorderShelfCodes: (_, _) {},
          onAddShelfCode: (_) {},
          onDeleteShelfCode: (_) {},
          onRenameShelfCode: (_, _) {},
          categories: buildDefaultCategories(),
          onAddCategory: (name, color, zone, days) => buildDefaultCategories().fallback,
          onEditCategory: (_, _, _, _, _) {},
          onDeleteCategory: (_) {},
          onReorderCategories: (_, _) {},
          buildBackupBytes: () => <int>[],
          onImportBackup: (_) async {},
          requestNotificationPermission: () async => true,
          purchaseService: purchaseService,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Data section hidden and Pro card shown when not purchased',
      (tester) async {
    await _pumpSettings(tester, isPro: false);

    expect(find.text(ZhStrings().sectionData), findsNothing);
    expect(find.text(ZhStrings().proUpgrade), findsOneWidget);
  });

  testWidgets('Data section shown and Pro card hidden once purchased',
      (tester) async {
    await _pumpSettings(tester, isPro: true);

    expect(find.text(ZhStrings().sectionData), findsOneWidget);
    expect(find.text(ZhStrings().proUpgrade), findsNothing);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: FAIL——如果 Task 6/7 都已经做完，这一步应该已经是 PASS 了（这个任务本质是给已完成的改动补测试，不是严格的先写测试后实现）；如果还没做 Task 6/7，会因为 `SettingsScreen` 缺 `purchaseService` 参数而编译失败。请确认 Task 6/7 都已完成后再执行本 Step。

- [ ] **Step 3: 跑测试确认通过**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: PASS，2 个测试都通过。

- [ ] **Step 4: Commit**

```bash
git add test/screens/settings_screen_test.dart
git commit -m "test: cover settings screen Data-section/Pro-card visibility"
```

---

### Task 9: 收尾说明（不是代码改动）

**没有 Apple Developer 账号之前，这个功能没法做端到端真机验证。** 在 App Store Connect 里创建非消耗型内购商品 `com.ffviii.shoppinglist.pro_unlock`（定价、展示名称、审核用的商品描述截图这些都在那边填）之前：

- 模拟器/未配置商品的真机上，`_loadProduct()` 里的 `queryProductDetails` 会返回空结果，`proProduct` 一直是 `null`，购买页面按钮会一直显示"价格加载中…"且不可点——这是预期的优雅降级，不是 bug。
- `flutter analyze`/`flutter test` 能验证代码逻辑正确，但验证不了"点击购买后 StoreKit 弹窗弹出、沙盒账号扣款、`purchaseStream` 收到 `purchased` 状态"这一整条链路——这必须等 App Store Connect 配置完、且用沙盒测试账号登录真机后才能测。

建议：账号/商品配置好之后，找一台真机，登录一个 App Store 沙盒测试账号（在 App Store Connect 的"用户和访问"里创建），完整走一遍"点 Pro 卡片 → 点购买解锁 → 系统弹窗确认 → 返回设置页 → 数据分组出现"这条路径，再验证"杀掉 App 重开 → 数据分组还在（`isPro` 持久化生效）"和"卸载重装 → 点恢复购买 → 数据分组恢复"这两条。
