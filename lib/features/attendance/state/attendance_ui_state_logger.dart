import '../logging/attendance_log_categories.dart';

/// @deprecated Prefer [AttendanceLogCategories.state] / `.ui` (Phase 3.6).
abstract final class AttendanceUiStateLogger {
  static const String ui = AttendanceLogCategories.ui;
  static const String stateSync = AttendanceLogCategories.sync;
  static const String stateResolver = AttendanceLogCategories.state;

  static void log(
    String prefix,
    String message, {
    String? sessionId,
    String? studentId,
    String? detail,
  }) {
    AttendanceLogCategories.log(
      prefix,
      message,
      sessionId: sessionId,
      studentId: studentId,
      detail: detail,
    );
  }
}
