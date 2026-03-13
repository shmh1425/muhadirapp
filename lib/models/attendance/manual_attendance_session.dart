import 'package:cloud_firestore/cloud_firestore.dart';

class ManualAttendanceSession {
  const ManualAttendanceSession({
    required this.sessionId,
    required this.sectionId,
    required this.courseName,
    required this.sectionLabel,
    required this.lectureStartTime,
    required this.lectureEndTime,
    required this.lectureDate,
    required this.dayOfWeek,
  });

  final String sessionId;
  final String sectionId;
  final String courseName;
  final String sectionLabel;
  final String lectureStartTime;
  final String lectureEndTime;
  final DateTime lectureDate;
  final int dayOfWeek;

  factory ManualAttendanceSession.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    DateTime lectureDate;
    final y = _safeInt(data['lectureYear']);
    final m = _safeInt(data['lectureMonth']);
    final d = _safeInt(data['lectureDay']);
    if (y > 0 && m > 0 && d > 0) {
      lectureDate = DateTime(y, m, d);
    } else {
      final dateKey = (data['dateKey'] ?? '').toString();
      if (dateKey.length == 8) {
        final yy = int.tryParse(dateKey.substring(0, 4)) ?? 0;
        final mm = int.tryParse(dateKey.substring(4, 6)) ?? 0;
        final dd = int.tryParse(dateKey.substring(6, 8)) ?? 0;
        if (yy > 0 && mm > 0 && dd > 0) {
          lectureDate = DateTime(yy, mm, dd);
        } else {
          final dateRaw = data['lectureDate'];
          lectureDate = dateRaw is Timestamp
              ? dateRaw.toDate()
              : DateTime.now();
        }
      } else {
        final dateRaw = data['lectureDate'];
        lectureDate = dateRaw is Timestamp ? dateRaw.toDate() : DateTime.now();
      }
    }
    final dayOfWeek = _safeInt(data['lectureDayOfWeek']);
    return ManualAttendanceSession(
      sessionId: (data['sessionId'] ?? doc.id).toString(),
      sectionId: (data['sectionId'] ?? '').toString(),
      courseName: (data['courseName'] ?? '').toString(),
      sectionLabel: (data['section'] ?? '').toString(),
      lectureStartTime: (data['lectureStartTime'] ?? '').toString(),
      lectureEndTime: (data['lectureEndTime'] ?? '').toString(),
      lectureDate: lectureDate,
      dayOfWeek: (dayOfWeek >= DateTime.monday && dayOfWeek <= DateTime.sunday)
          ? dayOfWeek
          : lectureDate.weekday,
    );
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
