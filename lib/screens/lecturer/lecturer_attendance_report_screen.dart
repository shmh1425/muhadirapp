import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../models/attendance/manual_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../models/lecturer/unified_lecturer_catalog.dart';
import '../../providers/lecturer_catalog_providers.dart';
import '../../services/attendance/attendance_session_export_service.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/lecturer_attendance_sessions_warm_cache.dart';
import '../../services/lecturer_auth_service.dart';
import '../../utils/shared/time_utils.dart';
import 'lecturer_language.dart';
import 'lecturer_navigation.dart';
import 'widgets/modern_popup_dialog.dart';
import 'widgets/profile_back_button.dart';

class _AttendanceReportNavCache {
  _AttendanceReportNavCache({
    required this.lecturerId,
    required this.groups,
    required this.calendarNow,
    required this.calendarSelectedDate,
    required this.weekIsAuto,
    required this.selectedWeekNumber,
    required this.selectedDayOfWeek,
    required this.selectedCourseCode,
    required this.selectedSessionId,
    required this.statusFilter,
    required this.loadedRecordSessionIds,
    required this.selectedLectureForCalendar,
  });

  final String lecturerId;
  final List<_LectureAttendanceGroup> groups;
  final DateTime calendarNow;
  final DateTime calendarSelectedDate;
  final bool weekIsAuto;
  final int? selectedWeekNumber;
  final int selectedDayOfWeek;
  final String? selectedCourseCode;
  final String? selectedSessionId;
  final _StatusFilter statusFilter;
  final Set<String> loadedRecordSessionIds;
  final LectureItem? selectedLectureForCalendar;
}

_AttendanceReportNavCache? _gAttendanceReportNavCache;

/// Cleared on lecturer logout.
void clearLecturerAttendanceReportNavCache() {
  _gAttendanceReportNavCache = null;
}

class LecturerAttendanceReportScreen extends ConsumerStatefulWidget {
  const LecturerAttendanceReportScreen({super.key});

  @override
  ConsumerState<LecturerAttendanceReportScreen> createState() =>
      _LecturerAttendanceReportScreenState();
}

class _LecturerAttendanceReportScreenState
    extends ConsumerState<LecturerAttendanceReportScreen> {
  static const Color _primary = Color(0xFF006571);
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
  bool _isRefreshingReport = false;
  bool _isLoadingRecords = false;
  Set<String> _loadedRecordSessionIds = <String>{};
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
  String? _selectedCourseCode;
  String? _selectedSessionId;
  _StatusFilter _statusFilter = _StatusFilter.all;
  Map<String, _AttendanceStatus> _draftStatuses = <String, _AttendanceStatus>{};

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  @override
  void initState() {
    super.initState();
    _selectedDayOfWeek = DateTime.now().weekday;
    LecturerLanguageController.notifier.addListener(_onLecturerLanguageChanged);
    _calendarSyncSub = CalendarSyncService.instance.watchChanges().listen(
      (_) => _handleRealtimeCalendarChange(),
    );
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    final cached = _gAttendanceReportNavCache;
    if (lecturerId.isNotEmpty &&
        cached != null &&
        cached.lecturerId == lecturerId &&
        cached.groups.isNotEmpty) {
      _applyAttendanceReportNavCache(cached);
    } else {
      _loadReportData();
    }
  }

  @override
  void dispose() {
    _saveAttendanceReportNavCache();
    LecturerLanguageController.notifier.removeListener(_onLecturerLanguageChanged);
    _calendarSyncSub?.cancel();
    super.dispose();
  }

  void _applyAttendanceReportNavCache(_AttendanceReportNavCache c) {
    _calendarNow = c.calendarNow;
    _calendarSelectedDate = c.calendarSelectedDate;
    _weekIsAuto = c.weekIsAuto;
    _selectedWeekNumber = c.selectedWeekNumber;
    _selectedDayOfWeek = c.selectedDayOfWeek;
    _selectedCourseCode = c.selectedCourseCode;
    _selectedSessionId = c.selectedSessionId;
    _statusFilter = c.statusFilter;
    _selectedLectureForCalendar = c.selectedLectureForCalendar;
    _groups = c.groups.map((g) => g.deepCopy()).toList();
    _loadedRecordSessionIds = Set<String>.from(c.loadedRecordSessionIds);
    _isRefreshingReport = false;
    _isLoadingRecords = false;
    _loadError = null;
    _isEditMode = false;
    _hasPendingChanges = false;
    _draftStatuses = <String, _AttendanceStatus>{};
  }

  void _saveAttendanceReportNavCache() {
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    if (lecturerId.isEmpty || _groups.isEmpty) return;
    _gAttendanceReportNavCache = _AttendanceReportNavCache(
      lecturerId: lecturerId,
      groups: _groups.map((g) => g.deepCopy()).toList(),
      calendarNow: _calendarNow,
      calendarSelectedDate: _calendarSelectedDate,
      weekIsAuto: _weekIsAuto,
      selectedWeekNumber: _selectedWeekNumber,
      selectedDayOfWeek: _selectedDayOfWeek,
      selectedCourseCode: _selectedCourseCode,
      selectedSessionId: _selectedSessionId,
      statusFilter: _statusFilter,
      loadedRecordSessionIds: Set<String>.from(_loadedRecordSessionIds),
      selectedLectureForCalendar: _selectedLectureForCalendar,
    );
  }

  void _onLecturerLanguageChanged() {
    unawaited(_syncReportLabelsFromCatalog());
  }

  Future<void> _syncReportLabelsFromCatalog() async {
    try {
      final asyncCat = ref.read(lecturerUnifiedCatalogProvider);
      final UnifiedLecturerCatalog catalog = asyncCat.hasValue
          ? asyncCat.requireValue
          : await ref.read(lecturerUnifiedCatalogProvider.future);
      if (!mounted || _groups.isEmpty) return;
      final lectures = catalog.toLectureItems(
        isArabic: LecturerLanguageController.isArabic,
      );
      final bySection = <String, LectureItem>{};
      for (final lecture in lectures) {
        final sectionId = (lecture.sectionId ?? '').trim();
        if (sectionId.isEmpty) continue;
        bySection[sectionId] = lecture;
      }
      setState(() {
        _groups = _groups.map((g) {
          final sid = g.sectionId.trim();
          final lec = sid.isNotEmpty ? bySection[sid] : null;
          final nextLecture = lec ?? g.lecture;
          final courseName =
              (nextLecture?.courseName.trim().isNotEmpty ?? false)
                  ? nextLecture!.courseName
                  : g.courseName;
          final courseCode = (nextLecture?.crn.trim().isNotEmpty ?? false)
              ? nextLecture!.crn.trim()
              : g.courseCode;
          final section = (nextLecture?.section.trim().isNotEmpty ?? false)
              ? nextLecture!.section
              : g.section;
          return _LectureAttendanceGroup(
            sessionId: g.sessionId,
            lecture: nextLecture,
            courseName: courseName,
            courseCode: courseCode,
            section: section,
            sectionId: g.sectionId,
            dayOfWeek: g.dayOfWeek,
            weekNumber: g.weekNumber,
            lectureDate: g.lectureDate,
            startTime: g.startTime,
            timeRange: g.timeRange,
            students: g.students,
          );
        }).toList();
      });
      _saveAttendanceReportNavCache();
    } catch (_) {
      // Keep cached sessions; labels fall back to last loaded values.
    }
  }

  Set<String> _targetSessionIdsForRecordsLoad() {
    final sid = _selectedSessionId?.trim() ?? '';
    if (sid.isNotEmpty) return {sid};
    // No session selected yet: don't eagerly load all records (can be huge).
    // We only load records when user narrows by selecting a course/week or picks a session.
    return const <String>{};
  }

  Future<void> _ensureRecordsLoaded(Set<String> sessionIds) async {
    final ids = sessionIds.where((e) => e.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return;
    final want = ids.difference(_loadedRecordSessionIds);
    if (want.isEmpty) return;
    if (_isLoadingRecords) return;

    setState(() => _isLoadingRecords = true);
    try {
      final recordsBySession = await _manualAttendanceService.getRecordsForSessionIds(want);
      if (!mounted) return;
      setState(() {
        _loadedRecordSessionIds.addAll(want);
        _applyRecordsToGroups(recordsBySession);
      });
    } catch (_) {
      // Keep UI responsive; records can be re-attempted by changing filters/session.
    } finally {
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  void _applyRecordsToGroups(Map<String, List<ManualAttendanceRecord>> recordsBySession) {
    if (recordsBySession.isEmpty) return;
    final updated = <_LectureAttendanceGroup>[];
    for (final g in _groups) {
      final records = recordsBySession[g.sessionId];
      if (records == null) {
        updated.add(g);
        continue;
      }
      String timeText(ManualAttendanceRecord record) {
        final stored = record.attendanceTime.trim();
        if (stored.isNotEmpty) return stored;
        if (record.isPresentLike) return g.startTime;
        return '--';
      }

      final students = records.map((record) {
        return _StudentAttendanceRecord(
          id: record.recordId,
          studentId: record.studentId,
          name: record.studentName.trim().isNotEmpty
              ? record.studentName
              : record.studentId.toString(),
          academicNumber: record.studentId.toString(),
          time: timeText(record),
          status: _statusFromManual(record.status),
        );
      }).toList();

      updated.add(
        _LectureAttendanceGroup(
          sessionId: g.sessionId,
          lecture: g.lecture,
          courseName: g.courseName,
          courseCode: g.courseCode,
          section: g.section,
          sectionId: g.sectionId,
          dayOfWeek: g.dayOfWeek,
          weekNumber: g.weekNumber,
          lectureDate: g.lectureDate,
          startTime: g.startTime,
          timeRange: g.timeRange,
          students: students,
        ),
      );
    }
    _groups = updated;
  }

  int get _currentWeekNumber => _calendarRepository.getWeekNumber(_calendarNow);
  int get _effectiveWeekNumber => _weekIsAuto
      ? _currentWeekNumber
      : (_selectedWeekNumber ?? _currentWeekNumber);

  List<int> get _availableDayOptions {
    final days = _groups.map((g) => g.dayOfWeek).toSet();
    if (days.isEmpty) return _defaultWeekdayOrder;
    return _allWeekdayOrder.where(days.contains).toList();
  }

  bool get _isCourseSelected =>
      _selectedCourseCode != null && _selectedCourseCode!.trim().isNotEmpty;
  bool get _hasSelectedSession =>
      _selectedSessionId != null && _selectedSessionId!.trim().isNotEmpty;
  bool get _hasCompleteRequiredSelection => _hasSelectedSession;

  List<_CourseOption> get _courseOptions {
    final map = <String, _CourseOption>{};
    for (final group in _groups) {
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

  List<int> get _weekOptionsForSelectedCourse {
    final source = _isCourseSelected
        ? _groups.where((group) {
            final key = group.courseCode.trim().isNotEmpty
                ? group.courseCode.trim()
                : group.courseName.trim();
            return key == _selectedCourseCode;
          })
        : _groups;
    final weeks = source.map((group) => group.weekNumber).toSet().toList()
      ..sort();
    return weeks;
  }

  List<_LectureAttendanceGroup> get _filteredGroups {
    var list = _groups.where((group) {
      if (_isCourseSelected) {
        final courseKey = group.courseCode.trim().isNotEmpty
            ? group.courseCode.trim()
            : group.courseName.trim();
        if (courseKey != _selectedCourseCode) return false;
      }
      if (_selectedWeekNumber != null &&
          group.weekNumber != _selectedWeekNumber) {
        return false;
      }
      return true;
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

  /// Instant path: catalog already in memory + warm session list matches sections.
  List<_LectureAttendanceGroup>? _computeHydratedGroupsFromCaches() {
    final cat = ref.read(lecturerUnifiedCatalogProvider).valueOrNull;
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    if (cat == null || cat.isEmpty || lecturerId.isEmpty) return null;
    final lectures = cat.toLectureItems(
      isArabic: LecturerLanguageController.isArabic,
    );
    final lectureBySection = <String, LectureItem>{};
    final sectionIds = <String>{};
    for (final lecture in lectures) {
      final sectionId = (lecture.sectionId ?? '').trim();
      if (sectionId.isEmpty) continue;
      sectionIds.add(sectionId);
      lectureBySection[sectionId] = lecture;
    }
    final warm =
        LecturerAttendanceSessionsWarmCache.takeMatching(lecturerId, sectionIds);
    if (warm == null) return null;
    final groups = _buildGroupsFromFirestore(
      sessions: warm,
      recordsBySession: const <String, List<ManualAttendanceRecord>>{},
      lectureBySection: lectureBySection,
    );
    if (groups.isEmpty) return null;
    return groups;
  }

  Future<void> _loadReportData() async {
    final hadGroups = _groups.isNotEmpty;
    if (!mounted) return;
    setState(() {
      _loadError = null;
      _isRefreshingReport = true;
    });

    if (!hadGroups) {
      final hydrated = _computeHydratedGroupsFromCaches();
      if (hydrated != null && mounted) {
        setState(() {
          _calendarNow = _calendarRepository.currentDateTime;
          if (_weekIsAuto) {
            _selectedDayOfWeek = _calendarNow.weekday;
          }
          _calendarSelectedDate = DateTime(
            _calendarNow.year,
            _calendarNow.month,
            _calendarNow.day,
          );
          _weekIsAuto = false;
          _selectedWeekNumber = null;
          _groups = hydrated;
          _selectedCourseCode = null;
          _selectedSessionId = null;
          _statusFilter = _StatusFilter.all;
          _normalizeLinkedSelections();
          _normalizeSelectedSession();
        });
        _saveAttendanceReportNavCache();
      }
    }

    try {
      await Future.wait<Object?>([
        _calendarRepository.refreshAcademicCalendar(),
        ref.read(lecturerUnifiedCatalogProvider.future),
      ]);
      _calendarNow = _calendarRepository.currentDateTime;
      if (_weekIsAuto) {
        _selectedDayOfWeek = _calendarNow.weekday;
      }
      final catalog = ref.read(lecturerUnifiedCatalogProvider).requireValue;
      final lectures = catalog.toLectureItems(
        isArabic: LecturerLanguageController.isArabic,
      );
      final lectureBySection = <String, LectureItem>{};
      final sectionIds = <String>{};
      for (final lecture in lectures) {
        final sectionId = (lecture.sectionId ?? '').trim();
        if (sectionId.isEmpty) continue;
        sectionIds.add(sectionId);
        lectureBySection[sectionId] = lecture;
      }

      final lecturerIdForWarm =
          LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
      final warmSessions = lecturerIdForWarm.isNotEmpty
          ? LecturerAttendanceSessionsWarmCache.takeMatching(
              lecturerIdForWarm,
              sectionIds,
            )
          : null;
      final sessions = warmSessions ??
          await _manualAttendanceService.getSessionsForSectionIds(
            sectionIds,
          );
      final groups = _buildGroupsFromFirestore(
        sessions: sessions,
        recordsBySession: const <String, List<ManualAttendanceRecord>>{},
        lectureBySection: lectureBySection,
      );

      if (!mounted) return;
      setState(() {
        _calendarSelectedDate = DateTime(
          _calendarNow.year,
          _calendarNow.month,
          _calendarNow.day,
        );
        _weekIsAuto = false;
        _selectedWeekNumber = null;
        _groups = groups;
        _selectedCourseCode = null;
        _selectedSessionId = null;
        _statusFilter = _StatusFilter.all;
        _normalizeLinkedSelections();
        _normalizeSelectedSession();
        _isRefreshingReport = false;
      });

      _saveAttendanceReportNavCache();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRefreshingReport = false;
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
      case ManualAttendanceStatus.pending:
        return _AttendanceStatus.pending;
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
      case _AttendanceStatus.pending:
        return ManualAttendanceStatus.pending;
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
      _selectedWeekNumber = null;
      _selectedSessionId = null;
    }
    if (_selectedWeekNumber != null &&
        !_weekOptionsForSelectedCourse.contains(_selectedWeekNumber)) {
      _selectedWeekNumber = null;
      _selectedSessionId = null;
    }
  }

  void _normalizeSelectedSession() {
    final activeIds = _filteredGroups.map((e) => e.sessionId).toSet();
    if (_selectedSessionId != null && !activeIds.contains(_selectedSessionId)) {
      _selectedSessionId = null;
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
      _applyWeekAndDaySelectionToDate(resetLinkedSelection: true);
      _normalizeLinkedSelections();
      _normalizeSelectedSession();
      _resetEditState();
    });
    unawaited(_ensureRecordsLoaded(_targetSessionIdsForRecordsLoad()));
  }

  void _applyWeekAndDaySelectionToDate({required bool resetLinkedSelection}) {
    final target = _calendarRepository.dateForWeekAndWeekday(
      _effectiveWeekNumber,
      _selectedDayOfWeek,
    );
    if (target == null) return;
    _calendarSelectedDate = DateTime(target.year, target.month, target.day);
    if (resetLinkedSelection) {
      _selectedCourseCode = null;
      _selectedSessionId = null;
      _statusFilter = _StatusFilter.all;
    }
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
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: ModernPopupDialog(
            accentColor: _primary,
            title: Text(
              _tr('إجراء الحضور', 'Attendance action'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2F4449),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const SizedBox(height: 10),
                _sessionDecisionDialogActions(
                  dialogContext: dialogContext,
                  isFuture: isFuture,
                  hasExistingAttendance: hasExistingAttendance,
                ),
              ],
            ),
            actions: [
              ModernPopupActionButton(
                label: _tr('إلغاء', 'Cancel'),
                onTap: () => Navigator.of(dialogContext).pop(),
                isPrimary: false,
              ),
            ],
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

  void _onCourseChanged(String? courseCode) {
    setState(() {
      _selectedCourseCode = courseCode;
      _selectedWeekNumber = null;
      _selectedSessionId = null;
      _statusFilter = _StatusFilter.all;
      _normalizeLinkedSelections();
      _normalizeSelectedSession();
      _resetEditState();
    });
    unawaited(_ensureRecordsLoaded(_targetSessionIdsForRecordsLoad()));
  }

  void _onWeekChanged({required bool auto, int? week}) {
    setState(() {
      _weekIsAuto = auto;
      _selectedWeekNumber = auto ? _currentWeekNumber : week;
      _selectedSessionId = null;
      _normalizeLinkedSelections();
      _normalizeSelectedSession();
      _resetEditState();
    });
    unawaited(_ensureRecordsLoaded(_targetSessionIdsForRecordsLoad()));
  }

  void _onSessionChanged(String? sessionId) {
    setState(() {
      _selectedSessionId = sessionId;
      if (sessionId != null && _groups.isNotEmpty) {
        final found = _groups.firstWhere(
          (g) => g.sessionId == sessionId,
          orElse: () => _groups.first,
        );
        _selectedCourseCode = found.courseCode.trim().isNotEmpty
            ? found.courseCode.trim()
            : found.courseName.trim();
        _selectedWeekNumber = found.weekNumber;
        _calendarSelectedDate = DateTime(
          found.lectureDate.year,
          found.lectureDate.month,
          found.lectureDate.day,
        );
      }
      _statusFilter = _StatusFilter.all;
      _resetEditState();
    });
    unawaited(_ensureRecordsLoaded(_targetSessionIdsForRecordsLoad()));
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
          child: ModernPopupSheet(
            accentColor: _primary,
            title: _tr('تعديل حالة الطالب', 'Edit student status'),
            subtitle: student.name,
            onClose: () => Navigator.pop(ctx),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          child: ModernPopupSheet(
            accentColor: _primary,
            title: _tr('ملخص الحضور', 'Attendance Summary'),
            subtitle:
                '${group.courseName} • ${_dayName(group.dayOfWeek)} • ${group.timeRange} • ${_tr('الشعبة', 'Section')} ${group.section}',
            onClose: () => Navigator.pop(ctx),
            margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Column(
              children: [
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
        case _AttendanceStatus.pending:
          break;
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
      case _AttendanceStatus.pending:
        return _StatusFilter.all;
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
      case _AttendanceStatus.pending:
        return _StatusStyle(
          label: _tr('بانتظار التحضير', 'Pending attendance'),
          bg: const Color(0xFFECEFF0),
          fg: const Color(0xFF6F7D82),
          color: const Color(0xFF6F7D82),
        );
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
              child: _loadError != null
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
                              if (_isLoadingRecords || _isRefreshingReport)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: LinearProgressIndicator(
                                    minHeight: 3,
                                    color: Color(0xFF006571),
                                    backgroundColor: Color(0xFFE6F1F2),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: ProfileBackButton(onTap: _goBack),
                              ),
                              const SizedBox(height: 10),
                              _buildReportHeroCard(),
                              const SizedBox(height: 10),
                              if (_showLegacyReportPanel) ...[
                                _buildFilters(),
                                const SizedBox(height: 10),
                                _buildWeekLectureCards(),
                                const SizedBox(height: 10),
                                _buildSelectionStateBanner(),
                                const SizedBox(height: 10),
                                if (_hasCompleteRequiredSelection &&
                                    group != null) ...[
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

  Widget _buildReportHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B8793), Color(0xFF005B66)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.23),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.fact_check_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr('تقرير الحضور', 'Attendance Report'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _tr(
                    'فلترة التقرير واختيار المحاضرة',
                    'Filter the report and choose lecture',
                  ),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSectionTitle({
    required IconData icon,
    required String title,
    String? hint,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4F5),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: _primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13.2,
            fontWeight: FontWeight.w800,
            color: Color(0xFF24484F),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B8389),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilters() {
    final courses = _courseOptions;
    final weeks = _weekOptionsForSelectedCourse;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B8793), Color(0xFF066A75)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune_rounded, color: Colors.white, size: 17),
                const SizedBox(width: 6),
                Text(
                  _tr('فلترة التقرير', 'Report Filters'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.6,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildFilterSectionTitle(
            icon: Icons.auto_stories_rounded,
            title: _tr('المقرر', 'Course'),
            hint: _tr('اختاري المقرر لعرض الأسابيع', 'Choose course first'),
          ),
          const SizedBox(height: 8),
          if (courses.isEmpty)
            _buildInlineFilterHint(
              _tr('لا توجد مقررات متاحة حالياً.', 'No courses available now.'),
            )
          else
            _buildCourseChoiceScroller(courses),
          const SizedBox(height: 12),
          _buildFilterSectionTitle(
            icon: Icons.view_week_rounded,
            title: _tr('الأسبوع', 'Week'),
            hint: _tr('اختياري لتضييق النتائج', 'Optional to narrow results'),
          ),
          const SizedBox(height: 8),
          if (weeks.isEmpty)
            _buildInlineFilterHint(
              _tr(
                'لا توجد أسابيع متاحة حالياً.',
                'No weeks available right now.',
              ),
            )
          else
            _buildWeekDropdown(weeks),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCourseCode = null;
                  _selectedWeekNumber = null;
                  _selectedSessionId = null;
                  _statusFilter = _StatusFilter.all;
                  _normalizeSelectedSession();
                  _resetEditState();
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(_tr('إعادة ضبط الفلتر', 'Reset filters')),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF5A757C),
                textStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineFilterHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE8EA)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11.8,
          color: Color(0xFF698188),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCourseChoiceScroller(List<_CourseOption> courses) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = min(420.0, screenWidth - 56);
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: courses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final course = courses[index];
          return SizedBox(
            width: cardWidth,
            child: _buildCoursePillCard(
              title: course.label,
              subtitle: course.code,
              selected: _selectedCourseCode == course.code,
              onTap: () => _onCourseChanged(course.code),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeekDropdown(List<int> weeks) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E5E8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: _selectedWeekNumber,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2B4B52),
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(_tr('كل الأسابيع', 'All weeks')),
            ),
            ...weeks.map(
              (week) => DropdownMenuItem<int?>(
                value: week,
                child: Text(_tr('الأسبوع $week', 'Week $week')),
              ),
            ),
          ],
          onChanged: (week) => _onWeekChanged(auto: false, week: week),
        ),
      ),
    );
  }

  Widget _buildCoursePillCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedScale(
          scale: selected ? 1.01 : 1,
          duration: const Duration(milliseconds: 140),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0A7E88)
                    : const Color(0xFFD9E8EB),
                width: selected ? 1.6 : 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? 0.06 : 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: selected
                          ? const [Color(0xFF0B8793), Color(0xFF0A6A74)]
                          : const [Color(0xFFCFE4E7), Color(0xFFC2DCE0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14.4,
                          color: selected
                              ? const Color(0xFF11464E)
                              : const Color(0xFF2F464C),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.4,
                            color: selected
                                ? const Color(0xFF19606B)
                                : const Color(0xFF69858B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: selected
                      ? const Color(0xFF0A7A84)
                      : const Color(0xFF9EB4BA),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: selected
                      ? const Color(0xFF0A7A84)
                      : const Color(0xFF96ACB2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekLectureCards() {
    final sessions = _filteredGroups;
    if (sessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDE9EB)),
        ),
        child: Text(
          _tr(
            'لا توجد محاضرات مطابقة للفلاتر الحالية.',
            'No lectures match the current filters.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5F747A),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE9EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 24,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _tr('محاضرات الأسبوع', 'Week Lectures'),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF32484D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...sessions.map((session) {
            final selected = _selectedSessionId == session.sessionId;
            final mainTitle = session.courseName.trim().isNotEmpty
                ? session.courseName.trim()
                : '${_tr('الشعبة', 'Section')} ${session.section}';
            final subTitle =
                '${_dayName(session.dayOfWeek)} • ${session.timeRange}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onSessionChanged(session.sessionId),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF0B7D88)
                            : const Color(0xFFDCE7E9),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: selected
                                  ? const [Color(0xFF0B8793), Color(0xFF076772)]
                                  : const [
                                      Color(0xFFCFE4E7),
                                      Color(0xFFC2DCE0),
                                    ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mainTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13.1,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? const Color(0xFF15414A)
                                      : const Color(0xFF2E4348),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11.3,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? const Color(0xFF2A5C65)
                                      : const Color(0xFF627B82),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F8F9),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${_tr('الشعبة', 'Section')} ${session.section}',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 10.6,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF5E7A81),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDate(session.lectureDate),
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? const Color(0xFF2A5C65)
                                    : const Color(0xFF769097),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: selected
                                  ? const Color(0xFF006571)
                                  : const Color(0xFF8AA0A6),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReportActionButtons(_LectureAttendanceGroup group) {
    final canExport = !_isExporting;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openAttendanceForGroup(group, viewOnly: false),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF006571),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.edit_note_rounded, size: 19),
            label: Text(
              _tr('فتح التقرير', 'Open report'),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                fontSize: 13.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canExport
                    ? () => _exportActiveSessionCsv(group)
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: const BorderSide(color: Color(0xFF006571)),
                  foregroundColor: const Color(0xFF006571),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isExporting
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share_rounded, size: 17),
                label: Text(
                  _tr('تصدير', 'Export'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openExcuseManagementForGroup(group),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: const BorderSide(color: Color(0xFF006571)),
                  foregroundColor: const Color(0xFF006571),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.fact_check_rounded, size: 17),
                label: Text(
                  _tr('الأعذار', 'Excuses'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectionStateBanner() {
    String message;
    Color bg = const Color(0xFFF3F7F8);
    Color border = const Color(0xFFD8E4E7);
    Color text = const Color(0xFF455D63);
    IconData icon = Icons.info_outline_rounded;

    final hasSessions = _filteredGroups.isNotEmpty;
    if (!hasSessions) {
      message = _tr(
        'لا توجد بيانات محاضرات ضمن الفلاتر الحالية.',
        'No lecture data found within the current filters.',
      );
      icon = Icons.event_busy_rounded;
    } else if (!_hasSelectedSession) {
      message = _tr(
        'اختاري محاضرة من القائمة لبدء التقرير.',
        'Select a lecture card from the list to start the report.',
      );
      icon = Icons.library_books_rounded;
    } else {
      final group = _activeGroup;
      if (group == null) {
        message = _tr(
          'لا توجد بيانات تقرير للمحاضرة المختارة.',
          'No report data for the selected lecture.',
        );
        icon = Icons.event_busy_rounded;
      } else {
        message = _tr(
          'المعاينة والتعديل متاحان لهذا التقرير.',
          'Preview and editing are available for this report.',
        );
        bg = const Color(0xFFEAF7EF);
        border = const Color(0xFFCBE8D2);
        text = const Color(0xFF24643A);
        icon = Icons.check_circle_outline_rounded;
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

  Future<void> _openExcuseManagementForGroup(
    _LectureAttendanceGroup group,
  ) async {
    final lecture = group.lecture;
    if (lecture == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'لا يمكن فتح إدارة الأعذار لأن بيانات المحاضرة غير مكتملة.',
              'Cannot open excuse management because lecture data is incomplete.',
            ),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
      return;
    }
    await LecturerNavigation.goToExcuseManagement(
      context,
      lecture,
      sessionId: group.sessionId,
      sessionDate: group.lectureDate,
    );
  }

  Widget _buildReportSummaryCard(_LectureAttendanceGroup group) {
    final statusLabel = _tr('قابل للتعديل', 'Editable');
    final statusColor = const Color(0xFF1B8E3E);
    final statusBg = const Color(0xFFEAF7EF);

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

  // ignore: unused_element
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
                value: _isEditMode,
                activeTrackColor: _primary.withValues(alpha: 0.5),
                activeThumbColor: _primary,
                onChanged: _isExporting
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
  void _showDayPickerSheet() {
    final options = _availableDayOptions;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ModernPopupSheet(
        accentColor: _primary,
        title: _tr('اختيار اليوم', 'Day picker'),
        onClose: () => Navigator.pop(ctx),
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.paddingOf(ctx).bottom,
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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

enum _AttendanceStatus { pending, present, absent, excused, late }

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

  _LectureAttendanceGroup deepCopy() {
    return _LectureAttendanceGroup(
      sessionId: sessionId,
      lecture: lecture,
      courseName: courseName,
      courseCode: courseCode,
      section: section,
      sectionId: sectionId,
      dayOfWeek: dayOfWeek,
      weekNumber: weekNumber,
      lectureDate: lectureDate,
      startTime: startTime,
      timeRange: timeRange,
      students: students.map((s) => s.deepCopy()).toList(),
    );
  }
}

class _CourseOption {
  const _CourseOption({required this.code, required this.label});

  final String code;
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

  _StudentAttendanceRecord deepCopy() {
    return _StudentAttendanceRecord(
      id: id,
      studentId: studentId,
      name: name,
      academicNumber: academicNumber,
      time: time,
      status: status,
    );
  }
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
