import '../attendance_source.dart';

/// Frozen contract for every attendance submission channel (Phase 3.6).
abstract interface class AttendanceSubmissionContract {
  String get sessionId;
  String get studentId;
  String get courseId;
  AttendanceSource get source;
  DateTime get timestamp;
  String get requestId;
}

/// Normalized identity fields shared across NFC / BLE / QR / Manual.
class AttendanceSubmissionIdentity {
  const AttendanceSubmissionIdentity({
    required this.sessionId,
    required this.studentId,
    required this.courseId,
    required this.source,
    required this.requestId,
    this.attendanceStatus = 'present',
    this.timestamp,
  });

  final String sessionId;
  final String studentId;
  final String courseId;
  final AttendanceSource source;
  final String requestId;
  final String attendanceStatus;
  final DateTime? timestamp;

  DateTime get effectiveTimestamp => timestamp ?? DateTime.now().toUtc();

  Map<String, dynamic> toMap({Map<String, dynamic>? metadata}) {
    return <String, dynamic>{
      'sessionId': sessionId.trim(),
      'studentId': int.tryParse(studentId.trim()) ?? studentId,
      'courseId': courseId.trim(),
      'source': source.wireValue,
      'requestId': requestId.trim(),
      'timestamp': effectiveTimestamp.toIso8601String(),
      'attendanceStatus': attendanceStatus,
      if (metadata != null) ...metadata,
    };
  }
}
