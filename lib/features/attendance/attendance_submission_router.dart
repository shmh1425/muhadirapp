import 'package:uuid/uuid.dart';

import 'attendance_payload.dart';
import 'attendance_pipeline_logger.dart';
import 'attendance_source.dart';
import 'attendance_submission_result.dart';
import 'attendance_unified_service.dart';

/// Routes normalized payloads to [AttendanceUnifiedService].
class AttendanceSubmissionRouter {
  AttendanceSubmissionRouter._();
  static final AttendanceSubmissionRouter instance =
      AttendanceSubmissionRouter._();

  static final Uuid _uuid = const Uuid();

  Future<AttendanceSubmissionResult> route({
    required AttendanceSource source,
    required String sessionId,
    required String studentId,
    required String courseId,
    Map<String, dynamic>? metadata,
    String? requestId,
    String? attendanceStatus,
  }) async {
    final rid = (requestId?.trim().isNotEmpty ?? false)
        ? requestId!.trim()
        : _uuid.v4();
    final payload = AttendancePayload(
      sessionId: sessionId,
      studentId: studentId,
      courseId: courseId,
      source: source,
      requestId: rid,
      metadata: metadata,
      attendanceStatus: attendanceStatus,
    );
    AttendancePipelineLogger.log(
      AttendancePipelineLogger.router,
      'route',
      requestId: rid,
      sessionId: sessionId,
      studentId: studentId,
      detail: 'source=${source.wireValue}',
    );
    return AttendanceUnifiedService.instance.submit(payload);
  }
}
