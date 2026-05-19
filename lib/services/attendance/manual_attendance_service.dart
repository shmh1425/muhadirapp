import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../models/attendance/manual_attendance_session.dart';
import '../../models/external_student.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../models/term_week.dart';
import '../../repositories/academic_term_repository.dart';
import '../lecturer_auth_service.dart';
import '../../utils/lecture_action_eligibility.dart';
import 'attendance_status_policy.dart';

class ManualEnrollmentStudent {
  const ManualEnrollmentStudent({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.studentDocId,
  });

  final int studentId;
  final String studentName;
  final String studentEmail;
  final String studentDocId;
}

class ManualAttendanceService {
  ManualAttendanceService._();
  static final ManualAttendanceService instance = ManualAttendanceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _sessionsCollection = 'manual_attendance_sessions';
  static const String _recordsCollection = 'manual_attendance_records';
  static const String _enrollmentsCollection = 'student_section_enrollments';

  static const String attendanceMethodDefaultPresent = 'default_present';
  static const String defaultPresentReasonLecturerNoOpen =
      'lecturer_did_not_open_session';
  static const String defaultPresentRecordSource = 'default_present_policy';
  static const String createdBySystem = 'system';

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

  Future<String> prepareSessionForLecture({
    required LectureItem lecture,
    DateTime? sessionDate,
  }) async {
    final sectionId = (lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) {
      throw StateError('Lecture sectionId is required for manual attendance.');
    }

    final date = _normalizedDate(sessionDate ?? DateTime.now());
    final sessionId = buildSessionId(
      sectionId: sectionId,
      sessionDate: date,
      lectureStartTime: lecture.startTime,
    );

    await _upsertSessionDoc(
      sessionId: sessionId,
      sectionId: sectionId,
      lecture: lecture,
      date: date,
    );
    await _ensureDefaultPendingRecords(
      sessionId: sessionId,
      sectionId: sectionId,
      lecture: lecture,
      date: date,
    );
    return sessionId;
  }

  Stream<List<ManualAttendanceRecord>> watchSessionRecords(String sessionId) {
    return _firestore
        .collection(_recordsCollection)
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((snapshot) {
          final records = snapshot.docs
              .map(ManualAttendanceRecord.fromDoc)
              .toList();
          records.sort((a, b) => a.studentName.compareTo(b.studentName));
          return records;
        });
  }

  /// Read-only fallback roster for a section (no writes).
  /// Useful for preview mode when session records are not yet created.
  Future<List<ManualEnrollmentStudent>> getActiveSectionRoster(
    String sectionId,
  ) async {
    final rawSectionId = sectionId.trim();
    if (rawSectionId.isEmpty) return const <ManualEnrollmentStudent>[];

    final normalizedSectionId = rawSectionId.replaceAll(RegExp(r'\s+'), '');
    final snapshots = <QuerySnapshot<Map<String, dynamic>>>[
      await _firestore
          .collection(_enrollmentsCollection)
          .where('sectionId', isEqualTo: rawSectionId)
          .get(),
    ];
    if (normalizedSectionId != rawSectionId) {
      snapshots.add(
        await _firestore
            .collection(_enrollmentsCollection)
            .where('sectionId', isEqualTo: normalizedSectionId)
            .get(),
      );
    }

    final byStudentId = <int, ManualEnrollmentStudent>{};
    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['isActive'] == false) continue;
        final studentId = _safeInt(data['studentId']);
        if (studentId <= 0) continue;
        final name = (data['studentName'] ?? '').toString().trim();
        byStudentId[studentId] = ManualEnrollmentStudent(
          studentId: studentId,
          studentName: name.isEmpty ? '$studentId' : name,
          studentEmail: (data['studentEmail'] ?? '').toString().trim(),
          studentDocId: (data['studentDocId'] ?? '').toString().trim(),
        );
      }
    }

    final roster = byStudentId.values.toList();
    roster.sort((a, b) => a.studentName.compareTo(b.studentName));
    return roster;
  }

  static const String _studentsCollection = 'external_students';

  /// Bilingual student profiles for lecturer attendance / excuse UIs.
  Future<Map<int, ExternalStudent>> fetchStudentProfilesByIds(
    Set<int> studentIds,
  ) async {
    final ids = studentIds.where((id) => id > 0).toList();
    if (ids.isEmpty) return {};

    final result = <int, ExternalStudent>{};
    const chunkSize = 30;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, (i + chunkSize).clamp(0, ids.length));
      final snap = await _firestore
          .collection(_studentsCollection)
          .where('studentId', whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final student = ExternalStudent.fromMap(data);
        if (student.studentId > 0) {
          result[student.studentId] = student;
        }
      }
    }
    return result;
  }

  Stream<List<ManualAttendanceRecord>> watchStudentRecords(int studentId) {
    return _firestore
        .collection(_recordsCollection)
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final records = snapshot.docs
              .map(ManualAttendanceRecord.fromDoc)
              .toList();
          records.sort((a, b) {
            final byDate = b.lectureDate.compareTo(a.lectureDate);
            if (byDate != 0) return byDate;
            return b.lectureStartTime.compareTo(a.lectureStartTime);
          });
          return records;
        });
  }

  /// Single session document (e.g. export, validation).
  Future<ManualAttendanceSession?> getSessionById(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return null;
    final snap = await _firestore.collection(_sessionsCollection).doc(id).get();
    if (!snap.exists) return null;
    return ManualAttendanceSession.fromDocumentSnapshot(snap);
  }

  /// Raw session fields for export metadata (e.g. default-present flags).
  Future<Map<String, dynamic>?> getSessionRawDataById(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return null;
    final snap = await _firestore.collection(_sessionsCollection).doc(id).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  Future<List<ManualAttendanceSession>> getSessionsForSectionIds(
    Set<String> sectionIds,
  ) async {
    if (sectionIds.isEmpty) return const <ManualAttendanceSession>[];
    final sections = sectionIds.where((s) => s.trim().isNotEmpty).toList();
    if (sections.isEmpty) return const <ManualAttendanceSession>[];

    final chunks = _chunk(sections, 10);
    final snapshots = await Future.wait(
      chunks.map(
        (chunk) => _firestore
            .collection(_sessionsCollection)
            .where('sectionId', whereIn: chunk)
            .get(),
      ),
    );
    final sessions = <ManualAttendanceSession>[];
    for (final snap in snapshots) {
      sessions.addAll(snap.docs.map(ManualAttendanceSession.fromDoc));
    }
    sessions.sort((a, b) {
      final byDate = b.lectureDate.compareTo(a.lectureDate);
      if (byDate != 0) return byDate;
      return a.lectureStartTime.compareTo(b.lectureStartTime);
    });
    return sessions;
  }

  Future<Map<String, List<ManualAttendanceRecord>>> getRecordsForSessionIds(
    Set<String> sessionIds,
  ) async {
    if (sessionIds.isEmpty) {
      return const <String, List<ManualAttendanceRecord>>{};
    }
    final ids = sessionIds.where((s) => s.trim().isNotEmpty).toList();
    if (ids.isEmpty) return const <String, List<ManualAttendanceRecord>>{};

    // finalizeSessionPendingAsAbsent does I/O per session; run in small parallel
    // batches so attendance reports don't block on dozens of sequential awaits.
    const finalizeBatchSize = 8;
    for (final batch in _chunk(ids, finalizeBatchSize)) {
      await Future.wait(
        batch.map((id) async {
          final snap =
              await _firestore.collection(_sessionsCollection).doc(id).get();
          final data = snap.data();
          if (data != null && _isDefaultPresentSessionData(data)) {
            return;
          }
          await finalizeSessionPendingAsAbsent(id);
        }),
      );
    }

    final recordChunks = _chunk(ids, 10);
    final recordSnaps = await Future.wait(
      recordChunks.map(
        (chunk) => _firestore
            .collection(_recordsCollection)
            .where('sessionId', whereIn: chunk)
            .get(),
      ),
    );
    final records = <ManualAttendanceRecord>[];
    for (final snap in recordSnaps) {
      records.addAll(snap.docs.map(ManualAttendanceRecord.fromDoc));
    }

    final grouped = <String, List<ManualAttendanceRecord>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.sessionId, () => <ManualAttendanceRecord>[]);
      grouped[record.sessionId]!.add(record);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.studentName.compareTo(b.studentName));
    }
    return grouped;
  }

  Future<void> updateSessionStatuses({
    required String sessionId,
    required Map<int, ManualAttendanceStatus> updates,
  }) async {
    if (updates.isEmpty) return;

    final batch = _firestore.batch();
    final nowStamp = FieldValue.serverTimestamp();
    final updater =
        LecturerAuthService.instance.currentLecturer?.lecturerId ?? '';

    for (final entry in updates.entries) {
      final studentId = entry.key;
      final status = entry.value;
      final recordId = '${sessionId}_$studentId';
      final ref = _firestore.collection(_recordsCollection).doc(recordId);
      batch.set(ref, {
        'status': ManualAttendanceRecord.statusToString(status),
        'attendanceTime': _attendanceTimeForStatus(status),
        'updatedAt': nowStamp,
        'updatedBy': updater,
        'attendanceMethod': 'manual',
      }, SetOptions(merge: true));
    }

    batch.set(
      _firestore.collection(_sessionsCollection).doc(sessionId),
      {
        'updatedAt': nowStamp,
        'updatedBy': updater,
        'attendanceMethod': 'manual',
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Sets [status] on a single attendance record when the document exists.
  /// Used by excuse review when [attendanceRecordId] is explicit in Firestore.
  Future<bool> updateRecordStatusIfExists({
    required String recordId,
    required ManualAttendanceStatus status,
  }) async {
    final id = recordId.trim();
    if (id.isEmpty) return false;
    final ref = _firestore.collection(_recordsCollection).doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      return false;
    }
    final nowStamp = FieldValue.serverTimestamp();
    final updater =
        LecturerAuthService.instance.currentLecturer?.lecturerId ?? '';
    await ref.set(<String, dynamic>{
      'status': ManualAttendanceRecord.statusToString(status),
      'attendanceTime': _attendanceTimeForStatus(status),
      'updatedAt': nowStamp,
      'updatedBy': updater,
      'attendanceMethod': 'manual',
    }, SetOptions(merge: true));
    return true;
  }

  /// Manual mode policy:
  /// when lecturer starts manual attendance, any remaining pending students are
  /// considered present by default unless lecturer marks them absent later.
  Future<int> markPendingAsPresentForManual(
    String sessionId, {
    DateTime? markTime,
  }) async {
    final id = sessionId.trim();
    if (id.isEmpty) return 0;

    final session = await getSessionById(id);
    final attendanceTime =
        (session?.lectureStartTime.trim().isNotEmpty ?? false)
        ? session!.lectureStartTime.trim()
        : _hhmm(markTime ?? DateTime.now());
    final updater =
        LecturerAuthService.instance.currentLecturer?.lecturerId ?? '';

    final pendingSnapshot = await _firestore
        .collection(_recordsCollection)
        .where('sessionId', isEqualTo: id)
        .where(
          'status',
          isEqualTo: ManualAttendanceRecord.statusToString(
            ManualAttendanceStatus.pending,
          ),
        )
        .get();
    if (pendingSnapshot.docs.isEmpty) {
      await _firestore.collection(_sessionsCollection).doc(id).set({
        'attendanceMethod': 'manual',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updater,
      }, SetOptions(merge: true));
      return 0;
    }

    final batch = _firestore.batch();
    for (final doc in pendingSnapshot.docs) {
      batch.set(doc.reference, {
        'status': ManualAttendanceRecord.statusToString(
          ManualAttendanceStatus.present,
        ),
        'attendanceTime': attendanceTime,
        'attendanceMethod': 'manual',
        'updatedBy': updater,
        'updatedByRole': 'lecturer',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    batch.set(_firestore.collection(_sessionsCollection).doc(id), {
      'attendanceMethod': 'manual',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updater,
    }, SetOptions(merge: true));
    await batch.commit();
    return pendingSnapshot.docs.length;
  }

  /// True while the lecture end is still in the future (do not report/materialize).
  bool isLectureStillOpenForReporting(
    LectureItem lecture,
    DateTime lectureDate, {
    DateTime? now,
  }) {
    return LectureActionEligibility.isLectureItemActionable(
      lecture: lecture,
      lectureDate: lectureDate,
      now: now ?? DateTime.now(),
    );
  }

  /// Persists a default-present session + present records for an ended lecture
  /// with no lecturer-opened session. Idempotent; never overwrites real sessions
  /// or existing records.
  Future<String?> ensureDefaultPresentSessionForEndedLecture({
    required LectureItem lecture,
    required DateTime lectureDate,
    DateTime? now,
  }) async {
    final sectionId = (lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) return null;

    final date = _normalizedDate(lectureDate);
    final current = now ?? DateTime.now();
    if (isLectureStillOpenForReporting(lecture, date, now: current)) {
      return null;
    }

    final sessionId = buildSessionId(
      sectionId: sectionId,
      sessionDate: date,
      lectureStartTime: lecture.startTime,
    );
    final sessionRef = _firestore.collection(_sessionsCollection).doc(sessionId);
    final existingSnap = await sessionRef.get();

    if (existingSnap.exists) {
      final data = existingSnap.data() ?? <String, dynamic>{};
      if (_isOpenedManualSessionData(data)) {
        return sessionId;
      }
      await _ensureDefaultPresentRecordsForSession(
        sessionId: sessionId,
        sectionId: sectionId,
        lecture: lecture,
        date: date,
        existingSessionData: data,
      );
      return sessionId;
    }

    await _createDefaultPresentSessionWithRecords(
      sessionId: sessionId,
      sectionId: sectionId,
      lecture: lecture,
      date: date,
    );
    return sessionId;
  }

  Future<bool> finalizeSessionPendingAsAbsent(
    String sessionId, {
    DateTime? currentTime,
  }) async {
    final id = sessionId.trim();
    if (id.isEmpty) return false;

    final sessionRef = _firestore.collection(_sessionsCollection).doc(id);
    final sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists || sessionSnap.data() == null) {
      return false;
    }

    if (_isDefaultPresentSessionData(sessionSnap.data()!)) {
      return false;
    }

    final session = ManualAttendanceSession.fromDocumentSnapshot(sessionSnap);
    if (session.attendanceFinalized) {
      return false;
    }

    final openedAt =
        session.sessionOpenedAt ??
        AttendanceStatusPolicy.combineDateAndTime(
          session.lectureDate,
          session.lectureStartTime,
        );
    final now = currentTime ?? DateTime.now();
    final shouldFinalize = AttendanceStatusPolicy.shouldFinalizePendingToAbsent(
      sessionOpenedAt: openedAt,
      lectureStartTime: session.lectureStartTime,
      lectureEndTime: session.lectureEndTime,
      lectureDate: session.lectureDate,
      currentTime: now,
    );
    if (!shouldFinalize) {
      return false;
    }

    final pendingSnapshot = await _firestore
        .collection(_recordsCollection)
        .where('sessionId', isEqualTo: id)
        .where(
          'status',
          isEqualTo: ManualAttendanceRecord.statusToString(
            ManualAttendanceStatus.pending,
          ),
        )
        .get();

    final batch = _firestore.batch();
    for (final doc in pendingSnapshot.docs) {
      batch.set(doc.reference, {
        'status': ManualAttendanceRecord.statusToString(
          ManualAttendanceStatus.absent,
        ),
        'attendanceTime': _attendanceTimeForStatus(
          ManualAttendanceStatus.absent,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByRole': 'system',
      }, SetOptions(merge: true));
    }

    batch.set(sessionRef, {
      'attendanceFinalized': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    return true;
  }

  Future<void> _upsertSessionDoc({
    required String sessionId,
    required String sectionId,
    required LectureItem lecture,
    required DateTime date,
  }) async {
    final sessionRef = _firestore
        .collection(_sessionsCollection)
        .doc(sessionId);
    final existingSessionSnap = await sessionRef.get();
    final existingSessionData =
        existingSessionSnap.data() ?? <String, dynamic>{};
    final sectionRef = _firestore.collection('sections').doc(sectionId);
    final sectionSnap = await sectionRef.get();
    final sectionData = sectionSnap.data() ?? <String, dynamic>{};
    final now = DateTime.now();
    final existingOpenedAt = existingSessionData['sessionOpenedAt'];
    final sessionOpenedAt = existingOpenedAt is Timestamp
        ? existingOpenedAt.toDate()
        : now;
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    final convertingFromDefaultPresent = existingSessionSnap.exists &&
        _isDefaultPresentSessionData(existingSessionData);

    final termLabel = (sectionData['term'] ?? '').toString();
    final termId = (sectionData['termId'] ?? '').toString().trim();
    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'sectionId': sectionId,
      'courseName': lecture.courseName,
      'courseCode': lecture.crn,
      'section': lecture.section,
      'lectureStartTime': lecture.startTime,
      'lectureEndTime': lecture.endTime,
      'lectureDate': Timestamp.fromDate(date),
      'lectureDayOfWeek': date.weekday,
      'lectureYear': date.year,
      'lectureMonth': date.month,
      'lectureDay': date.day,
      'dateKey': _dateKey(date),
      'attendanceMethod': 'manual',
      'lecturerId': lecturerId,
      'sessionOpenedAt': Timestamp.fromDate(sessionOpenedAt),
      'sessionWasOpened': true,
      'autoGenerated': false,
      'defaultPresentPolicyApplied': false,
      'defaultReason': FieldValue.delete(),
      'term': termLabel,
      'updatedAt': FieldValue.serverTimestamp(),
      'attendanceFinalized': false,
    };

    if (lecturerId.isNotEmpty) {
      payload['openedBy'] = lecturerId;
    }

    if (!existingSessionSnap.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      if (lecturerId.isNotEmpty) {
        payload['createdBy'] = lecturerId;
      }
    } else if (convertingFromDefaultPresent) {
      if (lecturerId.isNotEmpty) {
        payload['createdBy'] = lecturerId;
      } else {
        payload['createdBy'] = FieldValue.delete();
      }
    }

    if (termId.isNotEmpty) {
      final term = await AcademicTermRepository.instance.getTerm(termId);
      if (term != null) {
        payload['termId'] = termId;
        final weeks = await AcademicTermRepository.instance.getWeeks(termId);
        final officialWeekNumber = _officialWeekFromDate(
          term.startDate,
          date,
          term.officialWeeksCount,
        );
        payload['officialWeekNumber'] = officialWeekNumber;
        TermWeek? week;
        for (final w in weeks) {
          if (w.officialWeekNumber == officialWeekNumber) {
            week = w;
            break;
          }
        }
        bool countInAttendance = false;
        if (week != null) {
          payload['effectiveWeekNumber'] = week.effectiveWeekNumber;
          countInAttendance = week.countInAttendance;
        }
        if (countInAttendance) {
          final dateExcluded = await AcademicTermRepository.instance
              .isDateExcludedFromAttendance(termId, date);
          if (dateExcluded) countInAttendance = false;
        }
        payload['countInAttendance'] = countInAttendance;
      }
    }

    await sessionRef.set(payload, SetOptions(merge: true));
  }

  /// Compute 1-based official week number from term start and session date.
  static int _officialWeekFromDate(
    DateTime termStart,
    DateTime sessionDate,
    int officialWeeksCount,
  ) {
    final start = DateTime(termStart.year, termStart.month, termStart.day);
    final session = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
    );
    final days = session.difference(start).inDays;
    if (days < 0) return 1;
    final week = (days / 7).floor() + 1;
    if (week > officialWeeksCount) return officialWeeksCount;
    return week;
  }

  Future<void> _ensureDefaultPendingRecords({
    required String sessionId,
    required String sectionId,
    required LectureItem lecture,
    required DateTime date,
  }) async {
    final session = await getSessionById(sessionId);
    final sessionOpenedAt = session?.sessionOpenedAt ?? DateTime.now();
    final existingSnapshot = await _firestore
        .collection(_recordsCollection)
        .where('sessionId', isEqualTo: sessionId)
        .get();
    final existingStudentIds = existingSnapshot.docs
        .map((d) => _safeInt(d.data()['studentId']))
        .toSet();

    final enrollmentsSnapshot = await _firestore
        .collection(_enrollmentsCollection)
        .where('sectionId', isEqualTo: sectionId)
        .get();

    final docs = enrollmentsSnapshot.docs.where((doc) {
      final isActive = doc.data()['isActive'];
      return isActive != false;
    }).toList();

    if (docs.isEmpty) return;

    final updater =
        LecturerAuthService.instance.currentLecturer?.lecturerId ?? '';
    WriteBatch batch = _firestore.batch();
    int ops = 0;

    Future<void> commitBatch() async {
      if (ops == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      ops = 0;
    }

    for (final enrollment in docs) {
      final data = enrollment.data();
      final studentId = _safeInt(data['studentId']);
      if (studentId <= 0 || existingStudentIds.contains(studentId)) {
        continue;
      }
      final studentName = (data['studentName'] ?? '').toString().trim();
      final studentDocId = (data['studentDocId'] ?? '').toString().trim();
      final recordId = '${sessionId}_$studentId';
      batch.set(
        _firestore.collection(_recordsCollection).doc(recordId),
        {
          'recordId': recordId,
          'sessionId': sessionId,
          'sectionId': sectionId,
          'studentId': studentId,
          'studentDocId': studentDocId,
          'studentName': studentName,
          'studentEmail': (data['studentEmail'] ?? '').toString(),
          'courseName': lecture.courseName,
          'courseCode': lecture.crn,
          'section': lecture.section,
          'lectureDate': Timestamp.fromDate(date),
          'lectureYear': date.year,
          'lectureMonth': date.month,
          'lectureDay': date.day,
          'lectureDayOfWeek': date.weekday,
          'dateKey': _dateKey(date),
          'lectureStartTime': lecture.startTime,
          'lectureEndTime': lecture.endTime,
          'sessionOpenedAt': Timestamp.fromDate(sessionOpenedAt),
          'attendanceTime': _attendanceTimeForStatus(
            ManualAttendanceStatus.pending,
          ),
          'status': ManualAttendanceRecord.statusToString(
            ManualAttendanceStatus.pending,
          ),
          'attendanceMethod': 'manual',
          'updatedByRole': 'lecturer',
          'createdBy': updater,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      ops++;
      if (ops >= 450) {
        await commitBatch();
      }
    }

    await commitBatch();
  }

  static bool _isRealOpenedAttendanceMethod(String method) {
    switch (method.trim().toLowerCase()) {
      case 'manual':
      case 'qr':
      case 'nfc':
      case 'bluetooth':
        return true;
      default:
        return false;
    }
  }

  static bool _isDefaultPresentSessionData(Map<String, dynamic> data) {
    if (data['sessionWasOpened'] == true) return false;
    final method = (data['attendanceMethod'] ?? '').toString().trim();
    if (_isRealOpenedAttendanceMethod(method)) return false;
    if (data['defaultPresentPolicyApplied'] == true) return true;
    if (method == attendanceMethodDefaultPresent) return true;
    return data['autoGenerated'] == true && data['sessionWasOpened'] == false;
  }

  static bool _isOpenedManualSessionData(Map<String, dynamic> data) {
    if (data['sessionWasOpened'] == true) return true;
    final method = (data['attendanceMethod'] ?? '').toString().trim();
    if (_isRealOpenedAttendanceMethod(method)) return true;
    if (_isDefaultPresentSessionData(data)) return false;
    if (method.isEmpty) {
      return data['sessionOpenedAt'] != null;
    }
    return method != attendanceMethodDefaultPresent;
  }

  Future<void> _createDefaultPresentSessionWithRecords({
    required String sessionId,
    required String sectionId,
    required LectureItem lecture,
    required DateTime date,
  }) async {
    final sessionRef = _firestore.collection(_sessionsCollection).doc(sessionId);
    final termPayload = await _termMetadataForSession(sectionId, date);
    final nowStamp = FieldValue.serverTimestamp();

    await sessionRef.set(<String, dynamic>{
      'sessionId': sessionId,
      'sectionId': sectionId,
      'courseName': lecture.courseName,
      'courseCode': lecture.crn,
      'section': lecture.section,
      'lectureStartTime': lecture.startTime,
      'lectureEndTime': lecture.endTime,
      'lectureDate': Timestamp.fromDate(date),
      'lectureDayOfWeek': date.weekday,
      'lectureYear': date.year,
      'lectureMonth': date.month,
      'lectureDay': date.day,
      'dateKey': _dateKey(date),
      'lecturerId':
          LecturerAuthService.instance.currentLecturer?.lecturerId ?? '',
      'attendanceMethod': attendanceMethodDefaultPresent,
      'sessionWasOpened': false,
      'autoGenerated': true,
      'defaultPresentPolicyApplied': true,
      'defaultReason': defaultPresentReasonLecturerNoOpen,
      'createdBy': createdBySystem,
      'attendanceFinalized': true,
      'sessionOpenedAt': null,
      'createdAt': nowStamp,
      'updatedAt': nowStamp,
      ...termPayload,
    });

    await _ensureDefaultPresentRecordsForSession(
      sessionId: sessionId,
      sectionId: sectionId,
      lecture: lecture,
      date: date,
      existingSessionData: const <String, dynamic>{},
    );
  }

  Future<void> _ensureDefaultPresentRecordsForSession({
    required String sessionId,
    required String sectionId,
    required LectureItem lecture,
    required DateTime date,
    required Map<String, dynamic> existingSessionData,
  }) async {
    if (_isOpenedManualSessionData(existingSessionData)) {
      return;
    }

    final roster = await getActiveSectionRoster(sectionId);
    if (roster.isEmpty) return;

    final existingSnapshot = await _firestore
        .collection(_recordsCollection)
        .where('sessionId', isEqualTo: sessionId)
        .get();
    final existingStudentIds = existingSnapshot.docs
        .map((d) => _safeInt(d.data()['studentId']))
        .toSet();

    final attendanceTime = lecture.startTime.trim().isNotEmpty
        ? lecture.startTime.trim()
        : _hhmm(date);

    WriteBatch batch = _firestore.batch();
    var ops = 0;

    Future<void> commitBatch() async {
      if (ops == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      ops = 0;
    }

    for (final student in roster) {
      if (student.studentId <= 0 ||
          existingStudentIds.contains(student.studentId)) {
        continue;
      }
      final recordId = '${sessionId}_${student.studentId}';
      batch.set(
        _firestore.collection(_recordsCollection).doc(recordId),
        <String, dynamic>{
          'recordId': recordId,
          'sessionId': sessionId,
          'sectionId': sectionId,
          'studentId': student.studentId,
          'studentDocId': student.studentDocId,
          'studentName': student.studentName,
          'studentEmail': student.studentEmail,
          'courseName': lecture.courseName,
          'courseCode': lecture.crn,
          'section': lecture.section,
          'lectureDate': Timestamp.fromDate(date),
          'lectureYear': date.year,
          'lectureMonth': date.month,
          'lectureDay': date.day,
          'lectureDayOfWeek': date.weekday,
          'dateKey': _dateKey(date),
          'lectureStartTime': lecture.startTime,
          'lectureEndTime': lecture.endTime,
          'attendanceTime': attendanceTime,
          'status': ManualAttendanceRecord.statusToString(
            ManualAttendanceStatus.present,
          ),
          'attendanceMethod': attendanceMethodDefaultPresent,
          'source': defaultPresentRecordSource,
          'sessionWasOpened': false,
          'autoGenerated': true,
          'defaultPresentPolicyApplied': true,
          'defaultReason': defaultPresentReasonLecturerNoOpen,
          'createdBy': createdBySystem,
          'updatedByRole': createdBySystem,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      ops++;
      if (ops >= 450) {
        await commitBatch();
      }
    }

    await commitBatch();

    await sessionRefMergeDefaultPresent(sessionId);
  }

  Future<void> sessionRefMergeDefaultPresent(String sessionId) async {
    await _firestore.collection(_sessionsCollection).doc(sessionId).set(
      <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'attendanceFinalized': true,
      },
      SetOptions(merge: true),
    );
  }

  Future<Map<String, dynamic>> _termMetadataForSession(
    String sectionId,
    DateTime date,
  ) async {
    final payload = <String, dynamic>{};
    try {
      final sectionSnap =
          await _firestore.collection('sections').doc(sectionId).get();
      final sectionData = sectionSnap.data() ?? <String, dynamic>{};
      final termLabel = (sectionData['term'] ?? '').toString();
      if (termLabel.isNotEmpty) {
        payload['term'] = termLabel;
      }
      final termId = (sectionData['termId'] ?? '').toString().trim();
      if (termId.isEmpty) return payload;

      final term = await AcademicTermRepository.instance.getTerm(termId);
      if (term == null) {
        payload['termId'] = termId;
        return payload;
      }
      payload['termId'] = termId;
      final weeks = await AcademicTermRepository.instance.getWeeks(termId);
      final officialWeekNumber = _officialWeekFromDate(
        term.startDate,
        date,
        term.officialWeeksCount,
      );
      payload['officialWeekNumber'] = officialWeekNumber;
      TermWeek? week;
      for (final w in weeks) {
        if (w.officialWeekNumber == officialWeekNumber) {
          week = w;
          break;
        }
      }
      var countInAttendance = false;
      if (week != null) {
        payload['effectiveWeekNumber'] = week.effectiveWeekNumber;
        countInAttendance = week.countInAttendance;
      }
      if (countInAttendance) {
        final dateExcluded = await AcademicTermRepository.instance
            .isDateExcludedFromAttendance(termId, date);
        if (dateExcluded) countInAttendance = false;
      }
      payload['countInAttendance'] = countInAttendance;
    } catch (_) {
      // Optional metadata only.
    }
    return payload;
  }

  static String _dateKey(DateTime value) {
    final d = _normalizedDate(value);
    return '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime _normalizedDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  static String _hhmm(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _attendanceTimeForStatus(ManualAttendanceStatus status) {
    switch (status) {
      case ManualAttendanceStatus.pending:
        return '--';
      case ManualAttendanceStatus.present:
      case ManualAttendanceStatus.late:
        return '';
      case ManualAttendanceStatus.absent:
      case ManualAttendanceStatus.excused:
        return '--';
    }
  }

  static List<List<T>> _chunk<T>(List<T> source, int size) {
    if (source.isEmpty) return <List<T>>[];
    final result = <List<T>>[];
    for (int i = 0; i < source.length; i += size) {
      final end = (i + size < source.length) ? i + size : source.length;
      result.add(source.sublist(i, end));
    }
    return result;
  }

  // ─── Admin/database-side: countable sessions and absence percentage ───

  /// Returns sessions that count toward attendance (instructional, finalized).
  /// Break weeks and non-finalized sessions excluded. Backward compatible: sessions
  /// without these fields are treated as countable.
  Future<List<ManualAttendanceSession>> getCountableSessionsForSection(
    String sectionId, {
    String? termId,
  }) async {
    Query<Map<String, dynamic>> q = _firestore
        .collection(_sessionsCollection)
        .where('sectionId', isEqualTo: sectionId);
    if (termId != null && termId.trim().isNotEmpty) {
      q = q.where('termId', isEqualTo: termId.trim());
    }
    final snapshot = await q.get();
    for (final doc in snapshot.docs) {
      await finalizeSessionPendingAsAbsent(doc.id);
    }
    final sessions = snapshot.docs
        .map(ManualAttendanceSession.fromDoc)
        .where((s) => s.countInAttendance && s.attendanceFinalized)
        .toList();
    sessions.sort((a, b) {
      final byDate = a.lectureDate.compareTo(b.lectureDate);
      if (byDate != 0) return byDate;
      return a.lectureStartTime.compareTo(b.lectureStartTime);
    });
    return sessions;
  }

  /// Absence stats for a student in a section. Admin/database side only.
  /// totalCountableSessions = finalized instructional sessions;
  /// unexcusedAbsenceCount = records with status absent (excused/present/late excluded);
  /// absencePercentage = unexcusedAbsenceCount / totalCountableSessions * 100.
  Future<
    ({
      int totalCountableSessions,
      int unexcusedAbsenceCount,
      double absencePercentage,
    })
  >
  getAbsenceStatsForStudentInSection(
    int studentId,
    String sectionId, {
    String? termId,
  }) async {
    final countableSessions = await getCountableSessionsForSection(
      sectionId,
      termId: termId,
    );
    final totalCountableSessions = countableSessions.length;
    if (totalCountableSessions == 0) {
      return (
        totalCountableSessions: 0,
        unexcusedAbsenceCount: 0,
        absencePercentage: 0.0,
      );
    }
    final sessionIds = countableSessions.map((s) => s.sessionId).toSet();
    int unexcusedAbsenceCount = 0;
    for (final chunk in _chunk(sessionIds.toList(), 10)) {
      final snapshot = await _firestore
          .collection(_recordsCollection)
          .where('sessionId', whereIn: chunk)
          .where('studentId', isEqualTo: studentId)
          .get();
      for (final doc in snapshot.docs) {
        final status = (doc.data()['status'] ?? '').toString().toLowerCase();
        if (status == 'absent') unexcusedAbsenceCount++;
      }
    }
    final absencePercentage = totalCountableSessions > 0
        ? (unexcusedAbsenceCount / totalCountableSessions) * 100.0
        : 0.0;
    return (
      totalCountableSessions: totalCountableSessions,
      unexcusedAbsenceCount: unexcusedAbsenceCount,
      absencePercentage: absencePercentage,
    );
  }
}
