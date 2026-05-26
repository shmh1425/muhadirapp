import 'dart:async';

/// Lightweight queue/sync notifications for attendance UI (no queue logic).
enum OfflineAttendanceSignalKind {
  operationChanged,
  runtimeSyncStarted,
  runtimeSyncEnded,
  operationRemoved,
}

class OfflineAttendanceSignal {
  const OfflineAttendanceSignal({
    required this.kind,
    this.operationId,
    this.operationType,
    this.sessionId,
    this.studentId,
  });

  final OfflineAttendanceSignalKind kind;
  final String? operationId;
  final String? operationType;
  final String? sessionId;
  final String? studentId;
}

/// Broadcast bus: queue writes + runtime sync transitions only.
class OfflineAttendanceSignals {
  OfflineAttendanceSignals._();
  static final OfflineAttendanceSignals instance = OfflineAttendanceSignals._();

  final StreamController<OfflineAttendanceSignal> _controller =
      StreamController<OfflineAttendanceSignal>.broadcast();

  Stream<OfflineAttendanceSignal> get stream => _controller.stream;

  void publish(OfflineAttendanceSignal signal) {
    if (_controller.isClosed) return;
    _controller.add(signal);
  }
}
