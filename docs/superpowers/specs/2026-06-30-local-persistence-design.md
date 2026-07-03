# 设计文档：本地数据库持久化（Hive）

日期：2026-06-30
状态：已批准设计，待实施计划

## 1. 目标

目前清单、库存、记账、分类、货架、设置等所有数据都只存在 `_AppShellState` 的内存字段里（`lib/main.dart`），App 完全退出重启后全部丢失，只重新生成示例数据。本设计让这些数据写入本地数据库（Hive），重启后正确恢复，用户的改动不再丢失。

## 2. 关键决策（已与用户确认）

| 决策 | 选择 |
|---|---|
| 数据库引擎 | Hive（轻量 NoSQL 对象存储） |
| 是否用 codegen | 不用 `hive_generator`/`build_runner`；手写 `toMap`/`fromMap` 映射，避免给项目新增代码生成工具链 |
| 持久化范围 | 简单清单、计划清单、库存、记账、分类、货架分区、货架码顺序、App 设置 |
| 示例数据 | 仅首次安装（数据库为空）时写入一次作为初始数据；之后只读用户自己的数据，不会被重置 |
| 写入策略 | 写穿（write-through）：每次 `setState` 修改相关字段后立即落盘，不做防抖/批处理 |
| 账号同步 | 不在本设计范围内（用户确认是未来的收费功能），但架构上要留出替换空间 |

显式排除（YAGNI）：不引入云同步、不引入用户账号、不做数据库版本迁移框架（Hive box 后续新增字段时用可空字段+默认值兼容即可，不单独建迁移系统）、语言设置不动（继续用现有的 `shared_preferences`）。

## 3. 架构

新增目录 `lib/storage/`：

### 3.1 `hive_models.dart` — 存储格式转换
不引入 Hive 的 `@HiveType`/`@HiveField` 注解 + codegen，而是给每个模型类写手动的 `Map<String, dynamic> toMap()` / `static X fromMap(Map)` 方法（作为 `lib/models/item.dart` 里各类的 extension，或直接写在 `hive_models.dart` 里作为顶层函数，避免污染模型文件）。Hive 的 box 存的就是 `Map<String, dynamic>`（Hive 原生支持存 Map）。

- `Category`：直接存全部字段（id/name/color.value/bgColor.value/shelfZone/defaultDays）。
- `ShoppingItem` / `InventoryItem`：存 `categoryId`（即 `category.id`），**不**存整个 Category 对象，避免冗余和不一致。读取时用 `_categories.findById(categoryId) ?? _categories.fallback` 接回引用。
- `BudgetItem`：无 Category 字段，全部字段直接存。
- `AppSettings`：全部字段直接存。
- `ShelfZone`：存 `name` + `dotColor.value`。

### 3.2 `app_repository.dart` — 唯一的读写入口
封装 6 个 Hive box：

| Box 名 | 存的内容 |
|---|---|
| `shopping_simple` | `List<ShoppingItem>`（简单清单） |
| `shopping_smart` | `List<ShoppingItem>`（计划清单） |
| `inventory` | `List<InventoryItem>` |
| `budget` | `List<BudgetItem>` |
| `categories` | `List<Category>` |
| `app_meta` | 单个 box，用固定 key 存：`settings`（`AppSettings`）、`shelf_zones`（`List<ShelfZone>`）、`shelf_code_order`（`List<String>`） |

`categories` box 是否为空，作为"是否首次安装"的判断依据（分类是最基础的数据，不可能被用户清空到 0 个，因为 fallback 分类不可删除）。

对外 API（`AppRepository` 类）：
```dart
class AppRepository {
  Future<void> init();           // 打开所有 box（应用启动时调用一次）
  Future<AppData> load();        // 读出全部数据；若 categories box 为空，
                                  // 先写入示例数据再读出（首次安装路径）
  Future<void> saveShoppingSimple(List<ShoppingItem> items);
  Future<void> saveShoppingSmart(List<ShoppingItem> items);
  Future<void> saveInventory(List<InventoryItem> items);
  Future<void> saveBudget(List<BudgetItem> items);
  Future<void> saveCategories(List<Category> categories);
  Future<void> saveSettings(AppSettings settings);
  Future<void> saveShelfZones(List<ShelfZone> zones);
  Future<void> saveShelfCodeOrder(List<String> order);
}

class AppData {
  final List<ShoppingItem> shoppingSimple;
  final List<ShoppingItem> shoppingSmart;
  final List<InventoryItem> inventory;
  final List<BudgetItem> budget;
  final List<Category> categories;
  final AppSettings settings;
  final List<ShelfZone> shelfZones;
  final List<String> shelfCodeOrder;
}
```

这一层是未来接云同步的替换点：以后做账号同步功能时，只需要新增一个实现相同接口的 `CloudSyncRepository`（或在 `AppRepository` 内部加一层同步），`main.dart` 的业务逻辑不需要改。

## 4. `main.dart` 改动

### 4.1 启动流程
- `main()` 改为 `async`：`WidgetsFlutterBinding.ensureInitialized()` → `Hive.initFlutter()` → `final repo = AppRepository()` → `await repo.init()` → `runApp(...)`，把 `repo` 传给 `ShoppingListApp` → `AppShell`。
- `_AppShellState.initState()` 不再同步直接赋值示例数据；改为标记 `_loading = true`，在 `initState` 里调用异步 `_loadData()`（调用 `widget.repository.load()`），完成后 `setState` 把结果填进现有字段并设 `_loading = false`。
- `build()` 在 `_loading == true` 时返回一个简单的 loading 占位（`Scaffold` + `CircularProgressIndicator`，启动这一下通常是几十毫秒级，不需要做精美的启动页）。

### 4.2 每个 setState 修改点追加保存调用
`main.dart` 里现有的修改方法（`_addCategory`/`_editCategory`/`_deleteCategory`/`_reorderCategories`/`_reorderShelfCodes`/`_addShelfCode`/`_deleteShelfCode`/`_renameShelfCode`/`_reorderShelfZones`/`_addBudgetItem`/...等约 20+ 处）保持各自原有逻辑不变，只在 `setState(...)` 块结束后，按这次改动涉及到的字段追加调用对应的 `_repository.save*()`。例如 `_deleteCategory` 一次性改了 `_categories`/`_shopping`/`_shoppingSimple`/`_inventory` 四个字段，就追加四个 save 调用。这是纯粹的"在已有代码后面加一行"，不改变原有业务逻辑和 setState 内部结构。

## 5. 错误处理

- Hive 初始化或读取失败（理论上极少见，本地文件损坏等情况）：捕获异常，回退到当前的示例数据生成逻辑，保证 App 仍可正常使用（不会因为存储层故障导致整个 App 打不开）。
- 写入失败：忽略并记录到 debug 日志即可（`debugPrint`），不向用户弹错误提示——本地写入失败极罕见，且清单类 App 没必要为此打断用户操作流程。

## 6. 测试

- 手动验证为主（这是一个 UI 状态持久化变更，核心验证方式是真机/模拟器上的行为测试）：
  1. 全新安装 → 看到示例数据 → 退出重开 → 数据还在（不再重置成示例数据）。
  2. 增删改清单/库存/记账/分类/货架码/设置 → 完全退出 App（不是切后台）→ 重新打开 → 改动都还在。
  3. 删除一个分类后，原先用该分类的清单/库存项要正确改成兜底分类，且重启后这个改动也保留。
