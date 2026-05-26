import '../../../models/attendance/manual_attendance_record.dart';
import '../contracts/attendance_ui_contract.dart';
import 'attendance_operation_ui_state.dart';
import 'attendance_state_event.dart';
import 'attendance_state_service.dart';

typedef AttendanceFirestoreMapBuilder = Future<Map<int, ManualAttendanceStatus>>
    Function();

/// Thin facade — all routing goes to [AttendanceStateService] (event-driven).
class AttendanceSyncEventRouter {
  AttendanceSyncEventRouter._();
  static final AttendanceSyncEventRouter instance = AttendanceSyncEventRouter._();

  AttendanceStateService get _service => AttendanceStateService.instance;

  Stream<AttendanceStateEvent> get attendanceStateEvents =>
      _service.attendanceStateEvents;

  void attachSession({
    required String sessionId,
    required AttendanceFirestoreMapBuilder firestoreMapBuilder,
  }) {
    _service.attachSession(
      sessionId: sessionId,
      firestoreMapBuilder: firestoreMapBuilder,
    );
  }

  void attachStudent({required String studentId}) {
    _service.attachStudent(studentId: studentId);
  }

  void detach() => _service.detach();

  void notifyPipelineOutcome({
    required String sessionId,
    required String studentId,
    required AttendanceUIState state,
    String? operationId,
    String? message,
  }) {
    _service.notifyPipelineOutcome(
      sessionId: sessionId,
      studentId: studentId,
      state: state,
      operationId: operationId,
      message: message,
    );
  }

  AttendanceUiContract? uiContractFor({
    required String sessionId,
    required String studentId,
  }) =>
      _service.uiContractFor(sessionId: sessionId, studentId: studentId);
}

/// @deprecated Use [AttendanceSyncEventRouter].
@Deprecated('Use AttendanceSyncEventRouter')
typedef AttendanceSyncUIListener = AttendanceSyncEventRouter;
