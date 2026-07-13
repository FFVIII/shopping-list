import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoPicker;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../storage/app_repository.dart';
import '../storage/backup.dart';
import '../widgets/toast.dart';
import '../services/purchase_service.dart';
import 'pro_upgrade_screen.dart';
import 'shelf_order_screen.dart';
import 'category_manage_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final void Function(AppSettings) onChanged;
  final AppLanguage language;
  final void Function(AppLanguage) onLanguageChanged;
  final List<ShelfZone> shelfZones;
  final void Function(int oldIndex, int newIndex) onReorderShelfZones;
  final List<String> shelfCodeOrder;
  final void Function(int oldIndex, int newIndex) onReorderShelfCodes;
  final void Function(String code) onAddShelfCode;
  final void Function(String code) onDeleteShelfCode;
  final void Function(String oldCode, String newCode) onRenameShelfCode;
  final List<Category> categories;
  final Category Function(String name, Color color, String shelfZone, int defaultDays)
      onAddCategory;
  final void Function(
    String id,
    String name,
    Color color,
    String shelfZone,
    int defaultDays,
  ) onEditCategory;
  final void Function(String id) onDeleteCategory;
  final void Function(int oldIndex, int newIndex) onReorderCategories;
  final List<int> Function() buildBackupBytes;
  final Future<void> Function(AppData data) onImportBackup;
  final Future<bool> Function() requestNotificationPermission;
  final PurchaseService purchaseService;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.language,
    required this.onLanguageChanged,
    required this.shelfZones,
    required this.onReorderShelfZones,
    required this.shelfCodeOrder,
    required this.onReorderShelfCodes,
    required this.onAddShelfCode,
    required this.onDeleteShelfCode,
    required this.onRenameShelfCode,
    required this.categories,
    required this.onAddCategory,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onReorderCategories,
    required this.buildBackupBytes,
    required this.onImportBackup,
    required this.requestNotificationPermission,
    required this.purchaseService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = AppSettings(
      reminderThresholdDays: widget.settings.reminderThresholdDays,
      restockReminderEnabled: widget.settings.restockReminderEnabled,
      reminderHour: widget.settings.reminderHour,
      reminderMinute: widget.settings.reminderMinute,
    );
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync the local copy when settings change from outside this screen
    // (e.g. a backup import replaced them).
    if (!identical(oldWidget.settings, widget.settings)) {
      _settings = AppSettings(
        reminderThresholdDays: widget.settings.reminderThresholdDays,
        restockReminderEnabled: widget.settings.restockReminderEnabled,
        reminderHour: widget.settings.reminderHour,
        reminderMinute: widget.settings.reminderMinute,
      );
    }
  }

  void _update(AppSettings updated) {
    setState(() => _settings = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
          children: [
            _buildHeader(l),
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
            const SizedBox(height: 24),
            _buildSection(l.sectionCategoryShelf, [
              _navRow(
                l.manageCategories,
                trailing: l.categoriesCount(widget.categories.length),
                onTap: _openCategoryManage,
              ),
              _navRow(l.shelfOrder, onTap: _openShelfOrder),
            ]),
            const SizedBox(height: 16),
            _buildSection(l.language, [
              _navRow(
                l.language,
                trailing: l.labelForLanguage(widget.language),
                onTap: () => _showLanguageSheet(l),
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection(l.sectionReminder, [
              _switchRow(
                l.restockReminder,
                _settings.restockReminderEnabled,
                _onReminderToggle,
              ),
              _navRow(
                l.reminderTimeLabel,
                trailing: l.reminderTimeDisplay(
                    _settings.reminderHour, _settings.reminderMinute),
                onTap: _pickReminderTime,
              ),
              _navRow(
                l.advanceDays,
                trailing: l.days(_settings.reminderThresholdDays),
                onTap: _pickLeadDays,
              ),
            ]),
            if (widget.purchaseService.isPro) ...[
              const SizedBox(height: 16),
              _buildSection(l.sectionData, [
                _navRow(l.backupExport, onTap: _exportBackup),
                _navRow(l.importRestore, onTap: _importBackup),
              ]),
            ],
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              _buildSection('Debug', [
                _switchRow(
                  'Force Pro (debug only)',
                  widget.purchaseService.isPro,
                  (value) => widget.purchaseService.debugSetIsPro(value),
                ),
              ]),
            ],
            const SizedBox(height: 32),
            Center(
              child: Text(
                l.appFooter,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppStrings l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Text(
        l.settingsTitle,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildProCard(AppStrings l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF388E3C), AppColors.brand],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l.proUpgrade,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l.proDesc,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l.proCta,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF388E3C),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1)
                    const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 0,
                        color: Color(0xFFF0F0F0)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _navRow(String label, {String? trailing, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      dense: true,
      title: Text(label,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textDisabled, size: 20),
        ],
      ),
    );
  }

  Widget _switchRow(
      String label, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      dense: true,
      title: Text(label,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.brand,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _pickLeadDays() async {
    final l = L10n.of(context);
    var selected = _settings.reminderThresholdDays;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l.cancel,
                        style: const TextStyle(color: AppColors.textMuted)),
                  ),
                  Text(l.advanceDays,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l.save,
                        style: const TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 216,
              child: CupertinoPicker(
                itemExtent: 36,
                scrollController: FixedExtentScrollController(
                    initialItem: _settings.reminderThresholdDays - 1),
                onSelectedItemChanged: (i) => selected = i + 1,
                children: [
                  for (var d = 1; d <= 14; d++)
                    Center(child: Text(l.days(d))),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (saved != true) return;
    _update(AppSettings(
      reminderThresholdDays: selected,
      restockReminderEnabled: _settings.restockReminderEnabled,
      reminderHour: _settings.reminderHour,
      reminderMinute: _settings.reminderMinute,
    ));
  }

  void _openCategoryManage() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CategoryManageScreen(
        categories: widget.categories,
        shelfZones: widget.shelfZones,
        onAdd: widget.onAddCategory,
        onEdit: widget.onEditCategory,
        onDelete: widget.onDeleteCategory,
        onReorder: widget.onReorderCategories,
      ),
    ));
  }

  void _openShelfOrder() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ShelfOrderScreen(
        shelfCodes: widget.shelfCodeOrder,
        onReorderCodes: widget.onReorderShelfCodes,
        onAddCode: widget.onAddShelfCode,
        onDeleteCode: widget.onDeleteShelfCode,
        onRenameCode: widget.onRenameShelfCode,
      ),
    ));
  }

  Future<void> _onReminderToggle(bool enabled) async {
    if (enabled) {
      final granted = await widget.requestNotificationPermission();
      if (!mounted) return;
      if (!granted) {
        // Leave the switch off; user must enable notifications in system
        // Settings first (spec §4.4).
        showAppToast(context, L10n.of(context).notifPermissionDenied);
        return;
      }
    }
    _update(AppSettings(
      reminderThresholdDays: _settings.reminderThresholdDays,
      restockReminderEnabled: enabled,
      reminderHour: _settings.reminderHour,
      reminderMinute: _settings.reminderMinute,
    ));
  }

  Future<void> _exportBackup() async {
    final l = L10n.of(context);
    try {
      final bytes = widget.buildBackupBytes();
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/shopping_list_backup_'
          '${now.year}-${two(now.month)}-${two(now.day)}.xlsx');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [
          XFile(file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
        ]),
      );
    } catch (e) {
      debugPrint('backup export failed: $e');
      if (mounted) showAppToast(context, l.exportFailedToast);
    }
  }

  Future<void> _importBackup() async {
    final l = L10n.of(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return; // user cancelled
    AppData data;
    try {
      data = decodeBackupExcel(await File(path).readAsBytes());
    } catch (e) {
      debugPrint('backup decode failed: $e');
      if (mounted) showAppToast(context, l.importInvalidFile);
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.importConfirmTitle),
        content: Text(
          l.importConfirmMessage,
          style: const TextStyle(color: Color(0xFFE53935)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.importAction,
              style: const TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onImportBackup(data);
    if (mounted) showAppToast(context, l.importSuccessToast);
  }

  Future<void> _pickReminderTime() async {
    final l = L10n.of(context);
    // Material showTimePicker's dial asserts on Flutter 3.44 when the
    // hour/minute selection changes inside the double-tap window (framework
    // bug in _DialTimeSelectorControl's conditional onDoubleTap), so we use
    // a Cupertino time wheel in an app-style sheet instead.
    var selected =
        DateTime(2000, 1, 1, _settings.reminderHour, _settings.reminderMinute);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l.cancel,
                        style: const TextStyle(color: AppColors.textMuted)),
                  ),
                  Text(l.reminderTimeLabel,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l.save,
                        style: const TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: selected,
                onDateTimeChanged: (dt) => selected = dt,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (saved != true) return;
    _update(AppSettings(
      reminderThresholdDays: _settings.reminderThresholdDays,
      restockReminderEnabled: _settings.restockReminderEnabled,
      reminderHour: selected.hour,
      reminderMinute: selected.minute,
    ));
  }

  void _showLanguageSheet(AppStrings l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final entry in <AppLanguage, String>{
              AppLanguage.system: l.languageSystem,
              AppLanguage.zh: l.languageZh,
              AppLanguage.en: l.languageEn,
            }.entries)
              ListTile(
                title: Text(entry.value),
                trailing: widget.language == entry.key
                    ? const Icon(Icons.check_rounded, color: AppColors.brand)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onLanguageChanged(entry.key);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
