import 'package:flutter/material.dart';
import '../student/components/notification_bell.dart';
import '../student/notifications_screen.dart';
import 'lecturer_language.dart';
import '../../widgets/monthly_calendar.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../models/calendar_day.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/calendar_service.dart';
import '../../services/lecturer/filter_service.dart';
import '../../widgets/lecturer/lecturer_home_header.dart';
import '../../widgets/lecturer/lecturer_filter_buttons.dart';
import '../../widgets/lecturer/manage_lectures_button.dart';
import '../../widgets/lecturer/lecture_timeline.dart';
import '../../widgets/lecturer/day_tap_handler.dart';
import 'lecturer_navigation.dart';

class LecturerHomeScreen extends StatefulWidget {
  const LecturerHomeScreen({super.key});

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

  // Data
  late List<LectureItem> _allLectures;

  @override
  void initState() {
    super.initState();
    _calendarService = CalendarService(_repository);
    _dayTapHandler = DayTapHandler(repository: _repository);
    _allLectures = _repository.getAllLectures();
  }

  void _handleFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  /// محاضرات المعروضة حسب الفلتر: اليوم / غداً (لو الغد إجازة = قائمة فارغة)
  List<LectureItem> _getLecturesForDisplay() {
    if (_selectedFilter == 'غدًا') {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      if (_repository.isHoliday(tomorrow)) return [];
    }
    return FilterService.filterLectures(_allLectures, _selectedFilter);
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
              child: ListView(
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
                      onLectureTap: (lecture) =>
                          LecturerNavigation.goToAttendance(context, lecture),
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
