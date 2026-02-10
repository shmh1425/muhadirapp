import 'package:flutter/material.dart';
import 'lecturer_nav_bar.dart';
import '../student/components/notification_bell.dart';
import '../student/notifications_screen.dart';
import 'lecturer_qr_screen.dart';
import 'lecturer_profile_screen.dart';
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

class LecturerHomeScreen extends StatefulWidget {
  const LecturerHomeScreen({super.key});

  @override
  State<LecturerHomeScreen> createState() => _LecturerHomeScreenState();
}

class _LecturerHomeScreenState extends State<LecturerHomeScreen> {
  int selectedIndex = 2; // Home selected by default
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
    _dayTapHandler = DayTapHandler(
      repository: _repository,
    );
    _allLectures = _repository.getAllLectures();
  }

  Future<void> _onItemTapped(int index) async {
    setState(() {
      selectedIndex = index;
    });

    switch (index) {
      case 0:
        await Future.delayed(const Duration(milliseconds: 160));
        if (!mounted) return;
        await Navigator.push(
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
        if (!mounted) return;
        setState(() {
          selectedIndex = 2; // الرجوع للهوم بعد الخروج من البروفايل
        });
        break;
      case 1:
        await Future.delayed(const Duration(milliseconds: 160));
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LecturerQrScreen(lecture: null),
          ),
        );
        if (!mounted) return;
        setState(() {
          selectedIndex = 2;
        });
        break;
      case 2:
        // Home الحالي
        break;
    }
  }

  void _handleFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  void _handleDayTap(CalendarDay day) {
    _dayTapHandler.handleDayTap(context, day, _allLectures);
  }

  void _handleMonthChanged(DateTime newMonth) {
    setState(() {
      _currentCalendarMonth = newMonth;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: LecturerNavBar(
          selectedIndex: selectedIndex,
          onItemTapped: _onItemTapped,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              // Header with greeting and notification
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LecturerHomeHeader(selectedFilter: _selectedFilter),
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

              // Filter buttons
              LecturerFilterButtons(
                selectedFilter: _selectedFilter,
                onFilterChanged: _handleFilterChanged,
              ),
              const SizedBox(height: 16),

              // Manage Lectures button (يظهر فقط عند اختيار اليوم أو غداً)
              if (_selectedFilter != 'الكل') ...[
                const ManageLecturesButton(),
                const SizedBox(height: 28),
              ] else
                const SizedBox(height: 16),

              // عرض التقويم أو Timeline حسب الفلتر
              if (_selectedFilter == 'الكل') ...[
                // التقويم الشهري
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
                // Section title
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    FilterService.getSectionTitle(_selectedFilter),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222222),
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                // Timeline with lectures
                LectureTimeline(
                  lectures: FilterService.filterLectures(
                    _allLectures,
                    _selectedFilter,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
