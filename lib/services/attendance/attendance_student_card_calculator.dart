import 'attendance_planned_summary.dart';

/// All percentage slices for the student attendance summary card / lecturer parity.
class AbsenceCardPercentages {
  const AbsenceCardPercentages({
    required this.presentPct,
    required this.excusedPct,
    required this.unexcusedPct,
    required this.latePct,
    required this.totalAbsencePct,
    required this.totalPlannedMinutes,
  });

  final double presentPct;
  final double excusedPct;
  final double unexcusedPct;
  final double latePct;
  final double totalAbsencePct;
  final int totalPlannedMinutes;

  int displayFloor(double v) {
    if (!v.isFinite || v <= 0) return 0;
    return v.floor().clamp(0, 100);
  }

  int get totalAbsenceDisplayFloor => displayFloor(totalAbsencePct);

  /// Student card "حرمان أكاديمي" + lecturer row highlight (single source of truth).
  bool get isAcademicallyDeprived =>
      AttendanceStudentCardCalculator.isAcademicallyDeprived(
        unexcusedPct: unexcusedPct,
        excusedPct: excusedPct,
        totalAbsencePct: totalAbsencePct,
      );
}

/// Per-student section metrics for lecturer rows (shared calculator output).
class StudentSectionAbsenceMetrics {
  const StudentSectionAbsenceMetrics({required this.breakdown});

  final AbsenceCardPercentages breakdown;

  int get displayPercentFloor => breakdown.totalAbsenceDisplayFloor;

  double get unexcusedPct => breakdown.unexcusedPct;

  double get totalAbsencePct => breakdown.totalAbsencePct;

  bool get isAcademicallyDeprived => breakdown.isAcademicallyDeprived;
}

/// Total absence % math aligned with [AttendanceTrackingScreen] [_CourseSummaryCard]:
/// - Denominator: `weeklyContactMinutes × semesterWeeks` (full term; no week filter).
/// - Numerator: excused + unexcused/absent minutes (not late/pending/present).
/// - Per-record minutes use lecture duration, with estimated session fallback when times are missing.
class AttendanceStudentCardCalculator {
  AttendanceStudentCardCalculator._();

  static const double unexcusedDeprivationThresholdPercent = 15;
  static const double totalAbsenceDeprivationThresholdPercent = 25;

  /// Matches student [_CourseSummaryCard] deprivation (strict `>` on each threshold).
  ///
  /// `excusedPct > 25` is redundant when `totalAbsencePct = excusedPct + unexcusedPct`,
  /// but kept explicitly so lecturer/student cannot drift if totals change later.
  static bool isAcademicallyDeprived({
    required double unexcusedPct,
    required double excusedPct,
    required double totalAbsencePct,
  }) {
    return unexcusedPct > unexcusedDeprivationThresholdPercent ||
        excusedPct > totalAbsenceDeprivationThresholdPercent ||
        totalAbsencePct > totalAbsenceDeprivationThresholdPercent;
  }

  static StudentSectionAbsenceMetrics metricsFromRecords({
    required List<Map<String, dynamic>> records,
    required int weeklyMinutesFromSection,
    required Map<String, int> codeToWeeklyMinutes,
    required String courseCode,
    required int semesterWeeksCount,
  }) {
    return StudentSectionAbsenceMetrics(
      breakdown: computeCardPercentages(
        records: records,
        weeklyMinutesFromSection: weeklyMinutesFromSection,
        codeToWeeklyMinutes: codeToWeeklyMinutes,
        courseCode: courseCode,
        semesterWeeksCount: semesterWeeksCount,
      ),
    );
  }

  static int statusPriority(String raw) {
    final st = raw.trim().toLowerCase();
    switch (st) {
      case 'present':
        return 4;
      case 'late':
        return 3;
      case 'excused':
        return 2;
      case 'unexcused':
      case 'absent':
        return 1;
      case 'pending':
      default:
        return 0;
    }
  }

  /// Same dedupe key/priority as [_AttendanceTrackingScreenState._dedupeAttendanceRecords].
  static List<Map<String, dynamic>> dedupeRecords(
    List<Map<String, dynamic>> input,
  ) {
    final map = <String, Map<String, dynamic>>{};
    for (final d in input) {
      final sid = (d['sectionId'] ?? '').toString().trim();
      final day = AttendancePlannedSummary.lectureDayFromRecord(d);
      if (day == null) continue;
      final tr = AttendancePlannedSummary.timeRangeFromRecord(d);
      final courseKey = (d['courseName'] ?? d['courseCode'] ?? sid).toString();
      final key = [
        sid.isEmpty ? courseKey : sid,
        day.toIso8601String(),
        tr.trim(),
      ].join('|');

      final prev = map[key];
      if (prev == null) {
        map[key] = d;
        continue;
      }
      final p0 = statusPriority((prev['status'] ?? '').toString());
      final p1 = statusPriority((d['status'] ?? '').toString());
      if (p1 >= p0) map[key] = d;
    }
    return map.values.toList();
  }

  static List<Map<String, dynamic>> recordsFromManualMaps(
    Iterable<Map<String, dynamic>> source,
  ) => source.map(Map<String, dynamic>.from).toList();

  /// Returns total absence % (excused + unexcused) as shown in the student donut (before floor).
  static double totalAbsenceRatePercent({
    required List<Map<String, dynamic>> records,
    required int weeklyMinutesFromSection,
    required Map<String, int> codeToWeeklyMinutes,
    required String courseCode,
    required int semesterWeeksCount,
  }) {
    final deduped = dedupeRecords(records);
    if (deduped.isEmpty) return 0;

    final weeklyFromDb = weeklyMinutesFromSection > 0
        ? weeklyMinutesFromSection
        : (codeToWeeklyMinutes[courseCode.trim()] ?? 0);
    final weeklyFallback = AttendancePlannedSummary.weeklyMinutesFallback(
      deduped,
      semesterWeeksCount,
      null,
    );
    final weekly =
        weeklyFromDb > 0 ? weeklyFromDb : weeklyFallback;

    final denomWeeks = semesterWeeksCount.clamp(1, 60);
    final totalPlannedMinutes =
        (weekly > 0 && denomWeeks > 0) ? (weekly * denomWeeks) : 0;
    if (totalPlannedMinutes <= 0) return 0;

    var sessionsPerWeek = 0;
    final byWeek = <String, Set<String>>{};
    for (final d in deduped) {
      final day = AttendancePlannedSummary.lectureDayFromRecord(d);
      if (day == null) continue;
      final tr = AttendancePlannedSummary.timeRangeFromRecord(d);
      final sectionId = (d['sectionId'] ?? '').toString().trim();
      final courseKey = (d['courseName'] ?? d['courseCode'] ?? sectionId).toString();
      final weekKey = day.toIso8601String();
      final sessionKey = '$courseKey|$weekKey|$tr';
      byWeek.putIfAbsent(weekKey, () => <String>{}).add(sessionKey);
    }
    for (final s in byWeek.values) {
      if (s.length > sessionsPerWeek) sessionsPerWeek = s.length;
    }
    final estimatedSessionMinutes = (weekly > 0 && sessionsPerWeek > 0)
        ? (weekly / sessionsPerWeek)
        : 120.0;

    int minutesFor(Map<String, dynamic> d) {
      final m = AttendancePlannedSummary.minutesFromTimeRange(
        AttendancePlannedSummary.timeRangeFromRecord(d),
      );
      if (m > 0) return m;
      return estimatedSessionMinutes.round();
    }

    var excusedMinutes = 0;
    var unexcusedMinutes = 0;
    for (final d in deduped) {
      final st = (d['status'] ?? '').toString().trim().toLowerCase();
      final m = minutesFor(d);
      if (st == 'excused') {
        excusedMinutes += m;
      } else if (st == 'absent' || st == 'unexcused') {
        unexcusedMinutes += m;
      }
    }

    return ((excusedMinutes + unexcusedMinutes) / totalPlannedMinutes) * 100.0;
  }

  /// Display value beside student name (matches student card `floor()` truncation).
  static int totalAbsencePercentDisplayFloor({
    required List<Map<String, dynamic>> records,
    required int weeklyMinutesFromSection,
    required Map<String, int> codeToWeeklyMinutes,
    required String courseCode,
    required int semesterWeeksCount,
  }) {
    final pct = totalAbsenceRatePercent(
      records: records,
      weeklyMinutesFromSection: weeklyMinutesFromSection,
      codeToWeeklyMinutes: codeToWeeklyMinutes,
      courseCode: courseCode,
      semesterWeeksCount: semesterWeeksCount,
    );
    if (!pct.isFinite || pct <= 0) return 0;
    return pct.floor().clamp(0, 100);
  }

  /// Full card breakdown (present / excused / unexcused / late / total absence).
  static AbsenceCardPercentages computeCardPercentages({
    required List<Map<String, dynamic>> records,
    required int weeklyMinutesFromSection,
    required Map<String, int> codeToWeeklyMinutes,
    required String courseCode,
    required int semesterWeeksCount,
  }) {
    final deduped = dedupeRecords(records);
    if (deduped.isEmpty) {
      return const AbsenceCardPercentages(
        presentPct: 0,
        excusedPct: 0,
        unexcusedPct: 0,
        latePct: 0,
        totalAbsencePct: 0,
        totalPlannedMinutes: 0,
      );
    }

    final weeklyFromDb = weeklyMinutesFromSection > 0
        ? weeklyMinutesFromSection
        : (codeToWeeklyMinutes[courseCode.trim()] ?? 0);
    final weeklyFallback = AttendancePlannedSummary.weeklyMinutesFallback(
      deduped,
      semesterWeeksCount,
      null,
    );
    final weekly = weeklyFromDb > 0 ? weeklyFromDb : weeklyFallback;

    final denomWeeks = semesterWeeksCount.clamp(1, 60);
    final totalPlannedMinutes =
        (weekly > 0 && denomWeeks > 0) ? (weekly * denomWeeks) : 0;

    if (totalPlannedMinutes <= 0) {
      return const AbsenceCardPercentages(
        presentPct: 0,
        excusedPct: 0,
        unexcusedPct: 0,
        latePct: 0,
        totalAbsencePct: 0,
        totalPlannedMinutes: 0,
      );
    }

    var sessionsPerWeek = 0;
    final byWeek = <String, Set<String>>{};
    for (final d in deduped) {
      final day = AttendancePlannedSummary.lectureDayFromRecord(d);
      if (day == null) continue;
      final tr = AttendancePlannedSummary.timeRangeFromRecord(d);
      final sectionId = (d['sectionId'] ?? '').toString().trim();
      final courseKey =
          (d['courseName'] ?? d['courseCode'] ?? sectionId).toString();
      final weekKey = day.toIso8601String();
      final sessionKey = '$courseKey|$weekKey|$tr';
      byWeek.putIfAbsent(weekKey, () => <String>{}).add(sessionKey);
    }
    for (final s in byWeek.values) {
      if (s.length > sessionsPerWeek) sessionsPerWeek = s.length;
    }
    final estimatedSessionMinutes = (weekly > 0 && sessionsPerWeek > 0)
        ? (weekly / sessionsPerWeek)
        : 120.0;

    int minutesFor(Map<String, dynamic> d) {
      final m = AttendancePlannedSummary.minutesFromTimeRange(
        AttendancePlannedSummary.timeRangeFromRecord(d),
      );
      if (m > 0) return m;
      return estimatedSessionMinutes.round();
    }

    int sumMinutes(bool Function(Map<String, dynamic>) pred) {
      var total = 0;
      for (final d in deduped) {
        if (!pred(d)) continue;
        total += minutesFor(d);
      }
      return total;
    }

    double pct(int minutes) => (minutes / totalPlannedMinutes) * 100.0;

    final presentMinutes = sumMinutes((d) {
      final st = (d['status'] ?? '').toString().trim().toLowerCase();
      return st == 'present';
    });
    final excusedMinutes = sumMinutes((d) {
      final st = (d['status'] ?? '').toString().trim().toLowerCase();
      return st == 'excused';
    });
    final unexcusedMinutes = sumMinutes((d) {
      final st = (d['status'] ?? '').toString().trim().toLowerCase();
      return st == 'absent' || st == 'unexcused';
    });
    final lateMinutes = sumMinutes((d) {
      final st = (d['status'] ?? '').toString().trim().toLowerCase();
      return st == 'late';
    });

    return AbsenceCardPercentages(
      presentPct: pct(presentMinutes),
      excusedPct: pct(excusedMinutes),
      unexcusedPct: pct(unexcusedMinutes),
      latePct: pct(lateMinutes),
      totalAbsencePct: pct(excusedMinutes + unexcusedMinutes),
      totalPlannedMinutes: totalPlannedMinutes,
    );
  }
}
