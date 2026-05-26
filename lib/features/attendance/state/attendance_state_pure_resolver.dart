import '../../../models/attendance/manual_attendance_record.dart';
import '../../../services/offline/offline_operation.dart';
import '../../../services/offline/offline_operation_status.dart';
import '../../../services/offline/offline_operation_types.dart';
import 'attendance_operation_ui_state.dart';
import 'attendance_queue_snapshot.dart';

/// Pure read-only mapping: queue snapshot + firestore overlay → UI state.
abstract final class AttendanceStatePureResolver {
  static AttendanceUIState resolveUiState({
    required OfflineOperation? operation,
    required Set<String> runtimeSyncingOperationIds,
    required bool firestoreSynced,
  }) {
    if (operation == null) {
      return firestoreSynced ? AttendanceUIState.synced : AttendanceUIState.idle;
    }
    if (operation.status == OfflineOperationStatus.failed) {
      return AttendanceUIState.failed;
    }
    if (runtimeSyncingOperationIds.contains(operation.id)) {
      return AttendanceUIState.syncing;
    }
    return AttendanceUIState.pending;
  }

  static AttendanceOperationUIModel resolveUiModel({
    required String sessionId,
    required String studentId,
    required AttendanceQueueSnapshot snapshot,
    required bool firestoreSynced,
  }) {
    final op = pickNewestMatchingOperation(
      snapshot: snapshot,
      sessionId: sessionId,
      studentId: studentId,
    );
    final state = resolveUiState(
      operation: op,
      runtimeSyncingOperationIds: snapshot.runtimeSyncingOperationIds,
      firestoreSynced: firestoreSynced,
    );
    return AttendanceOperationUIModel(
      sessionId: sessionId.trim(),
      studentId: studentId.trim(),
      state: state,
      lastUpdated: DateTime.now().toUtc(),
      message: op?.lastError,
      operationId: op?.id,
    );
  }

  static OfflineOperation? pickNewestMatchingOperation({
    required AttendanceQueueSnapshot snapshot,
    required String sessionId,
    required String studentId,
  }) {
    final studentInt = _parseStudentId(studentId);
    OfflineOperation? newest;
    for (final op in snapshot.unsyncedOperations) {
      if (!_operationMatchesSession(op, sessionId)) continue;
      if (!_operationMatchesStudent(op, studentId, studentInt)) continue;
      if (newest == null || op.updatedAt.isAfter(newest.updatedAt)) {
        newest = op;
      }
    }
    return newest;
  }

  /// Manual attendance display overlay (Firestore + queue snapshot).
  static Map<int, ResolvedAttendanceState> resolveManualSessionDisplay({
    required String sessionId,
    required Map<int, ManualAttendanceStatus> firestoreByStudentId,
    required AttendanceQueueSnapshot snapshot,
  }) {
    final session = sessionId.trim();
    final result = <int, ResolvedAttendanceState>{};

    for (final entry in firestoreByStudentId.entries) {
      result[entry.key] = ResolvedAttendanceState(
        studentId: entry.key,
        firestoreStatus: entry.value,
        displayStatus: entry.value,
        isPendingSync: false,
      );
    }

    for (final op in snapshot.unsyncedOperations) {
      if (op.type != OfflineOperationTypes.manualAttendance) continue;
      final opSession = (op.payload['sessionId'] ?? '').toString().trim();
      if (opSession != session) continue;
      final studentId = _parseStudentId(op.payload['studentId']);
      if (studentId <= 0) continue;

      final pendingStatus = _statusFromPayload(
        (op.payload['attendanceStatus'] ?? '').toString(),
      );
      final firestoreStatus = firestoreByStudentId[studentId];
      result[studentId] = ResolvedAttendanceState(
        studentId: studentId,
        firestoreStatus: firestoreStatus,
        displayStatus:
            pendingStatus ?? firestoreStatus ?? ManualAttendanceStatus.pending,
        isPendingSync: true,
        pendingOperationId: op.id,
      );
    }
    return result;
  }

  static bool _operationMatchesSession(OfflineOperation op, String sessionId) {
    final payloadSession = (op.payload['sessionId'] ?? '').toString().trim();
    if (payloadSession == sessionId) return true;
    if (sessionId.isEmpty) return false;
    final card = (op.payload['lecturerCardId'] ?? '').toString().trim();
    if (card.isNotEmpty && sessionId == 'nfc_$card') return true;
    return false;
  }

  static bool _operationMatchesStudent(
    OfflineOperation op,
    String studentId,
    int studentInt,
  ) {
    final payloadStudent = _parseStudentId(op.payload['studentId']);
    if (studentInt > 0 && payloadStudent == studentInt) return true;
    return payloadStudent > 0 &&
        studentId.trim().isNotEmpty &&
        payloadStudent.toString() == studentId.trim();
  }

  static ManualAttendanceStatus? _statusFromPayload(String raw) {
    switch (raw.trim().toLowerCase()) {
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
        return null;
    }
  }

  static int _parseStudentId(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString()) ?? 0;
  }
}

/// Manual attendance display row (kept here for pure resolver consumers).
class ResolvedAttendanceState {
  const ResolvedAttendanceState({
    required this.studentId,
    required this.firestoreStatus,
    required this.displayStatus,
    required this.isPendingSync,
    this.pendingOperationId,
  });

  final int studentId;
  final ManualAttendanceStatus? firestoreStatus;
  final ManualAttendanceStatus displayStatus;
  final bool isPendingSync;
  final String? pendingOperationId;
}
