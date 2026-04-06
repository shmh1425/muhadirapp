import 'package:flutter/material.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../services/lecturer/lecturer_sections_service.dart';
import 'lecturer_language.dart';
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
  static const double _tableRadius = 18;
  static const double _timeColWidth = 56;

  List<LectureItem> _allLectures = [];
  bool _isLoadingLectures = true;
  String? _loadError;

  String _selectedTab = 'الكل';

  final List<int> _dayOrder = const [7, 1, 2, 3, 4];

  /// ساعات العمل من 8 صباحاً إلى 6 مساءً
  final List<int> _timeSlots = const [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18];

  @override
  void initState() {
    super.initState();
    _loadLectures();
  }

  Future<void> _loadLectures() async {
    setState(() {
      _isLoadingLectures = true;
      _loadError = null;
    });
    try {
      final list = await LecturerSectionsService.instance
          .getLecturesForCurrentLecturer();
      if (!mounted) return;
      setState(() {
        _allLectures = list;
        _isLoadingLectures = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLectures = false;
        _loadError = e.toString();
      });
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

  void _goBack() {
    Navigator.of(context).pop();
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
            body: SafeArea(
              child: _isLoadingLectures
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
                                'حدث خطأ في تحميل المحاضرات',
                                'Failed to load lectures',
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
                              onPressed: _loadLectures,
                              icon: const Icon(Icons.refresh),
                              label: Text(_tr('إعادة المحاولة', 'Retry')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
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
                          _buildTabsSection(),
                          const SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _selectedTab == 'الكل'
                                      ? _buildAllScheduleTable()
                                      : _buildSingleDayTable(
                                          _tabs.firstWhere(
                                            (tab) => tab.label == _selectedTab,
                                          ),
                                        ),
                                  _scheduleTableBottomHint(),
                                ],
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
        borderRadius: BorderRadius.circular(_tableRadius),
        border: Border.all(color: const Color(0xFFD6E6E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _buildTabs(),
    );
  }

  Widget _buildTabs() {
    const double tabWidth = 78;
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
              child: SizedBox(
                width: tabWidth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
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
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : const Color(0xFF444444),
                    ),
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
        borderRadius: BorderRadius.circular(_tableRadius),
        border: Border.all(color: const Color(0xFFD6E5E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_tableRadius),
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF27A2A9), _headerBg],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: _timeColWidth,
                    child: Text(
                      _tr('الوقت', 'Time'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Cairo',
                        fontSize: 12,
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
              return Container(
                decoration: BoxDecoration(
                  color: rowIndex.isEven
                      ? const Color(0xFFFCFEFE)
                      : Colors.white,
                  border: Border(bottom: BorderSide(color: _rowBorder)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: _timeColWidth,
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
                    ..._dayOrder.map(
                      (day) => Expanded(
                        child: _buildCell(
                          lecture: _lectureAt(day, hour),
                          showInfo: true,
                          height: 40,
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

  static Widget _scheduleTableBottomHint() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Text(
        '٨ ص – ٦ م',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          color: Colors.grey.shade600,
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
        borderRadius: BorderRadius.circular(_tableRadius),
        border: Border.all(color: const Color(0xFFD6E5E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_tableRadius),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF27A2A9), _headerBg],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
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
              return Container(
                decoration: BoxDecoration(
                  color: rowIndex.isEven
                      ? const Color(0xFFFCFEFE)
                      : Colors.white,
                  border: Border(bottom: BorderSide(color: _rowBorder)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: _timeColWidth,
                      height: 42,
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
                        height: 42,
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
        ? const Color(0xFFDDF1F5)
        : const Color(0xFFF3EFE4);

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD6E5E8), width: 0.8),
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
              if (lecture.location != null &&
                  lecture.location!.trim().isNotEmpty)
                _detailRow(_tr('الموقع', 'Location'), lecture.location!.trim()),
              _detailRow(_tr('النوع', 'Type'), lecture.activity),
              _detailRow(
                _tr('اليوم', 'Day'),
                _displayDayName(lecture.dayOfWeek),
              ),
              _detailRow(
                _tr('الوقت', 'Time'),
                '${_displayHour(_normalizeHour(lecture.startTime))} – ${_displayHour(_normalizeHour(lecture.endTime))}',
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
