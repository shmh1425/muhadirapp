import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/attendance/qr_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../lecturer_auth_service.dart';

class QrAttendanceService {
  QrAttendanceService._();
  static final QrAttendanceService instance = QrAttendanceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random.secure();

  static const String _sessionsCollection = 'qr_attendance_sessions';
  static const Duration defaultQrValidity = Duration(minutes: 2);

  static String buildSessionId({
    required String sectionId,
    required DateTime sessionDate,
    required String lectureStartTime,
  }) {
    final normalizedSection = sectionId.trim().replaceAll(RegExp(r'\s+'), '');
    final dateKey = _dateKey(sessionDate);
    final startKey = lectureStartTime.replaceAll(':', '');
    return '${normalizedSection}_${dateKey}_$startKey';
  }

  Future<QrAttendanceSession> createOrGetSessionForLecture({
    required LectureItem lecture,
    DateTime? lectureDate,
  }) async {
    final sectionId = (lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) {
      throw StateError(
        'Lecture sectionId is required to create QR attendance session.',
      );
    }

    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    if (lecturerId.isEmpty) {
      throw StateError('Lecturer ID is required to create QR session.');
    }

    final date = _normalizedDate(lectureDate ?? DateTime.now());
    final sessionId = buildSessionId(
      sectionId: sectionId,
      sessionDate: date,
      lectureStartTime: lecture.startTime,
    );

    final sessionRef = _firestore.collection(_sessionsCollection).doc(sessionId);
    final existing = await sessionRef.get();
    if (existing.exists && existing.data() != null) {
      return QrAttendanceSession.fromDocumentSnapshot(existing);
    }

    final now = DateTime.now();
    final tokenId = _generateTokenId();
    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'sectionId': sectionId,
      'courseCode': lecture.crn,
      'courseName': lecture.courseName,
      'section': lecture.section,
      'lecturerId': lecturerId,
      'lectureDate': Timestamp.fromDate(date),
      'lectureYear': date.year,
      'lectureMonth': date.month,
      'lectureDay': date.day,
      'lectureDayOfWeek': date.weekday,
      'lectureStartTime': lecture.startTime,
      'lectureEndTime': lecture.endTime,
      'dateKey': _dateKey(date),
      'attendanceMethod': 'qr',
      'isOpen': true,
      'generatedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(_calculateExpiresAt(now)),
      'tokenVersion': 1,
      'currentTokenId': tokenId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await sessionRef.set(payload, SetOptions(merge: true));
    final created = await sessionRef.get();
    return QrAttendanceSession.fromDocumentSnapshot(created);
  }

  Future<QrAttendanceSession> refreshSessionToken(
    String sessionId, {
    Duration validity = defaultQrValidity,
  }) async {
    final id = sessionId.trim();
    if (id.isEmpty) {
      throw StateError('sessionId is required to refresh QR token.');
    }

    final ref = _firestore.collection(_sessionsCollection).doc(id);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) {
      throw StateError('QR attendance session not found for id: $id');
    }

    final currentSession = QrAttendanceSession.fromDocumentSnapshot(doc);
    final now = DateTime.now();
    final newVersion = currentSession.tokenVersion + 1;
    final newToken = _generateTokenId();

    await ref.set({
      'currentTokenId': newToken,
      'tokenVersion': newVersion,
      'generatedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(_calculateExpiresAt(now, validity)),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final updated = await ref.get();
    return QrAttendanceSession.fromDocumentSnapshot(updated);
  }

  DateTime _calculateExpiresAt(DateTime generatedAt, [Duration? validity]) {
    return generatedAt.add(validity ?? defaultQrValidity);
  }

  String _generateTokenId({int length = 24}) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      final index = _random.nextInt(alphabet.length);
      buffer.write(alphabet[index]);
    }
    return buffer.toString();
  }

  static String _dateKey(DateTime value) {
    final d = _normalizedDate(value);
    return '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime _normalizedDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
