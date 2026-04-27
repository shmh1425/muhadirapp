import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../models/attendance/manual_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../services/attendance/attendance_session_export_service.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/lecturer_sections_service.dart';
import '../../utils/shared/time_utils.dart';
import 'lecturer_language.dart';
import 'lecturer_navigation.dart';
import 'widgets/modern_popup_dialog.dart';
import 'widgets/profile_back_button.dart';

class LecturerAttendanceReportScreen extends StatefulWidget {
  const LecturerAttendanceReportScreen({super.key});

  @override
  State<LecturerAttendanceReportScreen> createState() =>
      _LecturerAttendanceReportScreenState();
}

class _LecturerAttendanceReportScreenState
    extends State<LecturerAttendanceReportScreen> {
  static const Color _primary = Color(0xFF006571);
  static const int _editableWindowDays = 14;
  static const List<int> _defaultWeekdayOrder = [7, 1, 2, 3, 4];
  static const List<int> _allWeekdayOrder = [7, 1, 2, 3, 4, 5, 6];

  final ManualAttendanceService _manualAttendanceService =
      ManualAttendanceService.instance;
  final LectureRepository _calendarRepository = LectureRepository();
  StreamSubscription<void>? _calendarSyncSub;
  DateTime _calendarNow = DateTime.now();
  bool _isSyncRefreshing = false;
  LectureItem? _selectedLectureForCalendar;
  DateTime _calendarSelectedDate = DateTime.now();

  List<_LectureAttendanceGroup> _groups = <_LectureAttendanceGroup>[];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExporting = false;
  String? _loadError;

  bool _isEditMode = false;
  bool _hasPendingChanges = false;
  bool _weekIsAuto = true;

  /// When true, shows filters, session chips, student table, summary, edit, and export.
  final bool _showLegacyReportPanel = true;
  int? _selectedWeekNumber;
  late int _selectedDayOfWeek;
  bool _hasExplicitDateSelection = false;
  String? _selectedCourseCode;
  String? _selectedSectionId;
  String? _selectedSessionId;
  _StatusFilter _statusFilter = _StatusFilter.all;
  Map<String, _AttendanceStatus> _draftStatuses = <String, _AttendanceStatus>{};

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  @override
  void initState() {
    super.initState();
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
  bool _isDateWithinEditWindow(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final today = DateTime(
      _calendarNow.year,
      _calendarNow.month,
      _calendarNow.day,
    );
    final cutoff = today.subtract(const Duration(days: _editableWindowDays));
    return !normalized.isBefore(cutoff);
  }

  List<int> get _availableDayOptions {
    final days = _groups.map((g) => g.dayOfWeek).toSet();
    if (days.isEmpty) return _defaultWeekdayOrder;
    return _allWeekdayOrder.where(days.contains).toList();
  }

  bool get _isDateSelected => _hasExplicitDateSelection;
  bool get _isSelectedDateInFuture {
    if (!_isDateSelected) return false;
    final today = DateTime(
      _calendarNow.year,
      _calendarNow.month,
      _calendarNow.day,
    );
    return _normalizedSelectedDate.isAfter(today);
  }

  bool get _isCourseSelected =>
      _selectedCourseCode != null && _selectedCourseCode!.trim().isNotEmpty;
  bool get _isSectionSelected =>
      _selectedSectionId != null && _selectedSectionId!.trim().isNotEmpty;
  bool get _hasCompleteRequiredSelection =>
      _isDateSelected &&
      !_isSelectedDateInFuture &&
      _isCourseSelected &&
      _isSectionSelected;

  DateTime get _normalizedSelectedDate => DateTime(
    _calendarSelectedDate.year,
    _calendarSelectedDate.month,
    _calendarSelectedDate.day,
  );

  List<_LectureAttendanceGroup> get _groupsForSelectedDate {
    if (!_isDateSelected) return const <_LectureAttendanceGroup>[];
    final selectedDate = _normalizedSelectedDate;
    return _groups.where((group) {
      final groupDate = DateTime(
        group.lectureDate.year,
        group.lectureDate.month,
        group.lectureDate.day,
      );
      return groupDate == selectedDate;
    }).toList();
  }

  List<_CourseOption> get _courseOptions {
    if (!_isDateSelected || _isSelectedDateInFuture) {
      return const <_CourseOption>[];
    }
    final map = <String, _CourseOption>{};
    for (final group in _groupsForSelectedDate) {
      final key = group.courseCode.trim().isNotEmpty
          ? group.courseCode.trim()
          : group.courseName.trim();
      map.putIfAbsent(
        key,
        () => _CourseOption(code: key, label: group.courseName.trim()),
      );
    }
    final options = map.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return options;
  }

  List<_SectionOption> get _sectionOptions {
    if (!_isDateSelected || _isSelectedDateInFuture || !_isCourseSelected) {
      return const <_SectionOption>[];
    }
    final map = <String, _SectionOption>{};
    for (final group in _groupsForSelectedDate) {
      final courseKey = group.courseCode.trim().isNotEmpty
          ? group.courseCode.trim()
          : group.courseName.trim();
      if (courseKey != _selectedCourseCode) continue;
      final sectionKey = group.sectionId.trim().isNotEmpty
          ? group.sectionId.trim()
          : group.section.trim();
      map.putIfAbsent(
        sectionKey,
        () => _SectionOption(id: sectionKey, label: group.section.trim()),
      );
    }
    final options = map.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return options;
  }

  List<_LectureAttendanceGroup> get _filteredGroups {
    if (_isSelectedDateInFuture) {
      return const <_LectureAttendanceGroup>[];
    }
    if (!_hasCompleteRequiredSelection) {
      return const <_LectureAttendanceGroup>[];
    }
    final selectedDate = _normalizedSelectedDate;
    var list = _groups.where((group) {
      final groupDate = DateTime(
        group.lectureDate.year,
        group.lectureDate.month,
        group.lectureDate.day,
      );
      final courseKey = group.courseCode.trim().isNotEmpty
          ? group.courseCode.trim()
          : group.courseName.trim();
      final sectionKey = group.sectionId.trim().isNotEmpty
          ? group.sectionId.trim()
          : group.section.trim();
      return groupDate == selectedDate &&
          courseKey == _selectedCourseCode &&
          sectionKey == _selectedSectionId;
    }).toList();
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

  String get _selectedCourseLabel {
    final key = _selectedCourseCode;
    if (key == null || key.trim().isEmpty) {
      return _tr('غير محدد', 'Not selected');
    }
    for (final option in _courseOptions) {
      if (option.code == key) return option.label;
    }
    return key;
  }

  String get _selectedSectionLabel {
    final key = _selectedSectionId;
    if (key == null || key.trim().isEmpty) {
      return _tr('غير محدد', 'Not selected');
    }
    for (final option in _sectionOptions) {
      if (option.id == key) return option.label;
    }
    return key;
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
        _calendarSelectedDate = DateTime(
          _calendarNow.year,
          _calendarNow.month,
          _calendarNow.day,
        );
        if (groups.isNotEmpty) {
          final latest = groups.first;
          _selectedDayOfWeek = latest.dayOfWeek;
          _weekIsAuto = false;
          _selectedWeekNumber = latest.weekNumber;
        }
        _groups = groups;
        _hasExplicitDateSelection = false;
        _selectedCourseCode = null;
        _selectedSectionId = null;
        _statusFilter = _StatusFilter.all;
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
      final courseCode = (session.courseCode ?? '').trim().isNotEmpty
          ? (session.courseCode ?? '').trim()
          : lecture?.crn.trim() ?? '';
      final sectionLabel = session.sectionLabel.trim().isNotEmpty
          ? session.sectionLabel
          : (lecture?.section ?? '-');
      final sectionId = session.sectionId.trim().isNotEmpty
          ? session.sectionId.trim()
          : (lecture?.sectionId ?? '').trim();
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
          courseCode: courseCode,
          section: sectionLabel,
          sectionId: sectionId,
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
    final selectedCourseCode = _selectedCourseCode;
    if (selectedCourseCode != null &&
        !_courseOptions.any((option) => option.code == selectedCourseCode)) {
      _selectedCourseCode = null;
    }
    final selectedSectionId = _selectedSectionId;
    if (selectedSectionId != null &&
        !_sectionOptions.any((option) => option.id == selectedSectionId)) {
      _selectedSectionId = null;
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

  Future<void> _exportActiveSessionCsv(_LectureAttendanceGroup group) async {
    if (_isExporting) return;
    if (_isEditMode && _hasPendingChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'احفظي تعديلات الحضور قبل التصدير.',
              'Save attendance changes before exporting.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      await AttendanceSessionExportService.instance.exportSessionCsvAndShare(
        group.sessionId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_tr('فشل التصدير.', 'Export failed.')} $e'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickReportDate() async {
    final initial = _isDateSelected ? _normalizedSelectedDate : DateTime.now();
    final today = DateTime(
      _calendarNow.year,
      _calendarNow.month,
      _calendarNow.day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      selectableDayPredicate: (day) {
        final normalizedDay = DateTime(day.year, day.month, day.day);
        return !normalizedDay.isAfter(today);
      },
      locale: LecturerLanguageController.isArabic
          ? const Locale('ar')
          : const Locale('en'),
      builder: (dialogContext, child) {
        final base = Theme.of(dialogContext);
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(
              primary: _primary,
              onPrimary: Colors.white,
              surface: const Color(0xFFF8FBFB),
              onSurface: const Color(0xFF23363B),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFFF8FBFB),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                textStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          child: Directionality(
            textDirection: LecturerLanguageController.direction(),
            child: Localizations.override(
              context: dialogContext,
              locale: LecturerLanguageController.isArabic
                  ? const Locale('ar')
                  : const Locale('en'),
              child: child!,
            ),
          ),
        );
      },
    );
    if (!mounted || picked == null) return;

    setState(() {
      _hasExplicitDateSelection = true;
      _calendarSelectedDate = DateTime(picked.year, picked.month, picked.day);
      _selectedCourseCode = null;
      _selectedSectionId = null;
      _selectedSessionId = null;
      _selectedDayOfWeek = _calendarSelectedDate.weekday;
      _statusFilter = _StatusFilter.all;
      _resetEditState();
    });
  }

  // ignore: unused_element
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
    final canEditInWindow = _isDateWithinEditWindow(selectedDate);
    final existingGroup = _findGroupForLectureAndDate(
      lecture: lecture,
      date: selectedDate,
    );
    final hasExistingAttendance = existingGroup != null;

    final action = await showDialog<_AttendanceCalendarAction>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) {
        final screenW = MediaQuery.sizeOf(dialogContext).width;
        final maxCardW = min(400.0, screenW - 40);
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxCardW,
                minWidth: min(300.0, maxCardW),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE3ECEE)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _tr('إجراء الحضور', 'Attendance action'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2F4449),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _tr(
                          'اختاري الإجراء للمحاضرة في ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          'Choose action for lecture on ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        ),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: Color(0xFF5F747A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(top: 14, bottom: 4),
                        color: const Color(0xFFE8EEF0),
                      ),
                      _sessionDecisionDialogActions(
                        dialogContext: dialogContext,
                        isFuture: isFuture,
                        canEditInWindow: canEditInWindow,
                        hasExistingAttendance: hasExistingAttendance,
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF60757A),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 20,
                            ),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(
                            _tr('إلغاء', 'Cancel'),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
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
      },
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _AttendanceCalendarAction.exportCsv:
        final g = existingGroup;
        if (g != null) {
          await _exportActiveSessionCsv(g);
        }
        break;
      case _AttendanceCalendarAction.preview:
        LecturerNavigation.goToAttendanceViewOnly(
          context,
          lecture,
          selectedDate,
        );
        break;
      case _AttendanceCalendarAction.editPrevious:
      case _AttendanceCalendarAction.attend:
        if (!canEditInWindow) {
          LecturerNavigation.goToAttendanceViewOnly(
            context,
            lecture,
            selectedDate,
          );
          break;
        }
        LecturerNavigation.goToAttendance(
          context,
          lecture,
          selectedDate: selectedDate,
        );
        break;
    }
  }

  /// Session decision modal — **actions only** (presentation). Branching matches
  /// `_openCalendarActionPopup`: same buttons, same conditions; layout is vertical + full width.
  Widget _sessionDecisionDialogActions({
    required BuildContext dialogContext,
    required bool isFuture,
    required bool canEditInWindow,
    required bool hasExistingAttendance,
  }) {
    const gap = SizedBox(height: 10);
    final filledStyle = FilledButton.styleFrom(
      backgroundColor: const Color(0xFF006571),
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    final outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF006571),
      side: const BorderSide(color: Color(0xFF006571)),
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    final labelStyle = const TextStyle(
      fontFamily: 'Cairo',
      fontWeight: FontWeight.w700,
      fontSize: 14,
    );

    if (isFuture) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            style: filledStyle,
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_AttendanceCalendarAction.attend),
            icon: const Icon(Icons.fact_check_rounded, size: 18),
            label: Text(_tr('تحضير', 'Take attendance'), style: labelStyle),
          ),
          if (hasExistingAttendance) ...[
            gap,
            OutlinedButton.icon(
              style: outlinedStyle,
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_AttendanceCalendarAction.exportCsv),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: Text(_tr('تصدير CSV', 'Export CSV'), style: labelStyle),
            ),
          ],
        ],
      );
    }
    if (hasExistingAttendance) {
      if (!canEditInWindow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              style: filledStyle,
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_AttendanceCalendarAction.preview),
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: Text(
                _tr('معاينة الحضور', 'Preview attendance'),
                style: labelStyle,
              ),
            ),
            gap,
            OutlinedButton.icon(
              style: outlinedStyle,
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_AttendanceCalendarAction.exportCsv),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: Text(_tr('تصدير CSV', 'Export CSV'), style: labelStyle),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            style: filledStyle,
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_AttendanceCalendarAction.editPrevious),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(
              _tr('تعديل الحضور', 'Edit attendance'),
              style: labelStyle,
            ),
          ),
          gap,
          OutlinedButton.icon(
            style: outlinedStyle,
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_AttendanceCalendarAction.preview),
            icon: const Icon(Icons.visibility_rounded, size: 18),
            label: Text(
              _tr('معاينة الحضور', 'Preview attendance'),
              style: labelStyle,
            ),
          ),
          gap,
          OutlinedButton.icon(
            style: outlinedStyle,
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_AttendanceCalendarAction.exportCsv),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text(_tr('تصدير CSV', 'Export CSV'), style: labelStyle),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: filledStyle,
          onPressed: () =>
              Navigator.of(dialogContext).pop(_AttendanceCalendarAction.attend),
          icon: const Icon(Icons.fact_check_rounded, size: 18),
          label: Text(_tr('تحضير', 'Take attendance'), style: labelStyle),
        ),
      ],
    );
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

  void _onSectionChanged(String? sectionId) {
    setState(() {
      _selectedSectionId = sectionId;
      final selectedCourseCode = _selectedCourseCode;
      final selectedId = _selectedSectionId;
      if (selectedCourseCode != null &&
          selectedId != null &&
          !_groupsForSelectedDate.any((group) {
            final courseKey = group.courseCode.trim().isNotEmpty
                ? group.courseCode.trim()
                : group.courseName.trim();
            final sectionKey = group.sectionId.trim().isNotEmpty
                ? group.sectionId.trim()
                : group.section.trim();
            return courseKey == selectedCourseCode && sectionKey == selectedId;
          })) {
        _selectedCourseCode = null;
      }
      _statusFilter = _StatusFilter.all;
      _normalizeLinkedSelections();
      _normalizeSelectedSession();
      _resetEditState();
    });
  }

  void _onCourseChanged(String? courseCode) {
    setState(() {
      _selectedCourseCode = courseCode;
      final selectedCourseCode = _selectedCourseCode;
      final selectedId = _selectedSectionId;
      if (selectedCourseCode != null &&
          selectedId != null &&
          !_groupsForSelectedDate.any((group) {
            final courseKey = group.courseCode.trim().isNotEmpty
                ? group.courseCode.trim()
                : group.courseName.trim();
            final sectionKey = group.sectionId.trim().isNotEmpty
                ? group.sectionId.trim()
                : group.section.trim();
            return courseKey == selectedCourseCode && sectionKey == selectedId;
          })) {
        _selectedSectionId = null;
      }
      _statusFilter = _StatusFilter.all;
      _normalizeLinkedSelections();
      _normalizeSelectedSession();
      _resetEditState();
    });
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

  void _onSessionChanged(String? sessionId) {
    setState(() {
      _selectedSessionId = sessionId;
      _statusFilter = _StatusFilter.all;
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

    if (!_isDateWithinEditWindow(group.lectureDate)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'هذه الجلسة أقدم من أسبوعين — المعاينة فقط متاحة.',
              'This session is older than two weeks — preview only is allowed.',
            ),
          ),
        ),
      );
      if (exitEditMode) {
        setState(() => _resetEditState());
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

  /// تصدير CSV متاح فقط لجلسة محددة وبعد حفظ أي تعديلات معلّقة.
  bool _canTapExportCsv(_LectureAttendanceGroup? g) {
    if (g == null || _isExporting || _isSaving) return false;
    if (_isEditMode && _hasPendingChanges) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final group = _activeGroup;

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
                              if (_showLegacyReportPanel) ...[
                                _buildFilters(),
                                const SizedBox(height: 10),
                                _buildSelectionStateBanner(),
                                const SizedBox(height: 10),
                                if (_hasCompleteRequiredSelection &&
                                    group != null) ...[
                                  _buildSessionSelector(),
                                  const SizedBox(height: 10),
                                  _buildReportSummaryCard(group),
                                  const SizedBox(height: 10),
                                  _buildReportActionButtons(group),
                                ] else if (_hasCompleteRequiredSelection)
                                  SizedBox(
                                    height: constraints.maxHeight * 0.30,
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

  Widget _buildFilters() {
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
                _tr('اختيار التقرير', 'Report Selection'),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2F4449),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FilterCard(
                  title: _tr('التاريخ', 'Date'),
                  value: _isDateSelected
                      ? _formatDate(_normalizedSelectedDate)
                      : _tr('غير محدد', 'Not selected'),
                  subtitle: _tr('اضغط لاختيار التاريخ', 'Tap to choose date'),
                  icon: Icons.calendar_month_rounded,
                  onTap: _pickReportDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterCard(
                  title: _tr('المقرر', 'Course'),
                  value: _selectedCourseLabel,
                  icon: Icons.menu_book_rounded,
                  onTap: _isDateSelected
                      ? (_isSelectedDateInFuture
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _tr(
                                        'لا يمكن عرض تقرير لتاريخ مستقبلي.',
                                        'Cannot open report for a future date.',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            : _showCoursePickerSheet)
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _tr(
                                  'اختر التاريخ أولاً ثم المقرر.',
                                  'Select date first, then choose course.',
                                ),
                              ),
                            ),
                          );
                        },
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
                  value: _selectedSectionLabel,
                  icon: Icons.groups_rounded,
                  onTap: (_isDateSelected && _isCourseSelected)
                      ? (_isSelectedDateInFuture
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _tr(
                                        'لا يمكن عرض تقرير لتاريخ مستقبلي.',
                                        'Cannot open report for a future date.',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            : _showSectionPickerSheet)
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _tr(
                                  'اختر التاريخ والمقرر أولاً ثم الشعبة.',
                                  'Select date and course first, then section.',
                                ),
                              ),
                            ),
                          );
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionStateBanner() {
    String message;
    Color bg = const Color(0xFFF3F7F8);
    Color border = const Color(0xFFD8E4E7);
    Color text = const Color(0xFF455D63);
    IconData icon = Icons.info_outline_rounded;

    if (!_isDateSelected) {
      message = _tr(
        'لم يتم اختيار التاريخ بعد. يرجى اختيار التاريخ من التقويم.',
        'Date is not selected yet. Please choose a date from the calendar.',
      );
    } else if (_isSelectedDateInFuture) {
      message = _tr(
        'هذا تاريخ مستقبلي. لا يمكن عرض تقرير لتاريخ مستقبلي.',
        'This is a future date. Reports are not available yet.',
      );
      bg = const Color(0xFFFFF4E5);
      border = const Color(0xFFF3D6A8);
      text = const Color(0xFF8A5A00);
      icon = Icons.schedule_rounded;
    } else if (!_isCourseSelected) {
      message = _tr('لم يتم اختيار المقرر بعد.', 'Course is not selected yet.');
    } else if (!_isSectionSelected) {
      message = _tr(
        'لم يتم اختيار الشعبة بعد.',
        'Section is not selected yet.',
      );
    } else {
      final group = _activeGroup;
      if (group == null) {
        message = _tr(
          'لا توجد محاضرة/تقرير مطابق للاختيارات المحددة.',
          'No lecture/report matches the selected date, course, and section.',
        );
        icon = Icons.event_busy_rounded;
      } else if (_isDateWithinEditWindow(group.lectureDate)) {
        message = _tr(
          'التقرير حديث: المعاينة والتعديل متاحان.',
          'Recent report: preview and edit are available.',
        );
        bg = const Color(0xFFEAF7EF);
        border = const Color(0xFFCBE8D2);
        text = const Color(0xFF24643A);
        icon = Icons.check_circle_outline_rounded;
      } else {
        message = _tr(
          'التقرير قديم (أكثر من 14 يوم): المعاينة فقط.',
          'Old report (older than 14 days): preview only.',
        );
        bg = const Color(0xFFFFF4E5);
        border = const Color(0xFFF3D6A8);
        text = const Color(0xFF8A5A00);
        icon = Icons.visibility_rounded;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: text),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttendanceForGroup(
    _LectureAttendanceGroup group, {
    required bool viewOnly,
  }) async {
    final lecture = group.lecture;
    if (lecture == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'لا يمكن فتح التقرير لأن بيانات المحاضرة غير مكتملة.',
              'Cannot open report because lecture data is incomplete.',
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
        sessionId: group.sessionId,
      );
      return;
    }

    LecturerNavigation.goToAttendance(
      context,
      lecture,
      selectedDate: group.lectureDate,
      sessionId: group.sessionId,
    );
  }

  Widget _buildReportSummaryCard(_LectureAttendanceGroup group) {
    final canEditInWindow = _isDateWithinEditWindow(group.lectureDate);
    final statusLabel = canEditInWindow
        ? _tr('قابل للتعديل', 'Editable')
        : _tr('معاينة فقط', 'Preview only');
    final statusColor = canEditInWindow
        ? const Color(0xFF1B8E3E)
        : const Color(0xFF8A5A00);
    final statusBg = canEditInWindow
        ? const Color(0xFFEAF7EF)
        : const Color(0xFFFFF4E5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE7E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF213236),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_tr('الشعبة', 'Section')}: ${group.section}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: Color(0xFF55666B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_tr('التاريخ', 'Date')}: ${_formatDate(group.lectureDate)}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: Color(0xFF55666B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportActionButtons(_LectureAttendanceGroup group) {
    final canEditInWindow = _isDateWithinEditWindow(group.lectureDate);
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _openAttendanceForGroup(group, viewOnly: true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF006571),
              minimumSize: const Size.fromHeight(44),
            ),
            icon: const Icon(Icons.visibility_rounded, size: 18),
            label: Text(
              _tr('معاينة التقرير', 'Preview report'),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (canEditInWindow) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openAttendanceForGroup(group, viewOnly: false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                side: const BorderSide(color: Color(0xFF006571)),
                foregroundColor: const Color(0xFF006571),
              ),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(
                _tr('تعديل التقرير', 'Edit report'),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isExporting
                ? null
                : () => _exportActiveSessionCsv(group),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: Color(0xFF006571)),
              foregroundColor: const Color(0xFF006571),
            ),
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_rounded, size: 18),
            label: Text(
              _tr('تصدير CSV', 'Export CSV'),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
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

  // ignore: unused_element
  Widget _buildControlBar(_LectureAttendanceGroup group) {
    final canEditInWindow = _isDateWithinEditWindow(group.lectureDate);
    if (!canEditInWindow && _isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _resetEditState());
      });
    }
    final modeLabel = _isEditMode
        ? _tr('وضع التعديل مفعل', 'Edit mode enabled')
        : canEditInWindow
        ? _tr('وضع المعاينة', 'Preview mode')
        : _tr('تقرير قديم: معاينة فقط', 'Old report: preview only');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE7E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                child: Tooltip(
                  message: _isEditMode && _hasPendingChanges
                      ? _tr(
                          'احفظي التعديلات قبل التصدير.',
                          'Save changes before export.',
                        )
                      : _tr(
                          'تصدير حضور هذه الجلسة CSV',
                          'Export this session as CSV',
                        ),
                  child: OutlinedButton.icon(
                    onPressed: !_canTapExportCsv(group)
                        ? null
                        : () => _exportActiveSessionCsv(group),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share_rounded, size: 18),
                    label: Text(
                      _tr('تصدير CSV', 'Export CSV'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      side: const BorderSide(color: Color(0xFF006571)),
                      foregroundColor: const Color(0xFF006571),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
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
                value: canEditInWindow && _isEditMode,
                activeTrackColor: _primary.withValues(alpha: 0.5),
                activeThumbColor: _primary,
                onChanged: (!canEditInWindow || _isExporting)
                    ? null
                    : (on) async {
                        if (on) {
                          _enterEditMode(group);
                          return;
                        }
                        await _switchToViewMode(group);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
  Widget _buildStudentsTable(double height) {
    final activeGroup = _activeGroup;
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
                        (activeGroup == null || activeGroup.students.isEmpty)
                            ? _tr(
                                'لا توجد سجلات حضور لهذه الجلسة.',
                                'No attendance records for this session.',
                              )
                            : _tr(
                                'لا يوجد طلاب مطابقون لهذا الفلتر.',
                                'No students match this filter.',
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
                'لا توجد محاضرة/تقرير مطابق للتاريخ والمقرر والشعبة المختارة.',
                'No lecture/report matches the selected date, course, and section.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFF4F6369),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _tr(
                'يمكنك اختيار تاريخ مختلف أو مقرر/شعبة مختلفة، أو التأكد من وجود جلسة حضور محفوظة في Firestore لهذه الاختيارات.',
                'Choose a different date/course/section, or verify that a matching attendance session exists in Firestore.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Color(0xFF758A90),
                fontWeight: FontWeight.w600,
                height: 1.35,
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

  // ignore: unused_element
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

  // ignore: unused_element
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
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSectionPickerSheet() {
    final options = _sectionOptions;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'لا توجد شعب متاحة لهذا المقرر في التاريخ المختار.',
              'No sections available for this course on selected date.',
            ),
          ),
        ),
      );
      return;
    }
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
              final selected = _selectedSectionId == section.id;
              return ListTile(
                title: Text(
                  section.label,
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
                  _onSectionChanged(section.id);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showCoursePickerSheet() {
    final options = _courseOptions;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'لا توجد مقررات لها جلسة في التاريخ المختار.',
              'No courses have a session on selected date.',
            ),
          ),
        ),
      );
      return;
    }
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
              final selected = _selectedCourseCode == course.code;
              return ListTile(
                title: Text(
                  course.label,
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
                  _onCourseChanged(course.code);
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

// ignore: unused_element
class _AttendanceDayActionScreen extends StatelessWidget {
  const _AttendanceDayActionScreen({
    required this.dayLabel,
    required this.weekNumber,
    required this.sessions,
    required this.tr,
    required this.onExportCsv,
  });

  final String dayLabel;
  final int weekNumber;
  final List<_LectureAttendanceGroup> sessions;
  final String Function(String ar, String en) tr;
  final Future<void> Function(String sessionId) onExportCsv;

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
        sessionId: group.sessionId,
      );
      return;
    }
    LecturerNavigation.goToAttendance(
      context,
      lecture,
      selectedDate: group.lectureDate,
      sessionId: group.sessionId,
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
                  final canEditInWindow = !groupDate.isBefore(
                    today.subtract(const Duration(days: 14)),
                  );
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
                          if (isFuture)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _openAttendanceForSession(
                                      context,
                                      group,
                                      viewOnly: false,
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
                                    icon: const Icon(
                                      Icons.fact_check_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      tr('تحضير', 'Take attendance'),
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        onExportCsv(group.sessionId),
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
                                      Icons.share_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      tr('تصدير', 'Export'),
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openAttendanceForSession(
                                      context,
                                      group,
                                      viewOnly: !canEditInWindow,
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
                                    icon: Icon(
                                      canEditInWindow
                                          ? Icons.edit_rounded
                                          : Icons.visibility_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      canEditInWindow
                                          ? tr(
                                              'تعديل الحضور',
                                              'Edit attendance',
                                            )
                                          : tr(
                                              'معاينة الحضور',
                                              'Preview attendance',
                                            ),
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _openAttendanceForSession(
                                      context,
                                      group,
                                      viewOnly: true,
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
                                    icon: const Icon(
                                      Icons.visibility_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      tr('معاينة الحضور', 'Preview attendance'),
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        onExportCsv(group.sessionId),
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
                                      Icons.share_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      tr('تصدير', 'Export'),
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
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

enum _AttendanceCalendarAction { attend, editPrevious, preview, exportCsv }

enum _StatusFilter { all, present, absent, excused, late }

enum _AttendanceStatus { present, absent, excused, late }

class _LectureAttendanceGroup {
  _LectureAttendanceGroup({
    required this.sessionId,
    required this.lecture,
    required this.courseName,
    required this.courseCode,
    required this.section,
    required this.sectionId,
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
  final String courseCode;
  final String section;
  final String sectionId;
  final int dayOfWeek;
  final int weekNumber;
  final DateTime lectureDate;
  final String startTime;
  final String timeRange;
  final List<_StudentAttendanceRecord> students;
}

class _CourseOption {
  const _CourseOption({required this.code, required this.label});

  final String code;
  final String label;
}

class _SectionOption {
  const _SectionOption({required this.id, required this.label});

  final String id;
  final String label;
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
