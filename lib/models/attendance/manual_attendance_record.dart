import 'package:cloud_firestore/cloud_firestore.dart';

enum ManualAttendanceStatus { present, absent, excused, late }

class ManualAttendanceRecord {
  const ManualAttendanceRecord({
    required this.recordId,
    required this.sessionId,
    required this.sectionId,
    required this.studentId,
    required this.studentName,
    required this.status,
    required this.lectureDate,
    required this.courseName,
    required this.sectionLabel,
    required this.lectureStartTime,
    required this.lectureEndTime,
    required this.attendanceTime,
  });

  final String recordId;
  final String sessionId;
  final String sectionId;
  final int studentId;
  final String studentName;
  final ManualAttendanceStatus status;
  final DateTime lectureDate;
  final String courseName;
  final String sectionLabel;
  final String lectureStartTime;
  final String lectureEndTime;
  final String attendanceTime;

  bool get isPresentLike =>
      status == ManualAttendanceStatus.present ||
      status == ManualAttendanceStatus.late;

  static ManualAttendanceStatus statusFromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'absent':
        return ManualAttendanceStatus.absent;
      case 'excused':
        return ManualAttendanceStatus.excused;
      case 'late':
        return ManualAttendanceStatus.late;
      case 'present':
      default:
        return ManualAttendanceStatus.present;
    }
  }

  static String statusToString(ManualAttendanceStatus status) {
    switch (status) {
      case ManualAttendanceStatus.present:
        return 'present';
      case ManualAttendanceStatus.absent:
        return 'absent';
      case ManualAttendanceStatus.excused:
        return 'excused';
      case ManualAttendanceStatus.late:
        return 'late';
    }
  }

  factory ManualAttendanceRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final lectureDate = _parseLectureDate(data);
    return ManualAttendanceRecord(
      recordId: doc.id,
      sessionId: (data['sessionId'] ?? '').toString(),
      sectionId: (data['sectionId'] ?? '').toString(),
      studentId: _safeInt(data['studentId']),
      studentName: (data['studentName'] ?? '').toString(),
      status: statusFromString((data['status'] ?? '').toString()),
      lectureDate: lectureDate,
      courseName: (data['courseName'] ?? '').toString(),
      sectionLabel: (data['section'] ?? '').toString(),
      lectureStartTime: (data['lectureStartTime'] ?? '').toString(),
      lectureEndTime: (data['lectureEndTime'] ?? '').toString(),
      attendanceTime: (data['attendanceTime'] ?? '').toString(),
    );
  }

  static DateTime _parseLectureDate(Map<String, dynamic> data) {
    final y = _safeInt(data['lectureYear']);
    final m = _safeInt(data['lectureMonth']);
    final d = _safeInt(data['lectureDay']);
    if (y > 0 && m > 0 && d > 0) {
      return DateTime(y, m, d);
    }

    final dateKey = (data['dateKey'] ?? '').toString().trim();
    if (dateKey.length == 8) {
      final yy = int.tryParse(dateKey.substring(0, 4)) ?? 0;
      final mm = int.tryParse(dateKey.substring(4, 6)) ?? 0;
      final dd = int.tryParse(dateKey.substring(6, 8)) ?? 0;
      if (yy > 0 && mm > 0 && dd > 0) {
        return DateTime(yy, mm, dd);
      }
    }

    final lectureTimestamp = data['lectureDate'];
    if (lectureTimestamp is Timestamp) {
      final ts = lectureTimestamp.toDate();
      return DateTime(ts.year, ts.month, ts.day);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
