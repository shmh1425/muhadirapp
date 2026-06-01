import 'dart:io' show InternetAddress, SocketException;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Connectivity probe for online-only channels (QR) and offline sync gating.
abstract final class AttendanceConnectivity {
  static final Connectivity _connectivity = Connectivity();

  /// Link/Wi‑Fi/cellular present (may still be captive — no real internet).
  static Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// True when Firestore host resolves (real internet, not Wi‑Fi-only).
  static Future<bool> canReachFirestore() async {
    if (!await isOnline()) return false;
    if (kIsWeb) return true;
    try {
      final addresses = await InternetAddress.lookup(
        'firestore.googleapis.com',
      ).timeout(const Duration(seconds: 4));
      return addresses.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Use before enqueue/sync: avoids false "online" on captive Wi‑Fi.
  static Future<bool> isOnlineForAttendance() => canReachFirestore();
}
