import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/student_auth_service.dart';
import 'components/custom_nav_bar_icons.dart';
import 'components/notification_bell.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import '../../shared/widgets/chat_fab.dart';
import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';

class AttendanceTrackingScreen extends StatefulWidget {
  const AttendanceTrackingScreen({super.key});

  @override
  State<AttendanceTrackingScreen> createState() =>
      _AttendanceTrackingScreenState();
}

class _AttendanceTrackingScreenState extends State<AttendanceTrackingScreen> {
  static const Color _primaryColor = Color(0xFF006571);
  static const Color _tabBackground = Color(0xFFF5F5F5);
  final ManualAttendanceService _manualAttendanceService =
      ManualAttendanceService.instance;
  StreamSubscription<List<ManualAttendanceRecord>>? _recordsSubscription;

  List<_AttendanceRecord> _records = <_AttendanceRecord>[];
  Map<String, int> _codeToWeeklyMinutes = <String, int>{};
  String? _selectedCourse;
  final Set<String> _selectedWeeks = <String>{};
  bool _isLoading = true;
  String? _loadError;
  int _semesterWeeksCount = 15;
  DateTime? _semesterStartDate;

  @override
  void initState() {
    super.initState();
    _bootstrapAttendance();
  }

  @override
  void dispose() {
    _recordsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrapAttendance() async {
    await _loadAcademicTermContext();
    await _subscribeAttendance();
  }

  Future<void> _loadAcademicTermContext() async {
    try {
      final now = DateTime.now();
      int? calendarWeeksCandidate;
      DateTime? calendarStartCandidate;

      bool hasAnyKey(Map<String, dynamic> m, List<String> keys) {
        for (final k in keys) {
          if (m.containsKey(k)) return true;
        }
        return false;
      }

      int? readWeeksFromKeys(Map<String, dynamic> m, List<String> keys) {
        for (final k in keys) {
          final v = _readPositiveInt(m[k]);
          if (v != null && v > 0) return v;
        }
        return null;
      }

      // Prefer the centralized academic calendar if present.
      try {
        final calendarDoc = await FirebaseFirestore.instance
            .collection('academic_calendar')
            .doc('current')
            .get();
        if (!calendarDoc.exists) {
          if (kDebugMode) {
            debugPrint('[AttendanceTracking] academic_calendar/current: MISSING');
          }
        } else {
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
            if (kDebugMode) {
              debugPrint(
                '[AttendanceTracking] academic_calendar/current: effectiveWeeks=$effectiveWeeks cal=$cal',
              );
            }
          } else {
            final officialWeeks = readWeeksFromKeys(cal, officialKeys);
            if (officialWeeks != null && officialWeeks > 0) {
              calendarWeeksCandidate = officialWeeks;
              if (kDebugMode) {
                debugPrint(
                  '[AttendanceTracking] academic_calendar/current: officialWeeks=$officialWeeks cal=$cal',
                );
              }
            } else if (kDebugMode) {
              debugPrint(
                '[AttendanceTracking] academic_calendar/current: no valid weeks keys. cal=$cal',
              );
            }
          }

          calendarStartCandidate =
              _readDate(cal['semesterStartDate']) ?? _readDate(cal['startDate']);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AttendanceTracking] academic_calendar/current READ FAILED: $e');
        }
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('academic_terms')
          // Some environments may not keep isActive in sync; we select the best
          // term by date range and fallback to the latest by startDate.
          .orderBy('startDate', descending: true)
          .limit(25)
          .get();
      if (snapshot.docs.isEmpty) return;

      QueryDocumentSnapshot<Map<String, dynamic>> preferred =
          snapshot.docs.first;
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
      if (kDebugMode) {
        debugPrint(
          '[AttendanceTracking] picked termId=$termId startDate=${data['startDate']} '
          'effectiveTeachingWeeks=${data['effectiveTeachingWeeks']} officialWeeksCount=${data['officialWeeksCount']}',
        );
      }

      // 1) Source of truth: term.effectiveTeachingWeeks (admin maintained).
      // 2) Next: term weeks subcollection (countInAttendance == true).
      // 3) Next: academic_calendar/current.
      // 4) Fallback: term official fields.
      final termEffectiveWeeks = _readPositiveInt(data['effectiveTeachingWeeks']);
      final termOfficialWeeks =
          _readPositiveInt(data['officialWeeksCount']) ?? _readPositiveInt(data['semesterWeeks']);

      int? weeksFromWeeksSubcollection;
      try {
        final weeksSnap = await FirebaseFirestore.instance
            .collection('academic_terms')
            .doc(termId)
            .collection('weeks')
            .get();
        if (weeksSnap.docs.isNotEmpty) {
          final countInAttendance = weeksSnap.docs
              .where((d) => (d.data()['countInAttendance'] == true))
              .length;
          if (countInAttendance > 0) weeksFromWeeksSubcollection = countInAttendance;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AttendanceTracking] academic_terms/$termId/weeks READ FAILED: $e');
        }
      }

      final chosenWeeks = termEffectiveWeeks ??
          weeksFromWeeksSubcollection ??
          calendarWeeksCandidate ??
          termOfficialWeeks ??
          15;
      _semesterWeeksCount = chosenWeeks.clamp(1, 40);

      // Start date: term startDate first, otherwise calendar, otherwise keep existing/default.
      _semesterStartDate = _readDate(data['startDate']) ?? calendarStartCandidate ?? _semesterStartDate;

      if (kDebugMode) {
        debugPrint(
          '[AttendanceTracking] weeks chosen=$_semesterWeeksCount '
          '(termEffective=$termEffectiveWeeks weeksSub=$weeksFromWeeksSubcollection calendar=$calendarWeeksCandidate termOfficial=$termOfficialWeeks) '
          'startDate=$_semesterStartDate',
        );
      }
    } catch (e) {
      // Keep defaults if term context is unavailable.
      if (kDebugMode) {
        debugPrint('[AttendanceTracking] _loadAcademicTermContext FAILED: $e');
      }
    }
  }

  Future<void> _subscribeAttendance() async {
    final student = StudentAuthService.instance.currentStudent;
    if (student == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'سجّل دخولك كطالب لعرض تتبع الحضور.';
      });
      return;
    }

    await _recordsSubscription?.cancel();
    _recordsSubscription = _manualAttendanceService
        .watchStudentRecords(student.studentId)
        .listen(
          (records) async {
            final metaMaps = await _fetchCourseMetaForRecords(records);
            if (!mounted) return;
            final semesterStart =
                _semesterStartDate ??
                (records.isEmpty
                    ? null
                    : records
                          .map((r) => r.lectureDate)
                          .reduce((a, b) => a.isBefore(b) ? a : b));
            final mapped = records
                .map(
                  (r) => _toAttendanceRecord(
                    r,
                    metaMaps.codeToType,
                    metaMaps.sectionIdToType,
                    metaMaps.codeToNameAr,
                    semesterStart,
                  ),
                )
                .toList();
            mapped.sort((a, b) => b.lectureDate.compareTo(a.lectureDate));
            if (!mounted) return;
            setState(() {
              _records = mapped;
              _codeToWeeklyMinutes = metaMaps.codeToWeeklyMinutes;
              _isLoading = false;
              _loadError = null;
              _syncSelectedWeeksWithAvailable();
              final courses = _courses;
              if (courses.isNotEmpty &&
                  (_selectedCourse == null ||
                      !courses.contains(_selectedCourse))) {
                _selectedCourse = courses.first;
              }
            });
          },
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _loadError = error.toString();
            });
          },
        );
  }

  static String _courseTypeLabel(String? courseType) {
    final t = (courseType ?? '').trim().toLowerCase();
    switch (t) {
      case 'theoretical':
        return 'نظري';
      case 'practical':
        return 'عملي';
      case 'graduation_project':
        return 'مشروع التخرج';
      default:
        return '—';
    }
  }

  /// جلب بيانات المقرر من courses ثم sections (نوع المقرر + الاسم العربي).
  Future<
    ({
      Map<String, String> codeToType,
      Map<String, String> sectionIdToType,
      Map<String, String> codeToNameAr,
      Map<String, int> codeToWeeklyMinutes,
    })
  >
  _fetchCourseMetaForRecords(List<ManualAttendanceRecord> records) async {
    // Always read course weekly *scheduled* hours from DB first.
    final codes = records
        .where((r) => (r.courseCode ?? '').trim().isNotEmpty)
        .map((r) => r.courseCode!.trim())
        .toSet()
        .toList();

    final needSectionType = records
        .where((r) => (r.courseType ?? '').trim().isEmpty)
        .where((r) => r.sectionId.trim().isNotEmpty)
        .map((r) => r.sectionId.trim())
        .toSet()
        .toList();

    if (codes.isEmpty && needSectionType.isEmpty) {
      return (
        codeToType: <String, String>{},
        sectionIdToType: <String, String>{},
        codeToNameAr: <String, String>{},
        codeToWeeklyMinutes: <String, int>{},
      );
    }

    final firestore = FirebaseFirestore.instance;
    final codeToType = <String, String>{};
    final sectionIdToType = <String, String>{};
    final codeToNameAr = <String, String>{};
    final codeToWeeklyMinutes = <String, int>{};

    String typeFromMap(Map<String, dynamic>? d) {
      if (d == null) return '';
      final v = d['courseType'] ?? d['course_type'] ?? d['CourseType'] ?? '';
      return (v ?? '').toString().trim();
    }
    String nameArFromMap(Map<String, dynamic>? d) {
      if (d == null) return '';
      final v = d['courseName_Ar'] ?? d['courseNameAr'] ?? '';
      return (v ?? '').toString().trim();
    }
    int weeklyMinutesFromMap(Map<String, dynamic>? d) {
      if (d == null) return 0;
      int readHours(dynamic raw) {
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
        return int.tryParse((raw ?? '').toString()) ?? 0;
      }

      // Absence must be based on actual scheduled weekly contact hours.
      // Prefer explicit weekly fields; do NOT use creditHours (academic credits)
      // because it can differ from real weekly contact hours.
      final weeklyHours =
          readHours(d['weeklyHours'] ?? d['hoursPerWeek'] ?? d['contactHours']);
      if (weeklyHours > 0) return weeklyHours * 60;

      return 0;
    }

    for (final code in codes) {
      final doc = await firestore.collection('courses').doc(code).get();
      if (doc.exists) {
        final type = typeFromMap(doc.data());
        if (type.isNotEmpty) codeToType[code] = type;
        final nameAr = nameArFromMap(doc.data());
        if (nameAr.isNotEmpty) codeToNameAr[code] = nameAr;
        final weekly = weeklyMinutesFromMap(doc.data());
        if (weekly > 0) codeToWeeklyMinutes[code] = weekly;
      }
    }

    for (final sectionId in needSectionType) {
      if (sectionIdToType.containsKey(sectionId)) continue;
      final doc = await firestore.collection('sections').doc(sectionId).get();
      if (doc.exists) {
        final type = typeFromMap(doc.data());
        if (type.isNotEmpty) sectionIdToType[sectionId] = type;
      }
    }

    return (
      codeToType: codeToType,
      sectionIdToType: sectionIdToType,
      codeToNameAr: codeToNameAr,
      codeToWeeklyMinutes: codeToWeeklyMinutes,
    );
  }

  _AttendanceRecord _toAttendanceRecord(
    ManualAttendanceRecord record,
    Map<String, String> codeToType,
    Map<String, String> sectionIdToType,
    Map<String, String> codeToNameAr,
    DateTime? semesterStart,
  ) {
    final status = switch (record.status) {
      ManualAttendanceStatus.present => 'present',
      ManualAttendanceStatus.late => 'late',
      ManualAttendanceStatus.excused => 'excused',
      ManualAttendanceStatus.absent => 'unexcused',
    };
    final sectionText = record.sectionLabel.trim().isEmpty
        ? '-'
        : record.sectionLabel;
    final fallbackName = record.courseName.trim().isEmpty ? '—' : record.courseName.trim();
    final courseName = (record.courseCode != null &&
            codeToNameAr[record.courseCode!]?.trim().isNotEmpty == true)
        ? codeToNameAr[record.courseCode!]!.trim()
        : fallbackName;
    String? rawType = (record.courseType ?? '').trim().isNotEmpty
        ? record.courseType?.trim()
        : null;
    rawType ??= record.courseCode != null
        ? codeToType[record.courseCode!]
        : null;
    rawType ??= sectionIdToType[record.sectionId];
    if (rawType == null || rawType.trim().isEmpty) rawType = 'theoretical';
    final courseType = _courseTypeLabel(rawType);
    final lectureDate = DateTime(
      record.lectureDate.year,
      record.lectureDate.month,
      record.lectureDate.day,
    );
    final weekKey = _semesterWeekKey(lectureDate, semesterStart);
    final day = lectureDate.day.toString().padLeft(2, '0');
    return _AttendanceRecord(
      courseCode: record.courseCode,
      courseKey: '$courseName • شعبة $sectionText',
      courseName: courseName,
      sectionLabel: sectionText,
      courseTypeLabel: courseType,
      course: courseName,
      courseType: courseType,
      weekKey: weekKey,
      day: day,
      lectureDate: lectureDate,
      timeRange: '${record.lectureStartTime}-${record.lectureEndTime}',
      dayName: _arabicDayName(record.lectureDate.weekday),
      status: status,
    );
  }

  /// أسبوع الفصل (0..14) من تاريخ بداية الفصل؛ إن لم يُحدد البداية يُستخدم أسبوع السنة.
  String _semesterWeekKey(DateTime date, DateTime? semesterStart) {
    if (semesterStart != null) {
      final start = DateTime(
        semesterStart.year,
        semesterStart.month,
        semesterStart.day,
      );
      final d = DateTime(date.year, date.month, date.day);
      final days = d.difference(start).inDays;
      if (days >= 0) {
        final weekIndex = (days / 7).floor();
        return weekIndex.clamp(0, _semesterWeeksCount - 1).toString();
      }
    }
    final startOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(startOfYear).inDays;
    final weekNum = (days / 7).floor();
    return weekNum.clamp(0, _semesterWeeksCount - 1).toString();
  }

  List<String> get _courses {
    final seen = <String>{};
    final list = <String>[];
    for (final r in _records) {
      final type = (r.courseType.trim().isEmpty || r.courseType == '—')
          ? 'نظري'
          : r.courseType;
      final label = '${r.course} $type'.trim();
      if (label.isNotEmpty && seen.add(label)) list.add(label);
    }
    list.sort();
    return list;
  }

  void _syncSelectedWeeksWithAvailable() {
    final weeks = _weeks;
    if (_selectedWeeks.isEmpty) {
      _selectedWeeks.addAll(weeks);
      return;
    }
    _selectedWeeks.removeWhere((week) => !weeks.contains(week));
    if (_selectedWeeks.isEmpty) {
      _selectedWeeks.addAll(weeks);
    }
  }

  /// قائمة أسابيع الفصل (15 أسبوع) للفلتر
  List<String> get _weeks {
    return List<String>.generate(
      _semesterWeeksCount,
      (i) => 'الأسبوع ${i + 1}',
    );
  }

  Map<String, String> get _weekKeyToDisplay {
    final map = <String, String>{};
    for (var i = 0; i < _semesterWeeksCount; i++) {
      map[i.toString()] = 'الأسبوع ${i + 1}';
    }
    return map;
  }

  String _arabicDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'الاثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      case DateTime.saturday:
        return 'السبت';
      case DateTime.sunday:
      default:
        return 'الأحد';
    }
  }

  DateTime? _readDate(dynamic value) {
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

  int? _readPositiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    final parsed = int.tryParse((value ?? '').toString());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  List<_AttendanceRecord> get _filteredRecordsForSummary {
    final weekKeyToDisplay = _weekKeyToDisplay;
    final weeks = _weeks;
    final allWeeksSelected = _selectedWeeks.length == weeks.length;
    final noWeekFilter = allWeeksSelected;
    final filtered = _records.where((record) {
      final type =
          (record.courseType.trim().isEmpty || record.courseType == '—')
              ? 'نظري'
              : record.courseType;
      final courseMatch = _selectedCourse == null
          ? true
          : ('${record.course} $type'.trim() == _selectedCourse);
      final weekLabel = weekKeyToDisplay[record.weekKey] ?? record.weekKey;
      final weekMatch = noWeekFilter || _selectedWeeks.contains(weekLabel);
      return courseMatch && weekMatch;
    }).toList();
    filtered.sort((a, b) => b.lectureDate.compareTo(a.lectureDate));
    return filtered;
  }

  int get _filteredWeeksCount {
    final weeks = _weeks;
    if (weeks.isEmpty) return _semesterWeeksCount;
    final allWeeksSelected = _selectedWeeks.length == weeks.length;
    if (allWeeksSelected) return _semesterWeeksCount;
    return _selectedWeeks.length.clamp(0, _semesterWeeksCount);
  }

  int _minutesFromTimeRange(String timeRange) {
    // Expects "HH:mm-HH:mm" (or similar). Returns 0 if parsing fails.
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
    // Handle cross-midnight just in case.
    final minutes = diff >= 0 ? diff : (diff + 24 * 60);
    return minutes.clamp(0, 24 * 60);
  }

  int _estimateWeeklyLectureMinutesForSelectedCourse() {
    // Backward-compatible estimate (used only as fallback when DB weekly hours missing).
    // We take the maximum total minutes found in any single week (unique sessions).
    final weekToSessions = <String, Map<String, int>>{};
    for (final r in _records) {
      final sessionKey =
          '${r.courseKey}|${r.lectureDate.toIso8601String()}|${r.timeRange}';
      final minutes = _minutesFromTimeRange(r.timeRange);
      if (minutes <= 0) continue;
      weekToSessions.putIfAbsent(r.weekKey, () => <String, int>{})[sessionKey] =
          minutes;
    }
    int maxMinutes = 0;
    for (final sessions in weekToSessions.values) {
      final total = sessions.values.fold<int>(0, (a, b) => a + b);
      if (total > maxMinutes) maxMinutes = total;
    }
    return maxMinutes;
  }

  int get _expectedTotalMinutes {
    // Prefer planned weekly minutes from `courses` (e.g. creditHours) when available.
    int weekly = 0;
    // Not used for per-course display anymore (kept for old single-summary fallback).
    weekly = weekly > 0 ? weekly : _estimateWeeklyLectureMinutesForSelectedCourse();
    final weeks = _filteredWeeksCount;
    final expected = weekly * weeks;
    return expected < 0 ? 0 : expected;
  }

  int get _totalPlannedMinutes {
    if (_expectedTotalMinutes > 0) return _expectedTotalMinutes;
    // Fallback: sum minutes from filtered records (when schedule is incomplete).
    return _filteredRecordsForSummary.fold<int>(
      0,
      (sum, r) => sum + _minutesFromTimeRange(r.timeRange),
    );
  }

  int get _presentMinutes => _filteredRecordsForSummary
      .where((r) => r.status == 'present')
      .fold<int>(0, (sum, r) => sum + _minutesFromTimeRange(r.timeRange));

  int get _excusedMinutes => _filteredRecordsForSummary
      .where((r) => r.status == 'excused')
      .fold<int>(0, (sum, r) => sum + _minutesFromTimeRange(r.timeRange));

  int get _unexcusedMinutes => _filteredRecordsForSummary
      .where((r) => r.status == 'unexcused')
      .fold<int>(0, (sum, r) => sum + _minutesFromTimeRange(r.timeRange));

  int get _lateMinutes => _filteredRecordsForSummary
      .where((r) => r.status == 'late')
      .fold<int>(0, (sum, r) => sum + _minutesFromTimeRange(r.timeRange));

  int get _totalAttendance =>
      _filteredRecordsForSummary.where((r) => r.status == 'present').length;
  int get _excusedAbsence =>
      _filteredRecordsForSummary.where((r) => r.status == 'excused').length;
  int get _unexcusedAbsence =>
      _filteredRecordsForSummary.where((r) => r.status == 'unexcused').length;
  int get _tardiness =>
      _filteredRecordsForSummary.where((r) => r.status == 'late').length;

  int get _totalAbsence => _excusedAbsence + _unexcusedAbsence;

  double get _attendancePercentage =>
      _totalPlannedMinutes == 0 ? 0 : (_presentMinutes / _totalPlannedMinutes) * 100;
  double get _excusedPercentage =>
      _totalPlannedMinutes == 0 ? 0 : (_excusedMinutes / _totalPlannedMinutes) * 100;
  double get _unexcusedPercentage =>
      _totalPlannedMinutes == 0 ? 0 : (_unexcusedMinutes / _totalPlannedMinutes) * 100;
  double get _tardinessPercentage =>
      _totalPlannedMinutes == 0 ? 0 : (_lateMinutes / _totalPlannedMinutes) * 100;

  double get _totalAbsencePercentage =>
      _totalPlannedMinutes == 0
          ? 0
          : ((_excusedMinutes + _unexcusedMinutes) / _totalPlannedMinutes) * 100;

  bool get _isTotalAbsenceOverLimit => _totalAbsencePercentage > 25;
  bool get _isExcusedAbsenceOverLimit => _excusedPercentage > 25;
  bool get _isUnexcusedAbsenceOverLimit => _unexcusedPercentage > 15;

  @override
  Widget build(BuildContext context) {
    final translation = TranslationController.instance;
    return AnimatedBuilder(
      animation: translation,
      builder: (context, _) => Directionality(
        textDirection: translation.textDirection,
        child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: const ChatFAB(),
        bottomNavigationBar: NavBarSettingsArabic(
          selectedIndex: 1,
          onItemTapped: (index) {
            if (index == 0) {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            } else if (index == 2) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            } else if (index == 1) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: _isLoading
                ? Column(
                    children: <Widget>[
                      _buildHeader(context),
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ],
                  )
                : _loadError != null
                ? Column(
                    children: <Widget>[
                      _buildHeader(context),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TText(
                                  _loadError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _bootstrapAttendance,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const TText('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _records.isEmpty
                ? Column(
                    children: <Widget>[
                      _buildHeader(context),
                      Expanded(
                        child: Center(
                          child: TText(
                            'لا توجد سجلات تحضير حتى الآن',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: <Widget>[
                      _buildHeader(context),
                      const SizedBox(height: 16),
                      _buildCourseTabs(),
                      const SizedBox(height: 16),
                      _buildAttendanceSummaryPerCourse(),
                      const SizedBox(height: 24),
                      _buildWeekFilterBar(),
                      const SizedBox(height: 24),
                      Expanded(child: _buildAttendanceLog()),
                    ],
                  ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final translation = TranslationController.instance;
    return Row(
      children: <Widget>[
        IconButton(
          icon: Transform(
            alignment: Alignment.center,
            transform: translation.textDirection == TextDirection.rtl
                ? Matrix4.rotationY(3.14159)
                : Matrix4.identity(),
            child: const Icon(
              Icons.arrow_back_ios,
              color: _primaryColor,
              size: 16,
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: TText(
            'تتبع الحضور',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 44),
        NotificationBell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAttendanceSummaryPerCourse() {
    final courses = _courses;
    if (courses.isEmpty) return const SizedBox.shrink();
    final selected =
        (_selectedCourse != null && courses.contains(_selectedCourse))
            ? _selectedCourse!
            : courses.first;
    return _CourseSummaryCard(
      courseLabel: selected,
      allRecords: _records,
      weekKeyToDisplay: _weekKeyToDisplay,
      selectedWeeks: _selectedWeeks,
      allWeeks: _weeks,
      weeksCountForTerm: _semesterWeeksCount,
      codeToWeeklyMinutes: _codeToWeeklyMinutes,
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required double percentage,
    required int count,
    required String label,
    bool isOverLimit = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '${percentage.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isOverLimit ? const Color(0xFFD32F2F) : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TText(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCourseTabs() {
    final translation = TranslationController.instance;
    final courses = _courses;
    if (courses.isEmpty) return const SizedBox.shrink();

    final selected =
        (_selectedCourse != null && courses.contains(_selectedCourse))
            ? _selectedCourse!
            : courses.first;
    if (selected != _selectedCourse) {
      _selectedCourse = selected;
    }

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _tabBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        reverse: translation.textDirection == TextDirection.rtl,
        child: Row(
          children: courses.map((String course) {
            final bool isActive = course == _selectedCourse;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => setState(() => _selectedCourse = course),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 36,
                  constraints: const BoxConstraints(minWidth: 110),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: isActive
                        ? const LinearGradient(
                            colors: <Color>[
                              Color(0xFF27A2A9),
                              Color(0xFF006571),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : null,
                    color: isActive ? null : Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: TText(
                    course,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : const Color(0xFF444444),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWeekFilterBar() {
    final weeks = _weeks;
    if (weeks.isEmpty) return const SizedBox.shrink();
    final allSelected = _selectedWeeks.length == weeks.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: false,
        child: Row(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedWeeks
                      ..clear()
                      ..addAll(weeks);
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: allSelected
                        ? const Color(0xFF27A2A9)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: TText(
                    'الكل',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: allSelected
                          ? Colors.white
                          : const Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            ...weeks.map((String week) {
              final bool isSelected = _selectedWeeks.contains(week);
              final String displayText = week.replaceFirst(' ', '\n');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedWeeks.remove(week);
                      } else {
                        _selectedWeeks.add(week);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF27A2A9)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: TText(
                      displayText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1A1A1A),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceLog() {
    final weekKeyToDisplay = _weekKeyToDisplay;
    final weeks = _weeks;
    final allWeeksSelected = _selectedWeeks.length == weeks.length;
    final noWeekFilter = allWeeksSelected;
    final filteredRecords = _records.where((record) {
      final type =
          (record.courseType.trim().isEmpty || record.courseType == '—')
          ? 'نظري'
          : record.courseType;
      final courseMatch = _selectedCourse == null
          ? true
          : ('${record.course} $type'.trim() == _selectedCourse);
      final weekLabel = weekKeyToDisplay[record.weekKey] ?? record.weekKey;
      final weekMatch = noWeekFilter || _selectedWeeks.contains(weekLabel);
      return courseMatch && weekMatch;
    }).toList();
    filteredRecords.sort((a, b) => b.lectureDate.compareTo(a.lectureDate));

    if (filteredRecords.isEmpty) {
      return const Center(
        child: TText(
          'لا توجد سجلات',
          style: TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: TText(
            'سجل الحضور',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: filteredRecords.length,
            itemBuilder: (BuildContext context, int index) {
              final record = filteredRecords[index];
              final weekLabel =
                  weekKeyToDisplay[record.weekKey] ?? record.weekKey;
              return _AttendanceCard(record: record, weekLabel: weekLabel);
            },
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.excusedPercentage,
    required this.unexcusedPercentage,
    this.unexcusedOverLimit,
  });

  final double excusedPercentage;
  final double unexcusedPercentage;
  final bool? unexcusedOverLimit;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 20.0;

    double startAngle = -math.pi / 2;

    final totalAbsence =
        (excusedPercentage + unexcusedPercentage).clamp(0, 100).toDouble();
    final denom = totalAbsence <= 0 ? 1.0 : totalAbsence;

    final excusedSweep = (excusedPercentage / denom) * 2 * math.pi;
    final excusedPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      excusedSweep,
      false,
      excusedPaint,
    );
    startAngle += excusedSweep;

    final unexcusedSweep = (unexcusedPercentage / denom) * 2 * math.pi;
    final unexcusedPaint = Paint()
      ..color = (unexcusedOverLimit ?? false)
          ? const Color(0xFFD32F2F)
          : const Color(0xFFFF9800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      unexcusedSweep,
      false,
      unexcusedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return excusedPercentage != oldDelegate.excusedPercentage ||
        unexcusedPercentage != oldDelegate.unexcusedPercentage ||
        unexcusedOverLimit != oldDelegate.unexcusedOverLimit;
  }
}

class _AttendanceRecord {
  _AttendanceRecord({
    this.courseCode,
    required this.courseKey,
    required this.courseName,
    required this.sectionLabel,
    required this.courseTypeLabel,
    required this.course,
    required this.courseType,
    required this.weekKey,
    required this.day,
    required this.lectureDate,
    required this.timeRange,
    required this.dayName,
    required this.status,
  });

  final String? courseCode;
  final String courseKey;
  final String courseName;
  final String sectionLabel;
  final String courseTypeLabel;
  final String course;
  final String courseType;
  final String weekKey;
  final String day;
  final DateTime lectureDate;
  final String timeRange;
  final String dayName;
  final String status;
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.record, required this.weekLabel});

  final _AttendanceRecord record;
  final String weekLabel;

  Color get _badgeColor {
    switch (record.status) {
      case 'present':
        return const Color(0xFF006571);
      case 'late':
        return const Color(0xFFFF9800);
      case 'excused':
        return const Color(0xFF2196F3);
      case 'unexcused':
        return const Color(0xFFE57373);
      default:
        return const Color(0xFF006571);
    }
  }

  @override
  Widget build(BuildContext context) {
    final translation = TranslationController.instance;
    final isLtr = translation.textDirection == TextDirection.ltr;
    final cross = isLtr ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final textAlign = isLtr ? TextAlign.left : TextAlign.right;

    final badge = Container(
      width: 46,
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: _badgeColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            record.day,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          TText(
            record.dayName,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    final timeColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: <Widget>[
        Text(
          record.timeRange,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 2),
        TText(
          'مدة المحاضرة',
          style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A)),
          textAlign: textAlign,
        ),
      ],
    );

    final details = Expanded(
      child: Align(
        alignment:
            isLtr ? Alignment.centerLeft : Alignment.centerRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: cross,
          children: <Widget>[
            TText(
              record.course,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: textAlign,
            ),
            const SizedBox(height: 2),
            TText(
              (record.courseType.isEmpty || record.courseType == '—')
                  ? 'نظري'
                  : record.courseType,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: textAlign,
            ),
            const SizedBox(height: 2),
            TText(
              weekLabel,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: textAlign,
            ),
          ],
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Directionality(
        textDirection: translation.textDirection,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isLtr) ...[
              details,
              const SizedBox(width: 10),
              timeColumn,
              const SizedBox(width: 10),
              badge,
            ] else ...[
              badge,
              const SizedBox(width: 10),
              details,
              const SizedBox(width: 10),
              timeColumn,
            ],
          ],
        ),
      ),
    );
  }
}

class _CourseSummaryCard extends StatelessWidget {
  const _CourseSummaryCard({
    required this.courseLabel,
    required this.allRecords,
    required this.weekKeyToDisplay,
    required this.selectedWeeks,
    required this.allWeeks,
    required this.weeksCountForTerm,
    required this.codeToWeeklyMinutes,
  });

  final String courseLabel;
  final List<_AttendanceRecord> allRecords;
  final Map<String, String> weekKeyToDisplay;
  final Set<String> selectedWeeks;
  final List<String> allWeeks;
  final int weeksCountForTerm;
  final Map<String, int> codeToWeeklyMinutes;

  int _truncatePct(double v) {
    if (!v.isFinite || v <= 0) return 0;
    return v.floor().clamp(0, 100);
  }

  int _minutesFromTimeRange(String timeRange) {
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

  bool _matchesCourse(_AttendanceRecord r) {
    final type =
        (r.courseType.trim().isEmpty || r.courseType == '—') ? 'نظري' : r.courseType;
    return ('${r.course} $type'.trim() == courseLabel);
  }

  List<_AttendanceRecord> _filteredCourseRecords() {
    final allWeeksSelected = selectedWeeks.length == allWeeks.length;
    final noWeekFilter = allWeeksSelected;
    final filtered = allRecords.where((r) {
      if (!_matchesCourse(r)) return false;
      final weekLabel = weekKeyToDisplay[r.weekKey] ?? r.weekKey;
      final weekMatch = noWeekFilter || selectedWeeks.contains(weekLabel);
      return weekMatch;
    }).toList();
    filtered.sort((a, b) => b.lectureDate.compareTo(a.lectureDate));
    return filtered;
  }

  int _filteredWeeksCount() {
    if (allWeeks.isEmpty) return weeksCountForTerm;
    final allWeeksSelected = selectedWeeks.length == allWeeks.length;
    if (allWeeksSelected) return weeksCountForTerm;
    return selectedWeeks.length.clamp(0, weeksCountForTerm);
  }

  int _weeklyMinutesFromDb(List<_AttendanceRecord> records) {
    int weekly = 0;
    final codes = records
        .map((r) => r.courseCode)
        .whereType<String>()
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    for (final code in codes) {
      final v = codeToWeeklyMinutes[code];
      if (v != null && v > weekly) weekly = v;
    }
    return weekly;
  }

  int _weeklyMinutesFallback(List<_AttendanceRecord> records) {
    final byWeek = <String, Map<String, int>>{};
    for (final r in records) {
      final minutes = _minutesFromTimeRange(r.timeRange);
      if (minutes <= 0) continue;
      final sessionKey =
          '${r.courseKey}|${r.lectureDate.toIso8601String()}|${r.timeRange}';
      byWeek.putIfAbsent(r.weekKey, () => <String, int>{})[sessionKey] = minutes;
    }
    int maxMinutes = 0;
    for (final sessions in byWeek.values) {
      final total = sessions.values.fold<int>(0, (a, b) => a + b);
      maxMinutes = math.max(maxMinutes, total);
    }
    return maxMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final records = _filteredCourseRecords();
    if (records.isEmpty) return const SizedBox.shrink();

    final presentMinutes = records
        .where((r) => r.status == 'present')
        .fold<int>(0, (s, r) => s + _minutesFromTimeRange(r.timeRange));
    final excusedMinutes = records
        .where((r) => r.status == 'excused')
        .fold<int>(0, (s, r) => s + _minutesFromTimeRange(r.timeRange));
    final unexcusedMinutes = records
        .where((r) => r.status == 'unexcused')
        .fold<int>(0, (s, r) => s + _minutesFromTimeRange(r.timeRange));
    final lateMinutes = records
        .where((r) => r.status == 'late')
        .fold<int>(0, (s, r) => s + _minutesFromTimeRange(r.timeRange));

    final weeklyFromDb = _weeklyMinutesFromDb(records);
    final weeklyFallback = _weeklyMinutesFallback(records);
    final weekly = weeklyFromDb > 0 ? weeklyFromDb : weeklyFallback;
    final filteredWeeksCount = _filteredWeeksCount();
    final planned = weekly * filteredWeeksCount;
    final totalPlannedMinutes = planned > 0
        ? planned
        : records.fold<int>(0, (s, r) => s + _minutesFromTimeRange(r.timeRange));

    if (kDebugMode) {
      final courseCodes = records
          .map((r) => r.courseCode?.trim())
          .whereType<String>()
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final dbWeeklyByCode = <String, int>{};
      for (final c in courseCodes) {
        final v = codeToWeeklyMinutes[c];
        if (v != null) dbWeeklyByCode[c] = v;
      }

      debugPrint(
        '[AttendanceTracking] course="$courseLabel" '
        'courseCodes=$courseCodes '
        'dbWeeklyByCode=$dbWeeklyByCode '
        'weeklyFromDb=$weeklyFromDb '
        'weeklyFallback=$weeklyFallback '
        'weeklyUsed=$weekly '
        'filteredWeeksCount=$filteredWeeksCount '
        'planned=$planned '
        'totalPlannedMinutes=$totalPlannedMinutes',
      );
    }

    double pct(int minutes) =>
        totalPlannedMinutes == 0 ? 0 : (minutes / totalPlannedMinutes) * 100;

    final excusedPct = pct(excusedMinutes);
    final unexcusedPct = pct(unexcusedMinutes);
    final totalAbsencePct = pct(excusedMinutes + unexcusedMinutes);
    final unexcusedOverLimit = unexcusedPct > 15;
    final totalOverLimit = totalAbsencePct > 25;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TText(
                  courseLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 10),
                _LegendRow(
                  color: const Color(0xFF006571),
                  label: 'الحضور',
                  percentage: pct(presentMinutes),
                ),
                const SizedBox(height: 8),
                _LegendRow(
                  color: const Color(0xFF2196F3),
                  label: 'بعذر',
                  percentage: excusedPct,
                  isOverLimit: excusedPct > 25,
                ),
                const SizedBox(height: 8),
                _LegendRow(
                  color: const Color(0xFFFF9800),
                  label: 'بدون عذر',
                  percentage: unexcusedPct,
                  isOverLimit: unexcusedOverLimit,
                ),
                const SizedBox(height: 8),
                _LegendRow(
                  color: const Color(0xFFFFC107),
                  label: 'تأخير',
                  percentage: pct(lateMinutes),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(110, 110),
                  painter: _DonutChartPainter(
                    excusedPercentage: excusedPct,
                    unexcusedPercentage: unexcusedPct,
                    unexcusedOverLimit: unexcusedOverLimit,
                  ),
                ),
                Text(
                  '${_truncatePct(totalAbsencePct)}%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: totalOverLimit
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF006571),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.percentage,
    this.isOverLimit = false,
  });

  final Color color;
  final String label;
  final double percentage;
  final bool isOverLimit;

  int _truncatePct(double v) {
    if (!v.isFinite || v <= 0) return 0;
    return v.floor().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final pctInt = _truncatePct(percentage);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$pctInt%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isOverLimit
                ? const Color(0xFFD32F2F)
                : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 6),
        TText(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A)),
        ),
      ],
    );
  }
}
