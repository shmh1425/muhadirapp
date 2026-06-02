import 'package:cloud_firestore/cloud_firestore.dart';

class QrAttendanceSession {
  const QrAttendanceSession({
    required this.sessionId,
    required this.sectionId,
    required this.courseCode,
    required this.courseName,
    required this.section,
    required this.lecturerId,
    required this.lectureDate,
    required this.lectureYear,
    required this.lectureMonth,
    required this.lectureDay,
    required this.lectureDayOfWeek,
    required this.lectureStartTime,
    required this.lectureEndTime,
    required this.dateKey,
    this.attendanceMethod = 'qr',
    required this.isOpen,
    this.explicitSessionOpened = false,
    required this.generatedAt,
    required this.expiresAt,
    required this.tokenVersion,
    required this.currentTokenId,
    required this.numericCode,
    required this.numericCodeGeneratedAt,
    required this.numericCodeExpiresAt,
    required this.codeVersion,
    this.previousNumericCode,
    this.previousNumericCodeExpiredAt,
    this.sessionOpenedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String sessionId;
  final String sectionId;
  final String courseCode;
  final String courseName;
  final String section;
  final String lecturerId;
  final DateTime lectureDate;
  final int lectureYear;
  final int lectureMonth;
  final int lectureDay;
  final int lectureDayOfWeek;
  final String lectureStartTime;
  final String lectureEndTime;
  final String dateKey;
  final String attendanceMethod;
  final bool isOpen;
  final bool explicitSessionOpened;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final int tokenVersion;
  final String currentTokenId;
  final String numericCode;
  final DateTime numericCodeGeneratedAt;
  final DateTime numericCodeExpiresAt;
  final int codeVersion;
  final String? previousNumericCode;
  final DateTime? previousNumericCodeExpiredAt;
  final DateTime? sessionOpenedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory QrAttendanceSession.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return QrAttendanceSession._fromMap(doc.id, doc.data());
  }

  factory QrAttendanceSession.fromDocumentSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists || doc.data() == null) {
      throw StateError('QR session document does not exist.');
    }
    return QrAttendanceSession._fromMap(doc.id, doc.data()!);
  }

  QrAttendanceSession copyWith({
    String? sessionId,
    String? sectionId,
    String? courseCode,
    String? courseName,
    String? section,
    String? lecturerId,
    DateTime? lectureDate,
    int? lectureYear,
    int? lectureMonth,
    int? lectureDay,
    int? lectureDayOfWeek,
    String? lectureStartTime,
    String? lectureEndTime,
    String? dateKey,
    String? attendanceMethod,
    bool? isOpen,
    bool? explicitSessionOpened,
    DateTime? generatedAt,
    DateTime? expiresAt,
    int? tokenVersion,
    String? currentTokenId,
    String? numericCode,
    DateTime? numericCodeGeneratedAt,
    DateTime? numericCodeExpiresAt,
    int? codeVersion,
    String? previousNumericCode,
    DateTime? previousNumericCodeExpiredAt,
    DateTime? sessionOpenedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QrAttendanceSession(
      sessionId: sessionId ?? this.sessionId,
      sectionId: sectionId ?? this.sectionId,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      section: section ?? this.section,
      lecturerId: lecturerId ?? this.lecturerId,
      lectureDate: lectureDate ?? this.lectureDate,
      lectureYear: lectureYear ?? this.lectureYear,
      lectureMonth: lectureMonth ?? this.lectureMonth,
      lectureDay: lectureDay ?? this.lectureDay,
      lectureDayOfWeek: lectureDayOfWeek ?? this.lectureDayOfWeek,
      lectureStartTime: lectureStartTime ?? this.lectureStartTime,
      lectureEndTime: lectureEndTime ?? this.lectureEndTime,
      dateKey: dateKey ?? this.dateKey,
      attendanceMethod: attendanceMethod ?? this.attendanceMethod,
      isOpen: isOpen ?? this.isOpen,
      explicitSessionOpened:
          explicitSessionOpened ?? this.explicitSessionOpened,
      generatedAt: generatedAt ?? this.generatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      tokenVersion: tokenVersion ?? this.tokenVersion,
      currentTokenId: currentTokenId ?? this.currentTokenId,
      numericCode: numericCode ?? this.numericCode,
      numericCodeGeneratedAt:
          numericCodeGeneratedAt ?? this.numericCodeGeneratedAt,
      numericCodeExpiresAt: numericCodeExpiresAt ?? this.numericCodeExpiresAt,
      codeVersion: codeVersion ?? this.codeVersion,
      previousNumericCode: previousNumericCode ?? this.previousNumericCode,
      previousNumericCodeExpiredAt:
          previousNumericCodeExpiredAt ?? this.previousNumericCodeExpiredAt,
      sessionOpenedAt: sessionOpenedAt ?? this.sessionOpenedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'sectionId': sectionId,
      'courseCode': courseCode,
      'courseName': courseName,
      'section': section,
      'lecturerId': lecturerId,
      'lectureDate': Timestamp.fromDate(_normalizedDate(lectureDate)),
      'lectureYear': lectureYear,
      'lectureMonth': lectureMonth,
      'lectureDay': lectureDay,
      'lectureDayOfWeek': lectureDayOfWeek,
      'lectureStartTime': lectureStartTime,
      'lectureEndTime': lectureEndTime,
      'dateKey': dateKey,
      'attendanceMethod': attendanceMethod,
      'isOpen': isOpen,
      'explicitSessionOpened': explicitSessionOpened,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'tokenVersion': tokenVersion,
      'currentTokenId': currentTokenId,
      'numericCode': numericCode,
      'numericCodeGeneratedAt': Timestamp.fromDate(numericCodeGeneratedAt),
      'numericCodeExpiresAt': Timestamp.fromDate(numericCodeExpiresAt),
      'codeVersion': codeVersion,
      if (previousNumericCode != null)
        'previousNumericCode': previousNumericCode,
      if (previousNumericCodeExpiredAt != null)
        'previousNumericCodeExpiredAt': Timestamp.fromDate(
          previousNumericCodeExpiredAt!,
        ),
      if (sessionOpenedAt != null)
        'sessionOpenedAt': Timestamp.fromDate(sessionOpenedAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  static QrAttendanceSession _fromMap(String docId, Map<String, dynamic> data) {
    final lectureDate = _parseLectureDate(data);
    final generatedAt = _toDateTime(data['generatedAt']) ?? DateTime.now();
    final expiresAt =
        _toDateTime(data['expiresAt']) ??
        generatedAt.add(const Duration(minutes: 2));
    final numericCodeGeneratedAt =
        _toDateTime(data['numericCodeGeneratedAt']) ?? generatedAt;
    final numericCodeExpiresAt =
        _toDateTime(data['numericCodeExpiresAt']) ??
        numericCodeGeneratedAt.add(const Duration(seconds: 45));

    return QrAttendanceSession(
      sessionId: (data['sessionId'] ?? docId).toString().trim(),
      sectionId: (data['sectionId'] ?? '').toString().trim(),
      courseCode: (data['courseCode'] ?? '').toString().trim(),
      courseName: (data['courseName'] ?? '').toString().trim(),
      section: (data['section'] ?? '').toString().trim(),
      lecturerId: (data['lecturerId'] ?? '').toString().trim(),
      lectureDate: lectureDate,
      lectureYear: _safeInt(data['lectureYear'], fallback: lectureDate.year),
      lectureMonth: _safeInt(data['lectureMonth'], fallback: lectureDate.month),
      lectureDay: _safeInt(data['lectureDay'], fallback: lectureDate.day),
      lectureDayOfWeek: _safeInt(
        data['lectureDayOfWeek'],
        fallback: lectureDate.weekday,
      ),
      lectureStartTime: (data['lectureStartTime'] ?? '').toString().trim(),
      lectureEndTime: (data['lectureEndTime'] ?? '').toString().trim(),
      dateKey: (data['dateKey'] ?? _dateKey(lectureDate)).toString().trim(),
      attendanceMethod: (data['attendanceMethod'] ?? 'qr').toString().trim(),
      isOpen: data['isOpen'] == true,
      explicitSessionOpened: data['explicitSessionOpened'] == true,
      generatedAt: generatedAt,
      expiresAt: expiresAt,
      tokenVersion: _safeInt(data['tokenVersion'], fallback: 1),
      currentTokenId: (data['currentTokenId'] ?? '').toString().trim(),
      numericCode: (data['numericCode'] ?? '').toString().trim(),
      numericCodeGeneratedAt: numericCodeGeneratedAt,
      numericCodeExpiresAt: numericCodeExpiresAt,
      codeVersion: _safeInt(data['codeVersion'], fallback: 1),
      previousNumericCode: _nullableTrimmedString(data['previousNumericCode']),
      previousNumericCodeExpiredAt: _toDateTime(
        data['previousNumericCodeExpiredAt'],
      ),
      sessionOpenedAt: _toDateTime(data['sessionOpenedAt']),
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  static DateTime _parseLectureDate(Map<String, dynamic> data) {
    final dateValue = _toDateTime(data['lectureDate']);
    if (dateValue != null) {
      return _normalizedDate(dateValue);
    }

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

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static int _safeInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  static String? _nullableTrimmedString(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime _normalizedDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _dateKey(DateTime value) {
    final d = _normalizedDate(value);
    return '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }
}
