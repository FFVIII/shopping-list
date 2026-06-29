import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';
import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import 'shelf_order_screen.dart';
import 'category_manage_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final void Function(AppSettings) onChanged;
  final AppLanguage language;
  final void Function(AppLanguage) onLanguageChanged;
  final List<ShelfZone> shelfZones;
  final void Function(int oldIndex, int newIndex) onReorderShelfZones;
  final List<Category> categories;
  final void Function(String name, Color color, String shelfZone, int defaultDays)
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

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.language,
    required this.onLanguageChanged,
    required this.shelfZones,
    required this.onReorderShelfZones,
    required this.categories,
    required this.onAddCategory,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onReorderCategories,
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
            const SizedBox(height: 4),
            _buildProCard(l),
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
                (v) => _update(AppSettings(
                  reminderThresholdDays: _settings.reminderThresholdDays,
                  restockReminderEnabled: v,
                  reminderHour: _settings.reminderHour,
                  reminderMinute: _settings.reminderMinute,
                )),
              ),
              _navRow(
                l.reminderTimeLabel,
                trailing: l.reminderTimeDisplay(
                    _settings.reminderHour, _settings.reminderMinute),
                onTap: _pickReminderTime,
              ),
              _thresholdRow(),
            ]),
            const SizedBox(height: 16),
            _buildSection(l.sectionData, [
              _navRow(l.backupExport),
              _navRow(l.importRestore),
            ]),
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

  Widget _thresholdRow() {
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.advanceDays,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary),
                ),
              ),
              Text(
                l.days(_settings.reminderThresholdDays),
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.brand,
              inactiveTrackColor: AppColors.divider,
              thumbColor: AppColors.brand,
              overlayColor:
                  AppColors.brand.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _settings.reminderThresholdDays.toDouble(),
              min: 1,
              max: 14,
              divisions: 13,
              onChanged: (v) => _update(AppSettings(
                reminderThresholdDays: v.round(),
                restockReminderEnabled:
                    _settings.restockReminderEnabled,
                reminderHour: _settings.reminderHour,
                reminderMinute: _settings.reminderMinute,
              )),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.scale1Day,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400])),
              Text(l.scale1Week,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400])),
              Text(l.scale2Week,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400])),
            ],
          ),
        ),
      ],
    );
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
        shelfZones: widget.shelfZones,
        onReorder: widget.onReorderShelfZones,
      ),
    ));
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _settings.reminderHour,
        minute: _settings.reminderMinute,
      ),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    _update(AppSettings(
      reminderThresholdDays: _settings.reminderThresholdDays,
      restockReminderEnabled: _settings.restockReminderEnabled,
      reminderHour: picked.hour,
      reminderMinute: picked.minute,
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
