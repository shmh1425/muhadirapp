import '../../features/attendance/identity/attendance_operation_identity.dart';

/// @deprecated Use [AttendanceOperationIdentity] (Phase 3.6). Kept for Phase 2B callers.
@Deprecated('Use AttendanceOperationIdentity instead.')
abstract final class ManualAttendanceOperationKey {
  static const String payloadField = AttendanceOperationIdentity.payloadField;

  static String build({
    required String sessionId,
    required int studentId,
    required String attendanceStatus,
    String source = 'manual',
  }) =>
      AttendanceOperationIdentity.buildOperationKey(
        sessionId: sessionId,
        studentId: studentId,
        attendanceStatus: attendanceStatus,
        source: source,
      );

  static String? fromPayload(Map<String, dynamic> payload) =>
      AttendanceOperationIdentity.operationKeyFromPayload(payload);

  static String recordDocId({
    required String sessionId,
    required int studentId,
  }) =>
      AttendanceOperationIdentity.recordDocId(
        sessionId: sessionId,
        studentId: studentId,
      );

  static Map<String, dynamic> withOperationKey(Map<String, dynamic> payload) =>
      AttendanceOperationIdentity.embedInPayload(payload);
}
