import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../models/attendance/manual_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../models/term_week.dart';
import '../../repositories/academic_term_repository.dart';
import '../lecturer_auth_service.dart';

class ManualAttendanceService {
  ManualAttendanceService._();
  static final ManualAttendanceService instance = ManualAttendanceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _sessionsCollection = 'manual_attendance_sessions';
  static const String _recordsCollection = 'manual_attendance_records';
  static const String _enrollmentsCollection = 'student_section_enrollments';

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
    await _ensureDefaultPresentRecords(
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
    final snap =
        await _firestore.collection(_sessionsCollection).doc(id).get();
    if (!snap.exists) return null;
    return ManualAttendanceSession.fromDocumentSnapshot(snap);
  }

  Future<List<ManualAttendanceSession>> getSessionsForSectionIds(
    Set<String> sectionIds,
  ) async {
    if (sectionIds.isEmpty) return const <ManualAttendanceSession>[];
    final sections = sectionIds.where((s) => s.trim().isNotEmpty).toList();
    if (sections.isEmpty) return const <ManualAttendanceSession>[];

    final sessions = <ManualAttendanceSession>[];
    for (final chunk in _chunk(sections, 10)) {
      final snapshot = await _firestore
          .collection(_sessionsCollection)
          .where('sectionId', whereIn: chunk)
          .get();
      sessions.addAll(snapshot.docs.map(ManualAttendanceSession.fromDoc));
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

    final records = <ManualAttendanceRecord>[];
    for (final chunk in _chunk(ids, 10)) {
      final snapshot = await _firestore
          .collection(_recordsCollection)
          .where('sessionId', whereIn: chunk)
          .get();
      records.addAll(snapshot.docs.map(ManualAttendanceRecord.fromDoc));
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

  Future<void> _upsertSessionDoc({
    required String sessionId,
    required String sectionId,
    required LectureItem lecture,
    required DateTime date,
  }) async {
    final sectionRef = _firestore.collection('sections').doc(sectionId);
    final sectionSnap = await sectionRef.get();
    final sectionData = sectionSnap.data() ?? <String, dynamic>{};

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
      'lecturerId': LecturerAuthService.instance.currentLecturer?.lecturerId ?? '',
      'term': termLabel,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (termId.isNotEmpty) {
      final term = await AcademicTermRepository.instance.getTerm(termId);
      if (term != null) {
        payload['termId'] = termId;
        final weeks = await AcademicTermRepository.instance.getWeeks(termId);
        final officialWeekNumber = _officialWeekFromDate(term.startDate, date, term.officialWeeksCount);
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
          final dateExcluded = await AcademicTermRepository.instance.isDateExcludedFromAttendance(termId, date);
          if (dateExcluded) countInAttendance = false;
        }
        payload['countInAttendance'] = countInAttendance;
        payload['attendanceFinalized'] = true;
      }
    }

    await _firestore.collection(_sessionsCollection).doc(sessionId).set(payload, SetOptions(merge: true));
  }

  /// Compute 1-based official week number from term start and session date.
  static int _officialWeekFromDate(DateTime termStart, DateTime sessionDate, int officialWeeksCount) {
    final start = DateTime(termStart.year, termStart.month, termStart.day);
    final session = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
    final days = session.difference(start).inDays;
    if (days < 0) return 1;
    final week = (days / 7).floor() + 1;
    if (week > officialWeeksCount) return officialWeeksCount;
    return week;
  }

  Future<void> _ensureDefaultPresentRecords({
    required String sessionId,
    required String sectionId,
    required LectureItem lecture,
    required DateTime date,
  }) async {
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
          'attendanceTime': lecture.startTime,
          'status': ManualAttendanceRecord.statusToString(
            ManualAttendanceStatus.present,
          ),
          'attendanceMethod': 'manual',
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

  String _attendanceTimeForStatus(ManualAttendanceStatus status) {
    switch (status) {
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
  Future<({int totalCountableSessions, int unexcusedAbsenceCount, double absencePercentage})>
      getAbsenceStatsForStudentInSection(
    int studentId,
    String sectionId, {
    String? termId,
  }) async {
    final countableSessions = await getCountableSessionsForSection(sectionId, termId: termId);
    final totalCountableSessions = countableSessions.length;
    if (totalCountableSessions == 0) {
      return (totalCountableSessions: 0, unexcusedAbsenceCount: 0, absencePercentage: 0.0);
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
