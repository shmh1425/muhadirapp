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
    this.termId,
    this.officialWeekNumber,
    this.effectiveWeekNumber,
    this.countInAttendance = true,
    this.attendanceFinalized = true,
    this.courseCode,
    this.lecturerId,
    this.sessionOpenedAt,
  });

  final String sessionId;
  final String sectionId;
  final String courseName;
  final String sectionLabel;
  /// From session doc `courseCode` (e.g. CRN) when present.
  final String? courseCode;
  /// From session doc when present.
  final String? lecturerId;
  final DateTime? sessionOpenedAt;
  final String lectureStartTime;
  final String lectureEndTime;
  final DateTime lectureDate;
  final int dayOfWeek;
  /// When set, session is linked to an academic term for week-based attendance.
  final String? termId;
  final int? officialWeekNumber;
  final int? effectiveWeekNumber;
  /// True only for instructional weeks; break weeks must not count in attendance.
  final bool countInAttendance;
  /// When true, session is included in totalCountableSessions for absence calculation.
  final bool attendanceFinalized;

  factory ManualAttendanceSession.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ManualAttendanceSession._fromMap(doc.id, doc.data());
  }

  factory ManualAttendanceSession.fromDocumentSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists || doc.data() == null) {
      throw StateError('Session document does not exist');
    }
    return ManualAttendanceSession._fromMap(doc.id, doc.data()!);
  }

  static ManualAttendanceSession _fromMap(String docId, Map<String, dynamic> data) {
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
    final officialWeek = _optionalInt(data['officialWeekNumber']);
    final effectiveWeek = _optionalInt(data['effectiveWeekNumber']);
    final cc = (data['courseCode'] ?? '').toString().trim();
    final lid = (data['lecturerId'] ?? '').toString().trim();
    final sessionOpenedAt = _toDateTime(data['sessionOpenedAt'] ?? data['openedAt']);
    return ManualAttendanceSession(
      sessionId: (data['sessionId'] ?? docId).toString(),
      sectionId: (data['sectionId'] ?? '').toString(),
      courseName: (data['courseName'] ?? '').toString(),
      sectionLabel: (data['section'] ?? '').toString(),
      lectureStartTime: (data['lectureStartTime'] ?? '').toString(),
      lectureEndTime: (data['lectureEndTime'] ?? '').toString(),
      lectureDate: lectureDate,
      dayOfWeek: (dayOfWeek >= DateTime.monday && dayOfWeek <= DateTime.sunday)
          ? dayOfWeek
          : lectureDate.weekday,
      termId: (data['termId'] ?? '').toString().trim().isEmpty ? null : (data['termId'] ?? '').toString(),
      officialWeekNumber: officialWeek,
      effectiveWeekNumber: effectiveWeek,
      countInAttendance: data['countInAttendance'] != false,
      attendanceFinalized: data['attendanceFinalized'] != false,
      courseCode: cc.isEmpty ? null : cc,
      lecturerId: lid.isEmpty ? null : lid,
      sessionOpenedAt: sessionOpenedAt,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static int? _optionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
