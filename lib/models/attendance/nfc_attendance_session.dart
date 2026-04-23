import 'package:cloud_firestore/cloud_firestore.dart';

class NfcAttendanceSession {
  const NfcAttendanceSession({
    required this.sessionId,
    required this.sectionId,
    required this.courseName,
    this.courseCode,
    required this.sectionLabel,
    required this.lectureStartTime,
    required this.lectureEndTime,
    required this.lectureDate,
    required this.lecturerId,
    required this.lecturerCardId,
    required this.isOpen,
    this.openedAt,
    this.closedAt,
  });

  final String sessionId;
  final String sectionId;
  final String courseName;
  final String? courseCode;
  final String sectionLabel;
  final String lectureStartTime;
  final String lectureEndTime;
  final DateTime lectureDate;
  final String lecturerId;
  final String lecturerCardId;
  final bool isOpen;
  final DateTime? openedAt;
  final DateTime? closedAt;

  factory NfcAttendanceSession.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return NfcAttendanceSession._fromMap(doc.id, doc.data());
  }

  factory NfcAttendanceSession.fromDocumentSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists || doc.data() == null) {
      throw StateError('NFC session document does not exist.');
    }
    return NfcAttendanceSession._fromMap(doc.id, doc.data()!);
  }

  static NfcAttendanceSession _fromMap(
    String docId,
    Map<String, dynamic> data,
  ) {
    final lectureDate = _parseLectureDate(data);
    return NfcAttendanceSession(
      sessionId: (data['sessionId'] ?? docId).toString().trim(),
      sectionId: (data['sectionId'] ?? '').toString().trim(),
      courseName: (data['courseName'] ?? '').toString().trim(),
      courseCode: (data['courseCode'] ?? '').toString().trim().isEmpty
          ? null
          : (data['courseCode'] ?? '').toString().trim(),
      sectionLabel: (data['section'] ?? '').toString().trim(),
      lectureStartTime: (data['lectureStartTime'] ?? '').toString().trim(),
      lectureEndTime: (data['lectureEndTime'] ?? '').toString().trim(),
      lectureDate: lectureDate,
      lecturerId: (data['lecturerId'] ?? '').toString().trim(),
      lecturerCardId: (data['lecturerCardId'] ?? '').toString().trim(),
      isOpen: data['isOpen'] == true,
      openedAt: _toDateTime(data['openedAt']),
      closedAt: _toDateTime(data['closedAt']),
    );
  }

  static DateTime _parseLectureDate(Map<String, dynamic> data) {
    final ts = data['lectureDate'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return DateTime(dt.year, dt.month, dt.day);
    }

    final y = _safeInt(data['lectureYear']);
    final m = _safeInt(data['lectureMonth']);
    final d = _safeInt(data['lectureDay']);
    if (y > 0 && m > 0 && d > 0) {
      return DateTime(y, m, d);
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
