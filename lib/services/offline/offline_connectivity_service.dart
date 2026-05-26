import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

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

    if (!_wasDisconnected) {
      // Ignore initial "online" emission — only sync after a prior disconnect.
      return;
    }

    _wasDisconnected = false;
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
}
