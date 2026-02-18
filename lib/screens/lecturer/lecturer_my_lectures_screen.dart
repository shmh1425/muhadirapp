import 'package:flutter/material.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../services/lecturer/lecture_repository.dart';
import 'lecturer_home_screen.dart';
import 'lecturer_language.dart';
import 'lecturer_nav_bar.dart';
import 'lecturer_profile_screen.dart';
import 'lecturer_qr_screen.dart';
import 'widgets/profile_back_button.dart';

class LecturerMyLecturesScreen extends StatefulWidget {
  const LecturerMyLecturesScreen({super.key});

  @override
  State<LecturerMyLecturesScreen> createState() =>
      _LecturerMyLecturesScreenState();
}

class _LecturerMyLecturesScreenState extends State<LecturerMyLecturesScreen> {
  static const Color _primaryColor = Color(0xFF006571);
  static const Color _headerBg = Color(0xFF0A6E79);
  static const Color _rowBorder = Color(0xFFE8E8E8);

  final LectureRepository _repository = LectureRepository();
  late final List<LectureItem> _allLectures;

  int _selectedNavIndex = 2;
  String _selectedTab = 'الكل';

  final List<int> _dayOrder = const [7, 1, 2, 3, 4];
  final List<int> _timeSlots = const [8, 9, 10, 11, 12, 13, 14, 15];

  @override
  void initState() {
    super.initState();
    _allLectures = _repository.getAllLectures();
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

  List<_DayTabItem> get _tabs => [
    const _DayTabItem(label: 'الكل'),
    ..._dayOrder.map((day) => _DayTabItem(label: _dayName(day), weekday: day)),
  ];

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  String _displayDayNameFromArabic(String day) {
    return LecturerLanguageController.dayNameFromArabic(day);
  }

  String _displayDayName(int weekday) {
    return _displayDayNameFromArabic(_dayName(weekday));
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
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FBFB),
            bottomNavigationBar: LecturerNavBar(
              selectedIndex: _selectedNavIndex,
              onItemTapped: _onItemTapped,
            ),
            body: SafeArea(
              child: Padding(
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
                    _buildTabsSection(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _selectedTab == 'الكل'
                            ? _buildAllScheduleTable()
                            : _buildSingleDayTable(
                                _tabs.firstWhere(
                                  (tab) => tab.label == _selectedTab,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E6E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildTabs(),
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _tabs.map((tab) {
          final bool isActive = _selectedTab == tab.label;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = tab.label),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isActive ? _primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? _primaryColor : const Color(0xFFD9D9D9),
                  ),
                ),
                child: Text(
                  _displayDayNameFromArabic(tab.label),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : const Color(0xFF444444),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAllScheduleTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E5E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              color: _headerBg,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      _tr('الوقت', 'Time'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ..._dayOrder.map(
                    (day) => Expanded(
                      child: Text(
                        _displayDayName(day),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ..._timeSlots.asMap().entries.map((entry) {
              final rowIndex = entry.key;
              final hour = entry.value;
              final bool isLast = rowIndex == _timeSlots.length - 1;

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isLast ? Colors.transparent : _rowBorder,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: _rowBorder)),
                      ),
                      child: Text(
                        _displayHour(hour),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Color(0xFF6B6B6B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ..._dayOrder.map(
                      (day) => Expanded(
                        child: _buildCell(
                          lecture: _lectureAt(day, hour),
                          showInfo: true,
                          height: 38,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleDayTable(_DayTabItem tab) {
    final day = tab.weekday;
    if (day == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E5E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: _headerBg,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _displayDayNameFromArabic(tab.label),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ..._timeSlots.asMap().entries.map((entry) {
              final rowIndex = entry.key;
              final hour = entry.value;
              final bool isLast = rowIndex == _timeSlots.length - 1;

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isLast ? Colors.transparent : _rowBorder,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: _rowBorder)),
                      ),
                      child: Text(
                        _displayHour(hour),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Color(0xFF6B6B6B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildCell(
                        lecture: _lectureAt(day, hour),
                        showInfo: false,
                        height: 40,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCell({
    required LectureItem? lecture,
    required bool showInfo,
    required double height,
  }) {
    if (lecture == null) return SizedBox(height: height);

    final Color fill = lecture.activity == 'عملي'
        ? const Color(0xFF8ABCC5)
        : const Color(0xFFE6E0D3);

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              lecture.courseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10.5,
                color: Color(0xFF2E2E2E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (showInfo)
            InkWell(
              onTap: () => _showLectureDialog(lecture),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: Color(0xFF006571),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showLectureDialog(LectureItem lecture) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: LecturerLanguageController.direction(),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D6D6),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _tr('تفاصيل المحاضرة', 'Lecture Details'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, color: _primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _detailRow(_tr('المقرر', 'Course'), lecture.courseName),
              _detailRow('CRN', lecture.crn),
              _detailRow(_tr('الشعبة', 'Section'), lecture.section),
              _detailRow(_tr('القاعة', 'Hall'), lecture.hall),
              _detailRow(_tr('النوع', 'Type'), lecture.activity),
              _detailRow(
                _tr('اليوم', 'Day'),
                _displayDayName(lecture.dayOfWeek),
              ),
              _detailRow(
                _tr('الوقت', 'Time'),
                _displayHour(_normalizeHour(lecture.startTime)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      _tr('إغلاق', 'Close'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3ECEE)),
        ),
        child: Text(
          '$label: $value',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  LectureItem? _lectureAt(int day, int hour) {
    final dayLectures = _allLectures.where((item) => item.dayOfWeek == day);
    for (final lecture in dayLectures) {
      final start = _normalizeHour(lecture.startTime);
      if (start == hour || (lecture.isDouble && start + 1 == hour)) {
        return lecture;
      }
    }
    return null;
  }

  int _normalizeHour(String time) {
    final int raw = int.tryParse(time.split(':').first) ?? 0;
    if (raw < 8) return raw + 12;
    return raw;
  }

  String _displayHour(int hour) {
    final int hour12 = hour > 12 ? hour - 12 : hour;
    final String suffix = hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:00 $suffix';
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
}

class _DayTabItem {
  const _DayTabItem({required this.label, this.weekday});

  final String label;
  final int? weekday;
}
