import '../offline/offline_engine_log.dart';

/// Debug log events for manual attendance (prefix [ATTENDANCE_SYNC]).
abstract final class ManualAttendanceOfflineLog {
  static const submitStart = 'ATTENDANCE_SUBMIT_START';
  static const firestoreSuccess = 'ATTENDANCE_FIRESTORE_SUCCESS';
  static const firestoreFail = 'ATTENDANCE_FIRESTORE_FAIL';
  static const enqueued = 'ATTENDANCE_ENQUEUED';
  static const duplicateSkipped = 'ATTENDANCE_DUPLICATE_SKIPPED';
  static const retry = 'ATTENDANCE_RETRY';
  static const finalFailure = 'ATTENDANCE_FINAL_FAILURE';

  static void log(
    String event, {
    String? sessionId,
    int? studentId,
    String? operationId,
    String? operationKey,
    String? recordId,
    String? detail,
  }) {
    final buffer = StringBuffer(event);
    if (sessionId != null) buffer.write(' sessionId=$sessionId');
    if (studentId != null) buffer.write(' studentId=$studentId');
    if (recordId != null) buffer.write(' recordId=$recordId');
    OfflineEngineLog.log(
      OfflineEngineLog.attendanceSync,
      buffer.toString(),
      operationId: operationId,
      operationKey: operationKey,
      detail: detail,
    );
  }
}
