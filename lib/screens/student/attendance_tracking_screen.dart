import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'components/notification_bell.dart';
import 'components/custom_nav_bar_icons.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class AttendanceTrackingScreen extends StatefulWidget {
  const AttendanceTrackingScreen({super.key});

  @override
  State<AttendanceTrackingScreen> createState() => _AttendanceTrackingScreenState();
}

class _AttendanceTrackingScreenState extends State<AttendanceTrackingScreen> {
  static const Color _primaryColor = Color(0xFF006571);
  static const Color _tabBackground = Color(0xFFF5F5F5);

  final List<String> _courses = <String>[
    'بحوث عمليات نظري',
    'جودة البرمجيات نظري',
    'هندسة البيانات نظري',
  ];

  final List<String> _weeks = <String>[
    'الأسبوع الأول',
    'الأسبوع الثاني',
    'الأسبوع الثالث',
    'الأسبوع الرابع',
    'الأسبوع الخامس',
    'الأسبوع السادس',
  ];

  String _selectedCourse = 'بحوث عمليات نظري';
  final Set<String> _selectedWeeks = <String>{'الأسبوع الرابع', 'الأسبوع الخامس'};

  final int _totalAttendance = 9;
  final int _excusedAbsence = 2;
  final int _unexcusedAbsence = 1;
  final int _tardiness = 1;
  final int _total = 13;

  late final List<_AttendanceRecord> _records;

  @override
  void initState() {
    super.initState();
    _records = <_AttendanceRecord>[
      const _AttendanceRecord(
        timeRange: '11:50-10:00',
        course: 'بحوث عمليات',
        courseType: 'نظري',
        week: 'الأسبوع الخامس',
        day: '19',
        dayName: 'الأحد',
        status: 'present',
      ),
      const _AttendanceRecord(
        timeRange: '12:50-12:00',
        course: 'بحوث عمليات',
        courseType: 'نظري',
        week: 'الأسبوع الرابع',
        day: '08',
        dayName: 'الثلاثاء',
        status: 'present',
      ),
      const _AttendanceRecord(
        timeRange: '11:50-10:00',
        course: 'بحوث عمليات',
        courseType: 'نظري',
        week: 'الأسبوع الرابع',
        day: '06',
        dayName: 'الأحد',
        status: 'late',
      ),
    ];
  }

  double get _attendancePercentage => (_totalAttendance / _total) * 100;
  double get _excusedPercentage => (_excusedAbsence / _total) * 100;
  double get _unexcusedPercentage => (_unexcusedAbsence / _total) * 100;
  double get _tardinessPercentage => (_tardiness / _total) * 100;

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: <Widget>[
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildCourseTabs(),
                const SizedBox(height: 24),
                _buildAttendanceSummary(),
                const SizedBox(height: 24),
                _buildWeekFilterBar(),
                const SizedBox(height: 24),
                Expanded(
                  child: _buildAttendanceLog(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
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
            'تتبع الحضور',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
        ),
        const NotificationBell(),
      ],
    );
  }

  Widget _buildCourseTabs() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _tabBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        reverse: true,
        child: Row(
          children: _courses.map((String course) {
            final bool isActive = course == _selectedCourse;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCourse = course;
                  });
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 36,
                  constraints: const BoxConstraints(minWidth: 100),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: isActive
                        ? const LinearGradient(
                            colors: <Color>[
                              Color(0xFF27A2A9),
                              Color(0xFF006571),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : null,
                    color: isActive ? null : Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    course,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : const Color(0xFF444444),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildLegendItem(
                  color: const Color(0xFF006571),
                  percentage: _attendancePercentage,
                  count: _totalAttendance,
                  label: 'الحضور',
                ),
                const SizedBox(height: 12),
                _buildLegendItem(
                  color: const Color(0xFF2196F3),
                  percentage: _excusedPercentage,
                  count: _excusedAbsence,
                  label: 'الغياب بعذر',
                ),
                const SizedBox(height: 12),
                _buildLegendItem(
                  color: const Color(0xFFFF9800),
                  percentage: _unexcusedPercentage,
                  count: _unexcusedAbsence,
                  label: 'الغياب بدون عذر',
                ),
                const SizedBox(height: 12),
                _buildLegendItem(
                  color: const Color(0xFFFFC107),
                  percentage: _tardinessPercentage,
                  count: _tardiness,
                  label: 'التأخير',
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CustomPaint(
                  size: const Size(120, 120),
                  painter: _DonutChartPainter(
                    attendancePercentage: _attendancePercentage,
                    excusedPercentage: _excusedPercentage,
                    unexcusedPercentage: _unexcusedPercentage,
                    tardinessPercentage: _tardinessPercentage,
                  ),
                ),
                const Text(
                  '15%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required double percentage,
    required int count,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${percentage.toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF1A1A1A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: _weeks.map((String week) {
            final bool isSelected = _selectedWeeks.contains(week);
            final String displayText = week.replaceFirst(' ', '\n');
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedWeeks.remove(week);
                    } else {
                      _selectedWeeks.add(week);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF27A2A9) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAttendanceLog() {
    final filteredRecords = _records.where((record) {
      final selectedCourseName = _selectedCourse.split(' ')[0];
      final courseMatch = record.course == selectedCourseName || _selectedCourse.contains(record.course);
      final weekMatch = _selectedWeeks.contains(record.week);
      return courseMatch && weekMatch;
    }).toList();

    if (filteredRecords.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد سجلات',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF9E9E9E),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'سجل الحضور',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: filteredRecords.length,
            itemBuilder: (BuildContext context, int index) {
              return _AttendanceCard(record: filteredRecords[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double attendancePercentage;
  final double excusedPercentage;
  final double unexcusedPercentage;
  final double tardinessPercentage;

  _DonutChartPainter({
    required this.attendancePercentage,
    required this.excusedPercentage,
    required this.unexcusedPercentage,
    required this.tardinessPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 20.0;

    double startAngle = -math.pi / 2;

    final attendanceSweep = (attendancePercentage / 100) * 2 * math.pi;
    final attendancePaint = Paint()
      ..color = const Color(0xFF006571)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      attendanceSweep,
      false,
      attendancePaint,
    );
    startAngle += attendanceSweep;

    final excusedSweep = (excusedPercentage / 100) * 2 * math.pi;
    final excusedPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      excusedSweep,
      false,
      excusedPaint,
    );
    startAngle += excusedSweep;

    final unexcusedSweep = (unexcusedPercentage / 100) * 2 * math.pi;
    final unexcusedPaint = Paint()
      ..color = const Color(0xFFFF9800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      unexcusedSweep,
      false,
      unexcusedPaint,
    );
    startAngle += unexcusedSweep;

    final tardinessSweep = (tardinessPercentage / 100) * 2 * math.pi;
    final tardinessPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      tardinessSweep,
      false,
      tardinessPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AttendanceRecord {
  const _AttendanceRecord({
    required this.timeRange,
    required this.course,
    required this.courseType,
    required this.week,
    required this.day,
    required this.dayName,
    required this.status,
  });

  final String timeRange;
  final String course;
  final String courseType;
  final String week;
  final String day;
  final String dayName;
  final String status;
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.record,
  });

  final _AttendanceRecord record;

  Color get _badgeColor {
    switch (record.status) {
      case 'present':
        return const Color(0xFF006571);
      case 'late':
        return const Color(0xFFFF9800);
      case 'excused':
        return const Color(0xFF2196F3);
      case 'unexcused':
        return const Color(0xFFE57373);
      default:
        return const Color(0xFF006571);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 46,
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            decoration: BoxDecoration(
              color: _badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  record.day,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  record.dayName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    record.course,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.courseType,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.week,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                record.timeRange,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 2),
              const Text(
                'مدة المحاضرة',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
