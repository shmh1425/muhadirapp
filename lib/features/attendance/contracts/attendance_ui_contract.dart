import '../state/attendance_operation_ui_state.dart';

/// Frozen UI status contract (screens must not read queue/runtime directly).
enum AttendanceUiStatus {
  idle,
  pending,
  syncing,
  synced,
  failed,
}

/// Per-student UI contract emitted by [AttendanceStateService].
class AttendanceUiContract {
  const AttendanceUiContract({
    required this.sessionId,
    required this.studentId,
    required this.status,
    this.message,
    this.operationId,
    this.lastUpdated,
  });

  final String sessionId;
  final String studentId;
  final AttendanceUiStatus status;
  final String? message;
  final String? operationId;
  final DateTime? lastUpdated;

  bool get isActiveSync =>
      status == AttendanceUiStatus.pending ||
      status == AttendanceUiStatus.syncing ||
      status == AttendanceUiStatus.failed;

  factory AttendanceUiContract.fromModel(AttendanceOperationUIModel model) {
    return AttendanceUiContract(
      sessionId: model.sessionId,
      studentId: model.studentId,
      status: model.state.toUiStatus(),
      message: model.message,
      operationId: model.operationId,
      lastUpdated: model.lastUpdated,
    );
  }
}

/// Maps legacy [AttendanceUIState] to frozen [AttendanceUiStatus].
extension AttendanceUiStatusMapping on AttendanceUIState {
  AttendanceUiStatus toUiStatus() {
    switch (this) {
      case AttendanceUIState.idle:
        return AttendanceUiStatus.idle;
      case AttendanceUIState.pending:
        return AttendanceUiStatus.pending;
      case AttendanceUIState.syncing:
        return AttendanceUiStatus.syncing;
      case AttendanceUIState.synced:
        return AttendanceUiStatus.synced;
      case AttendanceUIState.failed:
        return AttendanceUiStatus.failed;
    }
  }

  static AttendanceUIState fromUiStatus(AttendanceUiStatus status) {
    switch (status) {
      case AttendanceUiStatus.idle:
        return AttendanceUIState.idle;
      case AttendanceUiStatus.pending:
        return AttendanceUIState.pending;
      case AttendanceUiStatus.syncing:
        return AttendanceUIState.syncing;
      case AttendanceUiStatus.synced:
        return AttendanceUIState.synced;
      case AttendanceUiStatus.failed:
        return AttendanceUIState.failed;
    }
  }
}
