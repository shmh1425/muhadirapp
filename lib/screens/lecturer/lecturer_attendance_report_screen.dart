import 'package:flutter/material.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../services/lecturer/lecture_repository.dart';
import 'lecturer_home_screen.dart';
import 'lecturer_nav_bar.dart';
import 'lecturer_profile_screen.dart';
import 'lecturer_qr_screen.dart';
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

  int _selectedNavIndex = 2;
  bool _isEditMode = false;
  bool _hasPendingChanges = false;
  String _selectedCourse = 'الكل';
  String _selectedDay = 'اليوم';
  _StatusFilter _statusFilter = _StatusFilter.all;
  Map<String, _AttendanceStatus> _draftStatuses = {};

  @override
  void initState() {
    super.initState();
    _lectures = _repository.getAllLectures();
    _groups = _buildMockGroups(_lectures);
  }

  List<String> get _courseOptions {
    final courses = _groups.map((e) => e.courseName).toSet().toList()..sort();
    return ['الكل', ...courses];
  }

  List<String> get _dayOptions => [
    'اليوم',
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
  ];

  List<_LectureAttendanceGroup> get _filteredGroups {
    return _groups.where((group) {
      final courseOk =
          _selectedCourse == 'الكل' || group.courseName == _selectedCourse;
      final dayOk = _selectedDay == 'اليوم'
          ? group.dayOfWeek == DateTime.now().weekday
          : group.dayOfWeek == _dayToWeekday(_selectedDay);
      return courseOk && dayOk;
    }).toList();
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
          const SnackBar(content: Text('لا توجد تغييرات جديدة للحفظ.')),
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
      const SnackBar(
        content: Text('تم حفظ تغييرات تقرير الحضور.'),
        duration: Duration(seconds: 2),
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
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text(
              'تغييرات غير محفوظة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            content: const Text(
              'يوجد تعديلات لم يتم حفظها بعد. هل تريد حفظها قبل الخروج من وضع التعديل؟',
              style: TextStyle(fontFamily: 'Cairo', height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('تجاهل'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(backgroundColor: _primary),
                child: const Text('حفظ'),
              ),
            ],
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

  Future<void> _onItemTapped(int index) async {
    if (index == _selectedNavIndex) return;
    setState(() => _selectedNavIndex = index);

    switch (index) {
      case 0:
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LecturerProfileScreen(
              lecturer: LecturerProfile(
                name: 'أنـاس بوقس',
                email: 'username@example.com',
                college: 'كلية الحاسبات',
                department: 'هندسة البرمجيات',
              ),
            ),
          ),
        );
        break;
      case 1:
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LecturerQrScreen(lecture: null),
          ),
        );
        break;
      case 2:
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LecturerHomeScreen()),
        );
        break;
    }
  }

  Future<void> _goToProfile() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LecturerProfileScreen(
          lecturer: LecturerProfile(
            name: 'أنـاس بوقس',
            email: 'username@example.com',
            college: 'كلية الحاسبات',
            department: 'هندسة البرمجيات',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = _activeGroup;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FBFB),
        bottomNavigationBar: LecturerNavBar(
          selectedIndex: _selectedNavIndex,
          onItemTapped: _onItemTapped,
        ),
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
                      child: ProfileBackButton(onTap: _goToProfile),
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
  }

  Widget _buildFilters() {
    final hasCustomFilter =
        _selectedCourse != 'الكل' || _selectedDay != 'اليوم';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4E5E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasCustomFilter)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCourse = 'الكل';
                    _selectedDay = 'اليوم';
                    _resetEditState();
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                ),
                child: const Text(
                  'إعادة ضبط',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
          if (hasCustomFilter) const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildFilterSelector(
                  label: 'المقرر',
                  value: _selectedCourse,
                  icon: Icons.menu_book_rounded,
                  onTap: () async {
                    final selected = await _showFilterSheet(
                      title: 'اختيار المقرر',
                      options: _courseOptions,
                      current: _selectedCourse,
                    );
                    if (selected != null) {
                      setState(() {
                        _selectedCourse = selected;
                        _resetEditState();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterSelector(
                  label: 'اليوم',
                  value: _selectedDay,
                  icon: Icons.calendar_today_rounded,
                  onTap: () async {
                    final selected = await _showFilterSheet(
                      title: 'اختيار اليوم',
                      options: _dayOptions,
                      current: _selectedDay,
                    );
                    if (selected != null) {
                      setState(() {
                        _selectedDay = selected;
                        _resetEditState();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSelector({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDEE8EA)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: _primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: Color(0xFF6D7D82),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: Color(0xFF1D3E45),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF4F656B),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showFilterSheet({
    required String title,
    required List<String> options,
    required String current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
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
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D6D6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFEAEFF0)),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected = option == current;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.of(ctx).pop(option),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE7F4F6)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? _primary
                                        : const Color(0xFF2F4349),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: _primary,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                  '${_dayName(group.dayOfWeek)} • ${group.timeRange} • الشعبة ${group.section}',
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
                _summaryRow('عدد الطلاب', '${group.students.length}', _primary),
                _summaryRow(
                  'عدد الحضور',
                  '${counts.present}',
                  const Color(0xFF2EAF5E),
                ),
                _summaryRow(
                  'عدد الغياب',
                  '${counts.absent}',
                  const Color(0xFFE65151),
                ),
                _summaryRow(
                  'عدد المعذور',
                  '${counts.excused}',
                  const Color(0xFFF0A825),
                ),
                _summaryRow(
                  'عدد المتأخر',
                  '${counts.late}',
                  const Color(0xFF4D8EDB),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _modeButton(
                        label: 'معاينة',
                        icon: Icons.remove_red_eye_rounded,
                        isActive: !_isEditMode,
                        onTap: () => _switchToViewMode(group),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _modeButton(
                        label: 'تعديل',
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
                'حفظ التغييرات',
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
              child: const Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '#',
                      textAlign: TextAlign.center,
                      style: _headerStyle,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text('اسم الطالب', style: _headerStyle),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('الرقم الجامعي', style: _headerStyle),
                  ),
                  SizedBox(
                    width: 54,
                    child: Text(
                      'الوقت',
                      textAlign: TextAlign.center,
                      style: _headerStyle,
                    ),
                  ),
                  SizedBox(
                    width: 78,
                    child: Text(
                      'الحالة',
                      textAlign: TextAlign.center,
                      style: _headerStyle,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _visibleStudents.isEmpty
                  ? const Center(
                      child: Text(
                        'لا يوجد طلاب في هذا الفلتر.',
                        style: TextStyle(
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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded, color: _primary, size: 34),
            SizedBox(height: 8),
            Text(
              'لا توجد بيانات حضور لهذا اليوم.',
              style: TextStyle(
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
          textDirection: TextDirection.rtl,
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
                const Text(
                  'تعديل حالة الطالب',
                  style: TextStyle(
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
        return const _StatusStyle(
          label: 'حاضر',
          bg: Color(0xFFDFF4E5),
          fg: Color(0xFF2B9E56),
          color: Color(0xFF2B9E56),
        );
      case _AttendanceStatus.absent:
        return const _StatusStyle(
          label: 'غائب',
          bg: Color(0xFFFDE1E1),
          fg: Color(0xFFD14A4A),
          color: Color(0xFFD14A4A),
        );
      case _AttendanceStatus.excused:
        return const _StatusStyle(
          label: 'معذور',
          bg: Color(0xFFFFF3D6),
          fg: Color(0xFFC78A1E),
          color: Color(0xFFC78A1E),
        );
      case _AttendanceStatus.late:
        return const _StatusStyle(
          label: 'متأخر',
          bg: Color(0xFFE3EEFF),
          fg: Color(0xFF3E73C9),
          color: Color(0xFF3E73C9),
        );
    }
  }

  _StatusStyle _filterStyle(_StatusFilter filter) {
    switch (filter) {
      case _StatusFilter.all:
        return const _StatusStyle(
          label: 'الكل',
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

  int _dayToWeekday(String dayName) {
    switch (dayName) {
      case 'الأحد':
        return 7;
      case 'الاثنين':
        return 1;
      case 'الثلاثاء':
        return 2;
      case 'الأربعاء':
        return 3;
      case 'الخميس':
        return 4;
      default:
        return DateTime.now().weekday;
    }
  }

  String _dayName(int weekday) {
    switch (weekday) {
      case 7:
        return 'الأحد';
      case 1:
        return 'الاثنين';
      case 2:
        return 'الثلاثاء';
      case 3:
        return 'الأربعاء';
      case 4:
        return 'الخميس';
      case 5:
        return 'الجمعة';
      case 6:
        return 'السبت';
      default:
        return 'غير محدد';
    }
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
          timeRange: '${lecture.startTime} - ${lecture.endTime}',
          students: students,
        ),
      );
    }
    return groups;
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
    required this.timeRange,
    required this.students,
  });

  final String lectureId;
  final String courseName;
  final String section;
  final int dayOfWeek;
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
