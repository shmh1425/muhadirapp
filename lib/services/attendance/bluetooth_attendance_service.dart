import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/attendance/bluetooth_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../lecturer_auth_service.dart';
import 'manual_attendance_service.dart';

enum BluetoothAttendanceErrorCode {
  invalidInput,
  missingLecturerSession,
  sessionNotFound,
  unknown,
}

class BluetoothAttendanceException implements Exception {
  BluetoothAttendanceException({required this.code, required this.message});

  final BluetoothAttendanceErrorCode code;
  final String message;

  @override
  String toString() => message;
}

class BluetoothAttendanceService {
  BluetoothAttendanceService._();
  static final BluetoothAttendanceService instance =
      BluetoothAttendanceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random.secure();

  static const String sessionsCollection = 'bluetooth_attendance_sessions';
  static const String recordsCollection = 'bluetooth_attendance_records';
  static const Duration defaultTokenValidity = Duration(seconds: 45);
  static const Duration manualSessionOpenWindow = Duration(minutes: 15);
  static const int defaultMinRssi = -85;
  static const String defaultProximityPolicy = 'rssi_threshold';

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

  Future<BluetoothAttendanceSession> createOrGetSessionForLecture({
    required LectureItem lecture,
    DateTime? lectureDate,
  }) {
    return openSessionForLecture(lecture: lecture, lectureDate: lectureDate);
  }

  Future<BluetoothAttendanceSession> openSessionForLecture({
    required LectureItem lecture,
    DateTime? lectureDate,
  }) async {
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    if (lecturerId.isEmpty) {
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.missingLecturerSession,
        message: 'Lecturer session is missing. Please log in again.',
      );
    }

    final sectionId = (lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) {
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.invalidInput,
        message: 'Lecture sectionId is required to open Bluetooth session.',
      );
    }

    if (lecture.startTime.trim().isEmpty || lecture.endTime.trim().isEmpty) {
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.invalidInput,
        message: 'Lecture start and end time are required.',
      );
    }

    final date = _normalizedDate(lectureDate ?? DateTime.now());
    final sessionId = await ManualAttendanceService.instance
        .prepareSessionForLecture(lecture: lecture, sessionDate: date);
    final sessionRef = _firestore.collection(sessionsCollection).doc(sessionId);
    final now = DateTime.now();

    final existing = await sessionRef.get();
    if (existing.exists && existing.data() != null) {
      final session = BluetoothAttendanceSession.fromDocumentSnapshot(existing);
      await _closeSessionIfExpired(session);
      if (session.bluetoothSessionToken.isEmpty ||
          now.isAfter(session.expiresAt)) {
        await refreshSessionToken(session.sessionId);
      }

      _debugSessionWrite(
        action: 'reopen',
        lecturerId: lecturerId,
        sectionId: sectionId,
        sessionId: sessionId,
      );
      await _markSessionOpen(sessionRef, lecturerId);

      final reopened = await sessionRef.get();
      return BluetoothAttendanceSession.fromDocumentSnapshot(reopened);
    }

    final token = _generateSessionToken();
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
      'attendanceMethod': 'bluetooth',
      'isOpen': true,
      'sessionOpenedAt': Timestamp.fromDate(now),
      'openedAt': FieldValue.serverTimestamp(),
      'openedBy': lecturerId,
      'bluetoothSessionToken': token,
      'tokenVersion': 1,
      'generatedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(_calculateExpiresAt(now)),
      'advertisedServiceUuid': _generateUuid(),
      'beaconId': '',
      'minRssi': defaultMinRssi,
      'proximityPolicy': defaultProximityPolicy,
      'attendanceCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    _debugSessionWrite(
      action: 'create',
      lecturerId: lecturerId,
      sectionId: sectionId,
      sessionId: sessionId,
    );
    await sessionRef.set(payload, SetOptions(merge: true));
    final created = await sessionRef.get();
    return BluetoothAttendanceSession.fromDocumentSnapshot(created);
  }

  Future<BluetoothAttendanceSession> refreshSessionToken(
    String sessionId, {
    Duration validity = defaultTokenValidity,
  }) async {
    final id = sessionId.trim();
    if (id.isEmpty) {
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.invalidInput,
        message: 'sessionId is required to refresh Bluetooth token.',
      );
    }

    final ref = _firestore.collection(sessionsCollection).doc(id);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) {
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.sessionNotFound,
        message: 'Bluetooth attendance session not found for id: $id',
      );
    }

    final currentSession = BluetoothAttendanceSession.fromDocumentSnapshot(doc);
    if (currentSession.isOpen &&
        !_isWithinManualOpenWindow(currentSession, DateTime.now())) {
      await closeSession(currentSession.sessionId);
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.sessionNotFound,
        message: 'Bluetooth session window ended. Reopen the session.',
      );
    }
    final now = DateTime.now();
    final newToken = _generateSessionToken(
      excluding: currentSession.bluetoothSessionToken,
    );

    _debugSessionWrite(
      action: 'refresh_token',
      lecturerId: currentSession.lecturerId,
      sectionId: currentSession.sectionId,
      sessionId: currentSession.sessionId,
    );
    await ref.set({
      'bluetoothSessionToken': newToken,
      'tokenVersion': currentSession.tokenVersion + 1,
      'generatedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(_calculateExpiresAt(now, validity)),
      if (currentSession.bluetoothSessionToken.isNotEmpty)
        'previousBluetoothSessionToken': currentSession.bluetoothSessionToken,
      if (currentSession.bluetoothSessionToken.isNotEmpty)
        'previousBluetoothTokenExpiredAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final updated = await ref.get();
    return BluetoothAttendanceSession.fromDocumentSnapshot(updated);
  }

  Future<void> _markSessionOpen(
    DocumentReference<Map<String, dynamic>> sessionRef,
    String lecturerId,
  ) {
    final now = DateTime.now();
    return sessionRef.set({
      'isOpen': true,
      'openedAt': FieldValue.serverTimestamp(),
      'sessionOpenedAt': Timestamp.fromDate(now),
      'openedBy': lecturerId,
      'closedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> closeSession(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return;

    final existing = await _firestore
        .collection(sessionsCollection)
        .doc(id)
        .get();
    final existingSession = existing.exists && existing.data() != null
        ? BluetoothAttendanceSession.fromDocumentSnapshot(existing)
        : null;
    _debugSessionWrite(
      action: 'close',
      lecturerId:
          existingSession?.lecturerId ??
          (LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ??
              ''),
      sectionId: existingSession?.sectionId ?? '',
      sessionId: id,
    );
    await _firestore.collection(sessionsCollection).doc(id).set({
      'isOpen': false,
      'closedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await ManualAttendanceService.instance.finalizeSessionPendingAsAbsent(id);
  }

  Stream<BluetoothAttendanceSession?> watchSession(String sessionId) {
    final id = sessionId.trim();
    if (id.isEmpty) {
      return const Stream<BluetoothAttendanceSession?>.empty();
    }

    return _firestore.collection(sessionsCollection).doc(id).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      final session = BluetoothAttendanceSession.fromDocumentSnapshot(snapshot);
      if (session.isOpen &&
          !_isWithinManualOpenWindow(session, DateTime.now())) {
        unawaited(_closeSessionIfExpired(session));
      }
      return session;
    });
  }

  Future<BluetoothAttendanceSession?> getSessionById(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return null;

    final doc = await _firestore.collection(sessionsCollection).doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    final session = BluetoothAttendanceSession.fromDocumentSnapshot(doc);
    if (session.isOpen && !_isWithinManualOpenWindow(session, DateTime.now())) {
      await _closeSessionIfExpired(session);
      final refreshed = await _firestore
          .collection(sessionsCollection)
          .doc(id)
          .get();
      if (!refreshed.exists || refreshed.data() == null) return null;
      return BluetoothAttendanceSession.fromDocumentSnapshot(refreshed);
    }
    return session;
  }

  DateTime _calculateExpiresAt(DateTime generatedAt, [Duration? validity]) {
    return generatedAt.add(validity ?? defaultTokenValidity);
  }

  void _debugSessionWrite({
    required String action,
    required String lecturerId,
    required String sectionId,
    required String sessionId,
  }) {
    if (!kDebugMode) return;
    final authUser = FirebaseAuth.instance.currentUser;
    debugPrint(
      '[BluetoothAttendance] action=$action '
      'authUid=${authUser?.uid ?? ''} '
      'authEmail=${authUser?.email ?? ''} '
      'lecturerId=$lecturerId '
      'sectionId=$sectionId '
      'sessionId=$sessionId '
      'path=$sessionsCollection/$sessionId',
    );
  }

  String _generateSessionToken({int length = 24, String? excluding}) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    String token;
    do {
      final buffer = StringBuffer();
      for (int i = 0; i < length; i++) {
        buffer.write(alphabet[_random.nextInt(alphabet.length)]);
      }
      token = buffer.toString();
    } while (excluding != null && token == excluding);
    return token;
  }

  String _generateUuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static DateTime _normalizedDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _dateKey(DateTime value) {
    final d = _normalizedDate(value);
    return '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
  }

  bool _isWithinManualOpenWindow(
    BluetoothAttendanceSession session,
    DateTime now,
  ) {
    final openedAt = session.openedAt ?? session.sessionOpenedAt;
    if (openedAt == null) return true;
    final closeAt = openedAt.add(manualSessionOpenWindow);
    return now.isBefore(closeAt);
  }

  Future<void> _closeSessionIfExpired(
    BluetoothAttendanceSession session,
  ) async {
    final now = DateTime.now();
    if (!session.isOpen || _isWithinManualOpenWindow(session, now)) {
      return;
    }
    await closeSession(session.sessionId);
  }
}
