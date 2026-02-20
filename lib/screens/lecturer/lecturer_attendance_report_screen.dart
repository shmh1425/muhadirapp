import 'package:flutter/material.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../utils/shared/time_utils.dart';
import 'lecturer_language.dart';
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

  final LectureRepository _repository = LectureRepository();
  late final List<LectureItem> _lectures;
  late final List<_LectureAttendanceGroup> _groups;

  bool _isEditMode = false;
  bool _hasPendingChanges = false;
  bool _weekIsAuto = true;
  int? _selectedWeekNumber;
  late int _selectedDayOfWeek;
  String? _selectedCourse;
  String? _selectedSection;
  _StatusFilter _statusFilter = _StatusFilter.all;
  Map<String, _AttendanceStatus> _draftStatuses = {};
  static const int _maxWeeks = 53;
  static const List<int> _weekdayOrder = [7, 1, 2, 3, 4, 5, 6];

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  @override
  void initState() {
    super.initState();
    _lectures = _repository.getAllLectures();
    _groups = _buildMockGroups(_lectures);
    _selectedDayOfWeek = DateTime.now().weekday;
  }

  int _getTargetWeekday() => _selectedDayOfWeek;

  DateTime _getReferenceDate() {
    final now = DateTime.now();
    final target = _getTargetWeekday();
    if (target == now.weekday) return now;
    if (target == now.add(const Duration(days: 1)).weekday) {
      return now.add(const Duration(days: 1));
    }
    int diff = target - now.weekday;
    if (diff <= 0) diff += 7;
    return now.add(Duration(days: diff));
  }

  int get _weekNumber {
    final d = _getReferenceDate();
    final startOfYear = DateTime(d.year, 1, 1);
    final dayOfYear = d.difference(startOfYear).inDays + 1;
    final w = ((dayOfYear - d.weekday + 10) / 7).floor();
    return w.clamp(1, 53);
  }

  int get _displayWeekNumber =>
      _weekIsAuto ? _weekNumber : (_selectedWeekNumber ?? _weekNumber);

  List<_LectureAttendanceGroup> get _groupsForSelectedDay {
    final target = _getTargetWeekday();
    return _groups.where((group) => group.dayOfWeek == target).toList();
  }

  bool _hasMatchingGroup({String? course, String? section}) {
    return _groupsForSelectedDay.any((group) {
      final matchCourse = course == null || group.courseName == course;
      final matchSection = section == null || group.section == section;
      return matchCourse && matchSection;
    });
  }

  List<String> _courseOptionsForSection(String? section) {
    final names =
        _groupsForSelectedDay
            .where((group) => section == null || group.section == section)
            .map((group) => group.courseName)
            .toSet()
            .toList()
          ..sort();
    return names;
  }

  List<String> _sectionOptionsForCourse(String? course) {
    final sections =
        _groupsForSelectedDay
            .where((group) => course == null || group.courseName == course)
            .map((group) => group.section)
            .toSet()
            .toList()
          ..sort();
    return sections;
  }

  List<String> get _courseOptions {
    return _courseOptionsForSection(_selectedSection);
  }

  List<String> get _sectionOptions {
    return _sectionOptionsForCourse(_selectedCourse);
  }

  void _normalizeLinkedSelections() {
    if (_selectedCourse != null &&
        !_groupsForSelectedDay.any(
          (group) => group.courseName == _selectedCourse,
        )) {
      _selectedCourse = null;
    }
    if (_selectedSection != null &&
        !_groupsForSelectedDay.any(
          (group) => group.section == _selectedSection,
        )) {
      _selectedSection = null;
    }
    if (!_hasMatchingGroup(
      course: _selectedCourse,
      section: _selectedSection,
    )) {
      _selectedSection = null;
      if (!_hasMatchingGroup(course: _selectedCourse, section: null)) {
        _selectedCourse = null;
      }
    }
  }

  void _onSectionChanged(String? section) {
    _selectedSection = section;
    if (!_hasMatchingGroup(
      course: _selectedCourse,
      section: _selectedSection,
    )) {
      _selectedCourse = null;
    }
    final availableCourses = _courseOptionsForSection(_selectedSection);
    if (_selectedCourse == null && availableCourses.length == 1) {
      _selectedCourse = availableCourses.first;
    }
    _resetEditState();
  }

  void _onCourseChanged(String? course) {
    _selectedCourse = course;
    if (!_hasMatchingGroup(
      course: _selectedCourse,
      section: _selectedSection,
    )) {
      _selectedSection = null;
    }
    final availableSections = _sectionOptionsForCourse(_selectedCourse);
    if (_selectedSection == null && availableSections.length == 1) {
      _selectedSection = availableSections.first;
    }
    _resetEditState();
  }

  List<_LectureAttendanceGroup> get _filteredGroups {
    final target = _getTargetWeekday();
    var list = _groups.where((group) => group.dayOfWeek == target).toList();
    if (_selectedCourse != null && _selectedCourse!.trim().isNotEmpty) {
      list = list
          .where((group) => group.courseName == _selectedCourse)
          .toList();
    }
    if (_selectedSection != null && _selectedSection!.trim().isNotEmpty) {
      list = list.where((group) => group.section == _selectedSection).toList();
    }
    list.sort((a, b) {
      final aTime = TimeUtils.parseTimeString(a.startTime);
      final bTime = TimeUtils.parseTimeString(b.startTime);
      final aMinutes = aTime.$1 * 60 + aTime.$2;
      final bMinutes = bTime.$1 * 60 + bTime.$2;
      return aMinutes.compareTo(bMinutes);
    });
    return list;
  }

  _LectureAttendanceGroup? get _activeGroup {
    if (_filteredGroups.isEmpty) return null;
    return _filteredGroups.first;
  }

  List<_StudentAttendanceRecord> get _visibleStudents {
    final group = _activeGroup;
    if (group == null) return const [];
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
    return _draftStatuses[student.academicNumber] ?? student.status;
  }

  void _resetEditState() {
    _isEditMode = false;
    _hasPendingChanges = false;
    _draftStatuses = {};
  }

  void _enterEditMode(_LectureAttendanceGroup group) {
    if (_isEditMode) return;
    setState(() {
      _isEditMode = true;
      _hasPendingChanges = false;
      _draftStatuses = {
        for (final student in group.students)
          student.academicNumber: student.status,
      };
    });
  }

  void _saveAttendanceChanges(
    _LectureAttendanceGroup group, {
    bool exitEditMode = false,
  }) {
    if (!_isEditMode) return;

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

    setState(() {
      for (final student in group.students) {
        final updated = _draftStatuses[student.academicNumber];
        if (updated != null) {
          student.status = updated;
        }
      }
      _hasPendingChanges = false;
      if (exitEditMode) {
        _resetEditState();
      } else {
        _draftStatuses = {
          for (final student in group.students)
            student.academicNumber: student.status,
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
                'يوجد تعديلات لم يتم حفظها بعد. هل تريد حفظها قبل الخروج من وضع التعديل؟',
                'You have unsaved changes. Save before leaving edit mode?',
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
      _saveAttendanceChanges(group, exitEditMode: true);
      return;
    }
    setState(() => _resetEditState());
  }

  void _goBack() {
    Navigator.of(context).pop();
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableHeight = constraints.maxHeight * 0.58;
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
                        _buildFilters(),
                        const SizedBox(height: 12),
                        if (group != null) ...[
                          _buildLectureSummary(group),
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
                        const SizedBox(height: 8),
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
    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final tomorrowWeekday = now.add(const Duration(days: 1)).weekday;
    final dayLabel = _selectedDayOfWeek == todayWeekday
        ? _tr('اليوم', 'Today')
        : _selectedDayOfWeek == tomorrowWeekday
        ? _tr('غداً', 'Tomorrow')
        : LecturerLanguageController.dayNameFromWeekday(_selectedDayOfWeek);
    const double barRadius = 14;
    const double barPaddingH = 12;
    const double barPaddingV = 10;
    const double segmentWidth = 96;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: barPaddingH,
            vertical: barPaddingV,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(barRadius),
            border: Border.all(color: const Color(0xFFE8E8E8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: segmentWidth,
                child: _FilterSegment(
                  value: dayLabel,
                  segmentWidth: segmentWidth,
                  primary: _primary,
                  onTap: () => _showDayPickerSheet(
                    todayWeekday: todayWeekday,
                    tomorrowWeekday: tomorrowWeekday,
                  ),
                ),
              ),
              _FilterBarDivider(),
              SizedBox(
                width: segmentWidth,
                child: _FilterSegment(
                  value: '$_displayWeekNumber',
                  label: _tr('أسبوع', 'Week'),
                  segmentWidth: segmentWidth,
                  primary: _primary,
                  onTap: _showWeekPickerSheet,
                ),
              ),
              _FilterBarDivider(),
              SizedBox(
                width: segmentWidth,
                child: _FilterSegment(
                  value: _selectedSection ?? _tr('الشعبة', 'Section'),
                  segmentWidth: segmentWidth,
                  primary: _primary,
                  onTap: _showSectionPickerSheet,
                ),
              ),
              _FilterBarDivider(),
              SizedBox(
                width: segmentWidth,
                child: _FilterSegment(
                  value: _selectedCourse ?? _tr('المقرر', 'Course'),
                  segmentWidth: segmentWidth,
                  primary: _primary,
                  onTap: _showCoursePickerSheet,
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
                _tr('رقم الأسبوع', 'Week number'),
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
                  _tr('تلقائي (حسب اليوم المحدد)', 'Auto (by selected day)'),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: _weekIsAuto
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: _weekIsAuto ? _primary : const Color(0xFF222222),
                  ),
                ),
                trailing: _weekIsAuto
                    ? Icon(Icons.check_rounded, color: _primary, size: 22)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _weekIsAuto = true;
                    _selectedWeekNumber = null;
                    _normalizeLinkedSelections();
                    _resetEditState();
                  });
                },
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  controller: scrollController,
                  shrinkWrap: true,
                  itemCount: _maxWeeks,
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
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected ? _primary : const Color(0xFF222222),
                        ),
                      ),
                      trailing: selected
                          ? Icon(Icons.check_rounded, color: _primary, size: 22)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _weekIsAuto = false;
                          _selectedWeekNumber = week;
                          _normalizeLinkedSelections();
                          _resetEditState();
                        });
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

  void _showDayPickerSheet({
    required int todayWeekday,
    required int tomorrowWeekday,
  }) {
    final options = <int>[
      todayWeekday,
      tomorrowWeekday,
      ..._weekdayOrder.where((w) => w != todayWeekday && w != tomorrowWeekday),
    ];
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
              _tr('اليوم', 'Day'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options.map((w) {
                    final label = w == todayWeekday
                        ? _tr('اليوم', 'Today')
                        : w == tomorrowWeekday
                        ? _tr('غداً', 'Tomorrow')
                        : LecturerLanguageController.dayNameFromWeekday(w);
                    final selected = _selectedDayOfWeek == w;
                    return ListTile(
                      title: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected ? _primary : const Color(0xFF222222),
                        ),
                      ),
                      trailing: selected
                          ? Icon(Icons.check_rounded, color: _primary, size: 22)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedDayOfWeek = w;
                          _normalizeLinkedSelections();
                          _resetEditState();
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
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
              final label = section ?? _tr('الشعبة', 'Section');
              final selected = _selectedSection == section;
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? _primary : const Color(0xFF222222),
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check_rounded, color: _primary, size: 22)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _onSectionChanged(section);
                  });
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
              final label = course ?? _tr('المقرر', 'Course');
              final selected = _selectedCourse == course;
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? _primary : const Color(0xFF222222),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: selected
                    ? Icon(Icons.check_rounded, color: _primary, size: 22)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _onCourseChanged(course);
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLectureSummary(_LectureAttendanceGroup group) {
    final counts = _buildCounts(group.students);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB8DBE0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.courseName,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_dayName(group.dayOfWeek)} • ${group.timeRange} • ${_tr('الشعبة', 'Section')} ${group.section}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                _summaryRow(
                  _tr('عدد الطلاب', 'Total Students'),
                  '${group.students.length}',
                  _primary,
                ),
                _summaryRow(
                  _tr('عدد الحضور', 'Present Count'),
                  '${counts.present}',
                  const Color(0xFF2EAF5E),
                ),
                _summaryRow(
                  _tr('عدد الغياب', 'Absent Count'),
                  '${counts.absent}',
                  const Color(0xFFE65151),
                ),
                _summaryRow(
                  _tr('عدد المعذور', 'Excused Count'),
                  '${counts.excused}',
                  const Color(0xFFF0A825),
                ),
                _summaryRow(
                  _tr('عدد المتأخر', 'Late Count'),
                  '${counts.late}',
                  const Color(0xFF4D8EDB),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _modeButton(
                        label: _tr('معاينة', 'Preview'),
                        icon: Icons.remove_red_eye_rounded,
                        isActive: !_isEditMode,
                        onTap: () => _switchToViewMode(group),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _modeButton(
                        label: _tr('تعديل', 'Edit'),
                        icon: Icons.edit_rounded,
                        isActive: _isEditMode,
                        onTap: () => _enterEditMode(group),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveChangesButton(_LectureAttendanceGroup group) {
    final isEnabled = _hasPendingChanges;
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
              Icon(
                Icons.save_rounded,
                size: 18,
                color: isEnabled ? Colors.white : const Color(0xFF92A2A7),
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

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Color(0xFF4F4F4F),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: valueColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isActive ? null : const Color(0xFFEFF4F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isEnabled
                  ? (isActive ? Colors.white : const Color(0xFF4A5C61))
                  : const Color(0xFF9AA7AB),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: isEnabled
                    ? (isActive ? Colors.white : const Color(0xFF4A5C61))
                    : const Color(0xFF9AA7AB),
              ),
            ),
          ],
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
                'لا توجد بيانات حضور لهذا اليوم.',
                'No attendance data for this day.',
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

  Future<void> _showStatusPicker(_StudentAttendanceRecord student) async {
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
                          if (_isEditMode) {
                            _draftStatuses[student.academicNumber] = status;
                            _hasPendingChanges = true;
                          } else {
                            student.status = status;
                          }
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
          bg: Color(0xFFDFF4E5),
          fg: Color(0xFF2B9E56),
          color: Color(0xFF2B9E56),
        );
      case _AttendanceStatus.absent:
        return _StatusStyle(
          label: _tr('غائب', 'Absent'),
          bg: Color(0xFFFDE1E1),
          fg: Color(0xFFD14A4A),
          color: Color(0xFFD14A4A),
        );
      case _AttendanceStatus.excused:
        return _StatusStyle(
          label: _tr('معذور', 'Excused'),
          bg: Color(0xFFFFF3D6),
          fg: Color(0xFFC78A1E),
          color: Color(0xFFC78A1E),
        );
      case _AttendanceStatus.late:
        return _StatusStyle(
          label: _tr('متأخر', 'Late'),
          bg: Color(0xFFE3EEFF),
          fg: Color(0xFF3E73C9),
          color: Color(0xFF3E73C9),
        );
    }
  }

  _StatusStyle _filterStyle(_StatusFilter filter) {
    switch (filter) {
      case _StatusFilter.all:
        return _StatusStyle(
          label: _tr('الكل', 'All'),
          color: Color(0xFF6F7D82),
          bg: Color(0xFFECEFF0),
          fg: Color(0xFF6F7D82),
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

  List<_LectureAttendanceGroup> _buildMockGroups(List<LectureItem> lectures) {
    final names = [
      'أحمد علي',
      'محمد سامي',
      'عبدالله خالد',
      'ريم فهد',
      'نورة سالم',
      'سارة عبدالعزيز',
      'لينا عادل',
      'ياسر مازن',
    ];

    final groups = <_LectureAttendanceGroup>[];
    for (int i = 0; i < lectures.length; i++) {
      final lecture = lectures[i];
      final students = <_StudentAttendanceRecord>[];
      for (int j = 0; j < names.length; j++) {
        students.add(
          _StudentAttendanceRecord(
            id: '${i + 1}-${j + 1}',
            name: names[j],
            academicNumber: '44${(1000000 + i * 100 + j)}',
            time: lecture.startTime,
            status: _AttendanceStatus
                .values[(i + j) % _AttendanceStatus.values.length],
          ),
        );
      }

      groups.add(
        _LectureAttendanceGroup(
          lectureId: lecture.crn,
          courseName: lecture.courseName,
          section: lecture.section,
          dayOfWeek: lecture.dayOfWeek,
          startTime: lecture.startTime,
          timeRange: '${lecture.startTime} - ${lecture.endTime}',
          students: students,
        ),
      );
    }
    return groups;
  }
}

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({
    required this.value,
    this.label,
    required this.segmentWidth,
    required this.primary,
    required this.onTap,
  });

  final String value;
  final String? label;
  final double segmentWidth;
  final Color primary;
  final VoidCallback onTap;

  static const double _iconWidth = 20;
  static const double _gap = 4;

  static double _paddingHForWidth(double width) {
    if (width >= 100) return 12;
    if (width >= 75) return 8;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final display = label != null ? '$label $value' : value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableW = constraints.maxWidth;
            final dynamicPadding = _paddingHForWidth(availableW);
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: dynamicPadding,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      display,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                        fontFamily: 'Cairo',
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: _gap),
                  SizedBox(
                    width: _iconWidth,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: primary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FilterBarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 1,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: const Color(0xFFE8E8E8),
      ),
    );
  }
}

const TextStyle _headerStyle = TextStyle(
  fontFamily: 'Cairo',
  fontSize: 11,
  fontWeight: FontWeight.w800,
  color: Color(0xFF41575D),
);

enum _StatusFilter { all, present, absent, excused, late }

enum _AttendanceStatus { present, absent, excused, late }

class _LectureAttendanceGroup {
  _LectureAttendanceGroup({
    required this.lectureId,
    required this.courseName,
    required this.section,
    required this.dayOfWeek,
    required this.startTime,
    required this.timeRange,
    required this.students,
  });

  final String lectureId;
  final String courseName;
  final String section;
  final int dayOfWeek;
  final String startTime;
  final String timeRange;
  final List<_StudentAttendanceRecord> students;
}

class _StudentAttendanceRecord {
  _StudentAttendanceRecord({
    required this.id,
    required this.name,
    required this.academicNumber,
    required this.time,
    required this.status,
  });

  final String id;
  final String name;
  final String academicNumber;
  final String time;
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
