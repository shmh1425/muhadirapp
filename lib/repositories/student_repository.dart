import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/course_model.dart';
import '../models/course_weekly_slot.dart';

class StudentRepository {
  StudentRepository({
    FirebaseFirestore? firestore,
    Box<dynamic>? coursesBox,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _coursesBox = coursesBox;

  final FirebaseFirestore _firestore;
  final Box<dynamic>? _coursesBox;

  /// Hive box name (opened in [main] via [Hive.openBox]).
  static const String coursesBoxName = 'coursesBox';

  static const String _enrollmentsCollection = 'student_section_enrollments';
  static const String _sectionsCollection = 'sections';
  static const String _coursesCollection = 'courses';

  Box<dynamic> get _box {
    final b = _coursesBox ?? Hive.box<dynamic>(coursesBoxName);
    return b;
  }

  /// Fast synchronous read from Hive. Returns `null` if there is no entry for [studentId].
  List<CourseModel>? getCachedCourses(String studentId) {
    final key = studentId.trim();
    if (key.isEmpty) return null;
    if (!_box.isOpen) return null;
    final raw = _box.get(key);
    if (raw == null) return null;
    final decoded = _decodeCoursesList(raw);
    if (decoded == null) return null;
    return decoded;
  }

  /// Persists [courses] for [studentId] (overwrites existing).
  Future<void> saveCourses(String studentId, List<CourseModel> courses) async {
    final key = studentId.trim();
    if (key.isEmpty) return;
    final encoded = courses.map((c) => c.toJson()).toList();
    await _box.put(key, encoded);
  }

  /// Removes cached courses for [studentId] (e.g. on logout).
  Future<void> clearCoursesCache(String studentId) async {
    final key = studentId.trim();
    if (key.isEmpty) return;
    if (!_box.isOpen) return;
    await _box.delete(key);
  }

  /// Network-first with Hive fallback:
  /// always tries Firestore so admin deletes (course/section/enrollment) show up;
  /// uses cache only when the fetch fails.
  ///
  /// `weeklySlots` are parsed from Firestore `sections.schedule` using the same
  /// duration rules as [AttendancePlannedSummary.weeklyMinutesFromSectionSchedule]
  /// (see [StudentAttendanceMetaRepository.weeklyMinutesFromSlots]).
  /// Absence % denominators always reload from Firestore via
  /// [SectionAbsencePlanningRepository], not from Hive alone.
  Future<List<CourseModel>> getStudentCourses(String studentId) async {
    final sid = studentId.trim();
    if (sid.isEmpty) return const <CourseModel>[];

    try {
      final fresh = await _fetchCoursesFromFirestore(sid);
      await saveCourses(sid, fresh);
      return fresh;
    } catch (_) {
      // Do not show stale Hive rows after admin deletes (offline/errors).
      await clearCoursesCache(sid);
      return const <CourseModel>[];
    }
  }

  /// Fetches all courses for a student by:
  /// - reading `student_section_enrollments` to get sectionIds
  /// - fetching those `sections` documents
  /// - fetching related `courses` documents (by courseCode)
  ///
  /// Uses parallel fetches via [Future.wait] (no sequential per-section awaits).
  Future<List<CourseModel>> _fetchCoursesFromFirestore(String sidRaw) async {
    final sidInt = int.tryParse(sidRaw);

    final enrollmentDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    void mergeEnrollments(QuerySnapshot<Map<String, dynamic>> snap) {
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['isActive'] == false) continue;
        enrollmentDocs[doc.id] = doc;
      }
    }

    if (sidInt != null) {
      mergeEnrollments(
        await _firestore
            .collection(_enrollmentsCollection)
            .where('studentId', isEqualTo: sidInt)
            .get(),
      );
    }
    if (sidInt == null || sidInt.toString() != sidRaw) {
      mergeEnrollments(
        await _firestore
            .collection(_enrollmentsCollection)
            .where('studentId', isEqualTo: sidRaw)
            .get(),
      );
    }

    final sectionIds = enrollmentDocs.values
        .map((d) => (d.data()['sectionId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (sectionIds.isEmpty) return const <CourseModel>[];

    final sectionFutures = sectionIds
        .map(
          (id) => _firestore.collection(_sectionsCollection).doc(id).get(),
        )
        .toList();

    final sectionSnaps = await Future.wait(sectionFutures);

    final sectionsById = <String, Map<String, dynamic>>{};
    for (final snap in sectionSnaps) {
      if (!snap.exists) continue;
      final data = snap.data();
      if (data == null) continue;
      sectionsById[snap.id] = Map<String, dynamic>.from(data);
    }

    final courseCodes = sectionsById.values
        .map((s) => (s['courseCode'] ?? '').toString().trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();

    final courseSnaps = courseCodes.isEmpty
        ? const <DocumentSnapshot<Map<String, dynamic>>>[]
        : await Future.wait(
            courseCodes
                .map(
                  (code) =>
                      _firestore.collection(_coursesCollection).doc(code).get(),
                )
                .toList(),
          );

    final coursesByCode = <String, Map<String, dynamic>>{};
    for (final snap in courseSnaps) {
      if (!snap.exists) continue;
      final data = snap.data();
      if (data == null) continue;
      coursesByCode[snap.id] = Map<String, dynamic>.from(data);
    }

    final out = <CourseModel>[];
    for (final sectionId in sectionIds) {
      final section = sectionsById[sectionId];
      // Enrollment without a section doc (deleted in admin) — skip, don't show ghosts.
      if (section == null) continue;

      final courseCode = (section['courseCode'] ?? '').toString().trim();
      final courseDoc = courseCode.isEmpty ? null : coursesByCode[courseCode];

      // Section exists but master course was deleted and section has no copied names.
      final sectionNameArProbe =
          (section['courseName_Ar'] ?? '').toString().trim();
      final sectionNameEnProbe = (section['courseName'] ?? '').toString().trim();
      if (courseDoc == null &&
          courseCode.isNotEmpty &&
          sectionNameArProbe.isEmpty &&
          sectionNameEnProbe.isEmpty) {
        continue;
      }

      final sectionNameAr = (section['courseName_Ar'] ?? '').toString().trim();
      final sectionNameEn = (section['courseName'] ?? '').toString().trim();

      final courseNameAr = sectionNameAr.isNotEmpty
          ? sectionNameAr
          : (courseDoc?['courseName_Ar'] ?? '').toString().trim();
      final courseNameEn = sectionNameEn.isNotEmpty
          ? sectionNameEn
          : (courseDoc?['courseName'] ?? '').toString().trim();

      final sectionLabel = (section['section'] ?? section['sectionLabel'] ?? '')
          .toString()
          .trim();
      final lecturerName = (section['lecturerName'] ?? '').toString().trim();

      final rawTypeSection = (section['courseType'] ?? '').toString().trim();
      final rawTypeCourse = (courseDoc?['courseType'] ?? '').toString().trim();
      final courseType =
          rawTypeSection.isNotEmpty ? rawTypeSection : rawTypeCourse;

      final ch = courseDoc?['creditHours'];
      final creditHours = switch (ch) {
        int() => ch.toString(),
        num() => ch.toInt().toString(),
        _ => (ch ?? '').toString().trim(),
      };

      out.add(
        CourseModel(
          studentId: sidRaw,
          sectionId: sectionId,
          sectionLabel: sectionLabel,
          courseCode: courseCode,
          courseNameAr: courseNameAr,
          courseNameEn: courseNameEn,
          lecturerName: lecturerName,
          courseType: courseType,
          creditHours: creditHours,
          weeklySlots: _weeklySlotsFromSectionMap(section),
        ),
      );
    }

    return out;
  }
}

List<CourseWeeklySlot> _weeklySlotsFromSectionMap(Map<String, dynamic> data) {
  final schedule = data['schedule'];
  if (schedule is! List<dynamic>) return const <CourseWeeklySlot>[];
  final out = <CourseWeeklySlot>[];
  for (final e in schedule) {
    final m = Map<String, dynamic>.from(e is Map ? e : <String, dynamic>{});
    final dayOfWeek = m['dayOfWeek'] is int
        ? m['dayOfWeek'] as int
        : int.tryParse((m['dayOfWeek'] ?? '').toString()) ?? 0;
    var startTime = (m['startTime'] ?? '08:00').toString();
    if (startTime.length == 4 && startTime.isNotEmpty && startTime[0] != '0') {
      startTime = '0$startTime';
    }
    var endTime = (m['endTime'] ?? '10:00').toString();
    if (endTime.length == 4 && endTime.isNotEmpty && endTime[0] != '0') {
      endTime = '0$endTime';
    }
    final hall = (m['hall'] ?? '').toString();
    final location = (m['location'] ?? m['مقر'] ?? '').toString().trim();
    out.add(
      CourseWeeklySlot(
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        hall: hall,
        location: location,
      ),
    );
  }
  return out;
}

List<CourseModel>? _decodeCoursesList(dynamic raw) {
  if (raw is! List<dynamic>) return null;
  final out = <CourseModel>[];
  for (final item in raw) {
    if (item is! Map) return null;
    final map = Map<String, dynamic>.from(item);
    out.add(CourseModel.fromJson(map));
  }
  return out;
}
