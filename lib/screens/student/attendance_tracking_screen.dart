import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/attendance_schedule_slot.dart';
import '../../models/attendance/manual_attendance_record.dart';
import '../../providers/courses_providers.dart';
import '../../repositories/academic_term_context_repository.dart';
import '../../repositories/student_attendance_meta_repository.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/student_auth_service.dart';
import 'components/custom_nav_bar_icons.dart';
import 'components/notification_bell.dart';
import 'components/student_back_chevron_icon.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import '../../shared/widgets/chat_fab.dart';
import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';

class AttendanceTrackingScreen extends ConsumerStatefulWidget {
  const AttendanceTrackingScreen({super.key});

  @override
  ConsumerState<AttendanceTrackingScreen> createState() =>
      _AttendanceTrackingScreenState();
}

class _AttendanceTrackingScreenState
    extends ConsumerState<AttendanceTrackingScreen> {
  static const Color _primaryColor = Color(0xFF006571);
  static const Color _tabBackground = Color(0xFFF5F5F5);
  final ManualAttendanceService _manualAttendanceService =
      ManualAttendanceService.instance;
  StreamSubscription<List<ManualAttendanceRecord>>? _recordsSubscription;

  List<_AttendanceRecord> _records = <_AttendanceRecord>[];
  Map<String, int> _codeToWeeklyMinutes = <String, int>{};
  Map<String, int> _sectionIdToWeeklyMinutes = <String, int>{};
  String? _selectedCourse;
  final Set<String> _selectedWeeks = <String>{};
  bool _allWeeksMode = true; // "الكل" toggle state
  bool _weekFilterTouchedByUser = false;
  bool _isLoading = true;
  String? _loadError;
  int _semesterWeeksCount = 15;
  DateTime? _semesterStartDate;

  int _statusPriority(String status) {
    switch (status) {
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

  List<_AttendanceRecord> _dedupeAttendanceRecords(List<_AttendanceRecord> input) {
    // Collapse duplicates that represent the same session (same section/date/time).
    // If duplicates exist, keep the "best" status to avoid showing حاضر+غائب لنفس الجلسة.
    final map = <String, _AttendanceRecord>{};
    for (final r in input) {
      final sid = (r.sectionId ?? '').trim();
      final key = [
        sid.isEmpty ? r.courseKey : sid,
        r.lectureDate.toIso8601String(),
        r.timeRange.trim(),
      ].join('|');

      final prev = map[key];
      if (prev == null) {
        map[key] = r;
        continue;
      }
      if (_statusPriority(r.status) >= _statusPriority(prev.status)) {
        map[key] = r;
      }
    }
    final out = map.values.toList();
    out.sort((a, b) => b.lectureDate.compareTo(a.lectureDate));
    return out;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final student = StudentAuthService.instance.currentStudent;
      if (student == null) return;
      // Warm unified courses so the attendance stream callback does not block
      // on a cold Firestore path after the first snapshot.
      unawaited(
        ref.read(studentUnifiedCoursesProvider(student.studentId.toString()).future),
      );
    });
    _bootstrapAttendance();
  }

  @override
  void dispose() {
    _recordsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrapAttendance() async {
    // Never block attendance records on term metadata — a stuck `academic_terms`
    // query would leave this screen on the loading spinner forever.
    unawaited(_loadAcademicTermContext());
    await _subscribeAttendance();
  }

  Future<void> _loadAcademicTermContext() async {
    try {
      final ctx = await AcademicTermContextRepository.instance
          .loadCurrentWeekContext()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      if (ctx == null) return;
      if (!mounted) return;
      setState(() {
        _semesterWeeksCount = ctx.weeks;
        _semesterStartDate = ctx.start ?? _semesterStartDate;
      });
      if (kDebugMode) {
        debugPrint(
          '[AttendanceTracking] term context weeks=$_semesterWeeksCount start=$_semesterStartDate',
        );
      }
    } catch (e) {
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
            try {
              final unified = await ref.read(
                studentUnifiedCoursesProvider(student.studentId.toString()).future,
              );
              final metaMaps =
                  StudentAttendanceMetaRepository.instance.buildFromEnrollments(
                unified.allCourses,
                records,
              );
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
                      metaMaps.sectionIdToScheduleSlots,
                      semesterStart,
                    ),
                  )
                  .toList();
              mapped.sort((a, b) => b.lectureDate.compareTo(a.lectureDate));
              final deduped = _dedupeAttendanceRecords(mapped);
              if (!mounted) return;
              setState(() {
                _records = deduped;
                _codeToWeeklyMinutes = metaMaps.codeToWeeklyMinutes;
                _sectionIdToWeeklyMinutes = metaMaps.sectionIdToWeeklyMinutes;
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
            } catch (e, st) {
              if (kDebugMode) {
                debugPrint('[AttendanceTracking] stream handler error: $e\n$st');
              }
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _loadError ??= 'تعذر تحميل بيانات المقررات المرتبطة بالحضور.';
              });
            }
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

  _AttendanceRecord _toAttendanceRecord(
    ManualAttendanceRecord record,
    Map<String, String> codeToType,
    Map<String, String> sectionIdToType,
    Map<String, String> codeToNameAr,
    Map<String, List<AttendanceScheduleSlot>> sectionIdToScheduleSlots,
    DateTime? semesterStart,
  ) {
    final status = switch (record.status) {
      ManualAttendanceStatus.pending => 'pending',
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
    final weekday = lectureDate.weekday; // Dart: Mon=1..Sun=7
    String startTime = record.lectureStartTime;
    String endTime = record.lectureEndTime;
    final slots =
        sectionIdToScheduleSlots[record.sectionId.trim()] ??
            const <AttendanceScheduleSlot>[];
    if (slots.isNotEmpty) {
      final daySlots = slots.where((s) => s.dayOfWeek == weekday).toList();
      if (daySlots.isNotEmpty) {
        final matchesAny = daySlots.any(
          (s) => s.startTime == startTime.trim() && s.endTime == endTime.trim(),
        );
        // If time doesn't match schedule:
        // - if exactly 1 slot that day, force it (fixes wrong stored times)
        // - if multiple slots, keep original unless it matches
        if (!matchesAny) {
          if (daySlots.length == 1) {
            startTime = daySlots.first.startTime;
            endTime = daySlots.first.endTime;
          }
        }
      }
    }
    final weekKey = _semesterWeekKey(lectureDate, semesterStart);
    final day = lectureDate.day.toString().padLeft(2, '0');
    return _AttendanceRecord(
      courseCode: record.courseCode,
      sectionId: record.sectionId.trim().isEmpty ? null : record.sectionId,
      courseKey: '$courseName • شعبة $sectionText',
      courseName: courseName,
      sectionLabel: sectionText,
      courseTypeLabel: courseType,
      course: courseName,
      courseType: courseType,
      weekKey: weekKey,
      day: day,
      lectureDate: lectureDate,
      timeRange: '$startTime-$endTime',
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
    // When "All" mode is on, we don't need explicit selections.
    if (_allWeeksMode) return;
    if (_selectedWeeks.isEmpty) return;
    _selectedWeeks.removeWhere((week) => !weeks.contains(week));
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

  List<_AttendanceRecord> get _filteredRecordsForSummary {
    final weekKeyToDisplay = _weekKeyToDisplay;
    final weeks = _weeks;
    final noWeekFilter = _allWeeksMode;
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
    if (_allWeeksMode) return _semesterWeeksCount;
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
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
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
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      children: <Widget>[
                                        _buildCourseTabs(),
                                        const SizedBox(height: 16),
                                        _buildAttendanceSummaryPerCourse(),
                                        const SizedBox(height: 24),
                                        _buildWeekFilterBar(),
                                        const SizedBox(height: 24),
                                        _buildAttendanceLog(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: StudentBackChevronIcon(
            color: _primaryColor,
            size: 16,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TText(
              TranslationController.instance.translateToEnglish
                  ? 'Attendance tracking'
                  : 'تتبع الحضور',
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
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
      sectionIdToWeeklyMinutes: _sectionIdToWeeklyMinutes,
      allWeeksMode: _allWeeksMode,
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
    final allSelected = _allWeeksMode;
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
                  if (weeks.isEmpty) return;
                  setState(() {
                    _weekFilterTouchedByUser = true;
                    if (_allWeeksMode) {
                      // Toggle OFF: show nothing until user selects weeks
                      _allWeeksMode = false;
                      _selectedWeeks.clear();
                      return;
                    }
                    // Toggle ON: All mode
                    _allWeeksMode = true;
                    _selectedWeeks.clear();
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
              final bool isSelected =
                  _allWeeksMode || _selectedWeeks.contains(week);
              final String displayText = week.replaceFirst(' ', '\n');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _weekFilterTouchedByUser = true;
                      if (_allWeeksMode) _allWeeksMode = false;
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
    final noWeekFilter = _allWeeksMode;
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
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredRecords.length,
          itemBuilder: (BuildContext context, int index) {
            final record = filteredRecords[index];
            final weekLabel = weekKeyToDisplay[record.weekKey] ?? record.weekKey;
            return _AttendanceCard(record: record, weekLabel: weekLabel);
          },
        ),
        const SizedBox(height: 16),
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
    this.sectionId,
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
  final String? sectionId;
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
    required this.sectionIdToWeeklyMinutes,
    required this.allWeeksMode,
  });

  final String courseLabel;
  final List<_AttendanceRecord> allRecords;
  final Map<String, String> weekKeyToDisplay;
  final Set<String> selectedWeeks;
  final List<String> allWeeks;
  final int weeksCountForTerm;
  final Map<String, int> codeToWeeklyMinutes;
  final Map<String, int> sectionIdToWeeklyMinutes;
  final bool allWeeksMode;

  /// عرض النسبة كعدد صحيح (تقريب أقرب) ليتوافق مع فهم المستخدم والوسط في الدائرة.
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
    final noWeekFilter = allWeeksMode;
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
    if (allWeeksMode) return weeksCountForTerm;
    return selectedWeeks.length.clamp(1, weeksCountForTerm);
  }

  int _weeklyMinutesFromDb(List<_AttendanceRecord> records) {
    int weekly = 0;
    // Priority: section schedule-derived weekly minutes
    final sectionIds = records
        .map((r) => (r.sectionId ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    for (final sid in sectionIds) {
      final v = sectionIdToWeeklyMinutes[sid];
      if (v != null && v > weekly) weekly = v;
    }

    // Fallback: course schedule-derived weekly minutes (or explicit weekly hours if present)
    if (weekly <= 0) {
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

    final weeklyFromDb = _weeklyMinutesFromDb(records);
    final weeklyFallback = _weeklyMinutesFallback(records);
    final weekly = weeklyFromDb > 0 ? weeklyFromDb : weeklyFallback;
    // Denominator weeks are ALWAYS the full effective teaching weeks for term.
    // Week filter affects the numerator (which records are included), not the denominator.
    final denomWeeks = weeksCountForTerm;

    // Compute minutes per status from the actual lecture time range so that:
    // - Excused % = (excusedHours / totalTermHours) * 100
    // - Unexcused % = (unexcusedHours / totalTermHours) * 100
    // - Total absence % = sum of both
    //
    // If timeRange can't be parsed, fall back to an estimated session duration.
    int sessionsPerWeek = 0;
    final byWeek = <String, Set<String>>{};
    for (final r in records) {
      final key = '${r.courseKey}|${r.lectureDate.toIso8601String()}|${r.timeRange}';
      byWeek.putIfAbsent(r.weekKey, () => <String>{}).add(key);
    }
    for (final s in byWeek.values) {
      if (s.length > sessionsPerWeek) sessionsPerWeek = s.length;
    }
    final estimatedSessionMinutes =
        (weekly > 0 && sessionsPerWeek > 0) ? (weekly / sessionsPerWeek) : 120.0;

    int minutesFor(_AttendanceRecord r) {
      final m = _minutesFromTimeRange(r.timeRange);
      if (m > 0) return m;
      return estimatedSessionMinutes.round();
    }

    int sumWhere(bool Function(_AttendanceRecord) p) => records
        .where(p)
        .fold<int>(0, (s, r) => s + minutesFor(r));

    final presentMinutes = sumWhere((r) => r.status == 'present');
    final excusedMinutes = sumWhere((r) => r.status == 'excused');
    final unexcusedMinutes =
        sumWhere((r) => r.status == 'unexcused' || r.status == 'absent');
    final lateMinutes = sumWhere((r) => r.status == 'late');

    final totalPlannedMinutes =
        (weekly > 0 && denomWeeks > 0) ? (weekly * denomWeeks) : 0;

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
        'sessionsPerWeek=$sessionsPerWeek '
        'estimatedSessionMinutes=$estimatedSessionMinutes '
        'weeksForDenominator=$denomWeeks '
        'totalPlannedMinutes=$totalPlannedMinutes',
      );
    }

    double pct(int minutes) => totalPlannedMinutes <= 0
        ? 0
        : (minutes / totalPlannedMinutes) * 100;

    final excusedPct = pct(excusedMinutes);
    final unexcusedPct = pct(unexcusedMinutes);
    final totalAbsencePct = pct(excusedMinutes + unexcusedMinutes);
    final unexcusedOverLimit = unexcusedPct > 15;
    final totalOverLimit = totalAbsencePct > 25;
    final excusedOverLimit = excusedPct > 25;
    final academicDeprivation =
        unexcusedOverLimit || excusedOverLimit || totalOverLimit;

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
                  color: const Color(0xFFFF9800),
                  label: 'الغياب بدون عذر',
                  percentage: unexcusedPct,
                  isOverLimit: unexcusedOverLimit,
                ),
                const SizedBox(height: 8),
                _LegendRow(
                  color: const Color(0xFF2196F3),
                  label: 'الغياب بعذر',
                  percentage: excusedPct,
                  isOverLimit: excusedOverLimit,
                ),
                const SizedBox(height: 8),
                _LegendRow(
                  color: const Color(0xFFFFC107),
                  label: 'تأخير',
                  percentage: pct(lateMinutes),
                ),
                const SizedBox(height: 8),
                _LegendRow(
                  color: const Color(0xFFC62828),
                  label: 'إجمالي الغياب',
                  percentage: totalAbsencePct,
                  isOverLimit: totalOverLimit,
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
                academicDeprivation
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '${_truncatePct(totalAbsencePct)}%',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD32F2F),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'حرمان أكاديمي',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD32F2F),
                              height: 1.1,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '${_truncatePct(totalAbsencePct)}%',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006571),
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
