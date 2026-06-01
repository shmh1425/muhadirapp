import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../features/attendance/attendance_connectivity.dart';
import 'offline_operation_types.dart';
import 'offline_queue_service.dart';
import 'offline_sync_engine.dart';

/// Listens for connectivity restoration and triggers queue processing once.
class OfflineConnectivityService {
  OfflineConnectivityService._({
    Connectivity? connectivity,
    OfflineSyncEngine? syncEngine,
  })  : _connectivity = connectivity ?? Connectivity(),
        _syncEngine = syncEngine ?? OfflineSyncEngine.instance;

  static final OfflineConnectivityService instance =
      OfflineConnectivityService._();

  static const _logTag = '[OfflineConnectivity]';

  final Connectivity _connectivity;
  final OfflineSyncEngine _syncEngine;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _started = false;
  bool _wasDisconnected = false;

  /// Registers a connectivity listener. Idempotent.
  void startListening() {
    if (_started) return;
    _started = true;

    unawaited(_seedDisconnectedFromCurrentConnectivity());

    _subscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          debugPrint('$_logTag listener error: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      },
    );

    if (kDebugMode) {
      debugPrint('$_logTag listening (sync on reconnect only)');
    }
  }

  Future<void> _seedDisconnectedFromCurrentConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (!_isConnected(results)) {
        _wasDisconnected = true;
      }
    } catch (_) {
      // Best-effort; reconnect handler still works after a later offline event.
    }
  }

  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
    if (kDebugMode) {
      debugPrint('$_logTag stopped');
    }
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final connected = _isConnected(results);
    if (!connected) {
      _wasDisconnected = true;
      if (kDebugMode) {
        debugPrint('$_logTag offline results=$results');
      }
      return;
    }

    final hasQueuedAttendance = await _hasQueuedAttendanceOps();

    if (!_wasDisconnected && !hasQueuedAttendance) {
      // Ignore initial "online" unless there is pending attendance to flush.
      return;
    }

    _wasDisconnected = false;

    if (!await AttendanceConnectivity.canReachFirestore()) {
      if (kDebugMode) {
        debugPrint(
          '$_logTag Wi‑Fi/cellular up but Firestore unreachable — '
          'deferring sync results=$results',
        );
      }
      _wasDisconnected = true;
      return;
    }

    if (kDebugMode) {
      debugPrint('$_logTag online — triggering sync results=$results');
    }

    try {
      await _syncEngine.runStartupSyncSequence();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('$_logTag sync trigger failed: $e');
        debugPrintStack(stackTrace: st);
      }
    }
  }

  bool _isConnected(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> _hasQueuedAttendanceOps() async {
    try {
      await OfflineQueueService.instance.ensureInitialized();
      final pending = await OfflineQueueService.instance.getPendingOperations();
      if (pending.isNotEmpty) return true;
      final failed =
          await OfflineQueueService.instance.getFailedOperations();
      return failed.any(
        (op) =>
            op.type == OfflineOperationTypes.bluetoothAttendance ||
            op.type == OfflineOperationTypes.nfcAttendance,
      );
    } catch (_) {
      return false;
    }
  }
}
