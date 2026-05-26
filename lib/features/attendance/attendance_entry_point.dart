import 'package:uuid/uuid.dart';

import '../../models/attendance/manual_attendance_record.dart';
import 'attendance_idempotency_cache.dart';
import 'attendance_pipeline_logger.dart';
import 'attendance_source.dart';
import 'attendance_submission_result.dart';
import 'attendance_submission_router.dart';
import 'attendance_unified_service.dart';

/// The only UI-facing attendance submission API.
abstract final class AttendanceEntryPoint {
  static final Uuid _uuid = const Uuid();

  /// Single-student submission (NFC / Bluetooth / QR).
  static Future<AttendanceSubmissionResult> submit({
    required AttendanceSource source,
    required String sessionId,
    required String studentId,
    required String courseId,
    Map<String, dynamic>? metadata,
    String? requestId,
    String? attendanceStatus,
  }) async {
    final rid = _resolveRequestId(requestId, source, sessionId, studentId);
    AttendancePipelineLogger.log(
      AttendancePipelineLogger.entry,
      'submit start',
      requestId: rid,
      sessionId: sessionId,
      studentId: studentId,
      detail: 'source=${source.wireValue}',
    );
    if (!AttendanceIdempotencyCache.instance.tryConsume(rid)) {
      AttendancePipelineLogger.log(
        AttendancePipelineLogger.entry,
        'duplicate request skipped',
        requestId: rid,
      );
      return AttendanceSubmissionResult.duplicate(source);
    }
    final result = await AttendanceSubmissionRouter.instance.route(
      source: source,
      sessionId: sessionId,
      studentId: studentId,
      courseId: courseId,
      metadata: metadata,
      requestId: rid,
      attendanceStatus: attendanceStatus,
    );
    AttendancePipelineLogger.log(
      AttendancePipelineLogger.entry,
      'submit done',
      requestId: rid,
      detail: 'outcome=${result.outcome.name} success=${result.success}',
    );
    return result;
  }

  /// Lecturer manual multi-student save.
  static Future<AttendanceSubmissionResult> submitManualBatch({
    required String sessionId,
    required String courseId,
    required Map<int, ManualAttendanceStatus> updates,
    String? requestId,
  }) async {
    final rid = requestId?.trim().isNotEmpty == true
        ? requestId!.trim()
        : _uuid.v4();
    AttendancePipelineLogger.log(
      AttendancePipelineLogger.entry,
      'submitManualBatch start',
      requestId: rid,
      sessionId: sessionId,
      detail: 'students=${updates.length}',
    );
    if (!AttendanceIdempotencyCache.instance.tryConsume(rid)) {
      return AttendanceSubmissionResult.duplicate(AttendanceSource.manual);
    }
    return AttendanceUnifiedService.instance.submitManualBatch(
      sessionId: sessionId,
      courseId: courseId,
      updates: updates,
      requestId: rid,
    );
  }

  static String _resolveRequestId(
    String? requestId,
    AttendanceSource source,
    String sessionId,
    String studentId,
  ) {
    if (requestId != null && requestId.trim().isNotEmpty) {
      return requestId.trim();
    }
    return '${source.wireValue}_${sessionId.trim()}_${studentId.trim()}_${_uuid.v4()}';
  }
}
