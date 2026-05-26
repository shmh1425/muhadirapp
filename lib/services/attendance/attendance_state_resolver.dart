import '../../features/attendance/state/attendance_queue_snapshot.dart';
import '../../features/attendance/state/attendance_state_pure_resolver.dart';
import '../../models/attendance/manual_attendance_record.dart';
import '../offline/offline_operation_types.dart';
import '../offline/offline_queue_service.dart';

export '../../features/attendance/state/attendance_state_pure_resolver.dart'
    show ResolvedAttendanceState;

/// Read-only bridge: loads queue snapshot then pure resolve (no caching).
class AttendanceStateResolver {
  AttendanceStateResolver({OfflineQueueService? queue})
      : _queue = queue ?? OfflineQueueService.instance;

  final OfflineQueueService _queue;

  Future<AttendanceQueueSnapshot> _snapshot() async {
    await _queue.ensureInitialized();
    return AttendanceQueueSnapshot(
      unsyncedOperations: await _queue.getUnsyncedOperations(),
      runtimeSyncingOperationIds: _queue.snapshotRuntimeSyncingOperationIds(),
    );
  }

  /// Firestore = final truth; queue = temporary overlay for pending sync UI.
  Future<Map<int, ResolvedAttendanceState>> resolveForSession({
    required String sessionId,
    required Map<int, ManualAttendanceStatus> firestoreByStudentId,
  }) async {
    return AttendanceStatePureResolver.resolveManualSessionDisplay(
      sessionId: sessionId,
      firestoreByStudentId: firestoreByStudentId,
      snapshot: await _snapshot(),
    );
  }

  Future<Set<int>> pendingSyncStudentIds(String sessionId) async {
    return _queue.pendingStudentIdsForSession(
      type: OfflineOperationTypes.manualAttendance,
      sessionId: sessionId,
    );
  }
}
