import 'package:cloud_firestore/cloud_firestore.dart';

/// Matches [AttendanceTrackingScreen] / [_CourseSummaryCard]:
/// - Semester week count from term + `academic_terms/{id}/weeks` + calendar (same priority).
/// - Planned minutes = `weeklyContactMinutes * filteredWeekCount` (here: full term weeks).
/// - Total absence % = `(excusedMinutes + unexcusedMinutes) / totalPlannedMinutes * 100`.
class AttendancePlannedSummary {
  const AttendancePlannedSummary({
    required this.weeklyContactMinutes,
    required this.semesterWeeksUsed,
    required this.totalPlannedMinutes,
    required this.excusedMinutes,
    required this.unexcusedMinutes,
    required this.absenceMinutes,
    required this.excusedAbsenceRatePercent,
    required this.unexcusedAbsenceRatePercent,
    required this.absenceRatePercent,
  });

  final int weeklyContactMinutes;
  final int semesterWeeksUsed;
  final int totalPlannedMinutes;
  final int excusedMinutes;
  final int unexcusedMinutes;
  /// excused + unexcused (same as card total absence minutes).
  final int absenceMinutes;
  final double excusedAbsenceRatePercent;
  final double unexcusedAbsenceRatePercent;
  /// Total absence % = (excusedMinutes + unexcusedMinutes) / planned.
  final double absenceRatePercent;

  /// Same parsing as [_CourseSummaryCard._minutesFromTimeRange].
  static int minutesFromTimeRange(String timeRange) {
    final parts = timeRange.split('-');
    if (parts.length != 2) return 0;
    int? toMinutes(String s) {
      final p = s.trim().split(':');
      if (p.length < 2) return null;
      final h = int.tryParse(p[0].trim());
      final m = int.tryParse(p[1].trim());
      if (h == null || m == null) return null;
      return h * 60 + m;
    }

    final start = toMinutes(parts[0]);
    final end = toMinutes(parts[1]);
    if (start == null || end == null) return 0;
    final diff = end - start;
    final minutes = diff >= 0 ? diff : (diff + 24 * 60);
    return minutes.clamp(0, 24 * 60);
  }

  static String timeRangeFromRecord(Map<String, dynamic> d) {
    final a = (d['lectureStartTime'] ?? '').toString().trim();
    final b = (d['lectureEndTime'] ?? '').toString().trim();
    if (a.isEmpty || b.isEmpty) return '';
    return '$a-$b';
  }

  static DateTime? lectureDayFromRecord(Map<String, dynamic> d) {
    final ld = d['lectureDate'];
    if (ld is Timestamp) {
      final t = ld.toDate();
      return DateTime(t.year, t.month, t.day);
    }
    final y = (d['lectureYear'] as num?)?.toInt();
    final m = (d['lectureMonth'] as num?)?.toInt();
    final day = (d['lectureDay'] as num?)?.toInt();
    if (y != null && m != null && day != null && y > 0 && m > 0 && day > 0) {
      return DateTime(y, m, day);
    }
    return null;
  }

  static int weeklyMinutesFromCourseMap(Map<String, dynamic>? courseData) {
    if (courseData == null || courseData.isEmpty) return 0;
    int readHours(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse((raw ?? '').toString()) ?? 0;
    }

    final weeklyHours = readHours(
      courseData['weeklyHours'] ?? courseData['hoursPerWeek'] ?? courseData['contactHours'],
    );
    if (weeklyHours > 0) return weeklyHours * 60;
    return 0;
  }

  /// Same week index as [_AttendanceTrackingScreenState._semesterWeekKey].
  static String weekKeyForDate(
    DateTime date,
    DateTime? semesterStart,
    int semesterWeeksCount,
  ) {
    if (semesterStart != null) {
      final start = DateTime(semesterStart.year, semesterStart.month, semesterStart.day);
      final d = DateTime(date.year, date.month, date.day);
      final days = d.difference(start).inDays;
      if (days >= 0) {
        final weekIndex = (days / 7).floor();
        return weekIndex.clamp(0, semesterWeeksCount - 1).toString();
      }
    }
    final startOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(startOfYear).inDays;
    final weekNum = (days / 7).floor();
    return weekNum.clamp(0, semesterWeeksCount - 1).toString();
  }

  /// [_CourseSummaryCard._weeklyMinutesFallback] adapted for raw Firestore maps.
  static int weeklyMinutesFallback(
    List<Map<String, dynamic>> records,
    int semesterWeeksCount,
    DateTime? semesterStart,
  ) {
    final byWeek = <String, Map<String, int>>{};
    for (final d in records) {
      final day = lectureDayFromRecord(d);
      if (day == null) continue;
      final tr = timeRangeFromRecord(d);
      final minutes = minutesFromTimeRange(tr);
      if (minutes <= 0) continue;
      final weekKey = weekKeyForDate(day, semesterStart, semesterWeeksCount);
      final sectionId = (d['sectionId'] ?? '').toString().trim();
      final sessionKey = '$sectionId|${day.toIso8601String()}|$tr';
      byWeek.putIfAbsent(weekKey, () => <String, int>{})[sessionKey] = minutes;
    }
    var maxMinutes = 0;
    for (final sessions in byWeek.values) {
      final total = sessions.values.fold<int>(0, (a, b) => a + b);
      if (total > maxMinutes) maxMinutes = total;
    }
    return maxMinutes;
  }

  /// One section / course: same math as [_CourseSummaryCard] with all weeks selected.
  static AttendancePlannedSummary forSectionRecords({
    required String courseCode,
    required Map<String, int> codeToWeeklyMinutes,
    required List<Map<String, dynamic>> dedupedRecords,
    required int semesterWeeksCount,
    required DateTime? semesterStartDate,
  }) {
    final code = courseCode.trim();
    final weeklyFromDb =
        code.isNotEmpty && (codeToWeeklyMinutes[code] ?? 0) > 0 ? codeToWeeklyMinutes[code]! : 0;
    final weeklyFallback = weeklyMinutesFallback(
      dedupedRecords,
      semesterWeeksCount,
      semesterStartDate,
    );
    final weekly = weeklyFromDb > 0 ? weeklyFromDb : weeklyFallback;
    final filteredWeeksCount = semesterWeeksCount.clamp(1, 60);
    var planned = weekly * filteredWeeksCount;
    if (planned <= 0) {
      planned = dedupedRecords.fold<int>(
        0,
        (s, d) => s + minutesFromTimeRange(timeRangeFromRecord(d)),
      );
    }

    var excusedMinutes = 0;
    var unexcusedMinutes = 0;
    for (final d in dedupedRecords) {
      final st = (d['status'] ?? '').toString();
      final m = minutesFromTimeRange(timeRangeFromRecord(d));
      if (st == 'excused') {
        excusedMinutes += m;
      } else if (st == 'absent') {
        unexcusedMinutes += m;
      }
    }
    final absenceMinutes = excusedMinutes + unexcusedMinutes;

    final excusedPct = planned <= 0 ? 0.0 : (excusedMinutes / planned) * 100.0;
    final unexcusedPct = planned <= 0 ? 0.0 : (unexcusedMinutes / planned) * 100.0;
    final totalPct = planned <= 0 ? 0.0 : (absenceMinutes / planned) * 100.0;

    return AttendancePlannedSummary(
      weeklyContactMinutes: weekly,
      semesterWeeksUsed: filteredWeeksCount,
      totalPlannedMinutes: planned,
      excusedMinutes: excusedMinutes,
      unexcusedMinutes: unexcusedMinutes,
      absenceMinutes: absenceMinutes,
      excusedAbsenceRatePercent: excusedPct,
      unexcusedAbsenceRatePercent: unexcusedPct,
      absenceRatePercent: totalPct,
    );
  }
}

/// Copy of [_AttendanceTrackingScreenState._loadAcademicTermContext] resolution
/// (week count + semester start) so the chatbot uses the same denominator weeks.
class AttendanceSemesterContext {
  const AttendanceSemesterContext({
    required this.semesterWeeksCount,
    this.semesterStartDate,
  });

  final int semesterWeeksCount;
  final DateTime? semesterStartDate;

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return DateTime(d.year, d.month, d.day);
    }
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    if (value is String) {
      final d = DateTime.tryParse(value.trim());
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }
    return null;
  }

  static int? _readPositiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    final parsed = int.tryParse((value ?? '').toString());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static Future<AttendanceSemesterContext> load(FirebaseFirestore firestore) async {
    var weeks = 15;
    DateTime? semesterStart;

    int? calendarWeeksCandidate;
    DateTime? calendarStartCandidate;

    int? readWeeksFromKeys(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = _readPositiveInt(m[k]);
        if (v != null && v > 0) return v;
      }
      return null;
    }

    try {
      final calendarDoc =
          await firestore.collection('academic_calendar').doc('current').get();
      if (calendarDoc.exists) {
        final cal = calendarDoc.data() ?? <String, dynamic>{};
        const effectiveKeys = <String>[
          'effectiveTeachingWeeks',
          'effective_teaching_weeks',
          'effectiveWeeks',
        ];
        const officialKeys = <String>[
          'officialWeeksCount',
          'official_weeks_count',
          'semesterWeeks',
          'semester_weeks',
        ];
        final effectiveWeeks = readWeeksFromKeys(cal, effectiveKeys);
        if (effectiveWeeks != null && effectiveWeeks > 0) {
          calendarWeeksCandidate = effectiveWeeks;
        } else {
          final officialWeeks = readWeeksFromKeys(cal, officialKeys);
          if (officialWeeks != null && officialWeeks > 0) {
            calendarWeeksCandidate = officialWeeks;
          }
        }
        calendarStartCandidate =
            _readDate(cal['semesterStartDate']) ?? _readDate(cal['startDate']);
      }
    } catch (_) {}

    try {
      final now = DateTime.now();
      final snapshot = await firestore
          .collection('academic_terms')
          .orderBy('startDate', descending: true)
          .limit(25)
          .get();
      if (snapshot.docs.isNotEmpty) {
        QueryDocumentSnapshot<Map<String, dynamic>> preferred = snapshot.docs.first;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final start = _readDate(data['startDate']);
          final end = _readDate(data['endDate']);
          if (start == null || end == null) continue;
          final inRange =
              (now.isAfter(start) || now.isAtSameMomentAs(start)) &&
              (now.isBefore(end) || now.isAtSameMomentAs(end));
          if (inRange) {
            preferred = doc;
            break;
          }
        }

        if (preferred == snapshot.docs.first) {
          final sorted = [...snapshot.docs];
          sorted.sort((a, b) {
            final aStart = _readDate(a.data()['startDate']) ?? DateTime(1970);
            final bStart = _readDate(b.data()['startDate']) ?? DateTime(1970);
            return bStart.compareTo(aStart);
          });
          preferred = sorted.first;
        }

        final data = preferred.data();
        final termId = (data['termId'] ?? '').toString().trim().isNotEmpty
            ? (data['termId'] ?? '').toString().trim()
            : preferred.id;

        final termEffectiveWeeks = _readPositiveInt(data['effectiveTeachingWeeks']);
        final termOfficialWeeks =
            _readPositiveInt(data['officialWeeksCount']) ?? _readPositiveInt(data['semesterWeeks']);

        int? weeksFromWeeksSubcollection;
        try {
          final weeksSnap =
              await firestore.collection('academic_terms').doc(termId).collection('weeks').get();
          if (weeksSnap.docs.isNotEmpty) {
            final countInAttendance =
                weeksSnap.docs.where((d) => (d.data()['countInAttendance'] == true)).length;
            if (countInAttendance > 0) weeksFromWeeksSubcollection = countInAttendance;
          }
        } catch (_) {}

        final chosenWeeks = termEffectiveWeeks ??
            weeksFromWeeksSubcollection ??
            calendarWeeksCandidate ??
            termOfficialWeeks ??
            15;
        weeks = chosenWeeks.clamp(1, 40);

        semesterStart =
            _readDate(data['startDate']) ?? calendarStartCandidate ?? semesterStart;
      }
    } catch (_) {}

    return AttendanceSemesterContext(
      semesterWeeksCount: weeks,
      semesterStartDate: semesterStart,
    );
  }
}
