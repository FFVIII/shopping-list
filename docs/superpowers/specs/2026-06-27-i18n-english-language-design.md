# 设计文档：新增英语语言支持（中 / 英切换）

日期：2026-06-27
状态：已批准设计，待实施计划

## 1. 目标

为购物清单 App 增加英语支持，用户可在「中文 / English / 跟随系统」之间切换，整个界面文案随之变化。选择跨重启保留。

## 2. 关键决策（已与用户确认）

| 决策 | 选择 |
|---|---|
| 实现方式 | 轻量自建：`InheritedWidget` + 带 getter/方法的 `AppStrings` 类 |
| 持久化 | 是，使用 `shared_preferences` 记住用户选择 |
| 默认语言 | 跟随系统语言（系统为英文则英文，否则中文） |
| 示例数据（香蕉、牛奶等） | 随语言翻译显示 |

显式排除（YAGNI）：不引入 `flutter_localizations` / `gen_l10n` / `.arb`；不引入第三方 i18n 包；除语言外不新增其他持久化数据；不做第三种语言。

## 3. 架构

新增目录 `lib/l10n/`：

### 3.1 `AppLanguage` 枚举（用户的「设置值」）
```
enum AppLanguage { system, zh, en }
```
- 这是存盘与设置页展示的值。
- 解析为「生效语言」`Lang { zh, en }`：`system` → 读取设备 locale，`startsWith('zh')` 则 zh，否则 en。

### 3.2 `AppStrings`（文案表）
- 抽象基类 `AppStrings`，定义所有文案为 getter（静态文案）或方法（带参文案）。
- 两个实现：`ZhStrings`、`EnStrings`。
- 带参示例：
  - `String itemsRemaining(int n)` → "还差 4 件" / "4 left"
  - `String days(int n)` → "7天" / "7 days"
  - `String inventorySummary(int total, int restock)` → "8件常备 · 4件需补货" / "8 stocked · 4 to restock"
  - `String daysLeftApprox(int n)` / `String daysLeft(int n)`
  - `String addItemTitle(String name)` → "添加「香蕉」" / "Add \"Banana\""
  - `String boughtTitle(String name)` → "「香蕉」买到了！" / "\"Banana\" bought!"
  - `String recordToInventory(int days)` → "记录到库存（7天）" / "Save to inventory (7 days)"
  - `String dateLabel(DateTime d)` → "6月27日" / "Jun 27"
  - 分类、状态、货架区的显示名也通过方法取：`category(Category c)`、`stockStatus(StockStatus s)`、`shelfZone(String zoneId)`

### 3.3 `L10n` InheritedWidget
- 携带当前 `AppStrings strings` 与当前 `AppLanguage`。
- `static AppStrings of(BuildContext) => ...strings`（便捷访问）。
- 各页面调用 `L10n.of(context)` 取文案；语言变化时 `updateShouldNotify` 触发全树重建。

## 4. 状态与启动流程

- `ShoppingListApp` 改为 `StatefulWidget`，持有 `AppLanguage _language`。
- 切换语言：`setState` 更新 `_language` → 重建 `MaterialApp`（用 `L10n` 包裹）→ 异步写入 `shared_preferences`。
- `main()` 改为 `async`：
  1. `WidgetsFlutterBinding.ensureInitialized()`
  2. 从 `shared_preferences` 读取已存语言；无则用 `AppLanguage.system`
  3. `runApp(ShoppingListApp(initialLanguage: ...))`
- 同时给 `MaterialApp` 设置 `locale` / `supportedLocales`，使系统级 Material 组件（如有）随之本地化（次要，但顺手做）。

## 5. 设置页改动

- 在现有结构中新增一个 section 或行：「语言 / Language」。
- 点击弹出底部选择（跟随系统 / 中文 / English），样式沿用现有 sheet 风格。
- 选中即时生效并存盘；当前选择以 trailing 文字展示。

## 6. 需要国际化的范围

约 159 处中文硬编码字符串，分布于：
- `lib/main.dart`（底部导航标签、天数 sheet）
- `lib/screens/list_screen.dart`（标题、模式切换、空状态、添加 sheet、重命名 sheet、语音提示等）
- `lib/screens/inventory_screen.dart`（标题、搜索、详情 sheet、添加 sheet、空状态、状态徽章）
- `lib/screens/reminder_screen.dart`
- `lib/screens/settings_screen.dart`（全部分区标题与行）
- `lib/models/item.dart`：
  - `Category.label`（果蔬/乳制品/…）
  - `StockStatus.label`（充足/快没/用完）
  - `kShelfZones` 显示名
  - `buildSampleShopping()` / `buildSampleInventory()` 的商品名与 `AppSettings.reminderTime` 默认串「每天 18:00」

## 7. 最需小心的不变量（保护既有逻辑）

货架区字符串当前同时承担两个角色：**分组/排序的 key** 和 **显示文字**。

- **保持内部 key 不变**：`item.shelfZone` 仍存现有中文字符串（如 `'果蔬区'`）作为稳定标识；分组、跨组拖拽、库存匹配逻辑一律基于该 key，不受语言影响。
- **仅翻译显示**：渲染分组标题时用 `strings.shelfZone(zoneId)` 把 key 映射到当前语言文字。
- `Category` 已是枚举，天然是稳定 key，仅 label 改为按语言取，零风险。
- 商品名（示例数据）：英文模式按「中文名 → 英文名」映射表显示；分组与匹配仍可基于稳定字段，不破坏 `_confirmPurchase` 按 name 匹配库存的逻辑——映射在显示层完成，底层 name 维持单一来源。

> 约束：本次改动不得改变智能分组、拖拽排序、清单↔库存同步等任何现有行为，切换语言只影响「看到的文字」。

## 8. 依赖

- 新增 `shared_preferences`（pubspec）。
- 不新增其他依赖。

## 9. 测试与验收

- `flutter analyze` 零问题。
- 模拟器实测：
  1. 设置页切到 English → 四个 tab（清单/库存/提醒/设置）全部文案变英文，含示例数据。
  2. 切回中文恢复正常。
  3. 杀掉重开 App → 语言保持上次选择。
  4. 切换语言后，智能分组、拖拽、勾选→库存同步等行为与之前一致（回归）。

## 10. 不做的事（YAGNI）

- 不做翻译平台 / 在线文案。
- 不做 RTL 语言。
- 不为商品名提供用户自定义翻译，仅示例数据内置中英映射。
