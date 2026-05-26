import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity probe for online-only channels (QR).
abstract final class AttendanceConnectivity {
  static final Connectivity _connectivity = Connectivity();

  static Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }
}
