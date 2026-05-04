import 'package:cloud_firestore/cloud_firestore.dart';

class BluetoothAttendanceSession {
  const BluetoothAttendanceSession({
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
    this.attendanceMethod = 'bluetooth',
    required this.isOpen,
    this.sessionOpenedAt,
    this.openedAt,
    this.openedBy,
    this.closedAt,
    required this.bluetoothSessionToken,
    required this.tokenVersion,
    required this.generatedAt,
    required this.expiresAt,
    this.previousBluetoothSessionToken,
    this.previousBluetoothTokenExpiredAt,
    required this.advertisedServiceUuid,
    this.beaconId,
    required this.minRssi,
    required this.proximityPolicy,
    required this.attendanceCount,
    this.lastAttendanceAt,
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
  final DateTime? sessionOpenedAt;
  final DateTime? openedAt;
  final String? openedBy;
  final DateTime? closedAt;
  final String bluetoothSessionToken;
  final int tokenVersion;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final String? previousBluetoothSessionToken;
  final DateTime? previousBluetoothTokenExpiredAt;
  final String advertisedServiceUuid;
  final String? beaconId;
  final int minRssi;
  final String proximityPolicy;
  final int attendanceCount;
  final DateTime? lastAttendanceAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BluetoothAttendanceSession.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return BluetoothAttendanceSession._fromMap(doc.id, doc.data());
  }

  factory BluetoothAttendanceSession.fromDocumentSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists || doc.data() == null) {
      throw StateError('Bluetooth session document does not exist.');
    }
    return BluetoothAttendanceSession._fromMap(doc.id, doc.data()!);
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
      if (sessionOpenedAt != null)
        'sessionOpenedAt': Timestamp.fromDate(sessionOpenedAt!),
      if (openedAt != null) 'openedAt': Timestamp.fromDate(openedAt!),
      if (openedBy != null) 'openedBy': openedBy,
      if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
      'bluetoothSessionToken': bluetoothSessionToken,
      'tokenVersion': tokenVersion,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      if (previousBluetoothSessionToken != null)
        'previousBluetoothSessionToken': previousBluetoothSessionToken,
      if (previousBluetoothTokenExpiredAt != null)
        'previousBluetoothTokenExpiredAt': Timestamp.fromDate(
          previousBluetoothTokenExpiredAt!,
        ),
      'advertisedServiceUuid': advertisedServiceUuid,
      if (beaconId != null) 'beaconId': beaconId,
      'minRssi': minRssi,
      'proximityPolicy': proximityPolicy,
      'attendanceCount': attendanceCount,
      if (lastAttendanceAt != null)
        'lastAttendanceAt': Timestamp.fromDate(lastAttendanceAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  static BluetoothAttendanceSession _fromMap(
    String docId,
    Map<String, dynamic> data,
  ) {
    final lectureDate = _parseLectureDate(data);
    final generatedAt = _toDateTime(data['generatedAt']) ?? DateTime.now();
    final expiresAt =
        _toDateTime(data['expiresAt']) ??
        generatedAt.add(const Duration(seconds: 45));

    return BluetoothAttendanceSession(
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
      attendanceMethod: (data['attendanceMethod'] ?? 'bluetooth')
          .toString()
          .trim(),
      isOpen: data['isOpen'] == true,
      sessionOpenedAt: _toDateTime(data['sessionOpenedAt']),
      openedAt: _toDateTime(data['openedAt']),
      openedBy: _nullableTrimmedString(data['openedBy']),
      closedAt: _toDateTime(data['closedAt']),
      bluetoothSessionToken: (data['bluetoothSessionToken'] ?? '')
          .toString()
          .trim(),
      tokenVersion: _safeInt(data['tokenVersion'], fallback: 1),
      generatedAt: generatedAt,
      expiresAt: expiresAt,
      previousBluetoothSessionToken: _nullableTrimmedString(
        data['previousBluetoothSessionToken'],
      ),
      previousBluetoothTokenExpiredAt: _toDateTime(
        data['previousBluetoothTokenExpiredAt'],
      ),
      advertisedServiceUuid: (data['advertisedServiceUuid'] ?? '')
          .toString()
          .trim(),
      beaconId: _nullableTrimmedString(data['beaconId']),
      minRssi: _safeInt(data['minRssi'], fallback: -85),
      proximityPolicy: (data['proximityPolicy'] ?? 'rssi_threshold')
          .toString()
          .trim(),
      attendanceCount: _safeInt(data['attendanceCount']),
      lastAttendanceAt: _toDateTime(data['lastAttendanceAt']),
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
    return '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
