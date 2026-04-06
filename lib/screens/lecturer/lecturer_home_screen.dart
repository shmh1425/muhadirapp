import 'dart:async';

import 'package:flutter/material.dart';
import '../student/components/notification_bell.dart';
import '../student/notifications_screen.dart';
import 'lecturer_language.dart';
import '../../widgets/monthly_calendar.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../models/calendar_day.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/calendar_service.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import '../../services/lecturer/filter_service.dart';
import '../../services/lecturer/lecturer_sections_service.dart';
import '../../widgets/lecturer/lecturer_home_header.dart';
import '../../widgets/lecturer/lecturer_filter_buttons.dart';
import '../../widgets/lecturer/manage_lectures_button.dart';
import '../../widgets/lecturer/lecture_timeline.dart';
import '../../widgets/lecturer/day_tap_handler.dart';
import 'lecturer_navigation.dart';

class LecturerHomeScreen extends StatefulWidget {
  const LecturerHomeScreen({super.key, this.lecturerName});

  final String? lecturerName;

  @override
  State<LecturerHomeScreen> createState() => _LecturerHomeScreenState();
}

class _LecturerHomeScreenState extends State<LecturerHomeScreen> {
  String _selectedFilter = 'اليوم'; // اليوم، غدًا، الكل
  DateTime _currentCalendarMonth = DateTime.now(); // الشهر الحالي في التقويم

  // Services
  final LectureRepository _repository = LectureRepository();
  late final CalendarService _calendarService;
  late final DayTapHandler _dayTapHandler;

  // Data: محاضرات المحاضر من sections (Firebase)
  List<LectureItem> _allLectures = [];
  bool _isLoadingLectures = true;
  String? _loadError;
  StreamSubscription<void>? _calendarSyncSub;
  bool _isSyncRefreshing = false;

  @override
  void initState() {
    super.initState();
    _calendarService = CalendarService(_repository);
    _dayTapHandler = DayTapHandler(repository: _repository);
    _calendarSyncSub = CalendarSyncService.instance.watchChanges().listen(
      (_) => _handleRealtimeCalendarChange(),
    );
    _loadHomeData();
  }

  @override
  void dispose() {
    _calendarSyncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoadingLectures = true;
      _loadError = null;
    });
    try {
      await _repository.refreshAcademicCalendar();
      final list = await LecturerSectionsService.instance
          .getLecturesForCurrentLecturer();
      if (!mounted) return;
      setState(() {
        _allLectures = list;
        _currentCalendarMonth = DateTime(
          _repository.currentDateTime.year,
          _repository.currentDateTime.month,
          1,
        );
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

  void _handleFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _refreshCalendarContext();
  }

  Future<void> _refreshCalendarContext() async {
    try {
      await _repository.refreshAcademicCalendar();
      if (!mounted) return;
      setState(() {
        _currentCalendarMonth = DateTime(
          _repository.currentDateTime.year,
          _repository.currentDateTime.month,
          1,
        );
      });
    } catch (_) {
      // Keep current state on refresh failure.
    }
  }

  Future<void> _handleRealtimeCalendarChange() async {
    if (!mounted || _isSyncRefreshing) return;
    _isSyncRefreshing = true;
    try {
      await _repository.refreshAcademicCalendar();
      if (!mounted) return;
      setState(() {
        _currentCalendarMonth = DateTime(
          _repository.currentDateTime.year,
          _repository.currentDateTime.month,
          1,
        );
      });
    } catch (_) {
      // Ignore noisy realtime errors and keep current UI.
    } finally {
      _isSyncRefreshing = false;
    }
  }

  /// محاضرات المعروضة حسب الفلتر: اليوم / غداً (لو الغد إجازة = قائمة فارغة)
  List<LectureItem> _getLecturesForDisplay() {
    final baseDate = _repository.currentDateTime;
    if (_selectedFilter == 'غدًا') {
      final tomorrow = baseDate.add(const Duration(days: 1));
      if (_repository.isHoliday(tomorrow)) return [];
    }
    return FilterService.filterLectures(
      _allLectures,
      _selectedFilter,
      baseDate: baseDate,
    );
  }

  DateTime _selectedLectureDateForFilter() {
    final d = FilterService.getSelectedDate(
      _selectedFilter,
      baseDate: _repository.currentDateTime,
    );
    return DateTime(d.year, d.month, d.day);
  }

  void _openAttendanceForSelectedFilter(LectureItem lecture) {
    final selectedDate = _selectedLectureDateForFilter();
    final today = DateTime(
      _repository.currentDateTime.year,
      _repository.currentDateTime.month,
      _repository.currentDateTime.day,
    );
    if (selectedDate.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LecturerLanguageController.tr(
              'لا يمكن فتح حضور تاريخ مستقبلي قبل يومه',
              'Cannot open future attendance before its day',
            ),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
      return;
    }
    LecturerNavigation.goToAttendance(
      context,
      lecture,
      selectedDate: selectedDate,
    );
  }

  void _handleDayTap(CalendarDay day) {
    _dayTapHandler.handleDayTap(context, day, _allLectures);
  }

  void _handleMonthChanged(DateTime newMonth) {
    setState(() {
      _currentCalendarMonth = newMonth;
    });
  }

  String _sectionTitle(String filter) {
    switch (filter) {
      case 'غدًا':
        return LecturerLanguageController.tr(
          'محاضرات الغد',
          "Tomorrow's Lectures",
        );
      case 'الكل':
        return LecturerLanguageController.tr('جميع المحاضرات', 'All Lectures');
      default:
        return LecturerLanguageController.tr(
          "محاضرات اليوم",
          "Today's Lectures",
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: Colors.white,
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
                              LecturerLanguageController.tr(
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
                              onPressed: _loadHomeData,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                LecturerLanguageController.tr(
                                  'إعادة المحاولة',
                                  'Retry',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: LecturerHomeHeader(
                                selectedFilter: _selectedFilter,
                                referenceDateTime: _repository.currentDateTime,
                                lecturerName: widget.lecturerName,
                              ),
                            ),
                            NotificationBell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        LecturerFilterButtons(
                          selectedFilter: _selectedFilter,
                          onFilterChanged: _handleFilterChanged,
                        ),
                        const SizedBox(height: 16),
                        if (_selectedFilter != 'الكل') ...[
                          const ManageLecturesButton(),
                          const SizedBox(height: 28),
                        ] else
                          const SizedBox(height: 16),
                        if (_selectedFilter == 'الكل') ...[
                          MonthlyCalendar(
                            currentMonth: _currentCalendarMonth,
                            calendarDays: _calendarService.buildCalendarDays(
                              _currentCalendarMonth,
                              _allLectures,
                            ),
                            onDayTap: _handleDayTap,
                            onMonthChanged: _handleMonthChanged,
                          ),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _sectionTitle(_selectedFilter),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF222222),
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                          LectureTimeline(
                            lectures: _getLecturesForDisplay(),
                            onLectureTap: _openAttendanceForSelectedFilter,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
