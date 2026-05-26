import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/attendance/manual_attendance_record.dart';
import '../../../services/attendance/attendance_state_versioning.dart';
import '../../../services/attendance/manual_attendance_offline_log.dart';
import '../../../features/attendance/identity/attendance_operation_identity.dart';
import '../offline_operation.dart';
import '../offline_operation_types.dart';
import '../offline_sync_failure_policy.dart';
import 'offline_operation_processor.dart';

/// Syncs queued manual attendance operations to Firestore.
class ManualAttendanceProcessor implements OfflineOperationProcessor {
  ManualAttendanceProcessor({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int maxRetries = OfflineSyncFailurePolicy.defaultMaxRetries;
  static const String _recordsCollection = 'manual_attendance_records';
  static const String _sessionsCollection = 'manual_attendance_sessions';

  final FirebaseFirestore _firestore;

  @override
  String get type => OfflineOperationTypes.manualAttendance;

  @override
  Future<void> process(OfflineOperation operation) async {
    if (operation.retryCount >= maxRetries) {
      ManualAttendanceOfflineLog.log(
        ManualAttendanceOfflineLog.finalFailure,
        operationId: operation.id,
        detail: 'retryCount=${operation.retryCount}',
      );
      throw ManualAttendanceMaxRetriesException(operation.id);
    }

    if (operation.retryCount > 0) {
      ManualAttendanceOfflineLog.log(
        ManualAttendanceOfflineLog.retry,
        operationId: operation.id,
        operationKey:
            AttendanceOperationIdentity.operationKeyFromPayload(operation.payload),
        detail: 'retryCount=${operation.retryCount}',
      );
    }

    final sessionId = _requireString(operation.payload, 'sessionId');
    final studentId = _requireInt(operation.payload, 'studentId');
    final lecturerId =
        (operation.payload['lecturerId'] ?? '').toString().trim();
    final statusRaw =
        _requireString(operation.payload, 'attendanceStatus').toLowerCase();
    final source = (operation.payload['source'] ?? 'manual_ui').toString();
    final operationKey = AttendanceOperationIdentity.operationKeyFromPayload(
      operation.payload,
    );
    if (operationKey == null) {
      throw ArgumentError('operationKey is required in payload.');
    }

    final status = _statusFromPayload(statusRaw);
    final recordId = AttendanceOperationIdentity.recordDocId(
      sessionId: sessionId,
      studentId: studentId,
    );
    final recordRef = _firestore.collection(_recordsCollection).doc(recordId);

    final existing = await recordRef.get();
    final serverData = existing.data();
    final serverHash = AttendanceStateVersioning.computeServerStateHash(
      serverData,
    );
    final stateVersion = AttendanceStateVersioning.stateVersionFromPayload(
      operation.payload,
    );

    if (AttendanceStateVersioning.isStaleComparedToServer(
      serverData: serverData,
      stateVersionMs: stateVersion,
    )) {
      ManualAttendanceOfflineLog.log(
        ManualAttendanceOfflineLog.duplicateSkipped,
        sessionId: sessionId,
        studentId: studentId,
        operationId: operation.id,
        operationKey: operationKey,
        recordId: recordId,
        detail: 'stale queue version ignored',
      );
      return;
    }

    if (AttendanceStateVersioning.shouldSkipDuplicateApply(
      payload: operation.payload,
      serverData: serverData,
      operationId: operation.id,
    )) {
      ManualAttendanceOfflineLog.log(
        ManualAttendanceOfflineLog.duplicateSkipped,
        sessionId: sessionId,
        studentId: studentId,
        operationId: operation.id,
        operationKey: operationKey,
        recordId: recordId,
        detail: 'serverHash=$serverHash',
      );
      return;
    }

    final nowStamp = FieldValue.serverTimestamp();
    try {
      await recordRef.set(<String, dynamic>{
        'status': ManualAttendanceRecord.statusToString(status),
        'attendanceTime': _attendanceTimeForStatus(status),
        'updatedAt': nowStamp,
        'updatedBy': lecturerId,
        'attendanceMethod': 'manual',
        'courseId': (operation.payload['courseId'] ?? '').toString().trim(),
        AttendanceStateVersioning.clientMutationIdField: operation.id,
        AttendanceOperationIdentity.payloadField: operationKey,
        'source': source,
      }, SetOptions(merge: true));

      await _firestore.collection(_sessionsCollection).doc(sessionId).set(
        <String, dynamic>{
          'updatedAt': nowStamp,
          'updatedBy': lecturerId,
          'attendanceMethod': 'manual',
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      ManualAttendanceOfflineLog.log(
        ManualAttendanceOfflineLog.firestoreFail,
        sessionId: sessionId,
        studentId: studentId,
        operationId: operation.id,
        operationKey: operationKey,
        recordId: recordId,
        detail: 'code=${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  static ManualAttendanceStatus _statusFromPayload(String raw) {
    switch (raw) {
      case 'present':
        return ManualAttendanceStatus.present;
      case 'absent':
        return ManualAttendanceStatus.absent;
      case 'late':
        return ManualAttendanceStatus.late;
      case 'excused':
        return ManualAttendanceStatus.excused;
      case 'pending':
        return ManualAttendanceStatus.pending;
      default:
        throw ArgumentError('Unsupported attendanceStatus: $raw');
    }
  }

  static String _attendanceTimeForStatus(ManualAttendanceStatus status) {
    switch (status) {
      case ManualAttendanceStatus.pending:
        return '--';
      case ManualAttendanceStatus.present:
      case ManualAttendanceStatus.late:
        return '';
      case ManualAttendanceStatus.absent:
      case ManualAttendanceStatus.excused:
        return '--';
    }
  }

  static String _requireString(Map<String, dynamic> payload, String key) {
    final value = payload[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw ArgumentError('Payload field "$key" is required.');
    }
    return value;
  }

  static int _requireInt(Map<String, dynamic> payload, String key) {
    final raw = payload[key];
    if (raw is int && raw > 0) return raw;
    if (raw is num && raw.toInt() > 0) return raw.toInt();
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed == null || parsed <= 0) {
      throw ArgumentError('Payload field "$key" must be a positive int.');
    }
    return parsed;
  }
}

class ManualAttendanceMaxRetriesException implements Exception {
  ManualAttendanceMaxRetriesException(this.operationId);

  final String operationId;

  @override
  String toString() =>
      'Manual attendance sync exceeded max retries ($operationId).';
}
