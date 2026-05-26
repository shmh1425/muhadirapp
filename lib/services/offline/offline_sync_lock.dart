import 'offline_engine_log.dart';
import 'offline_queue_service.dart';

/// Persistent-style lock to avoid overlapping sync batches.
abstract final class OfflineSyncLock {
  static const String lockKey = 'OFFLINE_ENGINE_LOCK';
  static const Duration staleAfter = Duration(seconds: 60);

  static Future<bool> tryAcquire({String? ownerTraceId}) async {
    final queue = OfflineQueueService.instance;
    await queue.ensureInitialized();
    final existing = await queue.readLockMetadata();
    if (existing != null) {
      final lockedAt = existing.lockedAt;
      if (DateTime.now().toUtc().difference(lockedAt) < staleAfter) {
        OfflineEngineLog.log(
          OfflineEngineLog.sync,
          'sync lock busy',
          traceId: existing.traceId,
          detail: 'owner=${existing.ownerTraceId}',
        );
        return false;
      }
      OfflineEngineLog.log(
        OfflineEngineLog.sync,
        'stale sync lock cleared',
        traceId: existing.traceId,
      );
    }
    final traceId = ownerTraceId ?? OfflineEngineLog.newTraceId();
    await queue.writeLockMetadata(
      lockedAt: DateTime.now().toUtc(),
      ownerTraceId: traceId,
    );
    OfflineEngineLog.log(
      OfflineEngineLog.sync,
      'sync lock acquired',
      traceId: traceId,
    );
    return true;
  }

  static Future<void> release({String? traceId}) async {
    await OfflineQueueService.instance.clearLockMetadata();
    OfflineEngineLog.log(
      OfflineEngineLog.sync,
      'sync lock released',
      traceId: traceId,
    );
  }
}

class OfflineSyncLockMetadata {
  const OfflineSyncLockMetadata({
    required this.lockedAt,
    required this.ownerTraceId,
  });

  final DateTime lockedAt;
  final String ownerTraceId;
  String get traceId => ownerTraceId;
}
