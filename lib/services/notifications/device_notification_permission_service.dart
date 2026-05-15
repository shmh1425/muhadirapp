import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Reads and requests OS notification permission (Android 13+ / iOS).
class DeviceNotificationPermissionService {
  DeviceNotificationPermissionService._();

  static final DeviceNotificationPermissionService instance =
      DeviceNotificationPermissionService._();

  /// `null` until the first [refresh].
  final ValueNotifier<bool?> notificationsEnabled = ValueNotifier<bool?>(null);

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> refresh() async {
    if (!isSupported) {
      notificationsEnabled.value = false;
      return false;
    }
    try {
      final status = await Permission.notification.status;
      final granted = status.isGranted || status.isLimited;
      notificationsEnabled.value = granted;
      return granted;
    } catch (_) {
      notificationsEnabled.value = false;
      return false;
    }
  }

  Future<PermissionStatus> requestEnable() async {
    if (!isSupported) {
      notificationsEnabled.value = false;
      return PermissionStatus.denied;
    }
    final status = await Permission.notification.request();
    final granted = status.isGranted || status.isLimited;
    notificationsEnabled.value = granted;
    return status;
  }

  Future<void> openSystemSettings() => openAppSettings();
}
