import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/calendar_day.dart';
import '../../models/attendance/manual_attendance_record.dart';
import '../../models/attendance/manual_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/lecturer/calendar_service.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/lecturer_sections_service.dart';
import '../../utils/shared/time_utils.dart';
import 'lecturer_language.dart';
import 'lecturer_navigation.dart';
import 'widgets/modern_popup_dialog.dart';
import 'widgets/profile_back_button.dart';
import '../../widgets/monthly_calendar.dart';

class LecturerAttendanceReportScreen extends StatefulWidget {
  const LecturerAttendanceReportScreen({super.key});

  @override
  State<LecturerAttendanceReportScreen> createState() =>
      _LecturerAttendanceReportScreenState();
}

class _LecturerAttendanceReportScreenState
    extends State<LecturerAttendanceReportScreen> {
  static const Color _primary = Color(0xFF006571);
  static const List<int> _defaultWeekdayOrder = [7, 1, 2, 3, 4];
  static const List<int> _allWeekdayOrder = [7, 1, 2, 3, 4, 5, 6];

  final ManualAttendanceService _manualAttendanceService =
      ManualAttendanceService.instance;
  final LectureRepository _calendarRepository = LectureRepository();
  late final CalendarService _calendarService;
  StreamSubscription<void>? _calendarSyncSub;
  DateTime _calendarNow = DateTime.now();
  bool _isSyncRefreshing = false;
  List<LectureItem> _lecturerLectures = <LectureItem>[];
  LectureItem? _selectedLectureForCalendar;
  DateTime _calendarSelectedDate = DateTime.now();
  DateTime _calendarSelectedMonth = DateTime.now();

  List<_LectureAttendanceGroup> _groups = <_LectureAttendanceGroup>[];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  bool _isEditMode = false;
  bool _hasPendingChanges = false;
  bool _weekIsAuto = true;
  final bool _showLegacyReportPanel = false;
  int? _selectedWeekNumber;
  late int _selectedDayOfWeek;
  String? _selectedCourse;
  String? _selectedSection;
  String? _selectedSessionId;
  _StatusFilter _statusFilter = _StatusFilter.all;
  Map<String, _AttendanceStatus> _draftStatuses = <String, _AttendanceStatus>{};

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  @override
  void initState() {
    super.initState();
    _calendarService = CalendarService(_calendarRepository);
    _selectedDayOfWeek = DateTime.now().weekday;
    _calendarSyncSub = CalendarSyncService.instance.watchChanges().listen(
      (_) => _handleRealtimeCalendarChange(),
    );
    _loadReportData();
  }

  @override
  void dispose() {
    _calendarSyncSub?.cancel();
    super.dispose();
  }

  int get _currentWeekNumber => _calendarRepository.getWeekNumber(_calendarNow);
  int get _maxSelectableWeeks => _calendarRepository.semesterWeeks.clamp(1, 60);
  int get _displayWeekNumber => _weekIsAuto
      ? _currentWeekNumber
      : (_selectedWeekNumber ?? _currentWeekNumber);

  List<_LectureAttendanceGroup> get _groupsForSelectedDayWeek {
    return _groups
        .where(
          (group) =>
              group.dayOfWeek == _selectedDayOfWeek &&
              group.weekNumber == _displayWeekNumber,
        )
        .toList();
  }

  List<int> get _availableDayOptions {
    final days = _groups.map((g) => g.dayOfWeek).toSet();
    if (days.isEmpty) return _defaultWeekdayOrder;
    return _allWeekdayOrder.where(days.contains).toList();
  }

  List<String> get _courseOptions {
    return _groupsForSelectedDayWeek
        .where(
          (group) =>
              _selectedSection == null || group.section == _selectedSection,
        )
        .map((group) => group.courseName)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get _sectionOptions {
    return _groupsForSelectedDayWeek
        .where(
          (group) =>
              _selectedCourse == null || group.courseName == _selectedCourse,
        )
        .map((group) => group.section)
        .toSet()
        .toList()
      ..sort();
  }

  List<_LectureAttendanceGroup> get _filteredGroups {
    var list = _groupsForSelectedDayWeek;
    if (_selectedCourse != null && _selectedCourse!.trim().isNotEmpty) {
      list = list
          .where((group) => group.courseName == _selectedCourse)
          .toList();
    }
    if (_selectedSection != null && _selectedSection!.trim().isNotEmpty) {
      list = list.where((group) => group.section == _selectedSection).toList();
    }
    list.sort((a, b) {
      final byDate = b.lectureDate.compareTo(a.lectureDate);
      if (byDate != 0) return byDate;
      final aTime = TimeUtils.parseTimeString(a.startTime);
      final bTime = TimeUtils.parseTimeString(b.startTime);
      final aMinutes = aTime.$1 * 60 + aTime.$2;
      final bMinutes = bTime.$1 * 60 + bTime.$2;
      return aMinutes.compareTo(bMinutes);
    });
    return list;
  }

  _LectureAttendanceGroup? get _activeGroup {
    final list = _filteredGroups;
    if (list.isEmpty) return null;
    if (_selectedSessionId != null) {
      for (final group in list) {
        if (group.sessionId == _selectedSessionId) return group;
      }
    }
    return list.first;
  }

  List<_StudentAttendanceRecord> get _visibleStudents {
    final group = _activeGroup;
    if (group == null) return const <_StudentAttendanceRecord>[];
    if (_statusFilter == _StatusFilter.all) return group.students;
    return group.students
        .where(
          (student) =>
              _statusToFilter(_effectiveStatus(student)) == _statusFilter,
        )
        .toList();
  }

  _AttendanceStatus _effectiveStatus(_StudentAttendanceRecord student) {
    if (!_isEditMode) return student.status;
    return _draftStatuses[student.id] ?? student.status;
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      await _calendarRepository.refreshAcademicCalendar();
      _calendarNow = _calendarRepository.currentDateTime;
      if (_weekIsAuto) {
        _selectedDayOfWeek = _calendarNow.weekday;
      }
      final lectures = await LecturerSectionsService.instance
          .getLecturesForCurrentLecturer();
      final sortedLectures = [...lectures]
        ..sort((a, b) {
          final byCourse = a.courseName.compareTo(b.courseName);
          if (byCourse != 0) return byCourse;
          final aTime = TimeUtils.parseTimeString(a.startTime);
          final bTime = TimeUtils.parseTimeString(b.startTime);
          return (aTime.$1 * 60 + aTime.$2).compareTo(bTime.$1 * 60 + bTime.$2);
        });
      final lectureBySection = <String, LectureItem>{};
      final sectionIds = <String>{};
      for (final lecture in lectures) {
        final sectionId = (lecture.sectionId ?? '').trim();
        if (sectionId.isEmpty) continue;
        sectionIds.add(sectionId);
        lectureBySection[sectionId] = lecture;
      }

      final sessions = await _manualAttendanceService.getSessionsForSectionIds(
        sectionIds,
      );
      final recordsBySession = await _manualAttendanceService
          .getRecordsForSessionIds(sessions.map((s) => s.sessionId).toSet());
      final groups = _buildGroupsFromFirestore(
        sessions: sessions,
        recordsBySession: recordsBySession,
        lectureBySection: lectureBySection,
      );

      if (!mounted) return;
      setState(() {
        _lecturerLectures = sortedLectures;
        _selectedLectureForCalendar =
            (sortedLectures.any(
              (lecture) =>
                  lecture.sectionId == _selectedLectureForCalendar?.sectionId &&
                  lecture.startTime == _selectedLectureForCalendar?.startTime,
            ))
            ? _selectedLectureForCalendar
            : (sortedLectures.isNotEmpty ? sortedLectures.first : null);
        _calendarSelectedDate = DateTime(
          _calendarNow.year,
          _calendarNow.month,
          _calendarNow.day,
        );
        _calendarSelectedMonth = DateTime(
          _calendarSelectedDate.year,
          _calendarSelectedDate.month,
          1,
        );
        if (groups.isNotEmpty) {
          final latest = groups.first;
          _selectedDayOfWeek = latest.dayOfWeek;
          _weekIsAuto = false;
          _selectedWeekNumber = latest.weekNumber;
        }
        _groups = groups;
        _normalizeLinkedSelections();
        _normalizeSelectedSession();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _handleRealtimeCalendarChange() async {
    if (!mounted || _isSyncRefreshing) return;
    _isSyncRefreshing = true;
    try {
      await _calendarRepository.refreshAcademicCalendar();
      final updatedNow = _calendarRepository.currentDateTime;
      if (!mounted) return;
      setState(() {
        _calendarNow = updatedNow;
        if (_weekIsAuto) {
          _selectedDayOfWeek = updatedNow.weekday;
        }
      });
    } catch (_) {
      // Ignore transient realtime listener errors.
    } finally {
      _isSyncRefreshing = false;
    }
  }

  List<_LectureAttendanceGroup> _buildGroupsFromFirestore({
    required List<ManualAttendanceSession> sessions,
    required Map<String, List<ManualAttendanceRecord>> recordsBySession,
    required Map<String, LectureItem> lectureBySection,
  }) {
    final groups = <_LectureAttendanceGroup>[];
    for (final session in sessions) {
      final effectiveDate = DateTime(
        session.lectureDate.year,
        session.lectureDate.month,
        session.lectureDate.day,
      );
      // Keep report aligned with academic calendar:
      // skip sessions outside attendance counting (breaks/exceptions/holidays).
      if (!session.countInAttendance ||
          _calendarRepository.isHoliday(effectiveDate)) {
        continue;
      }
      final records =
          recordsBySession[session.sessionId] ??
          const <ManualAttendanceRecord>[];
      final lecture = lectureBySection[session.sectionId];
      final courseName = session.courseName.trim().isNotEmpty
          ? session.courseName
          : (lecture?.courseName ?? session.sectionId);
      final sectionLabel = session.sectionLabel.trim().isNotEmpty
          ? session.sectionLabel
          : (lecture?.section ?? '-');
      final effectiveWeekday = effectiveDate.weekday;
      final students = records
          .map(
            (record) => _StudentAttendanceRecord(
              id: record.recordId,
              studentId: record.studentId,
              name: record.studentName.trim().isNotEmpty
                  ? record.studentName
                  : record.studentId.toString(),
              academicNumber: record.studentId.toString(),
              time: _timeTextForRecord(record, session),
              status: _statusFromManual(record.status),
            ),
          )
          .toList();

      groups.add(
        _LectureAttendanceGroup(
          sessionId: session.sessionId,
          lecture: lecture,
          courseName: courseName,
          section: sectionLabel,
          dayOfWeek: effectiveWeekday,
          weekNumber:
              session.officialWeekNumber ??
              _calendarRepository.getWeekNumber(effectiveDate),
          lectureDate: effectiveDate,
          startTime: session.lectureStartTime,
          timeRange: '${session.lectureStartTime} - ${session.lectureEndTime}',
          students: students,
        ),
      );
    }
    groups.sort((a, b) {
      final byDate = b.lectureDate.compareTo(a.lectureDate);
      if (byDate != 0) return byDate;
      final aTime = TimeUtils.parseTimeString(a.startTime);
      final bTime = TimeUtils.parseTimeString(b.startTime);
      final aMinutes = aTime.$1 * 60 + aTime.$2;
      final bMinutes = bTime.$1 * 60 + bTime.$2;
      return aMinutes.compareTo(bMinutes);
    });
    return groups;
  }

  String _timeTextForRecord(
    ManualAttendanceRecord record,
    ManualAttendanceSession session,
  ) {
    final stored = record.attendanceTime.trim();
    if (stored.isNotEmpty) return stored;
    if (record.isPresentLike) return session.lectureStartTime;
    return '--';
  }

  _AttendanceStatus _statusFromManual(ManualAttendanceStatus status) {
    switch (status) {
      case ManualAttendanceStatus.present:
        return _AttendanceStatus.present;
      case ManualAttendanceStatus.absent:
        return _AttendanceStatus.absent;
      case ManualAttendanceStatus.excused:
        return _AttendanceStatus.excused;
      case ManualAttendanceStatus.late:
        return _AttendanceStatus.late;
    }
  }

  ManualAttendanceStatus _manualFromStatus(_AttendanceStatus status) {
    switch (status) {
      case _AttendanceStatus.present:
        return ManualAttendanceStatus.present;
      case _AttendanceStatus.absent:
        return ManualAttendanceStatus.absent;
      case _AttendanceStatus.excused:
        return ManualAttendanceStatus.excused;
      case _AttendanceStatus.late:
        return ManualAttendanceStatus.late;
    }
  }

  void _normalizeLinkedSelections() {
    if (!_availableDayOptions.contains(_selectedDayOfWeek) &&
        _availableDayOptions.isNotEmpty) {
      _selectedDayOfWeek = _availableDayOptions.first;
    }
    if (_selectedCourse != null && !_courseOptions.contains(_selectedCourse)) {
      _selectedCourse = null;
    }
    if (_selectedSection != null &&
        !_sectionOptions.contains(_selectedSection)) {
      _selectedSection = null;
    }
    if (_selectedCourse != null &&
        _selectedSection != null &&
        !_groupsForSelectedDayWeek.any(
          (group) =>
              group.courseName == _selectedCourse &&
              group.section == _selectedSection,
        )) {
      _selectedSection = null;
    }
  }

  void _normalizeSelectedSession() {
    final activeIds = _filteredGroups.map((e) => e.sessionId).toSet();
    if (_selectedSessionId == null || !activeIds.contains(_selectedSessionId)) {
      _selectedSessionId = _filteredGroups.isEmpty
          ? null
          : _filteredGroups.first.sessionId;
    }
  }

  void _resetEditState() {
    _isEditMode = false;
    _hasPendingChanges = false;
    _draftStatuses = <String, _AttendanceStatus>{};
  }

  void _onDayChanged(int day) {
    setState(() {
      _selectedDayOfWeek = day;
      _normalizeLinkedSelections();
      _normalizeSelectedSession();
      _resetEditState();
    });
  }

  void _openAttendanceDayActionPage() {
    final sessions = _groupsForSelectedDayWeek;
    if (sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'لا توجد جلسات حضور لهذا اليوم.',
              'No attendance sessions for this day.',
            ),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AttendanceDayActionScreen(
          dayLabel: _dayName(_selectedDayOfWeek),
          weekNumber: _displayWeekNumber,
          sessions: sessions,
          tr: _tr,
        ),
      ),
    );
  }

  void _onCalendarDaySelected(CalendarDay day) {
    setState(() {
      _calendarSelectedDate = DateTime(
        day.date.year,
        day.date.month,
        day.date.day,
      );
      _selectedDayOfWeek = _calendarSelectedDate.weekday;
      _calendarSelectedMonth = DateTime(
        _calendarSelectedDate.year,
        _calendarSelectedDate.month,
        1,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openCalendarActionPopup();
    });
  }

  Future<void> _openCalendarActionPopup() async {
    final lecture = _selectedLectureForCalendar;
    if (lecture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('اختاري محاضرة أولاً.', 'Select a lecture first.')),
        ),
      );
      return;
    }

    final selectedDate = DateTime(
      _calendarSelectedDate.year,
      _calendarSelectedDate.month,
      _calendarSelectedDate.day,
    );
    if (_calendarRepository.isHoliday(selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'اليوم المختار إجازة حسب التقويم.',
              'Selected day is a holiday in calendar.',
            ),
          ),
        ),
      );
      return;
    }
    if (selectedDate.weekday != lecture.dayOfWeek) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'لا يوجد موعد لهذه المحاضرة في اليوم المختار.',
              'No lecture slot for selected day.',
            ),
          ),
        ),
      );
      return;
    }

    final today = DateTime(
      _calendarNow.year,
      _calendarNow.month,
      _calendarNow.day,
    );
    final isFuture = selectedDate.isAfter(today);
    final existingGroup = _findGroupForLectureAndDate(
      lecture: lecture,
      date: selectedDate,
    );
    final hasExistingAttendance = existingGroup != null;

    final action = await showDialog<_AttendanceCalendarAction>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: AlertDialog(
            title: Text(_tr('إجراء الحضور', 'Attendance action')),
            content: Text(
              _tr(
                'اختاري الإجراء للمحاضرة في ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                'Choose action for lecture on ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(_tr('إلغاء', 'Cancel')),
              ),
              if (isFuture) ...[
                FilledButton.icon(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_AttendanceCalendarAction.attend),
                  icon: const Icon(Icons.fact_check_rounded, size: 16),
                  label: Text(_tr('تحضير', 'Take attendance')),
                ),
              ] else if (hasExistingAttendance) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_AttendanceCalendarAction.preview),
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: Text(_tr('معاينة الحضور', 'Preview attendance')),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_AttendanceCalendarAction.editPrevious),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(_tr('تعديل الحضور', 'Edit attendance')),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_AttendanceCalendarAction.attend),
                  icon: const Icon(Icons.fact_check_rounded, size: 16),
                  label: Text(_tr('تحضير', 'Take attendance')),
                ),
              ],
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _AttendanceCalendarAction.preview:
        LecturerNavigation.goToAttendanceViewOnly(
          context,
          lecture,
          selectedDate,
        );
        break;
      case _AttendanceCalendarAction.editPrevious:
      case _AttendanceCalendarAction.attend:
        LecturerNavigation.goToAttendance(
          context,
          lecture,
          selectedDate: selectedDate,
        );
        break;
    }
  }

  _LectureAttendanceGroup? _findGroupForLectureAndDate({
    required LectureItem lecture,
    required DateTime date,
  }) {
    final targetDate = DateTime(date.year, date.month, date.day);
    final sectionId = (lecture.sectionId ?? '').trim();
    for (final group in _groups) {
      final groupDate = DateTime(
        group.lectureDate.year,
        group.lectureDate.month,
        group.lectureDate.day,
      );
      if (groupDate != targetDate) continue;
      if (sectionId.isNotEmpty &&
          (group.lecture?.sectionId ?? '').trim() == sectionId &&
          group.startTime.trim() == lecture.startTime.trim()) {
        return group;
      }
      if (group.courseName.trim() == lecture.courseName.trim() &&
          group.section.trim() == lecture.section.trim() &&
          group.startTime.trim() == lecture.startTime.trim()) {
        return group;
      }
    }
    return null;
  }

  Widget _buildLectureCalendarSelectionPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3ECEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _tr('1) اختار المحاضرة', '1) Choose lecture'),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2F4449),
            ),
          ),
          const SizedBox(height: 8),
          _buildLectureCards(),
          const SizedBox(height: 12),
          Text(
            _tr('2) اختار اليوم من التقويم', '2) Choose day from calendar'),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2F4449),
            ),
          ),
          const SizedBox(height: 8),
          _buildLectureCalendar(),
        ],
      ),
    );
  }

  Widget _buildLectureCards() {
    if (_lecturerLectures.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3ECEE)),
        ),
        child: Text(
          _tr(
            'لا توجد محاضرات مرتبطة بحسابك.',
            'No lectures linked to account.',
          ),
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: Color(0xFF667A7F),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _lecturerLectures.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final lecture = _lecturerLectures[index];
          final selected =
              lecture.sectionId == _selectedLectureForCalendar?.sectionId &&
              lecture.startTime == _selectedLectureForCalendar?.startTime &&
              lecture.dayOfWeek == _selectedLectureForCalendar?.dayOfWeek;
          final timeRange = TimeUtils.formatTimeRange(
            lecture.startTime,
            lecture.endTime,
          );
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedLectureForCalendar = lecture;
                _selectedCourse = lecture.courseName;
                _selectedSection = lecture.section;
              });
            },
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFE6F3F5) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? _primary : const Color(0xFFDDE7E9),
                  width: selected ? 1.3 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lecture.courseName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFF0A5A63)
                          : const Color(0xFF243238),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_dayName(lecture.dayOfWeek)} • $timeRange',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: Color(0xFF60757A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_tr('الشعبة', 'Section')} ${lecture.section}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: Color(0xFF60757A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLectureCalendar() {
    final lecture = _selectedLectureForCalendar;
    if (lecture == null) {
      return const SizedBox.shrink();
    }

    return MonthlyCalendar(
      currentMonth: _calendarSelectedMonth,
      calendarDays: _calendarService.buildCalendarDays(_calendarSelectedMonth, [
        lecture,
      ]),
      onDayTap: _onCalendarDaySelected,
      onMonthChanged: (month) {
        setState(() {
          _calendarSelectedMonth = DateTime(month.year, month.month, 1);
        });
      },
    );
  }

  void _onWeekChanged({required bool auto, int? week}) {
    setState(() {
      _weekIsAuto = auto;
      _selectedWeekNumber = auto ? null : week;
      _normalizeLinkedSelections();
      _normalizeSelectedSession();
      _resetEditState();
    });
  }

  void _onSectionChanged(String? section) {
    setState(() {
      _selectedSection = section;
      if (_selectedCourse != null &&
          !_groupsForSelectedDayWeek.any(
            (group) =>
                group.courseName == _selectedCourse &&
                group.section == _selectedSection,
          )) {
        _selectedCourse = null;
      }
      _normalizeLinkedSelections();
      _normalizeSelectedSession();
      _resetEditState();
    });
  }

  void _onCourseChanged(String? course) {
    setState(() {
      _selectedCourse = course;
      if (_selectedSection != null &&
          !_groupsForSelectedDayWeek.any(
            (group) =>
                group.courseName == _selectedCourse &&
                group.section == _selectedSection,
          )) {
        _selectedSection = null;
      }
      _normalizeLinkedSelections();
      _normalizeSelectedSession();
      _resetEditState();
    });
  }

  void _onSessionChanged(String? sessionId) {
    setState(() {
      _selectedSessionId = sessionId;
      _resetEditState();
    });
  }

  void _enterEditMode(_LectureAttendanceGroup group) {
    if (_isEditMode) return;
    setState(() {
      _isEditMode = true;
      _hasPendingChanges = false;
      _draftStatuses = {
        for (final student in group.students) student.id: student.status,
      };
    });
  }

  Future<void> _switchToViewMode(_LectureAttendanceGroup group) async {
    if (!_isEditMode) return;

    if (!_hasPendingChanges) {
      setState(() => _resetEditState());
      return;
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: ModernPopupDialog(
            title: Text(
              _tr('تغييرات غير محفوظة', 'Unsaved changes'),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: _primary,
              ),
            ),
            accentColor: _primary,
            actions: [
              ModernPopupActionButton(
                label: _tr('تجاهل', 'Discard'),
                onTap: () => Navigator.of(dialogContext).pop(false),
                isPrimary: false,
              ),
              ModernPopupActionButton(
                label: _tr('حفظ', 'Save'),
                onTap: () => Navigator.of(dialogContext).pop(true),
                isPrimary: true,
                primaryColor: _primary,
              ),
            ],
            child: Text(
              _tr(
                'يوجد تعديلات غير محفوظة. هل تريد حفظها قبل العودة لوضع المعاينة؟',
                'There are unsaved changes. Save before switching to preview mode?',
              ),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );

    if (shouldSave == null) return;
    if (shouldSave) {
      await _saveAttendanceChanges(group, exitEditMode: true);
      return;
    }
    setState(() => _resetEditState());
  }

  Future<void> _saveAttendanceChanges(
    _LectureAttendanceGroup group, {
    bool exitEditMode = false,
  }) async {
    if (!_isEditMode) return;
    if (_isSaving) return;

    if (!_hasPendingChanges) {
      if (exitEditMode) {
        setState(() => _resetEditState());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr('لا توجد تغييرات جديدة للحفظ.', 'No new changes to save.'),
            ),
          ),
        );
      }
      return;
    }

    final updates = <int, ManualAttendanceStatus>{};
    final changedByStudentRowId = <String, _AttendanceStatus>{};
    for (final student in group.students) {
      final draft = _draftStatuses[student.id];
      if (draft == null || draft == student.status) continue;
      updates[student.studentId] = _manualFromStatus(draft);
      changedByStudentRowId[student.id] = draft;
    }

    if (updates.isEmpty) {
      setState(() {
        _hasPendingChanges = false;
        if (exitEditMode) {
          _resetEditState();
        }
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _manualAttendanceService.updateSessionStatuses(
        sessionId: group.sessionId,
        updates: updates,
      );
      if (!mounted) return;

      setState(() {
        for (final student in group.students) {
          final updatedStatus = changedByStudentRowId[student.id];
          if (updatedStatus == null) continue;
          student.status = updatedStatus;
          student.time =
              (updatedStatus == _AttendanceStatus.present ||
                  updatedStatus == _AttendanceStatus.late)
              ? group.startTime
              : '--';
        }
        _hasPendingChanges = false;
        if (exitEditMode) {
          _resetEditState();
        } else {
          _draftStatuses = {
            for (final student in group.students) student.id: student.status,
          };
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تم حفظ تغييرات تقرير الحضور.',
              'Attendance report changes saved.',
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('فشل الحفظ. حاول مرة أخرى.', 'Save failed. Please try again.'),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showStatusPicker(_StudentAttendanceRecord student) async {
    if (!_isEditMode) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final statuses = _AttendanceStatus.values;
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr('تعديل حالة الطالب', 'Edit student status'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  student.name,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...statuses.map((status) {
                  final style = _statusStyle(status);
                  final selected = _effectiveStatus(student) == status;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _draftStatuses[student.id] = status;
                          _hasPendingChanges = true;
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: style.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? style.fg
                                : style.fg.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          style.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            color: style.fg,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSummaryPopup(_LectureAttendanceGroup group) {
    final counts = _buildCounts(group.students);
    final total = group.students.length;
    double percent(int v) => total == 0 ? 0 : (v / total) * 100;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.72,
            margin: const EdgeInsets.only(top: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D8D8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Expanded(
                        child: Text(
                          _tr('ملخص الحضور', 'Attendance Summary'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.courseName,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF24383D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_dayName(group.dayOfWeek)} • ${group.timeRange} • ${_tr('الشعبة', 'Section')} ${group.section}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Color(0xFF60757A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    children: [
                      _summaryTile(
                        label: _tr('إجمالي الطلاب', 'Total students'),
                        count: total,
                        percentage: 100,
                        color: _primary,
                      ),
                      const SizedBox(height: 10),
                      _summaryTile(
                        label: _tr('الحضور', 'Present'),
                        count: counts.present,
                        percentage: percent(counts.present),
                        color: const Color(0xFF2EAF5E),
                      ),
                      const SizedBox(height: 10),
                      _summaryTile(
                        label: _tr('الغياب', 'Absent'),
                        count: counts.absent,
                        percentage: percent(counts.absent),
                        color: const Color(0xFFE65151),
                      ),
                      const SizedBox(height: 10),
                      _summaryTile(
                        label: _tr('الغياب بعذر', 'Excused'),
                        count: counts.excused,
                        percentage: percent(counts.excused),
                        color: const Color(0xFFF0A825),
                      ),
                      const SizedBox(height: 10),
                      _summaryTile(
                        label: _tr('التأخر', 'Late'),
                        count: counts.late,
                        percentage: percent(counts.late),
                        color: const Color(0xFF4D8EDB),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryTile({
    required String label,
    required int count,
    required double percentage,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0EAEC)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3F44),
                  ),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (percentage / 100).clamp(0, 1),
              backgroundColor: const Color(0xFFEAEFF0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  _Counts _buildCounts(List<_StudentAttendanceRecord> students) {
    int present = 0;
    int absent = 0;
    int excused = 0;
    int late = 0;
    for (final student in students) {
      switch (_effectiveStatus(student)) {
        case _AttendanceStatus.present:
          present++;
          break;
        case _AttendanceStatus.absent:
          absent++;
          break;
        case _AttendanceStatus.excused:
          excused++;
          break;
        case _AttendanceStatus.late:
          late++;
          break;
      }
    }
    return _Counts(
      present: present,
      absent: absent,
      excused: excused,
      late: late,
    );
  }

  _StatusFilter _statusToFilter(_AttendanceStatus status) {
    switch (status) {
      case _AttendanceStatus.present:
        return _StatusFilter.present;
      case _AttendanceStatus.absent:
        return _StatusFilter.absent;
      case _AttendanceStatus.excused:
        return _StatusFilter.excused;
      case _AttendanceStatus.late:
        return _StatusFilter.late;
    }
  }

  _StatusStyle _statusStyle(_AttendanceStatus status) {
    switch (status) {
      case _AttendanceStatus.present:
        return _StatusStyle(
          label: _tr('حاضر', 'Present'),
          bg: const Color(0xFFDFF4E5),
          fg: const Color(0xFF2B9E56),
          color: const Color(0xFF2B9E56),
        );
      case _AttendanceStatus.absent:
        return _StatusStyle(
          label: _tr('غائب', 'Absent'),
          bg: const Color(0xFFFDE1E1),
          fg: const Color(0xFFD14A4A),
          color: const Color(0xFFD14A4A),
        );
      case _AttendanceStatus.excused:
        return _StatusStyle(
          label: _tr('معذور', 'Excused'),
          bg: const Color(0xFFFFF3D6),
          fg: const Color(0xFFC78A1E),
          color: const Color(0xFFC78A1E),
        );
      case _AttendanceStatus.late:
        return _StatusStyle(
          label: _tr('متأخر', 'Late'),
          bg: const Color(0xFFE3EEFF),
          fg: const Color(0xFF3E73C9),
          color: const Color(0xFF3E73C9),
        );
    }
  }

  _StatusStyle _filterStyle(_StatusFilter filter) {
    switch (filter) {
      case _StatusFilter.all:
        return _StatusStyle(
          label: _tr('الكل', 'All'),
          color: const Color(0xFF6F7D82),
          bg: const Color(0xFFECEFF0),
          fg: const Color(0xFF6F7D82),
        );
      case _StatusFilter.present:
        return _statusStyle(_AttendanceStatus.present);
      case _StatusFilter.absent:
        return _statusStyle(_AttendanceStatus.absent);
      case _StatusFilter.excused:
        return _statusStyle(_AttendanceStatus.excused);
      case _StatusFilter.late:
        return _statusStyle(_AttendanceStatus.late);
    }
  }

  String _dayName(int weekday) {
    return LecturerLanguageController.dayNameFromWeekday(weekday);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final group = _activeGroup;
    final currentFiltersLabel =
        '${_tr('اليوم', 'Day')}: ${_dayName(_selectedDayOfWeek)}   •   ${_tr('الأسبوع', 'Week')}: $_displayWeekNumber';

    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FBFB),
            body: SafeArea(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: Color(0xFF006571),
                        ),
                      ),
                    )
                  : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _tr(
                                'حدث خطأ في تحميل التقرير',
                                'Failed to load report',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _loadReportData,
                              icon: const Icon(Icons.refresh),
                              label: Text(_tr('إعادة المحاولة', 'Retry')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final tableHeight = constraints.maxHeight * 0.56;
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 6),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: ProfileBackButton(onTap: _goBack),
                              ),
                              const SizedBox(height: 10),
                              _buildLectureCalendarSelectionPanel(),
                              const SizedBox(height: 10),
                              if (_showLegacyReportPanel) ...[
                                _buildFilters(currentFiltersLabel),
                                const SizedBox(height: 10),
                                if (group != null) ...[
                                  _buildSessionSelector(),
                                  const SizedBox(height: 10),
                                  _buildControlBar(group),
                                  const SizedBox(height: 10),
                                  _buildStatusTabs(),
                                  const SizedBox(height: 8),
                                  _buildStudentsTable(tableHeight),
                                  if (_isEditMode) ...[
                                    const SizedBox(height: 12),
                                    _buildSaveChangesButton(group),
                                  ],
                                ] else
                                  SizedBox(
                                    height: constraints.maxHeight * 0.56,
                                    child: _buildEmptyState(),
                                  ),
                              ] else ...[
                                _buildMergedWorkflowHint(constraints.maxHeight),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters(String currentFiltersLabel) {
    final dayLabel = _dayName(_selectedDayOfWeek);
    final weekLabel = '${_tr('أسبوع', 'Week')} $_displayWeekNumber';
    final weekHint = _weekIsAuto
        ? _tr('تلقائي: الأسبوع الحالي', 'Auto: current week')
        : _tr('تم اختيار الأسبوع يدوياً', 'Manual week selection');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3ECEE)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: _primary, size: 18),
              const SizedBox(width: 6),
              Text(
                _tr('تصفية التقرير', 'Report Filters'),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2F4449),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              currentFiltersLabel,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                color: Color(0xFF667A7F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FilterCard(
                  title: _tr('اليوم', 'Day'),
                  value: dayLabel,
                  icon: Icons.calendar_today_rounded,
                  onTap: _showDayPickerSheet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterCard(
                  title: _tr('الأسبوع', 'Week'),
                  value: weekLabel,
                  subtitle: weekHint,
                  icon: Icons.date_range_rounded,
                  onTap: _showWeekPickerSheet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _FilterCard(
                  title: _tr('الشعبة', 'Section'),
                  value: _selectedSection ?? _tr('الكل', 'All'),
                  icon: Icons.groups_rounded,
                  onTap: _showSectionPickerSheet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterCard(
                  title: _tr('المقرر', 'Course'),
                  value: _selectedCourse ?? _tr('الكل', 'All'),
                  icon: Icons.menu_book_rounded,
                  onTap: _showCoursePickerSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSelector() {
    final sessions = _filteredGroups;
    if (sessions.length <= 1) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE7E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr('اختيار الجلسة', 'Select Session'),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              color: Color(0xFF32484D),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sessions.map((session) {
                final selected = _selectedSessionId == session.sessionId;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    selected: selected,
                    onSelected: (_) => _onSessionChanged(session.sessionId),
                    selectedColor: const Color(0xFF006571),
                    labelStyle: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF4F6267),
                    ),
                    label: Text(
                      '${session.courseName} • ${_formatDate(session.lectureDate)} • ${session.timeRange}',
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(_LectureAttendanceGroup group) {
    final modeLabel = _isEditMode
        ? _tr('وضع التعديل مفعل', 'Edit mode enabled')
        : _tr('وضع المعاينة', 'Preview mode');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE7E9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showSummaryPopup(group),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                side: const BorderSide(color: Color(0xFFBFD5D9)),
              ),
              child: Text(
                _tr('ملخص الحضور', 'Attendance Summary'),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    modeLabel,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _isEditMode ? _primary : const Color(0xFF60757A),
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: _isEditMode,
                  activeTrackColor: _primary.withValues(alpha: 0.5),
                  activeThumbColor: _primary,
                  onChanged: (on) async {
                    if (on) {
                      _enterEditMode(group);
                      return;
                    }
                    await _switchToViewMode(group);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveChangesButton(_LectureAttendanceGroup group) {
    final isEnabled = _hasPendingChanges && !_isSaving;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? () => _saveAttendanceChanges(group) : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          height: 46,
          decoration: BoxDecoration(
            gradient: isEnabled
                ? const LinearGradient(
                    colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: isEnabled ? null : const Color(0xFFE3E8EA),
            borderRadius: BorderRadius.circular(14),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF006571).withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.save_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
              const SizedBox(width: 8),
              Text(
                _tr('حفظ التغييرات', 'Save Changes'),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isEnabled ? Colors.white : const Color(0xFF92A2A7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    final tabs = <_StatusFilter>[
      _StatusFilter.all,
      _StatusFilter.present,
      _StatusFilter.absent,
      _StatusFilter.excused,
      _StatusFilter.late,
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE6E8)),
      ),
      child: Row(
        children: tabs.map((filter) {
          final bool active = _statusFilter == filter;
          final config = _filterStyle(filter);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _statusFilter = filter),
              child: Container(
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? config.color : const Color(0xFFF2F5F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  config.label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : const Color(0xFF516166),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStudentsTable(double height) {
    return SizedBox(
      height: height.clamp(260.0, 560.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE6E8)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F6F7),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(13),
                  topRight: Radius.circular(13),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 32,
                    child: Text(
                      '#',
                      textAlign: TextAlign.center,
                      style: _headerStyle,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      _tr('اسم الطالب', 'Student Name'),
                      style: _headerStyle,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _tr('الرقم الجامعي', 'Academic Number'),
                      style: _headerStyle,
                    ),
                  ),
                  SizedBox(
                    width: 54,
                    child: Text(
                      _tr('الوقت', 'Time'),
                      textAlign: TextAlign.center,
                      style: _headerStyle,
                    ),
                  ),
                  SizedBox(
                    width: 78,
                    child: Text(
                      _tr('الحالة', 'Status'),
                      textAlign: TextAlign.center,
                      style: _headerStyle,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _visibleStudents.isEmpty
                  ? Center(
                      child: Text(
                        _tr(
                          'لا يوجد طلاب في هذا الفلتر.',
                          'No students in this filter.',
                        ),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _visibleStudents.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFEAEFF0)),
                      itemBuilder: (context, index) {
                        final student = _visibleStudents[index];
                        final statusStyle = _statusStyle(
                          _effectiveStatus(student),
                        );
                        return Container(
                          color: index.isEven
                              ? Colors.white
                              : const Color(0xFFFCFEFE),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11.5,
                                    color: Color(0xFF5E6C70),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  student.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF213236),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  student.academicNumber,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    color: Color(0xFF55666B),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 54,
                                child: Text(
                                  student.time,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    color: Color(0xFF465A5F),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 78,
                                child: _isEditMode
                                    ? InkWell(
                                        onTap: () => _showStatusPicker(student),
                                        borderRadius: BorderRadius.circular(9),
                                        child: _statusChip(
                                          statusStyle.label,
                                          statusStyle.bg,
                                          statusStyle.fg,
                                          showEditIcon: true,
                                        ),
                                      )
                                    : _statusChip(
                                        statusStyle.label,
                                        statusStyle.bg,
                                        statusStyle.fg,
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(
    String label,
    Color bg,
    Color fg, {
    bool showEditIcon = false,
  }) {
    return Container(
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          if (showEditIcon) ...[
            const SizedBox(width: 4),
            Icon(Icons.edit_rounded, size: 12, color: fg),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE7E9)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_rounded, color: _primary, size: 34),
            const SizedBox(height: 8),
            Text(
              _tr(
                'لا توجد بيانات حضور لهذا الفلتر.',
                'No attendance data for this filter.',
              ),
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFF4F6369),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergedWorkflowHint(double availableHeight) {
    return SizedBox(
      height: (availableHeight * 0.42).clamp(170.0, 300.0),
      child: Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE7E9)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.merge_type_rounded, color: _primary, size: 34),
              const SizedBox(height: 8),
              Text(
                _tr(
                  'تم دمج التقرير مع لوحة الاختيار بالأعلى',
                  'Report is merged with the top selection panel',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFF4F6369),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _tr(
                  'اختاري المحاضرة ثم اليوم من التقويم لفتح إجراء الحضور مباشرة.',
                  'Choose lecture then day from calendar to open attendance actions directly.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Color(0xFF758A90),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWeekPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: 24 + MediaQuery.paddingOf(ctx).bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D8D8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _tr('اختيار الأسبوع', 'Week picker'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo',
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(
                  '${_tr('الأسبوع الحالي', 'Current week')} (${_tr('تلقائي', 'Auto')})',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: _weekIsAuto
                        ? FontWeight.w700
                        : FontWeight.normal,
                    color: _weekIsAuto ? _primary : const Color(0xFF222222),
                  ),
                ),
                subtitle: Text(
                  '${_tr('رقم الأسبوع', 'Week')} $_currentWeekNumber',
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
                trailing: _weekIsAuto
                    ? const Icon(Icons.check_rounded, color: _primary, size: 22)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _onWeekChanged(auto: true);
                },
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  controller: scrollController,
                  shrinkWrap: true,
                  itemCount: _maxSelectableWeeks,
                  itemBuilder: (_, index) {
                    final week = index + 1;
                    final selected =
                        !_weekIsAuto && _selectedWeekNumber == week;
                    return ListTile(
                      title: Text(
                        '${_tr('أسبوع', 'Week')} $week',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: selected ? _primary : const Color(0xFF222222),
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: _primary,
                              size: 22,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _onWeekChanged(auto: false, week: week);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDayPickerSheet() {
    final options = _availableDayOptions;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: 24 + MediaQuery.paddingOf(ctx).bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D8D8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _tr('اختيار اليوم', 'Day picker'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            ...options.map((w) {
              final label = _dayName(w);
              final selected = _selectedDayOfWeek == w;
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                    color: selected ? _primary : const Color(0xFF222222),
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check_rounded, color: _primary, size: 22)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _onDayChanged(w);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _openAttendanceDayActionPage();
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSectionPickerSheet() {
    final options = [null, ..._sectionOptions];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: 24 + MediaQuery.paddingOf(ctx).bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D8D8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _tr('الشعبة', 'Section'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            ...options.map((section) {
              final label = section ?? _tr('الكل', 'All');
              final selected = _selectedSection == section;
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                    color: selected ? _primary : const Color(0xFF222222),
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check_rounded, color: _primary, size: 22)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _onSectionChanged(section);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showCoursePickerSheet() {
    final options = [null, ..._courseOptions];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: 24 + MediaQuery.paddingOf(ctx).bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D8D8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _tr('المقرر', 'Course'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            ...options.map((course) {
              final label = course ?? _tr('الكل', 'All');
              final selected = _selectedCourse == course;
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                    color: selected ? _primary : const Color(0xFF222222),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: selected
                    ? const Icon(Icons.check_rounded, color: _primary, size: 22)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _onCourseChanged(course);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3ECEE)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF006571)),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        color: Color(0xFF688085),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Color(0xFF1F3338),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: Color(0xFF7D9095),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xFF006571),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceDayActionScreen extends StatelessWidget {
  const _AttendanceDayActionScreen({
    required this.dayLabel,
    required this.weekNumber,
    required this.sessions,
    required this.tr,
  });

  final String dayLabel;
  final int weekNumber;
  final List<_LectureAttendanceGroup> sessions;
  final String Function(String ar, String en) tr;

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  void _openAttendanceForSession(
    BuildContext context,
    _LectureAttendanceGroup group, {
    required bool viewOnly,
  }) {
    final lecture = group.lecture;
    if (lecture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'لا يمكن فتح شاشة التحضير لأن بيانات المحاضرة غير مكتملة.',
              'Cannot open attendance because lecture data is incomplete.',
            ),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
      return;
    }
    if (viewOnly) {
      LecturerNavigation.goToAttendanceViewOnly(
        context,
        lecture,
        group.lectureDate,
      );
      return;
    }
    LecturerNavigation.goToAttendance(
      context,
      lecture,
      selectedDate: group.lectureDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FBFB),
            appBar: AppBar(
              backgroundColor: const Color(0xFFF8FBFB),
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: const Color(0xFF24383D),
              ),
              title: Text(
                tr('جلسات يوم $dayLabel', 'Sessions on $dayLabel'),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF24383D),
                ),
              ),
              centerTitle: true,
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDDE7E9)),
                  ),
                  child: Text(
                    tr(
                      'الأسبوع: $weekNumber • اختاري المحاضرة ثم حددي الإجراء المناسب',
                      'Week: $weekNumber • Choose lecture then the proper action',
                    ),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4E656C),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...sessions.map((group) {
                  final groupDate = DateTime(
                    group.lectureDate.year,
                    group.lectureDate.month,
                    group.lectureDate.day,
                  );
                  final isFuture = groupDate.isAfter(today);
                  final previewStudents = group.students.take(4).toList();
                  final moreCount =
                      group.students.length - previewStudents.length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDDE7E9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.courseName,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF203237),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${tr('الشعبة', 'Section')} ${group.section} • ${group.timeRange} • ${_formatDate(group.lectureDate)}',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: Color(0xFF5F747A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tr('أسماء الطلاب', 'Student names'),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: Color(0xFF5F747A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (previewStudents.isEmpty)
                            Text(
                              tr('لا يوجد طلاب مسجلين', 'No enrolled students'),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: Color(0xFF8B9BA0),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final student in previewStudents)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF5F7),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      student.name,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11.5,
                                        color: Color(0xFF486068),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (moreCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE3EEF3),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      tr(
                                        '+ $moreCount طالب/ـة',
                                        '+ $moreCount students',
                                      ),
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11.5,
                                        color: Color(0xFF3E5760),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _openAttendanceForSession(
                                    context,
                                    group,
                                    viewOnly: !isFuture,
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF006571),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: Icon(
                                    isFuture
                                        ? Icons.fact_check_rounded
                                        : Icons.visibility_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    isFuture
                                        ? tr('تحضير', 'Take attendance')
                                        : tr(
                                            'معاينة الحضور',
                                            'Preview attendance',
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isFuture
                                      ? null
                                      : () => _openAttendanceForSession(
                                          context,
                                          group,
                                          viewOnly: false,
                                        ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF006571),
                                    side: const BorderSide(
                                      color: Color(0xFF006571),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    tr('تعديل الحضور', 'Edit attendance'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

const TextStyle _headerStyle = TextStyle(
  fontFamily: 'Cairo',
  fontSize: 11,
  fontWeight: FontWeight.w800,
  color: Color(0xFF41575D),
);

enum _AttendanceCalendarAction { attend, editPrevious, preview }

enum _StatusFilter { all, present, absent, excused, late }

enum _AttendanceStatus { present, absent, excused, late }

class _LectureAttendanceGroup {
  _LectureAttendanceGroup({
    required this.sessionId,
    required this.lecture,
    required this.courseName,
    required this.section,
    required this.dayOfWeek,
    required this.weekNumber,
    required this.lectureDate,
    required this.startTime,
    required this.timeRange,
    required this.students,
  });

  final String sessionId;
  final LectureItem? lecture;
  final String courseName;
  final String section;
  final int dayOfWeek;
  final int weekNumber;
  final DateTime lectureDate;
  final String startTime;
  final String timeRange;
  final List<_StudentAttendanceRecord> students;
}

class _StudentAttendanceRecord {
  _StudentAttendanceRecord({
    required this.id,
    required this.studentId,
    required this.name,
    required this.academicNumber,
    required this.time,
    required this.status,
  });

  final String id;
  final int studentId;
  final String name;
  final String academicNumber;
  String time;
  _AttendanceStatus status;
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.color,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color color;
  final Color bg;
  final Color fg;
}

class _Counts {
  const _Counts({
    required this.present,
    required this.absent,
    required this.excused,
    required this.late,
  });

  final int present;
  final int absent;
  final int excused;
  final int late;
}
