import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../models/attendance/qr_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../lecturer_auth_service.dart';
import '../student_auth_service.dart';
import 'attendance_status_policy.dart';
import 'manual_attendance_service.dart';

enum QrAttendanceErrorCode {
  invalidQrPayload,
  missingStudentSession,
  sessionNotFound,
  sessionClosed,
  tokenMismatch,
  qrExpired,
  invalidNumericCode,
  numericCodeExpired,
  attendanceWindowClosed,
  studentNotEnrolled,
  alreadyMarked,
  permissionDenied,
  unknown,
}

class QrAttendanceException implements Exception {
  QrAttendanceException({required this.code, required this.message});

  final QrAttendanceErrorCode code;
  final String message;

  @override
  String toString() => message;
}

class QrAttendanceSubmissionResult {
  const QrAttendanceSubmissionResult({
    required this.success,
    required this.message,
    required this.session,
    required this.recordId,
    required this.status,
    required this.qrAuditStored,
  });

  final bool success;
  final String message;
  final QrAttendanceSession session;
  final String recordId;
  final String status;
  final bool qrAuditStored;
}

class QrAttendanceService {
  QrAttendanceService._();
  static final QrAttendanceService instance = QrAttendanceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random.secure();

  static const String _sessionsCollection = 'qr_attendance_sessions';
  static const String _recordsCollection = 'qr_attendance_records';
  static const String _manualSessionsCollection = 'manual_attendance_sessions';
  static const String _manualRecordsCollection = 'manual_attendance_records';
  static const String _enrollmentsCollection = 'student_section_enrollments';
  static const Duration defaultQrValidity = Duration(seconds: 30);
  static const Duration numericCodeValidity = Duration(seconds: 30);

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

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
    await ManualAttendanceService.instance.prepareSessionForLecture(
      lecture: lecture,
      sessionDate: date,
    );
    final sessionId = buildSessionId(
      sectionId: sectionId,
      sessionDate: date,
      lectureStartTime: lecture.startTime,
    );

    final sessionRef = _firestore
        .collection(_sessionsCollection)
        .doc(sessionId);
    final existing = await sessionRef.get();
    if (existing.exists && existing.data() != null) {
      final session = QrAttendanceSession.fromDocumentSnapshot(existing);
      final now = DateTime.now();
      if (!session.explicitSessionOpened) {
        await sessionRef.set({
          'isOpen': true,
          ManualAttendanceService.explicitSessionOpenedField: true,
          'sessionOpenedAt': Timestamp.fromDate(now),
          'explicitSessionOpenedAt': Timestamp.fromDate(now),
          'explicitSessionOpenedBy': lecturerId,
          'lectureEndTime': lecture.endTime,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return refreshSessionToken(session.sessionId);
      }
      if (session.lectureEndTime.trim() != lecture.endTime.trim()) {
        await sessionRef.set({
          'lectureEndTime': lecture.endTime,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return refreshSessionToken(session.sessionId);
      }
      if (session.numericCode.isEmpty ||
          now.isAfter(session.numericCodeExpiresAt) ||
          now.isAfter(session.expiresAt)) {
        return refreshSessionToken(session.sessionId);
      }
      return session;
    }

    final now = DateTime.now();
    final tokenId = _generateTokenId();
    final numericCode = _generateNumericCode();
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
      ManualAttendanceService.explicitSessionOpenedField: true,
      'sessionOpenedAt': Timestamp.fromDate(now),
      'explicitSessionOpenedAt': Timestamp.fromDate(now),
      'explicitSessionOpenedBy': lecturerId,
      'generatedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(_calculateExpiresAt(now)),
      'tokenVersion': 1,
      'currentTokenId': tokenId,
      'numericCode': numericCode,
      'numericCodeGeneratedAt': Timestamp.fromDate(now),
      'numericCodeExpiresAt': Timestamp.fromDate(now.add(numericCodeValidity)),
      'codeVersion': 1,
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
    final newNumericCode = _generateNumericCode(
      excluding: currentSession.numericCode,
    );

    await ref.set({
      'currentTokenId': newToken,
      'tokenVersion': newVersion,
      'generatedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(_calculateExpiresAt(now, validity)),
      'numericCode': newNumericCode,
      'numericCodeGeneratedAt': Timestamp.fromDate(now),
      'numericCodeExpiresAt': Timestamp.fromDate(now.add(numericCodeValidity)),
      'codeVersion': currentSession.codeVersion + 1,
      if (currentSession.numericCode.isNotEmpty)
        'previousNumericCode': currentSession.numericCode,
      if (currentSession.numericCode.isNotEmpty)
        'previousNumericCodeExpiredAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final updated = await ref.get();
    return QrAttendanceSession.fromDocumentSnapshot(updated);
  }

  Future<QrAttendanceSubmissionResult> submitAttendanceFromNumericCode(
    String code, {
    DateTime? currentTime,
  }) async {
    final normalizedCode = code.replaceAll(RegExp(r'\D'), '').trim();
    if (normalizedCode.isEmpty) {
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.invalidNumericCode,
        message: 'رمز الحضور مطلوب',
      );
    }

    final now = currentTime ?? DateTime.now();
    final currentMatches = await _firestore
        .collection(_sessionsCollection)
        .where('numericCode', isEqualTo: normalizedCode)
        .limit(10)
        .get();

    QrAttendanceSession? closedMatch;
    QrAttendanceSession? expiredMatch;
    QrAttendanceSession? usableMatch;

    for (final doc in currentMatches.docs) {
      final session = QrAttendanceSession.fromDocumentSnapshot(doc);
      if (!session.isOpen) {
        closedMatch ??= session;
        continue;
      }
      if (now.isAfter(session.numericCodeExpiresAt) ||
          now.isAfter(session.expiresAt)) {
        expiredMatch ??= session;
        continue;
      }
      usableMatch ??= session;
    }

    if (usableMatch != null) {
      return submitAttendanceFromQrPayload(<String, dynamic>{
        'sessionId': usableMatch.sessionId,
        'sectionId': usableMatch.sectionId,
        'tokenId': usableMatch.currentTokenId,
        'tokenVersion': usableMatch.tokenVersion,
        'expiresAt': usableMatch.expiresAt.toUtc().toIso8601String(),
      }, currentTime: now);
    }

    if (closedMatch != null) {
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.sessionClosed,
        message: 'تم إغلاق الجلسة',
      );
    }

    if (expiredMatch != null ||
        await _matchesPreviousNumericCode(normalizedCode)) {
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.numericCodeExpired,
        message: 'انتهت صلاحية الرمز',
      );
    }

    throw QrAttendanceException(
      code: QrAttendanceErrorCode.invalidNumericCode,
      message: 'الرمز غير صحيح',
    );
  }

  Future<QrAttendanceSession?> getSessionById(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return null;

    final doc = await _firestore.collection(_sessionsCollection).doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return QrAttendanceSession.fromDocumentSnapshot(doc);
  }

  Future<QrAttendanceSubmissionResult> submitAttendanceFromQrPayload(
    Map<String, dynamic> payload, {
    DateTime? currentTime,
  }) async {
    final student = StudentAuthService.instance.currentStudent;
    if (student == null || student.studentId <= 0) {
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.missingStudentSession,
        message: 'انتهت جلسة الطالب. سجلي الدخول من جديد.',
      );
    }

    final sessionId = (payload['sessionId'] ?? '').toString().trim();
    final sectionId = (payload['sectionId'] ?? '').toString().trim();
    final tokenId = (payload['tokenId'] ?? '').toString().trim();
    final expiresAtRaw = (payload['expiresAt'] ?? '').toString().trim();
    final tokenVersion = _safeInt(payload['tokenVersion']);

    _debugLog(
      'QR_SCAN_PAYLOAD_PARSED sessionId=$sessionId sectionId=$sectionId',
    );

    if (sessionId.isEmpty ||
        sectionId.isEmpty ||
        tokenId.isEmpty ||
        expiresAtRaw.isEmpty ||
        tokenVersion <= 0) {
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.invalidQrPayload,
        message: 'رمز QR غير صالح. الرجاء مسح رمز التحضير من شاشة المحاضر.',
      );
    }

    final scannedExpiresAt = DateTime.tryParse(expiresAtRaw)?.toLocal();
    if (scannedExpiresAt == null) {
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.invalidQrPayload,
        message: 'رمز QR غير صالح. الرجاء مسح رمز التحضير من شاشة المحاضر.',
      );
    }

    _debugLog('QR_SESSION_FETCH_START sessionId=$sessionId');
    final session = await getSessionById(sessionId);
    if (session == null) {
      _debugLog('QR_SUBMIT_FAILED reason=session_not_found');
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.sessionNotFound,
        message: 'تعذر العثور على جلسة التحضير الخاصة بهذا الرمز.',
      );
    }
    _debugLog(
      'QR_SESSION_FETCH_SUCCESS isOpen=${session.isOpen} expiresAt=${session.expiresAt.toIso8601String()}',
    );

    final now = currentTime ?? DateTime.now();
    if (!session.isOpen || !session.explicitSessionOpened) {
      _debugLog('QR_SUBMIT_FAILED reason=session_closed');
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.sessionClosed,
        message: 'تم إغلاق جلسة التحضير لهذه المحاضرة.',
      );
    }

    if (session.sectionId != sectionId ||
        session.currentTokenId != tokenId ||
        session.tokenVersion != tokenVersion) {
      _debugLog('QR_SUBMIT_FAILED reason=token_mismatch');
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.tokenMismatch,
        message: 'رمز QR لم يعد صالحاً. الرجاء طلب تحديث الرمز من المحاضر.',
      );
    }

    if (now.isAfter(session.expiresAt) || now.isAfter(scannedExpiresAt)) {
      _debugLog('QR_SUBMIT_FAILED reason=qr_expired');
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.qrExpired,
        message: 'انتهت صلاحية رمز QR. الرجاء مسح رمز جديد من شاشة المحاضر.',
      );
    }

    final today = _normalizedDate(now);
    if (_normalizedDate(session.lectureDate) != today ||
        !_isSessionActive(session, now)) {
      _debugLog('QR_SUBMIT_FAILED reason=attendance_window_closed');
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.attendanceWindowClosed,
        message: 'نافذة التحضير لهذه المحاضرة غير متاحة حالياً.',
      );
    }

    _debugLog('QR_STUDENT_RESOLVED studentId=${student.studentId}');
    _debugLog(
      'QR_ENROLLMENT_CHECK_START sectionId=${session.sectionId} studentId=${student.studentId}',
    );

    final enrollmentSnap = await _firestore
        .collection(_enrollmentsCollection)
        .where('sectionId', isEqualTo: session.sectionId)
        .where('studentId', isEqualTo: student.studentId)
        .limit(1)
        .get();

    if (enrollmentSnap.docs.isEmpty ||
        enrollmentSnap.docs.first.data()['isActive'] == false) {
      _debugLog('QR_ENROLLMENT_CHECK_FAILED');
      _debugLog('QR_SUBMIT_FAILED reason=student_not_enrolled');
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.studentNotEnrolled,
        message: 'أنتِ غير مسجلة في هذه الشعبة.',
      );
    }
    _debugLog('QR_ENROLLMENT_CHECK_SUCCESS');

    final enrollmentData = enrollmentSnap.docs.first.data();
    final studentName = student.displayName.trim().isNotEmpty
        ? student.displayName.trim()
        : (enrollmentData['studentName'] ?? '').toString().trim();
    final studentEmail = student.email.trim().isNotEmpty
        ? student.email.trim()
        : (enrollmentData['studentEmail'] ?? '').toString().trim();
    final studentDocId = (enrollmentData['studentDocId'] ?? '')
        .toString()
        .trim();
    final recordId = '${session.sessionId}_${student.studentId}';
    final status = ManualAttendanceRecord.statusToString(
      AttendanceStatusPolicy.calculateCheckInStatus(
        sessionOpenedAt:
            session.sessionOpenedAt ??
            AttendanceStatusPolicy.combineDateAndTime(
              session.lectureDate,
              session.lectureStartTime,
            ),
        lectureStartTime: session.lectureStartTime,
        lectureEndTime: session.lectureEndTime,
        lectureDate: session.lectureDate,
        checkInTime: now,
      ),
    );
    final attendanceTime = _hhmm(now);

    _debugLog('QR_DUPLICATE_CHECK_START recordId=$recordId');
    final qrRecordRef = _firestore.collection(_recordsCollection).doc(recordId);
    final manualRecordRef = _firestore
        .collection(_manualRecordsCollection)
        .doc(recordId);
    final manualSessionRef = _firestore
        .collection(_manualSessionsCollection)
        .doc(session.sessionId);

    bool existsQrRecord = false;
    bool existsManualRecord = false;

    try {
      _debugLog('QR_DUPLICATE_QR_READ_START');
      final qrRecordSnap = await qrRecordRef.get();
      existsQrRecord = qrRecordSnap.exists;
      _debugLog('QR_DUPLICATE_QR_READ_SUCCESS exists=$existsQrRecord');
    } on FirebaseException catch (e) {
      _debugLog('QR_DUPLICATE_QR_READ_FAILED errorCode=${e.code}');
      if (e.code != 'permission-denied') {
        _debugLog('QR_SUBMIT_FAILED reason=duplicate_qr_read_${e.code}');
        throw QrAttendanceException(
          code: QrAttendanceErrorCode.unknown,
          message: 'تعذر التحقق من سجل QR حالياً. حاولي مرة أخرى.',
        );
      }
    } catch (_) {
      _debugLog('QR_DUPLICATE_QR_READ_FAILED errorCode=unknown');
      _debugLog('QR_SUBMIT_FAILED reason=duplicate_qr_read_unknown');
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.unknown,
        message: 'تعذر التحقق من سجل QR حالياً. حاولي مرة أخرى.',
      );
    }

    try {
      _debugLog('QR_DUPLICATE_MANUAL_READ_START');
      final manualRecordSnap = await manualRecordRef.get();
      existsManualRecord = manualRecordSnap.exists;
      _debugLog('QR_DUPLICATE_MANUAL_READ_SUCCESS exists=$existsManualRecord');
    } on FirebaseException catch (e) {
      _debugLog('QR_DUPLICATE_MANUAL_READ_FAILED errorCode=${e.code}');
      _debugLog('QR_SUBMIT_FAILED reason=duplicate_manual_read_${e.code}');
      if (e.code == 'permission-denied') {
        throw QrAttendanceException(
          code: QrAttendanceErrorCode.permissionDenied,
          message:
              'تعذر التحقق من كشف الحضور بسبب صلاحيات النظام. يرجى إبلاغ الدعم.',
        );
      }
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.unknown,
        message: 'تعذر التحقق من كشف الحضور حالياً. حاولي مرة أخرى.',
      );
    } catch (_) {
      _debugLog('QR_DUPLICATE_MANUAL_READ_FAILED errorCode=unknown');
      _debugLog('QR_SUBMIT_FAILED reason=duplicate_manual_read_unknown');
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.unknown,
        message: 'تعذر التحقق من كشف الحضور حالياً. حاولي مرة أخرى.',
      );
    }

    _debugLog(
      'QR_DUPLICATE_CHECK_RESULT existsQr=$existsQrRecord existsManual=$existsManualRecord',
    );

    try {
      _debugLog('QR_MANUAL_RECORD_WRITE_START recordId=$recordId');
      await _firestore.runTransaction((transaction) async {
        final existingManualRecord = await transaction.get(manualRecordRef);
        if (existingManualRecord.exists) {
          final existingData =
              existingManualRecord.data() ?? <String, dynamic>{};
          final existingStatus = (existingData['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (existingStatus == 'present' || existingStatus == 'late') {
            throw QrAttendanceException(
              code: QrAttendanceErrorCode.alreadyMarked,
              message: 'تم تسجيل حضورك مسبقاً لهذه المحاضرة.',
            );
          }
        }

        final manualPayload = <String, dynamic>{
          'recordId': recordId,
          'sessionId': session.sessionId,
          'sectionId': session.sectionId,
          'studentId': student.studentId,
          'studentDocId': studentDocId,
          'studentName': studentName,
          'studentEmail': studentEmail,
          'courseName': session.courseName,
          'courseCode': session.courseCode,
          'section': session.section,
          'lectureDate': Timestamp.fromDate(session.lectureDate),
          'lectureYear': session.lectureYear,
          'lectureMonth': session.lectureMonth,
          'lectureDay': session.lectureDay,
          'lectureDayOfWeek': session.lectureDayOfWeek,
          'dateKey': session.dateKey,
          'lectureStartTime': session.lectureStartTime,
          'lectureEndTime': session.lectureEndTime,
          'attendanceTime': attendanceTime,
          'status': status,
          'attendanceMethod': 'qr',
          'updatedAt': FieldValue.serverTimestamp(),
          'scannedAt': FieldValue.serverTimestamp(),
        };

        if (!existingManualRecord.exists) {
          manualPayload['createdAt'] = FieldValue.serverTimestamp();
        }

        transaction.set(
          manualRecordRef,
          manualPayload,
          SetOptions(merge: true),
        );

        transaction.set(manualSessionRef, {
          'sessionId': session.sessionId,
          'sectionId': session.sectionId,
          'courseName': session.courseName,
          'courseCode': session.courseCode,
          'section': session.section,
          'lectureDate': Timestamp.fromDate(session.lectureDate),
          'lectureYear': session.lectureYear,
          'lectureMonth': session.lectureMonth,
          'lectureDay': session.lectureDay,
          'lectureDayOfWeek': session.lectureDayOfWeek,
          'dateKey': session.dateKey,
          'lectureStartTime': session.lectureStartTime,
          'lectureEndTime': session.lectureEndTime,
          'sessionOpenedAt': Timestamp.fromDate(
            session.sessionOpenedAt ??
                AttendanceStatusPolicy.combineDateAndTime(
                  session.lectureDate,
                  session.lectureStartTime,
                ),
          ),
          'attendanceMethod': 'qr',
          ManualAttendanceService.explicitSessionOpenedField: true,
          'explicitSessionOpenedBy': session.lecturerId,
          'lecturerId': session.lecturerId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
      _debugLog('QR_MANUAL_RECORD_WRITE_SUCCESS');
    } on QrAttendanceException {
      _debugLog(
        'QR_MANUAL_RECORD_WRITE_FAILED errorCode=duplicate_or_validation',
      );
      rethrow;
    } on FirebaseException catch (e) {
      _debugLog('QR_MANUAL_RECORD_WRITE_FAILED errorCode=${e.code}');
      _debugLog('QR_SUBMIT_FAILED reason=manual_write_${e.code}');
      if (e.code == 'permission-denied') {
        throw QrAttendanceException(
          code: QrAttendanceErrorCode.permissionDenied,
          message: 'تعذر تسجيل الحضور بسبب صلاحيات النظام. يرجى إبلاغ الدعم.',
        );
      }
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.unknown,
        message: 'تعذر تسجيل الحضور حالياً. حاولي مرة أخرى.',
      );
    }

    var qrAuditStored = true;
    try {
      _debugLog('QR_QR_RECORD_WRITE_START recordId=$recordId');
      await qrRecordRef.set({
        'recordId': recordId,
        'sessionId': session.sessionId,
        'sectionId': session.sectionId,
        'studentId': student.studentId,
        'studentDocId': studentDocId,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'courseCode': session.courseCode,
        'courseName': session.courseName,
        'lectureDate': Timestamp.fromDate(session.lectureDate),
        'lectureStartTime': session.lectureStartTime,
        'lectureEndTime': session.lectureEndTime,
        'sessionOpenedAt': Timestamp.fromDate(
          session.sessionOpenedAt ??
              AttendanceStatusPolicy.combineDateAndTime(
                session.lectureDate,
                session.lectureStartTime,
              ),
        ),
        'attendanceMethod': 'qr',
        'status': status,
        'attendanceTime': attendanceTime,
        'scannedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'firebaseUid': FirebaseAuth.instance.currentUser?.uid ?? '',
      }, SetOptions(merge: true));
      _debugLog('QR_QR_RECORD_WRITE_SUCCESS');
    } on FirebaseException catch (e) {
      qrAuditStored = false;
      _debugLog('QR_QR_RECORD_WRITE_FAILED errorCode=${e.code}');
      _debugLog(
        'QR attendance audit record write failed for session ${session.sessionId}: ${e.code}',
      );
    }

    _debugLog('QR_SUBMIT_SUCCESS status=$status');
    return QrAttendanceSubmissionResult(
      success: true,
      message: qrAuditStored
          ? 'تم تسجيل الحضور بنجاح.'
          : 'تم تسجيل الحضور بنجاح في كشف المحاضرة، لكن تعذر حفظ سجل QR المساند بسبب صلاحيات النظام.',
      session: session,
      recordId: recordId,
      status: status,
      qrAuditStored: qrAuditStored,
    );
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

  String _generateNumericCode({String? excluding}) {
    String code;
    do {
      code = (_random.nextInt(900000) + 100000).toString();
    } while (excluding != null && code == excluding);
    return code;
  }

  Future<bool> _matchesPreviousNumericCode(String code) async {
    final previousMatches = await _firestore
        .collection(_sessionsCollection)
        .where('previousNumericCode', isEqualTo: code)
        .limit(1)
        .get();
    return previousMatches.docs.isNotEmpty;
  }

  static String _dateKey(DateTime value) {
    final d = _normalizedDate(value);
    return '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime _normalizedDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isSessionActive(QrAttendanceSession session, DateTime now) {
    return AttendanceStatusPolicy.isSessionWithinAttendanceWindow(
      lectureDate: session.lectureDate,
      lectureStartTime: session.lectureStartTime,
      lectureEndTime: session.lectureEndTime,
      currentTime: now,
    );
  }

  String _hhmm(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
