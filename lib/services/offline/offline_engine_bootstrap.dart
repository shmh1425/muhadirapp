import 'package:flutter/foundation.dart';

import 'offline_connectivity_service.dart';
import 'offline_engine_log.dart';
import 'offline_queue_service.dart';
import 'offline_safety_guard.dart';
import 'offline_sync_engine.dart';
import 'processors/bluetooth_attendance_processor.dart';
import 'processors/manual_attendance_processor.dart';
import 'processors/nfc_attendance_processor.dart';

/// Initializes offline infrastructure and Phase 2B manual attendance sync.
class OfflineEngineBootstrap {
  OfflineEngineBootstrap._();

  static bool _infrastructureReady = false;

  /// Hive queue + integrity + safety + connectivity (no Firestore — no processors).
  static Future<void> initializeInfrastructure() async {
    if (_infrastructureReady) return;
    await OfflineQueueService.instance.ensureInitialized();
    await OfflineQueueService.instance.validateQueueIntegrity();
    await OfflineSafetyGuard.run();
    OfflineConnectivityService.instance.startListening();
    _infrastructureReady = true;
    OfflineEngineLog.log(OfflineEngineLog.engine, 'infrastructure ready');
  }

  static bool _processorsRegistered = false;

  /// Processors require Firebase — call only after [Firebase.initializeApp].
  static void registerProcessors() {
    if (_processorsRegistered) return;
    OfflineSyncEngine.instance.registerProcessor(ManualAttendanceProcessor());
    OfflineSyncEngine.instance.registerProcessor(NfcAttendanceProcessor());
    OfflineSyncEngine.instance.registerProcessor(BluetoothAttendanceProcessor());
    _processorsRegistered = true;
    OfflineEngineLog.log(OfflineEngineLog.engine, 'processors registered');
  }

  /// Legacy entry — opens infrastructure only (sync deferred).
  static Future<void> initialize() async {
    await initializeInfrastructure();
  }

  /// Called after Firebase + auth/session restore.
  static Future<void> runAfterAuthReady() async {
    await initializeInfrastructure();
    registerProcessors();
    try {
      await OfflineSyncEngine.instance.runStartupSyncSequence();
    } catch (e, st) {
      OfflineEngineLog.logError(
        'startup sync failed',
        detail: '$e',
      );
      if (kDebugMode) debugPrintStack(stackTrace: st);
    }
  }
}
