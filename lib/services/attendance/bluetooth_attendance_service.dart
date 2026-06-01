import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/attendance/bluetooth_attendance_session.dart';
import '../../models/attendance/manual_attendance_record.dart';
import '../../models/lecturer/lecture_item.dart';
import '../lecturer_auth_service.dart';
import '../student_auth_service.dart';
import 'attendance_status_policy.dart';
import 'manual_attendance_service.dart';

enum BluetoothAttendanceErrorCode {
  invalidInput,
  missingLecturerSession,
  sessionNotFound,
  sessionClosed,
  sessionExpired,
  attendanceWindowClosed,
  tokenMismatch,
  weakSignal,
  studentNotEnrolled,
  alreadyMarked,
  unknown,
}

class BluetoothAttendanceException implements Exception {
  BluetoothAttendanceException({required this.code, required this.message});

  final BluetoothAttendanceErrorCode code;
  final String message;

  @override
  String toString() => message;
}

class BluetoothAttendanceSubmissionResult {
  const BluetoothAttendanceSubmissionResult({
    required this.success,
    required this.message,
    required this.session,
    required this.recordId,
    required this.status,
    required this.auditStored,
  });

  final bool success;
  final String message;
  final BluetoothAttendanceSession session;
  final String recordId;
  final String status;
  final bool auditStored;
}

class BluetoothAttendanceService {
  BluetoothAttendanceService._();
  static final BluetoothAttendanceService instance =
      BluetoothAttendanceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random.secure();

  static const String sessionsCollection = 'bluetooth_attendance_sessions';
  static const String recordsCollection = 'bluetooth_attendance_records';
  static const String _manualSessionsCollection = 'manual_attendance_sessions';
  static const String _manualRecordsCollection = 'manual_attendance_records';
  static const String _enrollmentsCollection = 'student_section_enrollments';
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
      'sessionWasOpened': true,
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

  Future<BluetoothAttendanceSubmissionResult>
  submitAttendanceFromBluetoothSignal({
    String? sessionId,
    String? bluetoothSessionToken,
    String? sessionIdHash,
    String? tokenFragment,
    int? tokenVersion,
    int? detectedSignalStrength,
    String? detectedSignalId,
    String? rawPayload,
    DateTime? currentTime,
    /// Offline queue replay: resolve closed sessions and skip live token checks.
    bool queueReplay = false,
  }) async {
    final student = StudentAuthService.instance.currentStudent;
    if (student == null || student.studentId <= 0) {
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.invalidInput,
        message: 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول من جديد.',
      );
    }

    final now = currentTime ?? DateTime.now();
    _debugBluetoothSubmitStart(
      sessionIdArg: sessionId,
      sessionIdHash: sessionIdHash,
      tokenFragment: tokenFragment,
    );
    _debugDetectedSignal(
      detectedSignalId: detectedSignalId,
      detectedSignalStrength: detectedSignalStrength,
      sessionId: sessionId,
      sessionIdHash: sessionIdHash,
      bluetoothSessionToken: bluetoothSessionToken,
      tokenFragment: tokenFragment,
      tokenVersion: tokenVersion,
      rawPayload: rawPayload,
    );
    final session = await _resolveDetectedSession(
      studentId: student.studentId,
      now: now,
      sessionId: sessionId,
      bluetoothSessionToken: bluetoothSessionToken,
      sessionIdHash: sessionIdHash,
      tokenFragment: tokenFragment,
      tokenVersion: tokenVersion,
      detectedSignalId: detectedSignalId,
      detectedSignalStrength: detectedSignalStrength,
      rawPayload: rawPayload,
      queueReplay: queueReplay,
    );
    if (session == null) {
      _debugBluetoothValidationFailed(
        reason: 'session_not_found',
        sessionIdArg: sessionId,
        sessionIdHash: sessionIdHash,
        tokenFragment: tokenFragment,
      );
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.sessionNotFound,
        message: 'لم يتم العثور على جلسة بلوتوث نشطة لهذه المحاضرة',
      );
    }

    _debugSignalSubmit(
      action: 'resolved',
      session: session,
      now: now,
      detectedSignalStrength: detectedSignalStrength,
      tokenVersion: tokenVersion,
    );

    if (!queueReplay && !session.isOpen) {
      _debugBluetoothValidationFailed(
        reason: 'session_closed',
        sessionIdArg: sessionId,
        sessionIdHash: sessionIdHash,
        tokenFragment: tokenFragment,
      );
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.sessionClosed,
        message: 'جلسة البلوتوث مغلقة',
      );
    }

    if (session.attendanceMethod.trim().toLowerCase() != 'bluetooth') {
      _debugBluetoothValidationFailed(
        reason: 'invalid_attendance_method',
        sessionIdArg: sessionId,
        sessionIdHash: sessionIdHash,
        tokenFragment: tokenFragment,
      );
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.sessionNotFound,
        message: 'لم يتم العثور على جلسة بلوتوث صالحة',
      );
    }

    if (!queueReplay) {
      if (tokenVersion != null && tokenVersion != session.tokenVersion) {
        _debugBluetoothValidationFailed(
          reason: 'token_version_mismatch',
          sessionIdArg: sessionId,
          sessionIdHash: sessionIdHash,
          tokenFragment: tokenFragment,
        );
        throw BluetoothAttendanceException(
          code: BluetoothAttendanceErrorCode.tokenMismatch,
          message: 'انتهت صلاحية جلسة البلوتوث',
        );
      }
      if (bluetoothSessionToken != null &&
          bluetoothSessionToken.trim().isNotEmpty &&
          bluetoothSessionToken.trim() != session.bluetoothSessionToken) {
        _debugBluetoothValidationFailed(
          reason: 'token_mismatch',
          sessionIdArg: sessionId,
          sessionIdHash: sessionIdHash,
          tokenFragment: tokenFragment,
        );
        throw BluetoothAttendanceException(
          code: BluetoothAttendanceErrorCode.tokenMismatch,
          message: 'انتهت صلاحية جلسة البلوتوث',
        );
      }
      if (tokenFragment != null &&
          tokenFragment.trim().isNotEmpty &&
          !session.bluetoothSessionToken.startsWith(tokenFragment.trim()) &&
          !_tokenMatchesPrevious(session, tokenFragment.trim())) {
        _debugBluetoothValidationFailed(
          reason: 'token_fragment_mismatch',
          sessionIdArg: sessionId,
          sessionIdHash: sessionIdHash,
          tokenFragment: tokenFragment,
        );
        throw BluetoothAttendanceException(
          code: BluetoothAttendanceErrorCode.tokenMismatch,
          message: 'انتهت صلاحية جلسة البلوتوث',
        );
      }

      if (now.isAfter(session.expiresAt)) {
      _debugBluetoothValidationFailed(
        reason: 'session_expired',
        sessionIdArg: sessionId,
        sessionIdHash: sessionIdHash,
        tokenFragment: tokenFragment,
      );
        throw BluetoothAttendanceException(
          code: BluetoothAttendanceErrorCode.sessionExpired,
          message: 'انتهت صلاحية جلسة البلوتوث',
        );
      }
    }

    final today = _normalizedDate(now);
    if (!_isSameDayLectureEndAfterStart(session)) {
      _debugSignalSubmit(
        action: 'rejected_invalid_lecture_window',
        session: session,
        now: now,
        detectedSignalStrength: detectedSignalStrength,
        tokenVersion: tokenVersion,
      );
      _debugBluetoothValidationFailed(
        reason: 'invalid_lecture_window',
        sessionIdArg: sessionId,
        sessionIdHash: sessionIdHash,
        tokenFragment: tokenFragment,
      );
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.invalidInput,
        message: 'وقت نهاية المحاضرة يجب أن يكون بعد وقت البداية',
      );
    }

    if (_normalizedDate(session.lectureDate) != today ||
        !AttendanceStatusPolicy.isSessionWithinAttendanceWindow(
          lectureDate: session.lectureDate,
          lectureStartTime: session.lectureStartTime,
          lectureEndTime: session.lectureEndTime,
          currentTime: now,
        )) {
      _debugSignalSubmit(
        action: 'rejected_window_closed',
        session: session,
        now: now,
        detectedSignalStrength: detectedSignalStrength,
        tokenVersion: tokenVersion,
      );
      _debugBluetoothValidationFailed(
        reason: 'attendance_window_closed',
        sessionIdArg: sessionId,
        sessionIdHash: sessionIdHash,
        tokenFragment: tokenFragment,
      );
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.attendanceWindowClosed,
        message: 'انتهت صلاحية جلسة البلوتوث',
      );
    }

    final proximityStatus = _proximityStatus(
      session: session,
      detectedSignalStrength: detectedSignalStrength,
    );
    if (!queueReplay && proximityStatus == 'weak') {
      _debugBluetoothValidationFailed(
        reason: 'weak_signal',
        sessionIdArg: sessionId,
        sessionIdHash: sessionIdHash,
        tokenFragment: tokenFragment,
      );
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.weakSignal,
        message: 'لم يتم العثور على جلسة بلوتوث صالحة',
      );
    }

    final enrollment = await _loadActiveEnrollment(
      sectionId: session.sectionId,
      studentId: student.studentId,
    );
    if (enrollment == null) {
      _debugBluetoothValidationFailed(
        reason: 'student_not_enrolled',
        sessionIdArg: sessionId,
        sessionIdHash: sessionIdHash,
        tokenFragment: tokenFragment,
      );
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.studentNotEnrolled,
        message: 'غير مسجل في هذه الشعبة',
      );
    }

    final sessionOpenedAt =
        session.sessionOpenedAt ??
        session.openedAt ??
        AttendanceStatusPolicy.combineDateAndTime(
          session.lectureDate,
          session.lectureStartTime,
        );
    final halfDurationCutoff = AttendanceStatusPolicy.calculatePresentUntil(
      sessionOpenedAt: sessionOpenedAt,
      lectureStartTime: session.lectureStartTime,
      lectureEndTime: session.lectureEndTime,
      lectureDate: session.lectureDate,
    );
    final status = ManualAttendanceRecord.statusToString(
      AttendanceStatusPolicy.calculateCheckInStatus(
        sessionOpenedAt: sessionOpenedAt,
        lectureStartTime: session.lectureStartTime,
        lectureEndTime: session.lectureEndTime,
        lectureDate: session.lectureDate,
        checkInTime: now,
      ),
    );
    _debugSignalSubmit(
      action: 'status_calculated',
      session: session,
      now: now,
      detectedSignalStrength: detectedSignalStrength,
      tokenVersion: tokenVersion,
      sessionOpenedAt: sessionOpenedAt,
      halfDurationCutoff: halfDurationCutoff,
      status: status,
    );

    final studentName = student.displayName.trim().isNotEmpty
        ? student.displayName.trim()
        : (enrollment['studentName'] ?? '').toString().trim();
    final studentEmail = student.email.trim().isNotEmpty
        ? student.email.trim()
        : (enrollment['studentEmail'] ?? '').toString().trim();
    final studentDocId = (enrollment['studentDocId'] ?? '').toString().trim();
    final recordId = '${session.sessionId}_${student.studentId}';
    final attendanceTime = _hhmm(now);
    final resolvedFromPayload =
        (sessionId ?? '').trim().isNotEmpty ||
        (sessionIdHash ?? '').trim().isNotEmpty ||
        (bluetoothSessionToken ?? '').trim().isNotEmpty ||
        (tokenFragment ?? '').trim().isNotEmpty ||
        tokenVersion != null;
    final bluetoothResolutionSource = resolvedFromPayload
        ? 'payload'
        : 'ios_proximity_firestore_session';
    final recordRef = _firestore
        .collection(_manualRecordsCollection)
        .doc(recordId);
    final manualSessionRef = _firestore
        .collection(_manualSessionsCollection)
        .doc(session.sessionId);

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
      'sessionOpenedAt': Timestamp.fromDate(sessionOpenedAt),
      'sessionWasOpened': true,
      'attendanceTime': attendanceTime,
      'status': status,
      'attendanceMethod': 'bluetooth',
      if (detectedSignalStrength != null)
        'detectedSignalStrength': detectedSignalStrength,
      if (detectedSignalId != null && detectedSignalId.trim().isNotEmpty)
        'detectedSignalId': detectedSignalId.trim(),
      'proximityStatus': proximityStatus,
      'bluetoothTokenVersion': session.tokenVersion,
      'bluetoothResolutionSource': bluetoothResolutionSource,
      if (rawPayload != null && rawPayload.trim().isNotEmpty)
        'bluetoothRawPayload': rawPayload.trim(),
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    _debugManualRecordWrite(
      action: 'MANUAL_RECORD_WRITE_START',
      recordId: recordId,
      studentId: student.studentId,
      sectionId: session.sectionId,
      sessionId: session.sessionId,
      status: status,
      attendanceMethod: 'bluetooth',
    );
    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(recordRef);
        if (existing.exists) {
          final existingData = existing.data() ?? <String, dynamic>{};
          final existingStatus = (existingData['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (existingStatus == 'present' || existingStatus == 'late') {
            _debugBluetoothValidationFailed(
              reason: 'already_marked',
              sessionIdArg: sessionId,
              sessionIdHash: sessionIdHash,
              tokenFragment: tokenFragment,
            );
            throw BluetoothAttendanceException(
              code: BluetoothAttendanceErrorCode.alreadyMarked,
              message: 'تم تسجيل الحضور مسبقًا',
            );
          }
        } else {
          manualPayload['createdAt'] = FieldValue.serverTimestamp();
        }

        transaction.set(recordRef, manualPayload, SetOptions(merge: true));
        transaction.set(manualSessionRef, {
          'attendanceMethod': 'bluetooth',
          'sessionWasOpened': true,
          'sessionOpenedAt': Timestamp.fromDate(sessionOpenedAt),
          'lastAttendanceAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
      _debugManualRecordWrite(
        action: 'MANUAL_RECORD_WRITE_SUCCESS',
        recordId: recordId,
        studentId: student.studentId,
        sectionId: session.sectionId,
        sessionId: session.sessionId,
        status: status,
        attendanceMethod: 'bluetooth',
      );
    } on BluetoothAttendanceException catch (e) {
      _debugManualRecordWrite(
        action: 'MANUAL_RECORD_WRITE_FAILED',
        recordId: recordId,
        studentId: student.studentId,
        sectionId: session.sectionId,
        sessionId: session.sessionId,
        status: status,
        attendanceMethod: 'bluetooth',
        errorCode: e.code.name,
        errorMessage: e.message,
      );
      rethrow;
    } on FirebaseException catch (e) {
      _debugManualRecordWrite(
        action: 'MANUAL_RECORD_WRITE_FAILED',
        recordId: recordId,
        studentId: student.studentId,
        sectionId: session.sectionId,
        sessionId: session.sessionId,
        status: status,
        attendanceMethod: 'bluetooth',
        errorCode: e.code,
        errorMessage: e.message,
      );
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.unknown,
        message: e.code == 'permission-denied'
            ? 'تعذر حفظ حضور البلوتوث بسبب صلاحيات Firestore'
            : 'تعذر حفظ حضور البلوتوث حالياً',
      );
    } catch (e) {
      _debugManualRecordWrite(
        action: 'MANUAL_RECORD_WRITE_FAILED',
        recordId: recordId,
        studentId: student.studentId,
        sectionId: session.sectionId,
        sessionId: session.sessionId,
        status: status,
        attendanceMethod: 'bluetooth',
        errorMessage: e.toString(),
      );
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.unknown,
        message: 'تعذر حفظ حضور البلوتوث حالياً',
      );
    }

    final auditStored = await _writeBluetoothAuditRecord(
      recordId: recordId,
      session: session,
      studentId: student.studentId,
      studentDocId: studentDocId,
      studentName: studentName,
      studentEmail: studentEmail,
      status: status,
      attendanceTime: attendanceTime,
      detectedSignalStrength: detectedSignalStrength,
      detectedSignalId: detectedSignalId,
      proximityStatus: proximityStatus,
      resolutionSource: bluetoothResolutionSource,
      rawPayload: rawPayload,
    );
    _debugBluetoothSubmitSuccess(
      recordId: recordId,
      sessionId: session.sessionId,
      status: status,
      auditStored: auditStored,
    );

    return BluetoothAttendanceSubmissionResult(
      success: true,
      message: 'تم تسجيل الحضور عبر البلوتوث بنجاح',
      session: session,
      recordId: recordId,
      status: status,
      auditStored: auditStored,
    );
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

  Future<BluetoothAttendanceSession?> _resolveDetectedSession({
    required int studentId,
    required DateTime now,
    String? sessionId,
    String? bluetoothSessionToken,
    String? sessionIdHash,
    String? tokenFragment,
    int? tokenVersion,
    String? detectedSignalId,
    int? detectedSignalStrength,
    String? rawPayload,
    bool queueReplay = false,
  }) async {
    final explicitSessionId = (sessionId ?? '').trim();
    final hash = (sessionIdHash ?? '').trim();
    final fragment = (tokenFragment ?? '').trim();
    if (_shouldResolveExactSessionId(explicitSessionId, hash)) {
      _debugBluetoothResolveExactStart(explicitSessionId);
      return getSessionById(explicitSessionId);
    }

    final fullToken = (bluetoothSessionToken ?? '').trim();
    if (fragment.isEmpty && hash.isEmpty && fullToken.isEmpty) {
      return _resolveActiveSessionFromDetectedProximity(
        studentId: studentId,
        now: now,
        detectedSignalId: detectedSignalId,
        detectedSignalStrength: detectedSignalStrength,
        rawPayload: rawPayload,
        queueReplay: queueReplay,
      );
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection(sessionsCollection)
        .where('attendanceMethod', isEqualTo: 'bluetooth');
    if (!queueReplay) {
      query = query.where('isOpen', isEqualTo: true);
      if (tokenVersion != null && tokenVersion > 0) {
        query = query.where('tokenVersion', isEqualTo: tokenVersion);
      }
    }

    _debugBluetoothResolveByHashStart(
      sessionIdHash: hash,
      tokenFragment: fragment,
      tokenVersion: tokenVersion,
      ignoredSessionIdArg: explicitSessionId,
    );
    final snapshot = await query.limit(queueReplay ? 50 : 25).get();
    final lectureDay = _normalizedDate(now);
    BluetoothAttendanceSession? best;
    for (final doc in snapshot.docs) {
      final session = BluetoothAttendanceSession.fromDocumentSnapshot(doc);
      if (_normalizedDate(session.lectureDate) != lectureDay) continue;
      if (hash.isNotEmpty && _shortHash(session.sessionId, 6) != hash) {
        continue;
      }
      if (!queueReplay) {
        if (fullToken.isNotEmpty && session.bluetoothSessionToken != fullToken) {
          continue;
        }
        if (fragment.isNotEmpty &&
            !session.bluetoothSessionToken.startsWith(fragment) &&
            !_tokenMatchesPrevious(session, fragment)) {
          continue;
        }
        if (tokenVersion != null &&
            tokenVersion > 0 &&
            tokenVersion != session.tokenVersion) {
          continue;
        }
      }
      if (best == null || (session.isOpen && !best.isOpen)) {
        best = session;
      }
    }
    if (best != null) {
      _debugBluetoothResolveByHashSuccess(best.sessionId);
    }
    return best;
  }

  static bool _tokenMatchesPrevious(
    BluetoothAttendanceSession session,
    String fragment,
  ) {
    final previous = (session.previousBluetoothSessionToken ?? '').trim();
    return previous.isNotEmpty && previous.startsWith(fragment);
  }

  Future<BluetoothAttendanceSession?>
  _resolveActiveSessionFromDetectedProximity({
    required int studentId,
    required DateTime now,
    required String? detectedSignalId,
    required int? detectedSignalStrength,
    required String? rawPayload,
    bool queueReplay = false,
  }) async {
    final signalId = (detectedSignalId ?? '').trim();
    final payload = (rawPayload ?? '').trim();
    final hasMuhadirSignal =
        signalId.toUpperCase().contains('MUHADIR') || payload.startsWith('MHD');
    _debugFallbackResolution(
      action: 'lookup_start',
      detectedSignalId: signalId,
      detectedSignalStrength: detectedSignalStrength,
      hasMuhadirSignal: hasMuhadirSignal,
    );
    if (!hasMuhadirSignal) {
      _debugFallbackResolution(
        action: 'rejected_no_recent_signal',
        detectedSignalId: signalId,
        detectedSignalStrength: detectedSignalStrength,
        hasMuhadirSignal: false,
      );
      return null;
    }

    final sectionIds = await _loadActiveEnrollmentSectionIds(
      studentId: studentId,
    );
    _debugFallbackResolution(
      action: 'enrolled_sections_loaded',
      detectedSignalId: signalId,
      detectedSignalStrength: detectedSignalStrength,
      hasMuhadirSignal: true,
      sectionIds: sectionIds,
    );
    if (sectionIds.isEmpty) {
      _debugFallbackResolution(
        action: 'rejected_no_active_enrollments',
        detectedSignalId: signalId,
        detectedSignalStrength: detectedSignalStrength,
        hasMuhadirSignal: true,
      );
      return null;
    }

    final today = _normalizedDate(now);
    final enrolledSectionKeys = sectionIds
        .map(_sectionLookupKey)
        .where((id) => id.isNotEmpty)
        .toSet();
    Query<Map<String, dynamic>> proximityQuery = _firestore
        .collection(sessionsCollection)
        .where('attendanceMethod', isEqualTo: 'bluetooth');
    if (!queueReplay) {
      proximityQuery = proximityQuery.where('isOpen', isEqualTo: true);
    }
    final snapshot = await proximityQuery.limit(50).get();

    final matches = <BluetoothAttendanceSession>[];
    var rejected = 0;
    var invalidLectureWindowCount = 0;
    for (final doc in snapshot.docs) {
      final session = BluetoothAttendanceSession.fromDocumentSnapshot(doc);
      final sectionMatches = enrolledSectionKeys.contains(
        _sectionLookupKey(session.sectionId),
      );
      final dateMatches = _normalizedDate(session.lectureDate) == today;
      final validLectureWindow = _isSameDayLectureEndAfterStart(session);
      if (sectionMatches && dateMatches && !validLectureWindow) {
        invalidLectureWindowCount += 1;
      }
      final windowOpen = AttendanceStatusPolicy.isSessionWithinAttendanceWindow(
        lectureDate: session.lectureDate,
        lectureStartTime: session.lectureStartTime,
        lectureEndTime: session.lectureEndTime,
        currentTime: now,
      );
      final notExpired = queueReplay || !now.isAfter(session.expiresAt);
      if (sectionMatches &&
          dateMatches &&
          validLectureWindow &&
          windowOpen &&
          notExpired) {
        matches.add(session);
      } else {
        rejected += 1;
      }
    }

    _debugFallbackResolution(
      action: 'active_sessions_checked',
      detectedSignalId: signalId,
      detectedSignalStrength: detectedSignalStrength,
      hasMuhadirSignal: true,
      sectionIds: sectionIds,
      activeSessionCount: matches.length,
      rejectedCount: rejected,
    );

    if (matches.isEmpty && invalidLectureWindowCount > 0) {
      _debugFallbackResolution(
        action: 'rejected_invalid_lecture_window',
        detectedSignalId: signalId,
        detectedSignalStrength: detectedSignalStrength,
        hasMuhadirSignal: true,
        sectionIds: sectionIds,
        activeSessionCount: 0,
        rejectedCount: rejected,
      );
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.invalidInput,
        message: 'وقت نهاية المحاضرة يجب أن يكون بعد وقت البداية',
      );
    }

    if (matches.length == 1) {
      _debugFallbackResolution(
        action: 'selected_fallback_session',
        detectedSignalId: signalId,
        detectedSignalStrength: detectedSignalStrength,
        hasMuhadirSignal: true,
        sectionIds: sectionIds,
        activeSessionCount: matches.length,
        selectedSessionId: matches.first.sessionId,
      );
      return matches.first;
    }
    if (matches.length > 1) {
      _debugFallbackResolution(
        action: 'rejected_multiple_active_sessions',
        detectedSignalId: signalId,
        detectedSignalStrength: detectedSignalStrength,
        hasMuhadirSignal: true,
        sectionIds: sectionIds,
        activeSessionCount: matches.length,
      );
      throw BluetoothAttendanceException(
        code: BluetoothAttendanceErrorCode.sessionNotFound,
        message:
            'توجد أكثر من جلسة بلوتوث نشطة، يرجى اختيار المحاضرة أو استخدام QR',
      );
    }

    _debugFallbackResolution(
      action: 'rejected_no_active_session',
      detectedSignalId: signalId,
      detectedSignalStrength: detectedSignalStrength,
      hasMuhadirSignal: true,
      sectionIds: sectionIds,
      activeSessionCount: 0,
    );
    return null;
  }

  Future<List<String>> _loadActiveEnrollmentSectionIds({
    required int studentId,
  }) async {
    if (studentId <= 0) return const <String>[];
    final snapshot = await _firestore
        .collection(_enrollmentsCollection)
        .where('studentId', isEqualTo: studentId)
        .get();
    final sectionIds = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['isActive'] == false) continue;
      final sectionId = (data['sectionId'] ?? '').toString().trim();
      if (sectionId.isNotEmpty) sectionIds.add(sectionId);
    }
    return sectionIds.toList(growable: false);
  }

  Future<Map<String, dynamic>?> _loadActiveEnrollment({
    required String sectionId,
    required int studentId,
  }) async {
    final rawSectionId = sectionId.trim();
    if (rawSectionId.isEmpty || studentId <= 0) return null;
    final normalizedSectionId = rawSectionId.replaceAll(RegExp(r'\s+'), '');

    final snapshots = <QuerySnapshot<Map<String, dynamic>>>[
      await _firestore
          .collection(_enrollmentsCollection)
          .where('sectionId', isEqualTo: rawSectionId)
          .where('studentId', isEqualTo: studentId)
          .get(),
    ];
    if (normalizedSectionId.isNotEmpty && normalizedSectionId != rawSectionId) {
      snapshots.add(
        await _firestore
            .collection(_enrollmentsCollection)
            .where('sectionId', isEqualTo: normalizedSectionId)
            .where('studentId', isEqualTo: studentId)
            .get(),
      );
    }

    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['isActive'] != false) return data;
      }
    }
    return null;
  }

  String _proximityStatus({
    required BluetoothAttendanceSession session,
    required int? detectedSignalStrength,
  }) {
    if (detectedSignalStrength == null) return 'unknown';
    if (session.proximityPolicy == defaultProximityPolicy &&
        detectedSignalStrength < session.minRssi) {
      return 'weak';
    }
    return 'accepted';
  }

  Future<bool> _writeBluetoothAuditRecord({
    required String recordId,
    required BluetoothAttendanceSession session,
    required int studentId,
    required String studentDocId,
    required String studentName,
    required String studentEmail,
    required String status,
    required String attendanceTime,
    required int? detectedSignalStrength,
    required String? detectedSignalId,
    required String proximityStatus,
    required String resolutionSource,
    required String? rawPayload,
  }) async {
    try {
      await _firestore.collection(recordsCollection).doc(recordId).set({
        'recordId': recordId,
        'sessionId': session.sessionId,
        'sectionId': session.sectionId,
        'studentId': studentId,
        'studentDocId': studentDocId,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'attendanceMethod': 'bluetooth',
        'status': status,
        'attendanceTime': attendanceTime,
        if (detectedSignalStrength != null)
          'detectedSignalStrength': detectedSignalStrength,
        if (detectedSignalId != null && detectedSignalId.trim().isNotEmpty)
          'detectedSignalId': detectedSignalId.trim(),
        'proximityStatus': proximityStatus,
        'resolutionSource': resolutionSource,
        'tokenVersion': session.tokenVersion,
        if (rawPayload != null && rawPayload.trim().isNotEmpty)
          'rawPayload': rawPayload.trim(),
        'submittedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[BluetoothAttendance] AUDIT_WRITE_BEST_EFFORT_FAILED '
          'recordId=$recordId path=$recordsCollection/$recordId '
          'code=${e.code} message=${e.message ?? ''} '
          'canonicalAttendanceUnaffected=true',
        );
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[BluetoothAttendance] AUDIT_WRITE_BEST_EFFORT_FAILED '
          'recordId=$recordId path=$recordsCollection/$recordId '
          'message=$e canonicalAttendanceUnaffected=true',
        );
      }
      return false;
    }
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
    return AttendanceStatusPolicy.isSessionWithinAttendanceWindow(
      lectureDate: session.lectureDate,
      lectureStartTime: session.lectureStartTime,
      lectureEndTime: session.lectureEndTime,
      currentTime: now,
    );
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

  String _hhmm(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  bool _isSameDayLectureEndAfterStart(BluetoothAttendanceSession session) {
    final start = AttendanceStatusPolicy.combineDateAndTime(
      session.lectureDate,
      session.lectureStartTime,
    );
    final end = AttendanceStatusPolicy.combineDateAndTime(
      session.lectureDate,
      session.lectureEndTime,
    );
    return end.isAfter(start);
  }

  bool _shouldResolveExactSessionId(String sessionId, String sessionIdHash) {
    if (sessionId.isEmpty) return false;
    if (sessionId == 'bt_pending') return false;
    if (sessionIdHash.isNotEmpty && sessionId == sessionIdHash) return false;
    // Bluetooth session ids are generated as section_date_start. Compact BLE
    // hashes are short and must be resolved through hash/token metadata.
    return sessionId.contains('_');
  }

  void _debugBluetoothSubmitStart({
    required String? sessionIdArg,
    required String? sessionIdHash,
    required String? tokenFragment,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[BluetoothAttendance] BLUETOOTH_SUBMIT_START '
      'sessionIdArg=${(sessionIdArg ?? '').trim()} '
      'sessionIdHash=${(sessionIdHash ?? '').trim()} '
      'tokenFragment=${(tokenFragment ?? '').trim()}',
    );
  }

  void _debugBluetoothResolveExactStart(String sessionId) {
    if (!kDebugMode) return;
    debugPrint(
      '[BluetoothAttendance] BLUETOOTH_RESOLVE_BY_EXACT_ID_START '
      'sessionId=$sessionId',
    );
  }

  void _debugBluetoothResolveByHashStart({
    required String sessionIdHash,
    required String tokenFragment,
    required int? tokenVersion,
    required String ignoredSessionIdArg,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[BluetoothAttendance] BLUETOOTH_RESOLVE_BY_HASH_START '
      'sessionIdHash=$sessionIdHash '
      'tokenFragment=$tokenFragment '
      'tokenVersion=${tokenVersion ?? ''} '
      'ignoredSessionIdArg=$ignoredSessionIdArg',
    );
  }

  void _debugBluetoothResolveByHashSuccess(String sessionId) {
    if (!kDebugMode) return;
    debugPrint(
      '[BluetoothAttendance] BLUETOOTH_RESOLVE_BY_HASH_SUCCESS '
      'sessionId=$sessionId',
    );
  }

  void _debugBluetoothValidationFailed({
    required String reason,
    required String? sessionIdArg,
    required String? sessionIdHash,
    required String? tokenFragment,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[BluetoothAttendance] BLUETOOTH_SUBMIT_VALIDATION_FAILED '
      'reason=$reason '
      'sessionIdArg=${(sessionIdArg ?? '').trim()} '
      'sessionIdHash=${(sessionIdHash ?? '').trim()} '
      'tokenFragment=${(tokenFragment ?? '').trim()}',
    );
  }

  String _shortHash(String input, int length) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0').substring(0, length);
  }

  String _sectionLookupKey(String sectionId) {
    return sectionId.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  void _debugDetectedSignal({
    required String? detectedSignalId,
    required int? detectedSignalStrength,
    required String? sessionId,
    required String? sessionIdHash,
    required String? bluetoothSessionToken,
    required String? tokenFragment,
    required int? tokenVersion,
    required String? rawPayload,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[BluetoothAttendance] action=detected_signal '
      'signalId=${(detectedSignalId ?? '').trim()} '
      'rssi=${detectedSignalStrength ?? ''} '
      'hasSessionId=${(sessionId ?? '').trim().isNotEmpty} '
      'hasSessionIdHash=${(sessionIdHash ?? '').trim().isNotEmpty} '
      'hasToken=${(bluetoothSessionToken ?? '').trim().isNotEmpty} '
      'hasTokenFragment=${(tokenFragment ?? '').trim().isNotEmpty} '
      'hasTokenVersion=${tokenVersion != null} '
      'hasRawPayload=${(rawPayload ?? '').trim().isNotEmpty}',
    );
  }

  void _debugFallbackResolution({
    required String action,
    required String detectedSignalId,
    required int? detectedSignalStrength,
    required bool hasMuhadirSignal,
    List<String> sectionIds = const <String>[],
    int? activeSessionCount,
    int? rejectedCount,
    String? selectedSessionId,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[BluetoothAttendance] action=$action '
      'signalId=$detectedSignalId '
      'rssi=${detectedSignalStrength ?? ''} '
      'payloadFallback=true '
      'hasMuhadirSignal=$hasMuhadirSignal '
      'enrolledSectionIds=${sectionIds.join(',')} '
      'activeBluetoothSessions=${activeSessionCount ?? ''} '
      'rejectedSessions=${rejectedCount ?? ''} '
      'selectedSessionId=${selectedSessionId ?? ''}',
    );
  }

  void _debugManualRecordWrite({
    required String action,
    required String recordId,
    required int studentId,
    required String sectionId,
    required String sessionId,
    required String status,
    required String attendanceMethod,
    String? errorCode,
    String? errorMessage,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[BluetoothAttendance] $action '
      'recordId=$recordId '
      'path=$_manualRecordsCollection/$recordId '
      'studentId=$studentId '
      'sectionId=$sectionId '
      'sessionId=$sessionId '
      'status=$status '
      'attendanceMethod=$attendanceMethod '
      'code=${errorCode ?? ''} '
      'message=${errorMessage ?? ''}',
    );
  }

  void _debugBluetoothSubmitSuccess({
    required String recordId,
    required String sessionId,
    required String status,
    required bool auditStored,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[BluetoothAttendance] BLUETOOTH_ATTENDANCE_WRITE_SUCCESS '
      'canonicalRecordId=$recordId '
      'path=$_manualRecordsCollection/$recordId '
      'sessionId=$sessionId '
      'status=$status',
    );
    debugPrint(
      '[BluetoothAttendance] BLUETOOTH_SUBMIT_SUCCESS '
      'canonicalRecordId=$recordId '
      'path=$_manualRecordsCollection/$recordId '
      'sessionId=$sessionId '
      'status=$status '
      'auditStored=$auditStored',
    );
  }

  void _debugSignalSubmit({
    required String action,
    required BluetoothAttendanceSession session,
    required DateTime now,
    required int? detectedSignalStrength,
    required int? tokenVersion,
    DateTime? sessionOpenedAt,
    DateTime? halfDurationCutoff,
    String? status,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[BluetoothAttendance] action=$action '
      'sessionId=${session.sessionId} '
      'sessionOpened=${session.isOpen} '
      'sessionStartTime=${(sessionOpenedAt ?? session.sessionOpenedAt ?? session.openedAt)?.toIso8601String() ?? ''} '
      'lectureStart=${session.lectureStartTime} '
      'lectureEnd=${session.lectureEndTime} '
      'halfDurationCutoff=${halfDurationCutoff?.toIso8601String() ?? ''} '
      'studentCheckInTime=${now.toIso8601String()} '
      'tokenVersion=${tokenVersion ?? session.tokenVersion} '
      'rssi=${detectedSignalStrength ?? ''} '
      'finalStatus=${status ?? ''}',
    );
  }
}
