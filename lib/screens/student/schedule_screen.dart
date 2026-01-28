import 'package:flutter/material.dart';
import 'components/notification_bell.dart';
import 'components/custom_nav_bar_icons.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const Color _primaryColor = Color(0xFF006571);

  final List<String> _days = <String>[
    'الأحد',
    'الأثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
  ];

  final List<TimeSlot> _timeSlots = <TimeSlot>[
    TimeSlot(start: '8:00', end: '8:50'),
    TimeSlot(start: '9:00', end: '9:50'),
    TimeSlot(start: '10:00', end: '10:50'),
    TimeSlot(start: '11:00', end: '11:50'),
    TimeSlot(start: '12:00', end: '12:50'),
    TimeSlot(start: '1:00', end: '1:50'),
    TimeSlot(start: '2:00', end: '2:50'),
  ];

  List<CourseSchedule> _courses = <CourseSchedule>[];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  void _loadSchedule() {
    _courses = <CourseSchedule>[
      CourseSchedule(
        courseName: 'بحوث العمليات',
        day: 'الأحد',
        startTime: '8:00',
        endTime: '9:50',
        color: const Color(0xFF4CAF50),
        courseCode: 'SE3321',
        activity: 'نظري',
        section: '1',
        hours: '4',
        lecturer: 'إناس محمد طاهر بوقس',
        location: 'الزاهر - طالبات',
        room: '102 ط',
      ),
      CourseSchedule(
        courseName: 'جودة البرمجيات',
        day: 'الأحد',
        startTime: '10:00',
        endTime: '11:50',
        color: const Color(0xFF2196F3),
        courseCode: 'SE3322',
        activity: 'نظري',
        section: '1',
        hours: '3',
        lecturer: 'محاضر',
        location: 'الزاهر - طالبات',
        room: '103 ط',
      ),
      CourseSchedule(
        courseName: 'بحوث العمليات',
        day: 'الأثنين',
        startTime: '8:00',
        endTime: '9:50',
        color: const Color(0xFF4CAF50),
        courseCode: 'SE3321',
        activity: 'نظري',
        section: '1',
        hours: '4',
        lecturer: 'إناس محمد طاهر بوقس',
        location: 'الزاهر - طالبات',
        room: '102 ط',
      ),
      CourseSchedule(
        courseName: 'هندسة البيانات',
        day: 'الأثنين',
        startTime: '10:00',
        endTime: '11:50',
        color: const Color(0xFF03A9F4),
        courseCode: 'SE3323',
        activity: 'نظري',
        section: '1',
        hours: '3',
        lecturer: 'محاضر',
        location: 'الزاهر - طالبات',
        room: '104 ط',
      ),
      CourseSchedule(
        courseName: 'بحوث العمليات',
        day: 'الثلاثاء',
        startTime: '8:00',
        endTime: '9:50',
        color: const Color(0xFF4CAF50),
        courseCode: 'SE3321',
        activity: 'نظري',
        section: '1',
        hours: '4',
        lecturer: 'إناس محمد طاهر بوقس',
        location: 'الزاهر - طالبات',
        room: '102 ط',
      ),
      CourseSchedule(
        courseName: 'هندسة البيانات',
        day: 'الثلاثاء',
        startTime: '10:00',
        endTime: '11:50',
        color: const Color(0xFF03A9F4),
        courseCode: 'SE3323',
        activity: 'نظري',
        section: '1',
        hours: '3',
        lecturer: 'محاضر',
        location: 'الزاهر - طالبات',
        room: '104 ط',
      ),
      CourseSchedule(
        courseName: 'جودة البرمجيات',
        day: 'الثلاثاء',
        startTime: '12:00',
        endTime: '12:50',
        color: const Color(0xFF673AB7),
        courseCode: 'SE3322',
        activity: 'نظري',
        section: '1',
        hours: '3',
        lecturer: 'محاضر',
        location: 'الزاهر - طالبات',
        room: '103 ط',
      ),
      CourseSchedule(
        courseName: 'هندسة البيانات',
        day: 'الخميس',
        startTime: '8:00',
        endTime: '9:50',
        color: const Color(0xFF03A9F4),
        courseCode: 'SE3323',
        activity: 'نظري',
        section: '1',
        hours: '3',
        lecturer: 'محاضر',
        location: 'الزاهر - طالبات',
        room: '104 ط',
      ),
      CourseSchedule(
        courseName: 'الثقافة الإسلامية',
        day: 'الخميس',
        startTime: '10:00',
        endTime: '11:50',
        color: const Color(0xFFE91E63),
        courseCode: 'ISL101',
        activity: 'نظري',
        section: '1',
        hours: '2',
        lecturer: 'محاضر',
        location: 'الزاهر - طالبات',
        room: '105 ط',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: NavBarSettingsArabic(
          selectedIndex: 1,
          onItemTapped: (index) {
            if (index == 0) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            } else if (index == 2) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            } else if (index == 1) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeader(context),
              Expanded(
                child: _buildSchedule(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(3.14159),
              child: const Icon(
                Icons.arrow_back_ios,
                color: _primaryColor,
                size: 16,
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'الجدول الدراسي',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
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
    );
  }

  Widget _buildSchedule() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dayWidth = (screenWidth - 80 - 32) / _days.length;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildDaysHeader(dayWidth),
                  _buildTimeTable(dayWidth),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDaysHeader(double dayWidth) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 80,
          child: Container(),
        ),
        ..._days.map((String day) {
          return SizedBox(
            width: dayWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
              ),
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTimeTable(double dayWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildTimeColumn(),
        ..._days.map((String day) {
          return SizedBox(
            width: dayWidth,
            child: _buildDayColumn(day),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTimeColumn() {
    return SizedBox(
      width: 80,
      child: Column(
        children: _timeSlots.map((TimeSlot timeSlot) {
          return Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${timeSlot.start} - ${timeSlot.end}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayColumn(String day) {
    return Column(
      children: _timeSlots.asMap().entries.map((entry) {
        final int index = entry.key;
        final TimeSlot timeSlot = entry.value;
        final slotStartMinutes = _parseTimeToMinutes(timeSlot.start);
        
        CourseSchedule? course;
        for (final c in _courses) {
          if (c.day != day) continue;
          final courseStartMinutes = _parseTimeToMinutes(c.startTime);
          final courseEndMinutes = _parseTimeToMinutes(c.endTime);
          if (slotStartMinutes >= courseStartMinutes && slotStartMinutes < courseEndMinutes) {
            if (slotStartMinutes == courseStartMinutes) {
              course = c;
              break;
            } else {
              return Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    left: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                ),
              );
            }
          }
        }

        if (course == null) {
          return Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
                left: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
          );
        }

        final courseStartMinutes = _parseTimeToMinutes(course.startTime);
        final courseEndMinutes = _parseTimeToMinutes(course.endTime);
        final courseDuration = courseEndMinutes - courseStartMinutes;
        final slotCount = (courseDuration / 50).ceil();
        final courseHeight = (slotCount * 60.0) - 4;

        return Container(
          height: 60,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade300,
                width: 1,
              ),
              left: BorderSide(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          child: GestureDetector(
            onTap: () => _showCourseDetails(course!),
            child: Container(
              height: courseHeight,
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: course.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      course.courseName,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  int _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }

  void _showCourseDetails(CourseSchedule course) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320, maxHeight: 460),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
                        child: Row(
                          children: <Widget>[
                            IconButton(
                              icon: const Icon(Icons.close, size: 22),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const Expanded(
                              child: Text(
                                '',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          course.courseName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow('رمز المقرر', course.courseCode),
                      _buildDetailRow('النشاط', course.activity),
                      _buildDetailRow('الشعبة', course.section),
                      _buildDetailRow('الساعات', course.hours),
                      _buildDetailRow('المحاضر', course.lecturer),
                      _buildDetailRow('الوقت', '${course.startTime} - ${course.endTime}'),
                      _buildDetailRow('اليوم', course.day),
                      _buildDetailRow('المقر', course.location),
                      _buildDetailRow('القاعة', course.room),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.right,
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}

class TimeSlot {
  const TimeSlot({
    required this.start,
    required this.end,
  });

  final String start;
  final String end;
}

class CourseSchedule {
  const CourseSchedule({
    required this.courseName,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.courseCode,
    required this.activity,
    required this.section,
    required this.hours,
    required this.lecturer,
    required this.location,
    required this.room,
  });

  final String courseName;
  final String day;
  final String startTime;
  final String endTime;
  final Color color;
  final String courseCode;
  final String activity;
  final String section;
  final String hours;
  final String lecturer;
  final String location;
  final String room;
}
