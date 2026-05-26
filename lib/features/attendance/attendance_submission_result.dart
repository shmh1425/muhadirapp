import 'attendance_session_snapshot.dart';
import 'attendance_source.dart';

enum AttendanceSubmissionOutcome {
  appliedOnline,
  queuedOffline,
  duplicateSkipped,
  rejectedOffline,
}

class AttendanceSubmissionResult {
  const AttendanceSubmissionResult({
    required this.success,
    required this.outcome,
    required this.source,
    this.message,
    this.requestId,
    this.recordId,
    this.queuedCount = 0,
    this.sessionSnapshot,
  });

  final bool success;
  final AttendanceSubmissionOutcome outcome;
  final AttendanceSource source;
  final String? message;
  final String? requestId;
  final String? recordId;
  final int queuedCount;
  final AttendanceSessionSnapshot? sessionSnapshot;

  factory AttendanceSubmissionResult.duplicate(AttendanceSource source) {
    return AttendanceSubmissionResult(
      success: true,
      outcome: AttendanceSubmissionOutcome.duplicateSkipped,
      source: source,
      message: 'Duplicate request skipped.',
    );
  }

  factory AttendanceSubmissionResult.rejectedOffline(AttendanceSource source) {
    return AttendanceSubmissionResult(
      success: false,
      outcome: AttendanceSubmissionOutcome.rejectedOffline,
      source: source,
      message: 'QR attendance requires an internet connection.',
    );
  }
}
