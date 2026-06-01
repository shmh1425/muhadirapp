import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../attendance/attendance_state_versioning.dart';
import '../../features/attendance/identity/attendance_operation_identity.dart';
import 'offline_attendance_signals.dart';
import 'offline_engine_log.dart';
import 'offline_operation.dart';
import 'offline_operation_status.dart';
import 'offline_operation_types.dart';
import 'offline_sync_failure_policy.dart';
import 'offline_sync_lock.dart';

/// Persistent unified offline queue backed by Hive.
class OfflineQueueService {
  OfflineQueueService._();
  static final OfflineQueueService instance = OfflineQueueService._();

  static const boxName = 'offline_operations_queue';
  static const int _enqueuePersistAttempts = 3;

  final Uuid _uuid = const Uuid();
  Box<dynamic>? _box;

  final Set<String> _runtimeSyncingIds = <String>{};
  final Map<String, DateTime> _runtimeSyncStartedAt = <String, DateTime>{};

  Future<void> ensureInitialized() async {
    if (_box != null && _box!.isOpen) {
      await _recoverStaleSyncingInStorage();
      return;
    }
    _box = await Hive.openBox<dynamic>(boxName);
    await _recoverStaleSyncingInStorage();
    OfflineEngineLog.log(
      OfflineEngineLog.queue,
      'box opened',
      detail: 'name=$boxName count=${_box!.length}',
    );
  }

  Box<dynamic> get _requireBox {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('OfflineQueueService not initialized.');
    }
    return box;
  }

  Future<QueueIntegrityReport> validateQueueIntegrity() async {
    await ensureInitialized();
    var corruptRemoved = 0;
    var syncingRecovered = 0;
    var invalidUuidRemoved = 0;

    final keys = List<dynamic>.from(_requireBox.keys);
    for (final rawKey in keys) {
      if (rawKey.toString() == OfflineSyncLock.lockKey) continue;
      final raw = _requireBox.get(rawKey);
      final op = OfflineOperation.tryFromMap(raw);
      if (op == null) {
        await _requireBox.delete(rawKey);
        corruptRemoved++;
        continue;
      }
      if (!_isValidUuid(op.id)) {
        await _requireBox.delete(rawKey);
        invalidUuidRemoved++;
        continue;
      }
      if (op.status == OfflineOperationStatus.syncing) {
        await _write(
          op.copyWith(
            status: OfflineOperationStatus.pending,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
        syncingRecovered++;
      }
    }

    final deduped = await deduplicateUnsyncedByOperationKey();
    final orphans = await removeOrphanOperations();

    final report = QueueIntegrityReport(
      corruptRemoved: corruptRemoved,
      syncingRecovered: syncingRecovered,
      invalidUuidRemoved: invalidUuidRemoved,
      duplicateKeysRemoved: deduped,
      orphanRemoved: orphans,
    );
    OfflineEngineLog.log(
      OfflineEngineLog.queue,
      'validateQueueIntegrity',
      detail: report.toString(),
    );
    return report;
  }

  Future<OfflineOperation> enqueueOperation({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    await ensureInitialized();
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final normalizedPayload = AttendanceStateVersioning.enrichPayload(
      AttendanceOperationIdentity.embedInPayload(payload),
      clientMutationId: id,
    );
    final operation = OfflineOperation(
      id: id,
      type: type.trim(),
      createdAt: now,
      updatedAt: now,
      status: OfflineOperationStatus.pending,
      retryCount: 0,
      payload: normalizedPayload,
    );
    if (operation.type.isEmpty) {
      throw ArgumentError('Operation type must not be empty.');
    }
    await _persistWithConfirm(operation);
    OfflineEngineLog.log(
      OfflineEngineLog.queue,
      'enqueue confirmed',
      operationId: operation.id,
      operationKey:
          AttendanceOperationIdentity.operationKeyFromPayload(operation.payload),
    );
    return operation;
  }

  Future<OfflineOperation> enqueueOrCoalesceByOperationKey({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    await ensureInitialized();
    final normalizedPayload = AttendanceOperationIdentity.embedInPayload(payload);
    final operationKey =
        AttendanceOperationIdentity.operationKeyFromPayload(normalizedPayload);
    if (operationKey != null) {
      final existing = await findUnsyncedByOperationKey(
        type: type,
        operationKey: operationKey,
      );
      if (existing != null) {
        final merged = AttendanceStateVersioning.enrichPayload(
          normalizedPayload,
          clientMutationId: existing.id,
          serverStateHash:
              (normalizedPayload[AttendanceStateVersioning.serverStateHashField] ??
                      existing.payload[AttendanceStateVersioning
                          .serverStateHashField])
                  ?.toString(),
        );
        await updatePayload(existing.id, merged);
        OfflineEngineLog.log(
          OfflineEngineLog.queue,
          'coalesce by operationKey',
          operationId: existing.id,
          operationKey: operationKey,
        );
        return (await getById(existing.id))!;
      }
    }
    return enqueueOperation(type: type, payload: normalizedPayload);
  }

  Future<OfflineOperation?> findUnsyncedByOperationKey({
    required String type,
    required String operationKey,
  }) async {
    await ensureInitialized();
    final key = operationKey.trim();
    if (key.isEmpty) return null;
    for (final op in await getUnsyncedOperations()) {
      if (op.type != type) continue;
      if (AttendanceOperationIdentity.operationKeyFromPayload(op.payload) ==
          key) {
        return op;
      }
    }
    return null;
  }

  Future<List<OfflineOperation>> getPendingOperations() async {
    await ensureInitialized();
    return _readAll()
        .where((op) => op.status == OfflineOperationStatus.pending)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<List<OfflineOperation>> getFailedOperations() async {
    await ensureInitialized();
    return _readAll()
        .where((op) => op.status == OfflineOperationStatus.failed)
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  }

  Future<OfflineOperation?> getById(String id) async {
    await ensureInitialized();
    return OfflineOperation.tryFromMap(_requireBox.get(id.trim()));
  }

  /// Read-only snapshot for UI sync indicators (no persistence).
  Set<String> snapshotRuntimeSyncingOperationIds() =>
      Set<String>.unmodifiable(_runtimeSyncingIds);

  bool isRuntimeSyncing(String operationId) =>
      _runtimeSyncingIds.contains(operationId.trim());

  void beginRuntimeSync(String id) {
    final key = id.trim();
    _runtimeSyncingIds.add(key);
    _runtimeSyncStartedAt[key] = DateTime.now().toUtc();
    unawaited(_publishRuntimeSignal(key, OfflineAttendanceSignalKind.runtimeSyncStarted));
  }

  void endRuntimeSync(String id) {
    final key = id.trim();
    _runtimeSyncingIds.remove(key);
    _runtimeSyncStartedAt.remove(key);
    unawaited(_publishRuntimeSignal(key, OfflineAttendanceSignalKind.runtimeSyncEnded));
  }

  int clearStaleRuntimeSyncs({required Duration maxAge}) {
    final now = DateTime.now().toUtc();
    final stale = <String>[];
    for (final entry in _runtimeSyncStartedAt.entries) {
      if (now.difference(entry.value) > maxAge) {
        stale.add(entry.key);
      }
    }
    for (final id in stale) {
      endRuntimeSync(id);
    }
    return stale.length;
  }

  Future<void> markSyncing(String id) async => beginRuntimeSync(id);

  Future<void> markSynced(String id) async {
    endRuntimeSync(id);
    await _updateStatus(id, OfflineOperationStatus.synced, logLabel: 'markSynced');
  }

  Future<void> markFailed(String id, {String? error}) async {
    endRuntimeSync(id);
    await ensureInitialized();
    final existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(
        status: OfflineOperationStatus.failed,
        updatedAt: DateTime.now().toUtc(),
        retryCount: existing.retryCount + 1,
        lastError: error,
      ),
    );
  }

  Future<void> removeOperation(String id) async {
    final existing = await getById(id);
    endRuntimeSync(id);
    await ensureInitialized();
    await _requireBox.delete(id.trim());
    if (existing != null) {
      _publishOperationSignal(
        existing,
        OfflineAttendanceSignalKind.operationRemoved,
      );
    } else {
      OfflineAttendanceSignals.instance.publish(
        OfflineAttendanceSignal(
          kind: OfflineAttendanceSignalKind.operationRemoved,
          operationId: id.trim(),
        ),
      );
    }
  }

  Future<List<OfflineOperation>> getUnsyncedOperations() async {
    await ensureInitialized();
    return _readAll()
        .where(
          (op) =>
              op.status == OfflineOperationStatus.pending ||
              op.status == OfflineOperationStatus.failed,
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<Set<int>> pendingStudentIdsForSession({
    required String type,
    required String sessionId,
  }) async {
    final targetSession = sessionId.trim();
    if (targetSession.isEmpty) return const <int>{};
    final ids = <int>{};
    for (final op in await getUnsyncedOperations()) {
      if (op.type != type) continue;
      if ((op.payload['sessionId'] ?? '').toString().trim() != targetSession) {
        continue;
      }
      final studentId = _parseStudentId(op.payload['studentId']);
      if (studentId > 0) ids.add(studentId);
    }
    return ids;
  }

  /// Re-attempt failed Bluetooth attendance after connectivity (session may have closed).
  Future<int> requeueFailedBluetoothAttendanceOps() async {
    await ensureInitialized();
    var count = 0;
    for (final op in await getFailedOperations()) {
      if (op.type != OfflineOperationTypes.bluetoothAttendance) continue;
      await _write(
        op.copyWith(
          status: OfflineOperationStatus.pending,
          updatedAt: DateTime.now().toUtc(),
          retryCount: 0,
          clearLastError: true,
        ),
      );
      count++;
    }
    return count;
  }

  Future<int> requeueRetriableFailedOperations({
    int maxRetryCount = OfflineSyncFailurePolicy.defaultMaxRetries,
  }) async {
    await ensureInitialized();
    var count = 0;
    for (final op in await getFailedOperations()) {
      if (op.retryCount >= maxRetryCount) continue;
      await _write(
        op.copyWith(
          status: OfflineOperationStatus.pending,
          updatedAt: DateTime.now().toUtc(),
          clearLastError: true,
        ),
      );
      count++;
    }
    return count;
  }

  Future<void> markRetryPending(String id, {String? error}) async {
    endRuntimeSync(id);
    final existing = await getById(id);
    if (existing == null) return;
    if (existing.retryCount >= OfflineSyncFailurePolicy.defaultMaxRetries) {
      await markFailed(id, error: error ?? 'max retries exceeded');
      return;
    }
    await _write(
      existing.copyWith(
        status: OfflineOperationStatus.pending,
        updatedAt: DateTime.now().toUtc(),
        retryCount: existing.retryCount + 1,
        lastError: error,
      ),
    );
  }

  Future<void> updatePayload(String id, Map<String, dynamic> payload) async {
    final existing = await getById(id);
    if (existing == null) {
      throw StateError('Offline operation not found: $id');
    }
    await _persistWithConfirm(
      existing.copyWith(
        payload: AttendanceStateVersioning.enrichPayload(
          AttendanceOperationIdentity.embedInPayload(payload),
          clientMutationId: existing.id,
          serverStateHash:
              payload[AttendanceStateVersioning.serverStateHashField]?.toString(),
        ),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> removeOperationsByIds(Iterable<String> ids) async {
    for (final id in ids) {
      if (id.trim().isNotEmpty) await removeOperation(id);
    }
  }

  Future<int> deduplicateUnsyncedByOperationKey() async {
    final ops = await getUnsyncedOperations();
    final bestByKey = <String, OfflineOperation>{};
    final toRemove = <String>[];

    for (final op in ops) {
      final key = AttendanceOperationIdentity.operationKeyFromPayload(op.payload);
      if (key == null) continue;
      final existing = bestByKey[key];
      if (existing == null) {
        bestByKey[key] = op;
        continue;
      }
      final existingVersion = AttendanceStateVersioning.stateVersionFromPayload(
        existing.payload,
      );
      final candidateVersion = AttendanceStateVersioning.stateVersionFromPayload(
        op.payload,
      );
      if (candidateVersion >= existingVersion) {
        toRemove.add(existing.id);
        bestByKey[key] = op;
      } else {
        toRemove.add(op.id);
      }
    }

    for (final id in toRemove) {
      await removeOperation(id);
    }
    return toRemove.length;
  }

  Future<int> removeOrphanOperations() async {
    var removed = 0;
    for (final op in await getUnsyncedOperations()) {
      final sessionId = (op.payload['sessionId'] ?? '').toString().trim();
      final studentId = _parseStudentId(op.payload['studentId']);
      final status = (op.payload['attendanceStatus'] ?? '').toString().trim();
      if (sessionId.isEmpty || studentId <= 0 || status.isEmpty) {
        await removeOperation(op.id);
        removed++;
      }
    }
    return removed;
  }

  Future<OfflineSyncLockMetadata?> readLockMetadata() async {
    await ensureInitialized();
    final raw = _requireBox.get(OfflineSyncLock.lockKey);
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final lockedAt = DateTime.tryParse((map['lockedAt'] ?? '').toString())?.toUtc();
    final owner = (map['ownerTraceId'] ?? '').toString();
    if (lockedAt == null || owner.isEmpty) return null;
    return OfflineSyncLockMetadata(lockedAt: lockedAt, ownerTraceId: owner);
  }

  Future<void> writeLockMetadata({
    required DateTime lockedAt,
    required String ownerTraceId,
  }) async {
    await _requireBox.put(OfflineSyncLock.lockKey, <String, dynamic>{
      'lockedAt': lockedAt.toIso8601String(),
      'ownerTraceId': ownerTraceId,
    });
  }

  Future<void> clearLockMetadata() async {
    await ensureInitialized();
    await _requireBox.delete(OfflineSyncLock.lockKey);
  }

  Future<void> _persistWithConfirm(OfflineOperation operation) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _enqueuePersistAttempts; attempt++) {
      try {
        await _write(operation);
        final confirmed = await getById(operation.id);
        if (confirmed != null) return;
        lastError = StateError('enqueue confirm read-back miss id=${operation.id}');
      } catch (e) {
        lastError = e;
      }
      if (attempt < _enqueuePersistAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 50 * attempt));
      }
    }
    throw StateError('Failed to persist offline operation: $lastError');
  }

  Future<void> _recoverStaleSyncingInStorage() async {
    for (final op in _readAll()) {
      if (op.status != OfflineOperationStatus.syncing) continue;
      await _write(
        op.copyWith(
          status: OfflineOperationStatus.pending,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  Future<void> _updateStatus(
    String id,
    OfflineOperationStatus status, {
    required String logLabel,
  }) async {
    final existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(
        status: status,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    OfflineEngineLog.log(
      OfflineEngineLog.queue,
      logLabel,
      operationId: id,
      detail: 'status=${status.name}',
    );
  }

  Future<void> _write(OfflineOperation operation) async {
    await _requireBox.put(operation.id, operation.toMap());
    _publishOperationSignal(
      operation,
      OfflineAttendanceSignalKind.operationChanged,
    );
  }

  void _publishOperationSignal(
    OfflineOperation operation,
    OfflineAttendanceSignalKind kind,
  ) {
    OfflineAttendanceSignals.instance.publish(
      OfflineAttendanceSignal(
        kind: kind,
        operationId: operation.id,
        operationType: operation.type,
        sessionId: AttendanceOperationIdentity.effectiveSessionIdFromPayload(
          operation.payload,
        ),
        studentId: _parseStudentId(operation.payload['studentId']).toString(),
      ),
    );
  }

  Future<void> _publishRuntimeSignal(
    String operationId,
    OfflineAttendanceSignalKind kind,
  ) async {
    final op = await getById(operationId);
    if (op != null) {
      _publishOperationSignal(op, kind);
      return;
    }
    OfflineAttendanceSignals.instance.publish(
      OfflineAttendanceSignal(
        kind: kind,
        operationId: operationId,
      ),
    );
  }

  List<OfflineOperation> _readAll() {
    final results = <OfflineOperation>[];
    for (final key in _requireBox.keys) {
      if (key.toString() == OfflineSyncLock.lockKey) continue;
      final op = OfflineOperation.tryFromMap(_requireBox.get(key));
      if (op != null) results.add(op);
    }
    return results;
  }

  static bool _isValidUuid(String value) {
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return pattern.hasMatch(value.trim());
  }

  static int _parseStudentId(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString()) ?? 0;
  }
}

class QueueIntegrityReport {
  const QueueIntegrityReport({
    required this.corruptRemoved,
    required this.syncingRecovered,
    required this.invalidUuidRemoved,
    required this.duplicateKeysRemoved,
    required this.orphanRemoved,
  });

  final int corruptRemoved;
  final int syncingRecovered;
  final int invalidUuidRemoved;
  final int duplicateKeysRemoved;
  final int orphanRemoved;

  @override
  String toString() =>
      'corrupt=$corruptRemoved syncing=$syncingRecovered invalidUuid=$invalidUuidRemoved '
      'dupKeys=$duplicateKeysRemoved orphans=$orphanRemoved';
}
