import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_strings.dart';
import '../models/item.dart';

/// Items that will be low or out of stock at [moment]: projected remaining
/// days <= [thresholdDays]. Mirrors the math in [InventoryItem.statusFor]
/// (covers both StockStatus.low and StockStatus.empty).
List<InventoryItem> lowStockAt(
  DateTime moment,
  List<InventoryItem> inventory,
  int thresholdDays,
) {
  return inventory.where((item) {
    final elapsed = moment.difference(item.purchasedAt).inDays;
    final remaining = item.estimatedDays - elapsed;
    return remaining <= thresholdDays;
  }).toList();
}

/// How many days ahead we pre-schedule (design spec 2026-07-02 §4.1).
const int kNotificationHorizonDays = 14;

/// iOS local notifications for restock reminders. Deterministic
/// pre-scheduling: every data change cancels all pending notifications and
/// re-schedules the next [kNotificationHorizonDays] days.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('timezone lookup failed, keeping default: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          // Permission is requested from the settings toggle (spec §4.4),
          // not at startup.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// Shows the system permission prompt (or returns the existing decision).
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    final granted = await _ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  /// Silent check — never shows a prompt.
  Future<bool> _hasPermission() async {
    final options = await _ios?.checkPermissions();
    return options?.isEnabled ?? false;
  }

  Future<void> reschedule({
    required List<InventoryItem> inventory,
    required AppSettings settings,
    required AppStrings strings,
  }) async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    if (!settings.restockReminderEnabled) return;
    if (!await _hasPermission()) return;

    final now = tz.TZDateTime.now(tz.local);
    for (int d = 0; d < kNotificationHorizonDays; d++) {
      final day = now.add(Duration(days: d));
      final fireAt = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        settings.reminderHour,
        settings.reminderMinute,
      );
      if (!fireAt.isAfter(now)) continue; // today's slot already passed
      final low = lowStockAt(fireAt, inventory, settings.reminderThresholdDays);
      if (low.isEmpty) continue;
      await _plugin.zonedSchedule(
        id: d, // one stable id per day-offset
        title: strings.notifRestockTitle,
        body: strings.notifRestockBody(
          low.length,
          low.map((i) => strings.data(i.name)).toList(),
        ),
        scheduledDate: fireAt,
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentBanner: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
