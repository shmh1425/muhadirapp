import '../../models/attendance/bluetooth_attendance_session.dart';
import '../../models/attendance/nfc_attendance_session.dart';
import '../../models/attendance/qr_attendance_session.dart';

/// Lightweight session context for UI notifications after pipeline success.
class AttendanceSessionSnapshot {
  const AttendanceSessionSnapshot({
    this.courseName,
    this.section,
    this.sectionId,
    this.sessionId,
    this.lectureDate,
    this.lectureStartTime,
    this.lectureEndTime,
  });

  final String? courseName;
  final String? section;
  final String? sectionId;
  final String? sessionId;
  final DateTime? lectureDate;
  final String? lectureStartTime;
  final String? lectureEndTime;

  factory AttendanceSessionSnapshot.fromNfc(NfcAttendanceSession session) {
    return AttendanceSessionSnapshot(
      courseName: session.courseName,
      section: session.sectionLabel,
      sectionId: session.sectionId,
      sessionId: session.sessionId,
      lectureDate: session.lectureDate,
      lectureStartTime: session.lectureStartTime,
      lectureEndTime: session.lectureEndTime,
    );
  }

  factory AttendanceSessionSnapshot.fromBluetooth(
    BluetoothAttendanceSession session,
  ) {
    return AttendanceSessionSnapshot(
      courseName: session.courseName,
      section: session.section,
      sectionId: session.sectionId,
      sessionId: session.sessionId,
      lectureDate: session.lectureDate,
      lectureStartTime: session.lectureStartTime,
      lectureEndTime: session.lectureEndTime,
    );
  }

  factory AttendanceSessionSnapshot.fromQr(QrAttendanceSession session) {
    return AttendanceSessionSnapshot(
      courseName: session.courseName,
      section: session.section,
      sectionId: session.sectionId,
      sessionId: session.sessionId,
      lectureDate: session.lectureDate,
      lectureStartTime: session.lectureStartTime,
      lectureEndTime: session.lectureEndTime,
    );
  }
}
