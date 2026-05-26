import '../../../services/offline/offline_operation.dart';

/// Immutable read snapshot from offline queue + runtime sync (single truth).
class AttendanceQueueSnapshot {
  const AttendanceQueueSnapshot({
    required this.unsyncedOperations,
    required this.runtimeSyncingOperationIds,
  });

  final List<OfflineOperation> unsyncedOperations;
  final Set<String> runtimeSyncingOperationIds;
}
