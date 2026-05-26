import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../features/attendance/identity/attendance_operation_identity.dart';
import 'offline_engine_log.dart';
import 'offline_operation.dart';
import 'offline_queue_service.dart';
import 'offline_sync_failure_policy.dart';
import 'offline_sync_lock.dart';
import 'processors/offline_operation_processor.dart';

/// Generic FIFO sync runner.
class OfflineSyncEngine {
  OfflineSyncEngine({
    OfflineQueueService? queueService,
    List<OfflineOperationProcessor>? processors,
  })  : _queue = queueService ?? OfflineQueueService.instance,
        _processors = {
          for (final p in processors ?? const <OfflineOperationProcessor>[])
            p.type: p,
        };

  static final OfflineSyncEngine instance = OfflineSyncEngine();

  final OfflineQueueService _queue;
  final Map<String, OfflineOperationProcessor> _processors;

  bool _isSyncing = false;
  final Set<String> _inFlightIds = <String>{};
  final Set<String> _inFlightOperationKeys = <String>{};

  static const int _maxBackoffMs = 30000;
  static const int _baseBackoffMs = 1000;

  void registerProcessor(OfflineOperationProcessor processor) {
    _processors[processor.type] = processor;
    OfflineEngineLog.log(
      OfflineEngineLog.sync,
      'registerProcessor',
      detail: 'type=${processor.type}',
    );
  }

  Future<OfflineSyncResult> runStartupSyncSequence() async {
    if (_isSyncing) {
      return const OfflineSyncResult(skippedBecauseBusy: true);
    }
    final traceId = OfflineEngineLog.newTraceId();
    final correlationId = OfflineEngineLog.newCorrelationId();
    if (!await OfflineSyncLock.tryAcquire(ownerTraceId: traceId)) {
      return const OfflineSyncResult(skippedBecauseBusy: true);
    }

    _isSyncing = true;
    try {
      await _queue.ensureInitialized();
      OfflineEngineLog.log(
        OfflineEngineLog.sync,
        'startup sequence start',
        traceId: traceId,
        correlationId: correlationId,
      );
      final first = await _drainPendingUnlocked(
        traceId: traceId,
        correlationId: correlationId,
      );
      final requeued = await _queue.requeueRetriableFailedOperations(
        maxRetryCount: OfflineSyncFailurePolicy.defaultMaxRetries,
      );
      final second = await _drainPendingUnlocked(
        traceId: traceId,
        correlationId: correlationId,
      );
      OfflineEngineLog.log(
        OfflineEngineLog.sync,
        'startup sequence done',
        traceId: traceId,
        correlationId: correlationId,
        detail:
            'pass1=${first.succeeded}/${first.processed} '
            'pass2=${second.succeeded}/${second.processed} requeued=$requeued',
      );
      return OfflineSyncResult(
        processed: first.processed + second.processed,
        succeeded: first.succeeded + second.succeeded,
        failed: first.failed + second.failed,
        skipped: first.skipped + second.skipped,
      );
    } finally {
      _isSyncing = false;
      await OfflineSyncLock.release(traceId: traceId);
    }
  }

  Future<OfflineSyncResult> prepareAndProcessPending() =>
      runStartupSyncSequence();

  Future<OfflineSyncResult> processPendingOperations() async {
    if (_isSyncing) {
      return const OfflineSyncResult(skippedBecauseBusy: true);
    }
    final traceId = OfflineEngineLog.newTraceId();
    if (!await OfflineSyncLock.tryAcquire(ownerTraceId: traceId)) {
      return const OfflineSyncResult(skippedBecauseBusy: true);
    }

    _isSyncing = true;
    try {
      return await _drainPendingUnlocked(
        traceId: traceId,
        correlationId: OfflineEngineLog.newCorrelationId(),
      );
    } finally {
      _isSyncing = false;
      await OfflineSyncLock.release(traceId: traceId);
    }
  }

  Future<OfflineSyncResult> _drainPendingUnlocked({
    required String traceId,
    required String correlationId,
  }) async {
    var processed = 0;
    var succeeded = 0;
    var failed = 0;
    var skipped = 0;

    final pending = await _queue.getPendingOperations();
    OfflineEngineLog.log(
      OfflineEngineLog.sync,
      'batch start',
      traceId: traceId,
      correlationId: correlationId,
      detail: 'pending=${pending.length}',
    );

    for (final operation in pending) {
      if (_inFlightIds.contains(operation.id)) {
        skipped++;
        continue;
      }
      final operationKey = AttendanceOperationIdentity.operationKeyFromPayload(
        operation.payload,
      );
      if (operationKey != null &&
          _inFlightOperationKeys.contains(operationKey)) {
        skipped++;
        continue;
      }

      if (!_processors.containsKey(operation.type)) {
        skipped++;
        continue;
      }

      _inFlightIds.add(operation.id);
      if (operationKey != null) _inFlightOperationKeys.add(operationKey);
      processed++;

      try {
        await _applyExponentialBackoff(operation);
        await _processOne(
          operation,
          traceId: traceId,
          correlationId: correlationId,
        );
        succeeded++;
      } catch (e, st) {
        failed++;
        OfflineEngineLog.logError(
          'operation failure',
          traceId: traceId,
          correlationId: correlationId,
          detail: 'id=${operation.id} $e',
        );
        if (kDebugMode) debugPrintStack(stackTrace: st);
      } finally {
        _inFlightIds.remove(operation.id);
        if (operationKey != null) {
          _inFlightOperationKeys.remove(operationKey);
        }
      }
    }

    return OfflineSyncResult(
      processed: processed,
      succeeded: succeeded,
      failed: failed,
      skipped: skipped,
    );
  }

  Future<void> _applyExponentialBackoff(OfflineOperation operation) async {
    if (operation.retryCount <= 0) return;
    final exponent = math.min(operation.retryCount, 5);
    final delayMs = math.min(
      _maxBackoffMs,
      _baseBackoffMs * math.pow(2, exponent).toInt(),
    );
    OfflineEngineLog.log(
      OfflineEngineLog.sync,
      'exponential backoff',
      operationId: operation.id,
      detail: 'delayMs=$delayMs retryCount=${operation.retryCount}',
    );
    await Future<void>.delayed(Duration(milliseconds: delayMs));
  }

  Future<void> _processOne(
    OfflineOperation operation, {
    required String traceId,
    required String correlationId,
  }) async {
    if (operation.retryCount >= OfflineSyncFailurePolicy.defaultMaxRetries) {
      await _queue.markFailed(
        operation.id,
        error: 'retryCount>=${OfflineSyncFailurePolicy.defaultMaxRetries}',
      );
      return;
    }

    _queue.beginRuntimeSync(operation.id);
    final processor = _processors[operation.type]!;

    try {
      await processor.process(operation);
      await _queue.markSynced(operation.id);
      await _queue.removeOperation(operation.id);
      OfflineEngineLog.log(
        OfflineEngineLog.sync,
        'sync success',
        operationId: operation.id,
        traceId: traceId,
        correlationId: correlationId,
      );
    } catch (e) {
      final latest = await _queue.getById(operation.id) ?? operation;
      final permanent = OfflineSyncFailurePolicy.isPermanentFailure(e);
      final transient = OfflineSyncFailurePolicy.isTransientFailure(e);
      final atMaxRetries =
          latest.retryCount >= OfflineSyncFailurePolicy.defaultMaxRetries;
      final canRequeue = !permanent && !atMaxRetries && transient;

      if (canRequeue) {
        await _queue.markRetryPending(operation.id, error: e.toString());
      } else {
        await _queue.markFailed(operation.id, error: e.toString());
      }
      rethrow;
    } finally {
      _queue.endRuntimeSync(operation.id);
    }
  }
}

class OfflineSyncResult {
  const OfflineSyncResult({
    this.processed = 0,
    this.succeeded = 0,
    this.failed = 0,
    this.skipped = 0,
    this.skippedBecauseBusy = false,
  });

  final int processed;
  final int succeeded;
  final int failed;
  final int skipped;
  final bool skippedBecauseBusy;
}
