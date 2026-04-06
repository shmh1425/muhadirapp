import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
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
  String _selectedCourse = 'الكل';
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
      final snapshot = await FirebaseFirestore.instance
          .collection('academic_terms')
          .where('isActive', isEqualTo: true)
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
      final weeks =
          _readPositiveInt(data['effectiveTeachingWeeks']) ??
          _readPositiveInt(data['officialWeeksCount']) ??
          _readPositiveInt(data['semesterWeeks']) ??
          _semesterWeeksCount;
      _semesterWeeksCount = weeks.clamp(1, 20);
      _semesterStartDate = _readDate(data['startDate']);
    } catch (_) {
      // Keep defaults if term context is unavailable.
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
            final typeMaps = await _fetchCourseTypesForRecords(records);
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
                    typeMaps.codeToType,
                    typeMaps.sectionIdToType,
                    semesterStart,
                  ),
                )
                .toList();
            mapped.sort((a, b) => b.lectureDate.compareTo(a.lectureDate));
            if (!mounted) return;
            setState(() {
              _records = mapped;
              _isLoading = false;
              _loadError = null;
              _syncSelectedWeeksWithAvailable();
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

  /// جلب courseType من courses ثم sections للسجلات اللي ما عندها نوع
  Future<
    ({Map<String, String> codeToType, Map<String, String> sectionIdToType})
  >
  _fetchCourseTypesForRecords(List<ManualAttendanceRecord> records) async {
    final needType = records
        .where((r) => (r.courseType ?? '').trim().isEmpty)
        .toList();
    if (needType.isEmpty) {
      return (
        codeToType: <String, String>{},
        sectionIdToType: <String, String>{},
      );
    }

    final firestore = FirebaseFirestore.instance;
    final codeToType = <String, String>{};
    final sectionIdToType = <String, String>{};

    final codes = needType
        .where((r) => (r.courseCode ?? '').trim().isNotEmpty)
        .map((r) => r.courseCode!.trim())
        .toSet()
        .toList();
    String typeFromMap(Map<String, dynamic>? d) {
      if (d == null) return '';
      final v = d['courseType'] ?? d['course_type'] ?? d['CourseType'] ?? '';
      return (v ?? '').toString().trim();
    }

    for (final code in codes) {
      final doc = await firestore.collection('courses').doc(code).get();
      if (doc.exists) {
        final type = typeFromMap(doc.data());
        if (type.isNotEmpty) codeToType[code] = type;
      }
    }

    final sectionIds = needType
        .where((r) => (r.sectionId).trim().isNotEmpty)
        .map((r) => r.sectionId.trim())
        .toSet()
        .toList();
    for (final sectionId in sectionIds) {
      if (sectionIdToType.containsKey(sectionId)) continue;
      final doc = await firestore.collection('sections').doc(sectionId).get();
      if (doc.exists) {
        final type = typeFromMap(doc.data());
        if (type.isNotEmpty) sectionIdToType[sectionId] = type;
      }
    }

    return (codeToType: codeToType, sectionIdToType: sectionIdToType);
  }

  _AttendanceRecord _toAttendanceRecord(
    ManualAttendanceRecord record,
    Map<String, String> codeToType,
    Map<String, String> sectionIdToType,
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
    final courseName = (record.courseName).trim().isEmpty
        ? '—'
        : record.courseName;
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

  static const List<String> _weekOrdinals = <String>[
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
    'السابع',
    'الثامن',
    'التاسع',
    'العاشر',
    'الحادي عشر',
    'الثاني عشر',
    'الثالث عشر',
    'الرابع عشر',
    'الخامس عشر',
    'السادس عشر',
    'السابع عشر',
    'الثامن عشر',
    'التاسع عشر',
    'العشرون',
  ];

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
    return <String>['الكل', ...list];
  }

  String _weekOrdinal(int index) =>
      index < _weekOrdinals.length ? _weekOrdinals[index] : '${index + 1}';

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
      (i) => 'الأسبوع ${_weekOrdinal(i)}',
    );
  }

  Map<String, String> get _weekKeyToDisplay {
    final map = <String, String>{};
    for (var i = 0; i < _semesterWeeksCount; i++) {
      map[i.toString()] = 'الأسبوع ${_weekOrdinal(i)}';
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

  int get _total => _records.length;
  int get _totalAttendance =>
      _records.where((r) => r.status == 'present').length;
  int get _excusedAbsence =>
      _records.where((r) => r.status == 'excused').length;
  int get _unexcusedAbsence =>
      _records.where((r) => r.status == 'unexcused').length;
  int get _tardiness => _records.where((r) => r.status == 'late').length;

  double get _attendancePercentage =>
      _total == 0 ? 0 : (_totalAttendance / _total) * 100;
  double get _excusedPercentage =>
      _total == 0 ? 0 : (_excusedAbsence / _total) * 100;
  double get _unexcusedPercentage =>
      _total == 0 ? 0 : (_unexcusedAbsence / _total) * 100;
  double get _tardinessPercentage =>
      _total == 0 ? 0 : (_tardiness / _total) * 100;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
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
                                Text(
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
                                  label: const Text('إعادة المحاولة'),
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
                      const Expanded(
                        child: Center(
                          child: Text(
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
                      const SizedBox(height: 24),
                      _buildAttendanceSummary(),
                      const SizedBox(height: 24),
                      _buildWeekFilterBar(),
                      const SizedBox(height: 24),
                      Expanded(child: _buildAttendanceLog()),
                    ],
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
          icon: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.14159),
            child: const Icon(
              Icons.arrow_back_ios,
              color: _primaryColor,
              size: 16,
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Text(
            'تتبع الحضور',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
        ),
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

  Widget _buildAttendanceSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildLegendItem(
                  color: const Color(0xFF006571),
                  percentage: _attendancePercentage,
                  count: _totalAttendance,
                  label: 'الحضور',
                ),
                const SizedBox(height: 12),
                _buildLegendItem(
                  color: const Color(0xFF2196F3),
                  percentage: _excusedPercentage,
                  count: _excusedAbsence,
                  label: 'الغياب بعذر',
                ),
                const SizedBox(height: 12),
                _buildLegendItem(
                  color: const Color(0xFFFF9800),
                  percentage: _unexcusedPercentage,
                  count: _unexcusedAbsence,
                  label: 'الغياب بدون عذر',
                ),
                const SizedBox(height: 12),
                _buildLegendItem(
                  color: const Color(0xFFFFC107),
                  percentage: _tardinessPercentage,
                  count: _tardiness,
                  label: 'التأخير',
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CustomPaint(
                  size: const Size(120, 120),
                  painter: _DonutChartPainter(
                    attendancePercentage: _attendancePercentage,
                    excusedPercentage: _excusedPercentage,
                    unexcusedPercentage: _unexcusedPercentage,
                    tardinessPercentage: _tardinessPercentage,
                  ),
                ),
                Text(
                  '${_attendancePercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required double percentage,
    required int count,
    required String label,
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
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
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
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCourseTabs() {
    final courses = _courses;
    if (courses.isEmpty) return const SizedBox.shrink();
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
        reverse: true,
        child: Row(
          children: courses.map((String course) {
            final bool isActive = course == _selectedCourse;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedCourse = course);
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 36,
                  constraints: const BoxConstraints(minWidth: 100),
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
                  child: Text(
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
        reverse: true,
        child: Row(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (allSelected) {
                      _selectedWeeks.clear();
                    } else {
                      _selectedWeeks.addAll(weeks);
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
                    color: allSelected
                        ? const Color(0xFF27A2A9)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
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
                    child: Text(
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
      final courseMatch =
          _selectedCourse == 'الكل' ||
          ('${record.course} $type'.trim() == _selectedCourse);
      final weekLabel = weekKeyToDisplay[record.weekKey] ?? record.weekKey;
      final weekMatch = noWeekFilter || _selectedWeeks.contains(weekLabel);
      return courseMatch && weekMatch;
    }).toList();
    filteredRecords.sort((a, b) => b.lectureDate.compareTo(a.lectureDate));

    if (filteredRecords.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد سجلات',
          style: TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'سجل الحضور',
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
    required this.attendancePercentage,
    required this.excusedPercentage,
    required this.unexcusedPercentage,
    required this.tardinessPercentage,
  });

  final double attendancePercentage;
  final double excusedPercentage;
  final double unexcusedPercentage;
  final double tardinessPercentage;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 20.0;

    double startAngle = -math.pi / 2;

    final attendanceSweep = (attendancePercentage / 100) * 2 * math.pi;
    final attendancePaint = Paint()
      ..color = const Color(0xFF006571)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      attendanceSweep,
      false,
      attendancePaint,
    );
    startAngle += attendanceSweep;

    final excusedSweep = (excusedPercentage / 100) * 2 * math.pi;
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

    final unexcusedSweep = (unexcusedPercentage / 100) * 2 * math.pi;
    final unexcusedPaint = Paint()
      ..color = const Color(0xFFFF9800)
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
    startAngle += unexcusedSweep;

    final tardinessSweep = (tardinessPercentage / 100) * 2 * math.pi;
    final tardinessPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      tardinessSweep,
      false,
      tardinessPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return attendancePercentage != oldDelegate.attendancePercentage ||
        excusedPercentage != oldDelegate.excusedPercentage ||
        unexcusedPercentage != oldDelegate.unexcusedPercentage ||
        tardinessPercentage != oldDelegate.tardinessPercentage;
  }
}

class _AttendanceRecord {
  _AttendanceRecord({
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
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
                Text(
                  record.dayName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    record.course,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (record.courseType.isEmpty || record.courseType == '—')
                        ? 'نظري'
                        : record.courseType,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    weekLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                record.timeRange,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 2),
              const Text(
                'مدة المحاضرة',
                style: TextStyle(fontSize: 11, color: Color(0xFF1A1A1A)),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
