import 'contracts/attendance_submission_contract.dart';
import 'attendance_source.dart';

/// Normalized attendance submission passed through the pipeline.
class AttendancePayload implements AttendanceSubmissionContract {
  AttendancePayload({
    required this.sessionId,
    required this.studentId,
    required this.courseId,
    required this.source,
    required this.requestId,
    DateTime? timestamp,
    this.metadata,
    this.attendanceStatus,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  @override
  final String sessionId;
  @override
  final String studentId;
  @override
  final String courseId;
  @override
  final AttendanceSource source;
  @override
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final String? attendanceStatus;
  @override
  final String requestId;

  int? get studentIdInt => int.tryParse(studentId.trim());

  Map<String, dynamic> toQueuePayload() {
    return <String, dynamic>{
      'sessionId': sessionId.trim(),
      'studentId': studentIdInt ?? studentId,
      'courseId': courseId.trim(),
      'source': source.wireValue,
      'requestId': requestId,
      'timestamp': timestamp.toIso8601String(),
      'attendanceStatus': attendanceStatus ?? 'present',
      if (metadata != null) ...metadata!,
    };
  }

  static AttendancePayload fromQueueMap(Map<String, dynamic> map) {
    return AttendancePayload(
      sessionId: (map['sessionId'] ?? '').toString(),
      studentId: (map['studentId'] ?? '').toString(),
      courseId: (map['courseId'] ?? '').toString(),
      source: AttendanceSource.values.firstWhere(
        (s) => s.wireValue == (map['source'] ?? '').toString(),
        orElse: () => AttendanceSource.manual,
      ),
      requestId: (map['requestId'] ?? '').toString(),
      timestamp:
          DateTime.tryParse((map['timestamp'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
      metadata: Map<String, dynamic>.from(map),
      attendanceStatus: (map['attendanceStatus'] ?? '').toString(),
    );
  }
}
