import 'logging/attendance_log_categories.dart';

/// Structured attendance pipeline logs (debug only).
///
/// @deprecated Prefer [AttendanceLogCategories] directly (Phase 3.6).
abstract final class AttendancePipelineLogger {
  static const entry = AttendanceLogCategories.entry;
  static const router = AttendanceLogCategories.router;
  static const nfc = AttendanceLogCategories.nfc;
  static const bt = AttendanceLogCategories.bluetooth;
  static const qr = AttendanceLogCategories.qr;
  static const manual = AttendanceLogCategories.manual;
  static const offline = AttendanceLogCategories.offlineBridge;

  static void log(
    String prefix,
    String message, {
    String? requestId,
    String? sessionId,
    String? studentId,
    String? detail,
  }) {
    AttendanceLogCategories.log(
      prefix,
      message,
      requestId: requestId,
      sessionId: sessionId,
      studentId: studentId,
      detail: detail,
    );
  }
}
