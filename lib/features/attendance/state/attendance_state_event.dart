import 'attendance_operation_ui_state.dart';

/// Event-driven attendance UI updates (Phase 3.5).
enum AttendanceStateEventType {
  enqueued,
  syncing,
  synced,
  failed,
}

class AttendanceStateEvent {
  const AttendanceStateEvent({
    required this.type,
    required this.model,
  });

  final AttendanceStateEventType type;
  final AttendanceOperationUIModel model;

  String get sessionId => model.sessionId;
  String get studentId => model.studentId;
}
