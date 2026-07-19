import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/item.dart';
import '../storage/app_repository.dart';

/// Owns the app settings domain (reminder threshold, notification time, etc).
class SettingsNotifier extends ChangeNotifier {
  SettingsNotifier(this._repo);

  final AppRepository _repo;

  /// Invoked after every persist — used by the shell to reschedule
  /// restock notifications, since that depends on inventory too.
  VoidCallback? afterPersist;

  late AppSettings settings;

  void load(AppData data) {
    settings = data.settings;
    notifyListeners();
  }

  void update(AppSettings s) {
    settings = s;
    persist();
  }

  void persist() {
    notifyListeners();
    unawaited(
      _repo
          .saveSettings(settings)
          .catchError((e) => debugPrint('save settings failed: $e')),
    );
    afterPersist?.call();
  }
}
