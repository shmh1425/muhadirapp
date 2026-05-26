import 'offline_engine_log.dart';
import 'offline_queue_service.dart';
import 'offline_sync_failure_policy.dart';

/// Startup safety checks for queue consistency (hardening only).
abstract final class OfflineSafetyGuard {
  static const Duration maxRuntimeSyncAge = Duration(seconds: 60);

  static Future<OfflineSafetyReport> run() async {
    final queue = OfflineQueueService.instance;
    await queue.ensureInitialized();

    var duplicateKeysRemoved = 0;
    var orphanRemoved = 0;
    var stuckSyncCleared = 0;

    duplicateKeysRemoved = await queue.deduplicateUnsyncedByOperationKey();
    orphanRemoved = await queue.removeOrphanOperations();
    stuckSyncCleared = queue.clearStaleRuntimeSyncs(maxAge: maxRuntimeSyncAge);

    final pending = await queue.getPendingOperations();
    final failed = await queue.getFailedOperations();
    final overRetry = failed
        .where((o) => o.retryCount >= OfflineSyncFailurePolicy.defaultMaxRetries)
        .length;

    final report = OfflineSafetyReport(
      duplicateKeysRemoved: duplicateKeysRemoved,
      orphanOperationsRemoved: orphanRemoved,
      staleRuntimeSyncCleared: stuckSyncCleared,
      pendingCount: pending.length,
      failedCount: failed.length,
      failedOverMaxRetries: overRetry,
    );

    OfflineEngineLog.log(
      OfflineEngineLog.engine,
      'OfflineSafetyGuard',
      detail: report.toString(),
    );
    return report;
  }
}

class OfflineSafetyReport {
  const OfflineSafetyReport({
    required this.duplicateKeysRemoved,
    required this.orphanOperationsRemoved,
    required this.staleRuntimeSyncCleared,
    required this.pendingCount,
    required this.failedCount,
    required this.failedOverMaxRetries,
  });

  final int duplicateKeysRemoved;
  final int orphanOperationsRemoved;
  final int staleRuntimeSyncCleared;
  final int pendingCount;
  final int failedCount;
  final int failedOverMaxRetries;

  @override
  String toString() =>
      'duplicatesRemoved=$duplicateKeysRemoved orphans=$orphanOperationsRemoved '
      'staleSync=$staleRuntimeSyncCleared pending=$pendingCount '
      'failed=$failedCount overMaxRetry=$failedOverMaxRetries';
}
