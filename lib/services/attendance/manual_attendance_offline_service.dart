import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../features/attendance/attendance_connectivity.dart';
import '../../models/attendance/manual_attendance_record.dart';
import '../lecturer_auth_service.dart';
import '../offline/offline_engine_log.dart';
import '../offline/offline_operation_types.dart';
import '../offline/offline_queue_service.dart';
import '../offline/offline_sync_engine.dart';
import 'attendance_state_resolver.dart';
import 'attendance_state_versioning.dart';
import 'manual_attendance_offline_log.dart';
import '../../features/attendance/identity/attendance_operation_identity.dart';
import 'manual_attendance_service.dart';

/// Offline-capable attendance writes (manual channel; used by unified pipeline).
/// NFC/Bluetooth use [AttendanceOfflineBridge] with their own operation types.
class ManualAttendanceOfflineService {
  ManualAttendanceOfflineService._();
  static final ManualAttendanceOfflineService instance =
      ManualAttendanceOfflineService._();

  final ManualAttendanceService _manualAttendance =
      ManualAttendanceService.instance;
  final OfflineQueueService _queue = OfflineQueueService.instance;
  final AttendanceStateResolver _resolver = AttendanceStateResolver();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _recordsCollection = 'manual_attendance_records';

  /// Firestore batch writes can hang indefinitely when the device is offline.
  static const Duration _firestoreWriteTimeout = Duration(seconds: 12);

  /// Per-record hash reads during enqueue must not block the save button.
  static const Duration _serverHashReadTimeout = Duration(seconds: 3);

  Future<ManualAttendanceWriteResult> submitAttendance({
    required String sessionId,
    required String courseId,
    required Map<int, ManualAttendanceStatus> updates,
  }) async {
    return _unifiedWriteFlow(
      sessionId: sessionId,
      courseId: courseId,
      updates: updates,
    );
  }

  @Deprecated('Use submitAttendance')
  Future<ManualAttendanceWriteResult> updateSessionStatuses({
    required String sessionId,
    required String courseId,
    required Map<int, ManualAttendanceStatus> updates,
  }) =>
      submitAttendance(
        sessionId: sessionId,
        courseId: courseId,
        updates: updates,
      );

  Future<ManualAttendanceWriteResult> _unifiedWriteFlow({
    required String sessionId,
    required String courseId,
    required Map<int, ManualAttendanceStatus> updates,
  }) async {
    if (updates.isEmpty) {
      return const ManualAttendanceWriteResult(
        count: 0,
        outcome: ManualAttendanceWriteOutcome.none,
      );
    }

    final trimmedSessionId = sessionId.trim();
    final trimmedCourseId = courseId.trim();

    ManualAttendanceOfflineLog.log(
      ManualAttendanceOfflineLog.submitStart,
      sessionId: trimmedSessionId,
      detail: 'students=${updates.length}',
    );

    final hasConnectivity = await AttendanceConnectivity.isOnline();
    if (!hasConnectivity) {
      ManualAttendanceOfflineLog.log(
        ManualAttendanceOfflineLog.firestoreFail,
        sessionId: trimmedSessionId,
        detail: 'no connectivity — enqueue immediately',
      );
      return _queueAllUpdates(
        sessionId: trimmedSessionId,
        courseId: trimmedCourseId,
        updates: updates,
        queueReason: 'offline_no_connectivity',
      );
    }

    try {
      await _manualAttendance
          .updateSessionStatuses(
            sessionId: trimmedSessionId,
            updates: updates,
          )
          .timeout(
            _firestoreWriteTimeout,
            onTimeout: () => throw TimeoutException(
              'Firestore manual attendance write timed out',
            ),
          );
      ManualAttendanceOfflineLog.log(
        ManualAttendanceOfflineLog.firestoreSuccess,
        sessionId: trimmedSessionId,
        detail: 'students=${updates.length}',
      );
      await _removeQueueEntriesForAppliedUpdates(
        sessionId: trimmedSessionId,
        updates: updates,
      );
      return ManualAttendanceWriteResult(
        count: updates.length,
        outcome: ManualAttendanceWriteOutcome.firestore,
      );
    } catch (e, st) {
      ManualAttendanceOfflineLog.log(
        ManualAttendanceOfflineLog.firestoreFail,
        sessionId: trimmedSessionId,
        detail: '$e',
      );
      if (kDebugMode) debugPrintStack(stackTrace: st);
      return _queueAllUpdates(
        sessionId: trimmedSessionId,
        courseId: trimmedCourseId,
        updates: updates,
        queueReason: e.toString(),
      );
    }
  }

  Future<ManualAttendanceWriteResult> _queueAllUpdates({
    required String sessionId,
    required String courseId,
    required Map<int, ManualAttendanceStatus> updates,
    required String queueReason,
  }) async {
    final queued = await _enqueueUpdates(
      sessionId: sessionId,
      courseId: courseId,
      updates: updates,
      queueReason: queueReason,
    );
    ManualAttendanceOfflineLog.log(
      ManualAttendanceOfflineLog.enqueued,
      sessionId: sessionId,
      detail: 'count=$queued',
    );
    return ManualAttendanceWriteResult(
      count: updates.length,
      outcome: ManualAttendanceWriteOutcome.queued,
      queuedCount: queued,
    );
  }

  /// Display-only derived state (queue is source for pending indicator).
  Future<Set<int>> pendingSyncStudentIds(String sessionId) async {
    return _resolver.pendingSyncStudentIds(sessionId);
  }

  Future<Map<int, ResolvedAttendanceState>> resolvedStatesForSession({
    required String sessionId,
    required Map<int, ManualAttendanceStatus> firestoreByStudentId,
  }) async {
    return _resolver.resolveForSession(
      sessionId: sessionId,
      firestoreByStudentId: firestoreByStudentId,
    );
  }

  Future<void> triggerBackgroundSyncIfPossible() async {
    try {
      await OfflineSyncEngine.instance.runStartupSyncSequence();
    } catch (e) {
      OfflineEngineLog.logError('background sync error', detail: '$e');
    }
  }

  Future<int> _enqueueUpdates({
    required String sessionId,
    required String courseId,
    required Map<int, ManualAttendanceStatus> updates,
    required String queueReason,
  }) async {
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    final timestamp = DateTime.now().toUtc().toIso8601String();
    var enqueued = 0;

    final readServerHash = await AttendanceConnectivity.isOnline();

    for (final entry in updates.entries) {
      final status = _statusToPayload(entry.value);
      final serverHash = readServerHash
          ? await _readServerStateHash(
              sessionId: sessionId,
              studentId: entry.key,
            )
          : null;
      final payload = AttendanceOperationIdentity.embedInPayload(
        <String, dynamic>{
          'sessionId': sessionId,
          'studentId': entry.key,
          'lecturerId': lecturerId,
          'courseId': courseId,
          'attendanceStatus': status,
          'timestamp': timestamp,
          'source': 'manual_ui',
          if (serverHash != null)
            AttendanceStateVersioning.serverStateHashField: serverHash,
        },
      );

      await _queue.enqueueOrCoalesceByOperationKey(
        type: OfflineOperationTypes.manualAttendance,
        payload: payload,
      );
      enqueued++;
      ManualAttendanceOfflineLog.log(
        ManualAttendanceOfflineLog.enqueued,
        sessionId: sessionId,
        studentId: entry.key,
        operationKey: AttendanceOperationIdentity.buildOperationKey(
          sessionId: sessionId,
          studentId: entry.key,
          attendanceStatus: status,
        ),
        detail: queueReason,
      );
    }
    return enqueued;
  }

  Future<String?> _readServerStateHash({
    required String sessionId,
    required int studentId,
  }) async {
    try {
      final recordId = AttendanceOperationIdentity.recordDocId(
        sessionId: sessionId,
        studentId: studentId,
      );
      final snap = await _firestore
          .collection(_recordsCollection)
          .doc(recordId)
          .get()
          .timeout(_serverHashReadTimeout);
      return AttendanceStateVersioning.computeServerStateHash(snap.data());
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeQueueEntriesForAppliedUpdates({
    required String sessionId,
    required Map<int, ManualAttendanceStatus> updates,
  }) async {
    final toRemove = <String>[];
    for (final entry in updates.entries) {
      final operationKey = AttendanceOperationIdentity.buildOperationKey(
        sessionId: sessionId,
        studentId: entry.key,
        attendanceStatus: _statusToPayload(entry.value),
      );
      final op = await _queue.findUnsyncedByOperationKey(
        type: OfflineOperationTypes.manualAttendance,
        operationKey: operationKey,
      );
      if (op != null) toRemove.add(op.id);
    }
    if (toRemove.isNotEmpty) {
      await _queue.removeOperationsByIds(toRemove);
    }
  }

  static String _statusToPayload(ManualAttendanceStatus status) {
    return ManualAttendanceRecord.statusToString(status);
  }
}

enum ManualAttendanceWriteOutcome {
  none,
  firestore,
  queued,
}

class ManualAttendanceWriteResult {
  const ManualAttendanceWriteResult({
    required this.count,
    required this.outcome,
    this.queuedCount = 0,
  });

  final int count;
  final ManualAttendanceWriteOutcome outcome;
  final int queuedCount;

  bool get usedQueue => outcome == ManualAttendanceWriteOutcome.queued;
}
