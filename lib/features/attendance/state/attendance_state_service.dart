import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/attendance/manual_attendance_record.dart';
import '../../../services/offline/offline_attendance_signals.dart';
import '../../../services/offline/offline_operation.dart';
import '../../../services/offline/offline_queue_service.dart';
import 'attendance_operation_ui_state.dart';
import 'attendance_queue_snapshot.dart';
import 'attendance_state_event.dart';
import 'attendance_state_pure_resolver.dart';
import '../contracts/attendance_ui_contract.dart';
import '../logging/attendance_log_categories.dart';

typedef AttendanceFirestoreMapBuilder = Future<Map<int, ManualAttendanceStatus>>
    Function();

/// Single attendance UI state brain: queue snapshot → UI model → events.
class AttendanceStateService extends ChangeNotifier {
  AttendanceStateService({
    OfflineQueueService? queue,
  }) : _queue = queue ?? OfflineQueueService.instance {
    OfflineAttendanceSignals.instance.stream.listen(_onOfflineSignal);
  }

  static final AttendanceStateService instance = AttendanceStateService();

  final OfflineQueueService _queue;
  final StreamController<AttendanceStateEvent> _eventController =
      StreamController<AttendanceStateEvent>.broadcast();

  final Map<String, AttendanceOperationUIModel> _states =
      <String, AttendanceOperationUIModel>{};

  String? _activeSessionId;
  String? _trackedStudentId;
  AttendanceFirestoreMapBuilder? _firestoreMapBuilder;

  Stream<AttendanceStateEvent> get attendanceStateEvents =>
      _eventController.stream;

  String? get activeSessionId => _activeSessionId;

  void setActiveSession(String? sessionId) {
    _activeSessionId =
        sessionId != null && sessionId.trim().isNotEmpty ? sessionId.trim() : null;
  }

  AttendanceOperationUIModel? stateFor({
    required String sessionId,
    required String studentId,
  }) {
    return _states[AttendanceOperationUIModel.cacheKey(sessionId, studentId)];
  }

  /// Frozen UI contract — the only API screens should use for live state.
  AttendanceUiContract? uiContractFor({
    required String sessionId,
    required String studentId,
  }) {
    final model = stateFor(sessionId: sessionId, studentId: studentId);
    return model == null ? null : AttendanceUiContract.fromModel(model);
  }

  void attachSession({
    required String sessionId,
    required AttendanceFirestoreMapBuilder firestoreMapBuilder,
  }) {
    _activeSessionId = sessionId.trim();
    _trackedStudentId = null;
    _firestoreMapBuilder = firestoreMapBuilder;
    AttendanceLogCategories.log(
      AttendanceLogCategories.state,
      'attachSession',
      sessionId: _activeSessionId,
    );
    unawaited(_recomputeActiveSession());
  }

  void attachStudent({required String studentId}) {
    _trackedStudentId = studentId.trim();
    _firestoreMapBuilder = null;
    AttendanceLogCategories.log(
      AttendanceLogCategories.state,
      'attachStudent',
      studentId: _trackedStudentId,
    );
  }

  void detach() {
    _activeSessionId = null;
    _trackedStudentId = null;
    _firestoreMapBuilder = null;
    clearRuntimeCaches();
    AttendanceLogCategories.log(AttendanceLogCategories.state, 'detach');
  }

  /// Drops in-memory UI state (call from screen dispose / session change).
  void clearRuntimeCaches({String? sessionId}) {
    if (sessionId == null || sessionId.trim().isEmpty) {
      _states.clear();
      return;
    }
    final prefix = '${sessionId.trim()}_';
    _states.removeWhere((key, _) => key.startsWith(prefix));
  }

  void notifyPipelineOutcome({
    required String sessionId,
    required String studentId,
    required AttendanceUIState state,
    String? operationId,
    String? message,
  }) {
    _applyModel(
      AttendanceOperationUIModel(
        sessionId: sessionId.trim(),
        studentId: studentId.trim(),
        state: state,
        lastUpdated: DateTime.now().toUtc(),
        operationId: operationId,
        message: message,
      ),
    );
  }

  Iterable<AttendanceOperationUIModel> modelsForSession(String sessionId) sync* {
    final prefix = '${sessionId.trim()}_';
    for (final entry in _states.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      yield entry.value;
    }
  }

  Map<AttendanceUIState, int> countByStateForSession(String sessionId) {
    final counts = <AttendanceUIState, int>{
      for (final s in AttendanceUIState.values) s: 0,
    };
    for (final model in modelsForSession(sessionId)) {
      counts[model.state] = (counts[model.state] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _onOfflineSignal(OfflineAttendanceSignal signal) async {
    try {
      if (_activeSessionId != null && _firestoreMapBuilder != null) {
        final active = _activeSessionId!.trim();
        final signalSession = signal.sessionId?.trim() ?? '';
        if (signalSession.isNotEmpty &&
            signalSession != active &&
            !signalSession.startsWith('nfc_') &&
            signalSession != 'nfc_pending' &&
            signalSession != 'bt_pending') {
          return;
        }
        await _recomputeActiveSession(
          focusStudentId: signal.studentId,
          focusSessionId: signal.sessionId,
          firestoreSyncedOnRemove:
              signal.kind == OfflineAttendanceSignalKind.operationRemoved,
        );
        return;
      }
      if (_trackedStudentId != null) {
        await _recomputeTrackedStudent(signal);
      }
    } catch (e) {
      AttendanceLogCategories.log(
        AttendanceLogCategories.error,
        'signal error',
        detail: '$e',
      );
    }
  }

  Future<AttendanceQueueSnapshot> _readSnapshot() async {
    await _queue.ensureInitialized();
    return AttendanceQueueSnapshot(
      unsyncedOperations: await _queue.getUnsyncedOperations(),
      runtimeSyncingOperationIds: _queue.snapshotRuntimeSyncingOperationIds(),
    );
  }

  Future<void> _recomputeActiveSession({
    String? focusStudentId,
    String? focusSessionId,
    bool firestoreSyncedOnRemove = false,
  }) async {
    final sessionId = _activeSessionId?.trim() ?? '';
    if (sessionId.isEmpty || _firestoreMapBuilder == null) return;

    final firestoreMap = await _firestoreMapBuilder!.call();
    final snapshot = await _readSnapshot();
    final syncedIds = firestoreMap.entries
        .where((e) => e.value != ManualAttendanceStatus.pending)
        .map((e) => e.key.toString())
        .toSet();

    final targets = <String>{
      ...firestoreMap.keys.map((id) => id.toString()),
      if (focusStudentId != null && focusStudentId.trim().isNotEmpty)
        focusStudentId.trim(),
    };

    for (final studentId in targets) {
      final effectiveSession =
          (focusStudentId == studentId &&
                  focusSessionId != null &&
                  focusSessionId.trim().isNotEmpty)
              ? focusSessionId.trim()
              : sessionId;
      var firestoreSynced = syncedIds.contains(studentId);
      if (firestoreSyncedOnRemove && studentId == focusStudentId?.trim()) {
        firestoreSynced = true;
      }
      _applyModel(
        AttendanceStatePureResolver.resolveUiModel(
          sessionId: effectiveSession,
          studentId: studentId,
          snapshot: snapshot,
          firestoreSynced: firestoreSynced,
        ),
      );
    }
  }

  Future<void> _recomputeTrackedStudent(OfflineAttendanceSignal signal) async {
    final studentId = _trackedStudentId?.trim() ?? '';
    if (studentId.isEmpty) return;

    final snapshot = await _readSnapshot();
    OfflineOperation? match;
    for (final op in snapshot.unsyncedOperations) {
      final payloadStudent = _parseStudentId(op.payload['studentId']);
      final matches = payloadStudent > 0 &&
          (payloadStudent.toString() == studentId ||
              payloadStudent == (int.tryParse(studentId) ?? -1));
      if (!matches) continue;
      if (match == null || op.updatedAt.isAfter(match.updatedAt)) {
        match = op;
      }
    }

    final sessionId = signal.sessionId?.trim().isNotEmpty == true
        ? signal.sessionId!.trim()
        : (match != null
            ? (match.payload['sessionId'] ?? '').toString()
            : (_activeSessionId ?? ''));

    if (sessionId.isEmpty) return;
    _activeSessionId = sessionId;

    final firestoreSynced =
        signal.kind == OfflineAttendanceSignalKind.operationRemoved;
    _applyModel(
      AttendanceStatePureResolver.resolveUiModel(
        sessionId: sessionId,
        studentId: studentId,
        snapshot: snapshot,
        firestoreSynced: firestoreSynced,
      ),
    );
  }

  void _applyModel(AttendanceOperationUIModel model) {
    if (model.sessionId.isEmpty || model.studentId.isEmpty) return;
    final key =
        AttendanceOperationUIModel.cacheKey(model.sessionId, model.studentId);
    final previous = _states[key];
    if (previous?.state == model.state &&
        previous?.message == model.message &&
        previous?.operationId == model.operationId) {
      return;
    }
    _states[key] = model;
    AttendanceLogCategories.log(
      AttendanceLogCategories.ui,
      'state updated',
      sessionId: model.sessionId,
      studentId: model.studentId,
      detail: model.state.name,
    );
    final eventType = _eventTypeForState(model.state);
    if (eventType != null && !_eventController.isClosed) {
      _eventController.add(
        AttendanceStateEvent(type: eventType, model: model),
      );
    }
    notifyListeners();
  }

  static AttendanceStateEventType? _eventTypeForState(AttendanceUIState state) {
    switch (state) {
      case AttendanceUIState.pending:
        return AttendanceStateEventType.enqueued;
      case AttendanceUIState.syncing:
        return AttendanceStateEventType.syncing;
      case AttendanceUIState.synced:
        return AttendanceStateEventType.synced;
      case AttendanceUIState.failed:
        return AttendanceStateEventType.failed;
      case AttendanceUIState.idle:
        return null;
    }
  }

  static int _parseStudentId(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString()) ?? 0;
  }

}
