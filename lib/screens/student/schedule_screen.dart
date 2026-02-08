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
  static const Color _gridBorderColor = Color(0xFFE6E6E6);
  static const Color _headerCellColor = Color(0xFFF3F5F6);
  static const double _timeColWidth = 52;
  static const double _rowHeight = 60;

  String _formatHHmm(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;
    final hour = parts[0].padLeft(2, '0');
    final minute = parts[1].padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatSlotLabel(TimeSlot slot) {
    return '${_formatHHmm(slot.start)} - ${_formatHHmm(slot.end)}';
  }

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
        endTime: '10:50',
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
        courseName: 'الثقافة الإسلامية',
        day: 'الأربعاء',
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
        final dayWidth = (screenWidth - _timeColWidth - 32) / _days.length;
        // عرض وارتفاع محددان حتى لا يحصل الـ Column على قيود غير محدودة (تفشل التخطيط ثم hit test)
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _buildSemesterRow(),
                    const SizedBox(height: 10),
                    _buildTable(dayWidth),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSemesterRow() {
    return const Align(
      alignment: Alignment.centerRight,
      child: Text(
        'الفصل الدراسي: الثاني 1447 هـ',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _buildTable(double dayWidth) {
    final tableHeight = _timeSlots.length * _rowHeight;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _gridBorderColor, width: 1),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildDaysHeader(dayWidth),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // عمود الأوقات أولاً ليظهر على اليمين في RTL
                SizedBox(
                  width: _timeColWidth,
                  height: tableHeight,
                  child: _buildTimeColumn(),
                ),
                // أعمدة الأيام
                ..._days.map((day) {
                  return SizedBox(
                    width: dayWidth,
                    height: tableHeight,
                    child: _buildDayStack(day, dayWidth, tableHeight),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysHeader(double dayWidth) {
    return Row(
      children: <Widget>[
        // خلية فارغة فوق عمود الأوقات (يظهر على اليمين في RTL)
        SizedBox(
          width: _timeColWidth,
          child: Container(
            height: 48,
            decoration: const BoxDecoration(color: _headerCellColor),
          ),
        ),
        ..._days.map((String day) {
          return SizedBox(
            width: dayWidth,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: _headerCellColor),
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTimeColumn() {
    return Column(
      children: _timeSlots.map((TimeSlot slot) {
        return Container(
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.centerRight,
          decoration: const BoxDecoration(color: _headerCellColor),
          child: Text(
            _formatSlotLabel(slot),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayStack(String day, double dayWidth, double tableHeight) {
    final firstSlotMinutes = _parseTimeToMinutes(_timeSlots.first.start);
    const int slotMinutes = 50;

    final dayCourses = _courses.where((c) => c.day == day).toList();
    dayCourses.sort((a, b) => _parseTimeToMinutes(a.startTime) - _parseTimeToMinutes(b.startTime));

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        // Grid background
        Column(
          children: List<Widget>.generate(_timeSlots.length, (int idx) {
            return Container(
              height: _rowHeight,
              decoration: BoxDecoration(
                border: Border(
                  left: const BorderSide(color: _gridBorderColor, width: 1),
                  top: BorderSide(
                    color: idx == 0 ? _gridBorderColor : Colors.transparent,
                    width: 1,
                  ),
                  bottom: const BorderSide(color: _gridBorderColor, width: 1),
                ),
              ),
            );
          }),
        ),
        // Courses overlay - مربع مدمج (ساعتين = مربع واحد يمتد خليتين)
        ...dayCourses.map((course) {
          final startMin = _parseTimeToMinutes(course.startTime);
          final endMin = _parseTimeToMinutes(course.endTime);
          final durationMin = (endMin - startMin).clamp(0, 24 * 60);
          final slotCount = (durationMin / slotMinutes).ceil().clamp(1, _timeSlots.length);
          final slotIndex = ((startMin - firstSlotMinutes) / slotMinutes).floor().clamp(0, _timeSlots.length - 1);
          final top = slotIndex * _rowHeight;
          final blockHeight = slotCount * _rowHeight;

          return Positioned(
            top: top,
            left: 0,
            right: 0,
            child: SizedBox(
              width: dayWidth,
              height: blockHeight,
              child: GestureDetector(
                onTap: () => _showCourseDetails(course),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  decoration: BoxDecoration(
                    color: course.color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Expanded(
                        child: Center(
                          child: Text(
                            course.courseName,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
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
            ),
          );
        }),
      ],
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
                      _buildDetailRow(
                        'الوقت',
                        '${_formatHHmm(course.startTime)} - ${_formatHHmm(course.endTime)}',
                      ),
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
