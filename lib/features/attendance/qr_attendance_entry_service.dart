import 'attendance_entry_point.dart';
import 'attendance_source.dart';
import 'attendance_submission_result.dart';
import 'attendance_pipeline_logger.dart';

/// QR scan forwarding — online-only via entry point.
abstract final class QrAttendanceEntryService {
  static Future<AttendanceSubmissionResult> submitFromQrPayload({
    required Map<String, dynamic> qrPayload,
    String? requestId,
  }) async {
    final sessionId = (qrPayload['sessionId'] ?? '').toString();
    final sectionId = (qrPayload['sectionId'] ?? '').toString();
    AttendancePipelineLogger.log(
      AttendancePipelineLogger.qr,
      'forward to entry point',
      requestId: requestId,
      sessionId: sessionId,
    );
    return AttendanceEntryPoint.submit(
      source: AttendanceSource.qr,
      sessionId: sessionId,
      studentId: '', // resolved inside QR service from auth
      courseId: sectionId,
      requestId: requestId,
      metadata: Map<String, dynamic>.from(qrPayload),
    );
  }

  static Future<AttendanceSubmissionResult> submitFromNumericCode({
    required String numericCode,
    String? requestId,
  }) async {
    return AttendanceEntryPoint.submit(
      source: AttendanceSource.qr,
      sessionId: '',
      studentId: '',
      courseId: '',
      requestId: requestId,
      metadata: <String, dynamic>{'numericCode': numericCode},
    );
  }
}
