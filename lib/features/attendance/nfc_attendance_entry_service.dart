import 'attendance_entry_point.dart';
import 'attendance_source.dart';
import 'attendance_submission_result.dart';
import 'attendance_pipeline_logger.dart';

/// NFC tap forwarding — parsing only, no Firestore/queue access.
abstract final class NfcAttendanceEntryService {
  static Future<AttendanceSubmissionResult> submitFromCardTap({
    required String lecturerCardId,
    required int studentId,
    required String sessionId,
    required String courseId,
    String? requestId,
    Map<String, dynamic>? location,
  }) async {
    AttendancePipelineLogger.log(
      AttendancePipelineLogger.nfc,
      'forward to entry point',
      requestId: requestId,
      studentId: '$studentId',
    );
    return AttendanceEntryPoint.submit(
      source: AttendanceSource.nfc,
      sessionId: sessionId,
      studentId: studentId.toString(),
      courseId: courseId,
      requestId: requestId,
      metadata: <String, dynamic>{
        'lecturerCardId': lecturerCardId,
        if (location != null) 'location': location,
      },
    );
  }
}
