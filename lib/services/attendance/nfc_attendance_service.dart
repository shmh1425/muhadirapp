import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../models/attendance/nfc_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../lecturer_auth_service.dart';
import '../student_auth_service.dart';
import 'attendance_status_policy.dart';
import 'manual_attendance_service.dart';

enum NfcAttendanceErrorCode {
  missingLecturerCard,
  invalidLecturerCard,
  noActiveSession,
  studentNotEnrolled,
  alreadyMarked,
  invalidInput,
  unknown,
}

class NfcAttendanceException implements Exception {
  NfcAttendanceException({required this.code, required this.message});

  final NfcAttendanceErrorCode code;
  final String message;

  @override
  String toString() => message;
}

class NfcAttendanceSubmissionResult {
  const NfcAttendanceSubmissionResult({
    required this.success,
    required this.message,
    this.session,
    this.recordId,
  });

  final bool success;
  final String message;
  final NfcAttendanceSession? session;
  final String? recordId;
}

class NfcAttendanceService {
  NfcAttendanceService._();
  static final NfcAttendanceService instance = NfcAttendanceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _lecturersCollection = 'external_lecturers';
  static const String _studentsCollection = 'external_students';
  static const String _enrollmentsCollection = 'student_section_enrollments';
  static const String _sessionsCollection = 'nfc_attendance_sessions';
  static const String _recordsCollection = 'nfc_attendance_records';
  static const String _manualSessionsCollection = 'manual_attendance_sessions';
  static const String _manualRecordsCollection = 'manual_attendance_records';

  static String normalizeLecturerCardId(String raw) {
    return raw.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  Future<void> saveLecturerCardId({
    required String lecturerId,
    required String lecturerCardId,
  }) async {
    final lid = lecturerId.trim();
    if (lid.isEmpty) {
      throw NfcAttendanceException(
        code: NfcAttendanceErrorCode.invalidInput,
        message: 'Lecturer ID is required.',
      );
    }

    final normalizedCard = normalizeLecturerCardId(lecturerCardId);
    await _firestore.collection(_lecturersCollection).doc(lid).set({
      'lecturerCardId': normalizedCard,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> getCurrentLecturerCardId() async {
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    if (lecturerId.isEmpty) return null;

    final doc = await _firestore
        .collection(_lecturersCollection)
        .doc(lecturerId)
        .get();
    if (!doc.exists) return null;
    final data = doc.data() ?? <String, dynamic>{};
    final raw = (data['lecturerCardId'] ?? '').toString();
    final normalized = normalizeLecturerCardId(raw);
    if (normalized.isEmpty) return null;
    return normalized;
  }

  Stream<List<NfcAttendanceSession>> watchOpenSessionsForCurrentLecturer() {
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    if (lecturerId.isEmpty) {
      return const Stream<List<NfcAttendanceSession>>.empty();
    }

    return _firestore
        .collection(_sessionsCollection)
        .where('lecturerId', isEqualTo: lecturerId)
        .where('isOpen', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final sessions = snapshot.docs
              .map(NfcAttendanceSession.fromDoc)
              .toList();
          sessions.sort((a, b) {
            final byDate = b.lectureDate.compareTo(a.lectureDate);
            if (byDate != 0) return byDate;
            return a.lectureStartTime.compareTo(b.lectureStartTime);
          });
          return sessions;
        });
  }

  Future<String> openSessionForLecture({
    required LectureItem lecture,
    DateTime? lectureDate,
  }) async {
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    if (lecturerId.isEmpty) {
      throw NfcAttendanceException(
        code: NfcAttendanceErrorCode.invalidInput,
        message: 'Lecturer session is missing. Please log in again.',
      );
    }

    final sectionId = (lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) {
      throw NfcAttendanceException(
        code: NfcAttendanceErrorCode.invalidInput,
        message: 'Lecture sectionId is required to open NFC session.',
      );
    }

    final cardId = await getCurrentLecturerCardId();
    if (cardId == null || cardId.isEmpty) {
      throw NfcAttendanceException(
        code: NfcAttendanceErrorCode.missingLecturerCard,
        message: 'No NFC card assigned to this lecturer yet.',
      );
    }

    final date = _normalizedDate(lectureDate ?? DateTime.now());
    final sessionId = await ManualAttendanceService.instance
        .prepareSessionForLecture(lecture: lecture, sessionDate: date);

    final openSessionsSnapshot = await _firestore
        .collection(_sessionsCollection)
        .where('lecturerId', isEqualTo: lecturerId)
        .where('isOpen', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in openSessionsSnapshot.docs) {
      if (doc.id == sessionId) continue;
      batch.set(doc.reference, {
        'isOpen': false,
        'closedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final sessionRef = _firestore
        .collection(_sessionsCollection)
        .doc(sessionId);
    batch.set(sessionRef, {
      'sessionId': sessionId,
      'sectionId': sectionId,
      'courseName': lecture.courseName,
      'courseCode': lecture.crn,
      'section': lecture.section,
      'lectureStartTime': lecture.startTime,
      'lectureEndTime': lecture.endTime,
      'lectureDate': Timestamp.fromDate(date),
      'lectureYear': date.year,
      'lectureMonth': date.month,
      'lectureDay': date.day,
      'dateKey': _dateKey(date),
      'lectureDayOfWeek': date.weekday,
      'lecturerId': lecturerId,
      'lecturerCardId': cardId,
      'attendanceMethod': 'nfc',
      'isOpen': true,
      'openedAt': FieldValue.serverTimestamp(),
      'openedBy': lecturerId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    return sessionId;
  }

  Future<void> closeSession(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return;

    await _firestore.collection(_sessionsCollection).doc(id).set({
      'isOpen': false,
      'closedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await ManualAttendanceService.instance.finalizeSessionPendingAsAbsent(id);
  }

  Future<NfcAttendanceSubmissionResult> submitAttendanceFromCard({
    required String lecturerCardId,
    required int studentId,
    DateTime? currentTime,
    Map<String, dynamic>? location,
  }) async {
    final cardId = normalizeLecturerCardId(lecturerCardId);
    if (cardId.isEmpty) {
      throw NfcAttendanceException(
        code: NfcAttendanceErrorCode.invalidLecturerCard,
        message: 'معرّف البطاقة غير صالح.',
      );
    }

    if (studentId <= 0) {
      throw NfcAttendanceException(
        code: NfcAttendanceErrorCode.invalidInput,
        message: 'رقم الطالب غير صالح.',
      );
    }

    final now = currentTime ?? DateTime.now();

    final lecturerSnap = await _firestore
        .collection(_lecturersCollection)
        .where('lecturerCardId', isEqualTo: cardId)
        .limit(1)
        .get();

    if (lecturerSnap.docs.isEmpty) {
      throw NfcAttendanceException(
        code: NfcAttendanceErrorCode.invalidLecturerCard,
        message: 'هذه البطاقة غير مرتبطة بأي محاضر.',
      );
    }

    final lecturerData = lecturerSnap.docs.first.data();
    if (lecturerData['isActive'] == false) {
      throw NfcAttendanceException(
        code: NfcAttendanceErrorCode.invalidLecturerCard,
        message: 'هذه البطاقة تابعة لمحاضر غير فعّال.',
      );
    }

    final lecturerId =
        (lecturerData['lecturerId'] ?? lecturerSnap.docs.first.id)
            .toString()
            .trim();
    if (lecturerId.isEmpty) {
      throw NfcAttendanceException(
        code: NfcAttendanceErrorCode.invalidLecturerCard,
        message: 'تعذر تحديد المحاضر المرتبط بالبطاقة.',
      );
    }

    final sessionsSnap = await _firestore
        .collection(_sessionsCollection)
        .where('lecturerId', isEqualTo: lecturerId)
        .where('lecturerCardId', isEqualTo: cardId)
        .where('isOpen', isEqualTo: true)
        .get();

    if (sessionsSnap.docs.isEmpty) {
      throw NfcAttendanceException(
        code: NfcAttendanceErrorCode.noActiveSession,
        message: 'لا توجد جلسة تحضير NFC مفتوحة حالياً.',
      );
    }

    final activeSession = _pickActiveSessionNow(sessionsSnap.docs, now);
    if (activeSession == null) {
      throw NfcAttendanceException(
        code: NfcAttendanceErrorCode.noActiveSession,
        message: 'لا توجد محاضرة نشطة الآن لهذه البطاقة.',
      );
    }

    final enrollmentSnap = await _firestore
        .collection(_enrollmentsCollection)
        .where('sectionId', isEqualTo: activeSession.sectionId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    if (enrollmentSnap.docs.isEmpty ||
        enrollmentSnap.docs.first.data()['isActive'] == false) {
      throw NfcAttendanceException(
        code: NfcAttendanceErrorCode.studentNotEnrolled,
        message: 'الطالب غير مسجل في هذه الشعبة.',
      );
    }

    final recordId = '${activeSession.sessionId}_$studentId';
    final recordRef = _firestore.collection(_recordsCollection).doc(recordId);
    final studentProfile = await _loadStudentProfile(studentId);
    final enrollmentData = enrollmentSnap.docs.first.data();
    final studentName = studentProfile.name.isNotEmpty
        ? studentProfile.name
        : (enrollmentData['studentName'] ?? '').toString().trim();
    final studentEmail = studentProfile.email.isNotEmpty
        ? studentProfile.email
        : (enrollmentData['studentEmail'] ?? '').toString().trim();
    final studentDocId = (enrollmentData['studentDocId'] ?? '')
        .toString()
        .trim();
    final sessionOpenedAt =
        activeSession.openedAt ??
        AttendanceStatusPolicy.combineDateAndTime(
          activeSession.lectureDate,
          activeSession.lectureStartTime,
        );
    final status = ManualAttendanceRecord.statusToString(
      AttendanceStatusPolicy.calculateCheckInStatus(
        sessionOpenedAt: sessionOpenedAt,
        lectureStartTime: activeSession.lectureStartTime,
        lectureEndTime: activeSession.lectureEndTime,
        lectureDate: activeSession.lectureDate,
        checkInTime: now,
      ),
    );

    final nowTimeText = _hhmm(now);
    final nfcRecordPayload = <String, dynamic>{
      'recordId': recordId,
      'sessionId': activeSession.sessionId,
      'sectionId': activeSession.sectionId,
      'studentId': studentId,
      'studentDocId': studentDocId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'courseName': activeSession.courseName,
      'courseCode': activeSession.courseCode ?? '',
      'section': activeSession.sectionLabel,
      'lectureDate': Timestamp.fromDate(activeSession.lectureDate),
      'lectureYear': activeSession.lectureDate.year,
      'lectureMonth': activeSession.lectureDate.month,
      'lectureDay': activeSession.lectureDate.day,
      'dateKey': _dateKey(activeSession.lectureDate),
      'lectureStartTime': activeSession.lectureStartTime,
      'lectureEndTime': activeSession.lectureEndTime,
      'sessionOpenedAt': Timestamp.fromDate(sessionOpenedAt),
      'attendanceTime': nowTimeText,
      'status': status,
      'attendanceMethod': 'nfc',
      'lecturerId': activeSession.lecturerId,
      'lecturerCardId': activeSession.lecturerCardId,
      if (location != null) 'location': location,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final manualRecordRef = _firestore
        .collection(_manualRecordsCollection)
        .doc(recordId);
    final manualRecordPayload = <String, dynamic>{
      'recordId': recordId,
      'sessionId': activeSession.sessionId,
      'sectionId': activeSession.sectionId,
      'studentId': studentId,
      'studentDocId': studentDocId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'courseName': activeSession.courseName,
      'courseCode': activeSession.courseCode ?? '',
      'section': activeSession.sectionLabel,
      'lectureDate': Timestamp.fromDate(activeSession.lectureDate),
      'lectureYear': activeSession.lectureDate.year,
      'lectureMonth': activeSession.lectureDate.month,
      'lectureDay': activeSession.lectureDate.day,
      'dateKey': _dateKey(activeSession.lectureDate),
      'lectureStartTime': activeSession.lectureStartTime,
      'lectureEndTime': activeSession.lectureEndTime,
      'sessionOpenedAt': Timestamp.fromDate(sessionOpenedAt),
      'attendanceTime': nowTimeText,
      'status': status,
      'attendanceMethod': 'nfc',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final sessionRef = _firestore
        .collection(_sessionsCollection)
        .doc(activeSession.sessionId);
    final nfcSessionPatch = <String, dynamic>{
      'lastAttendanceAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'attendanceCount': FieldValue.increment(1),
    };

    final manualSessionRef = _firestore
        .collection(_manualSessionsCollection)
        .doc(activeSession.sessionId);
    final manualSessionPatch = <String, dynamic>{
      'attendanceMethod': 'nfc',
      'sessionOpenedAt': Timestamp.fromDate(sessionOpenedAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.runTransaction((transaction) async {
        final existingRecord = await transaction.get(recordRef);
        if (existingRecord.exists) {
          throw NfcAttendanceException(
            code: NfcAttendanceErrorCode.alreadyMarked,
            message: 'تم تسجيل حضورك مسبقاً لهذه المحاضرة.',
          );
        }
        final existingManualRecord = await transaction.get(manualRecordRef);
        if (existingManualRecord.exists) {
          final existingData = existingManualRecord.data() ?? <String, dynamic>{};
          final existingStatus = (existingData['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (existingStatus == 'present' || existingStatus == 'late') {
            throw NfcAttendanceException(
              code: NfcAttendanceErrorCode.alreadyMarked,
              message: 'تم تسجيل حضورك مسبقاً لهذه المحاضرة.',
            );
          }
        }

        transaction.set(recordRef, nfcRecordPayload, SetOptions(merge: true));
        transaction.set(
          manualRecordRef,
          manualRecordPayload,
          SetOptions(merge: true),
        );
        transaction.set(sessionRef, nfcSessionPatch, SetOptions(merge: true));
        transaction.set(
          manualSessionRef,
          manualSessionPatch,
          SetOptions(merge: true),
        );
      });
    } on NfcAttendanceException {
      rethrow;
    }

    return NfcAttendanceSubmissionResult(
      success: true,
      message: 'تم تسجيل الحضور بنجاح.',
      session: activeSession,
      recordId: recordId,
    );
  }

  NfcAttendanceSession? _pickActiveSessionNow(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DateTime now,
  ) {
    final sessions = docs.map(NfcAttendanceSession.fromDoc).toList();
    sessions.sort((a, b) {
      final aStart = _combineDateAndTime(a.lectureDate, a.lectureStartTime);
      final bStart = _combineDateAndTime(b.lectureDate, b.lectureStartTime);
      return bStart.compareTo(aStart);
    });

    for (final session in sessions) {
      if (_isSessionActive(session, now)) {
        return session;
      }
    }

    return null;
  }

  bool _isSessionActive(NfcAttendanceSession session, DateTime now) {
    return AttendanceStatusPolicy.isSessionWithinAttendanceWindow(
      lectureDate: session.lectureDate,
      lectureStartTime: session.lectureStartTime,
      lectureEndTime: session.lectureEndTime,
      currentTime: now,
    );
  }

  DateTime _combineDateAndTime(DateTime date, String hhmm) {
    return AttendanceStatusPolicy.combineDateAndTime(date, hhmm);
  }

  DateTime _normalizedDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _dateKey(DateTime value) {
    final d = _normalizedDate(value);
    return '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  String _hhmm(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<({String name, String email})> _loadStudentProfile(
    int studentId,
  ) async {
    final current = StudentAuthService.instance.currentStudent;
    if (current != null && current.studentId == studentId) {
      return (name: current.displayName, email: current.email.trim());
    }

    final byDoc = await _firestore
        .collection(_studentsCollection)
        .doc(studentId.toString())
        .get();
    if (byDoc.exists) {
      final data = byDoc.data() ?? <String, dynamic>{};
      final name = (data['name_ar'] ?? data['nameAr'] ?? data['name'] ?? '')
          .toString()
          .trim();
      final email = (data['email'] ?? '').toString().trim();
      return (name: name, email: email);
    }

    final byField = await _firestore
        .collection(_studentsCollection)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    if (byField.docs.isNotEmpty) {
      final data = byField.docs.first.data();
      final name = (data['name_ar'] ?? data['nameAr'] ?? data['name'] ?? '')
          .toString()
          .trim();
      final email = (data['email'] ?? '').toString().trim();
      return (name: name, email: email);
    }

    return (name: '', email: '');
  }
}
