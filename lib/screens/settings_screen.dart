import 'package:flutter/material.dart';
import '../models/item.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final void Function(AppSettings) onChanged;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
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
      reminderTime: widget.settings.reminderTime,
    );
  }

  void _update(AppSettings updated) {
    setState(() => _settings = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2ED),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
          children: [
            _buildHeader(),
            const SizedBox(height: 4),
            _buildProCard(),
            const SizedBox(height: 24),
            _buildSection('分类与货架', [
              _navRow('管理分类', trailing: '12类'),
              _navRow('货架顺序'),
            ]),
            const SizedBox(height: 16),
            _buildSection('提醒', [
              _switchRow(
                '补货提醒',
                _settings.restockReminderEnabled,
                (v) => _update(AppSettings(
                  reminderThresholdDays: _settings.reminderThresholdDays,
                  restockReminderEnabled: v,
                  reminderTime: _settings.reminderTime,
                )),
              ),
              _navRow('提醒时间', trailing: _settings.reminderTime),
              _thresholdRow(),
            ]),
            const SizedBox(height: 16),
            _buildSection('数据', [
              _navRow('备份导出'),
              _navRow('导入恢复'),
            ]),
            const SizedBox(height: 32),
            Center(
              child: Text(
                '购物清单 v1.0 · 本地优先',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Text(
        '设置',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1A1A1A),
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildProCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF388E3C), Color(0xFF4CAF50)],
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
                const Text(
                  '升级 Pro',
                  style: TextStyle(
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
              '拍照识别配图 · 快捷加项组件 · 多设备同步备份',
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
              child: const Text(
                '查看 Pro 功能 →',
                style: TextStyle(
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
              color: Color(0xFF9E9E9E),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
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
      ],
    );
  }

  Widget _navRow(String label, {String? trailing}) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      dense: true,
      title: Text(label,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF9E9E9E))),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFFBDBDBD), size: 20),
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
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A))),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: const Color(0xFF4CAF50),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _thresholdRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '提前天数',
                  style: TextStyle(
                      fontSize: 15, color: Color(0xFF1A1A1A)),
                ),
              ),
              Text(
                '${_settings.reminderThresholdDays}天',
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF4CAF50),
              inactiveTrackColor: const Color(0xFFE0E0E0),
              thumbColor: const Color(0xFF4CAF50),
              overlayColor:
                  const Color(0xFF4CAF50).withValues(alpha: 0.15),
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
                reminderTime: _settings.reminderTime,
              )),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1天',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400])),
              Text('1周',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400])),
              Text('2周',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400])),
            ],
          ),
        ),
      ],
    );
  }
}
