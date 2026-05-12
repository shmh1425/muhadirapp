import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../mappers/course_model_to_schedule.dart';
import '../../models/course_schedule.dart';
import '../../providers/courses_providers.dart';
import 'components/notification_bell.dart';
import 'components/custom_nav_bar_icons.dart';
import 'components/student_back_chevron_icon.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';
import '../../services/student_auth_service.dart';
import '../../shared/widgets/chat_fab.dart';
import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
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

  /// عربي (RTL): الأحد أول الأسبوع على **يمين** الجدول بجانب عمود الوقت.
  List<String> _daysInTableOrder(bool rtl) {
    return rtl ? _days.reversed.toList() : _days;
  }

  // أوقات الجدول بنظام 24 ساعة (يعرض أي شعبة مهما كان وقتها).
  final List<TimeSlot> _timeSlots = <TimeSlot>[
    TimeSlot(start: '00:00', end: '01:00'),
    TimeSlot(start: '01:00', end: '02:00'),
    TimeSlot(start: '02:00', end: '03:00'),
    TimeSlot(start: '03:00', end: '04:00'),
    TimeSlot(start: '04:00', end: '05:00'),
    TimeSlot(start: '05:00', end: '06:00'),
    TimeSlot(start: '06:00', end: '07:00'),
    TimeSlot(start: '07:00', end: '08:00'),
    TimeSlot(start: '08:00', end: '09:00'),
    TimeSlot(start: '09:00', end: '10:00'),
    TimeSlot(start: '10:00', end: '11:00'),
    TimeSlot(start: '11:00', end: '12:00'),
    TimeSlot(start: '12:00', end: '13:00'),
    TimeSlot(start: '13:00', end: '14:00'),
    TimeSlot(start: '14:00', end: '15:00'),
    TimeSlot(start: '15:00', end: '16:00'),
    TimeSlot(start: '16:00', end: '17:00'),
    TimeSlot(start: '17:00', end: '18:00'),
    TimeSlot(start: '18:00', end: '19:00'),
    TimeSlot(start: '19:00', end: '20:00'),
    TimeSlot(start: '20:00', end: '21:00'),
    TimeSlot(start: '21:00', end: '22:00'),
    TimeSlot(start: '22:00', end: '23:00'),
    TimeSlot(start: '23:00', end: '24:00'),
  ];

  @override
  Widget build(BuildContext context) {
    final translation = TranslationController.instance;
    return AnimatedBuilder(
      animation: translation,
      builder: (context, _) {
        return Directionality(
          textDirection: translation.textDirection,
          child: Scaffold(
            backgroundColor: Colors.white,
            floatingActionButton: const ChatFAB(),
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
                  Expanded(child: _buildScheduleBody()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: StudentBackChevronIcon(
              color: _primaryColor,
              size: 16,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TText(
                TranslationController.instance.translateToEnglish
                    ? 'Class schedule'
                    : 'الجدول الدراسي',
                textAlign: TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 44),
          NotificationBell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleBody() {
    final student = StudentAuthService.instance.currentStudent;
    if (student == null) {
      return const Center(
        child: TText('سجّل دخولك لعرض جدولك', style: TextStyle(fontSize: 16)),
      );
    }
    final sid = student.studentId.toString();
    final unifiedAsync = ref.watch(studentUnifiedCoursesProvider(sid));

    if (unifiedAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }
    if (unifiedAsync.hasError) {
      return const Center(
        child: TText(
          'تعذر تحميل الجدول.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    final unified = unifiedAsync.value!;
    final models = unified.allCourses;
    final courses = courseModelsToScheduleGrid(unified.scheduleCourses);
    if (models.isEmpty) {
      return const Center(
        child: TText(
          'لا توجد تسجيلات في مقررات لهذا الفصل',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    if (courses.isEmpty) {
      return const Center(
        child: TText(
          'لا يوجد جدول معرّف للسكاشن المسجّل فيها',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    return _buildSchedule(courses);
  }

  Widget _buildSchedule(List<CourseSchedule> courses) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dayWidth = (screenWidth - _timeColWidth - 32) / _days.length;
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const AlwaysScrollableScrollPhysics(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildSemesterRow(),
                  const SizedBox(height: 10),
                  _buildTable(dayWidth, courses),
                ],
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
      child: TText(
        'الفصل الدراسي: الثاني 1447 هـ',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _buildTable(double dayWidth, List<CourseSchedule> courses) {
    final translation = TranslationController.instance;
    final isRtl = translation.textDirection == TextDirection.rtl;
    final tableHeight = _timeSlots.length * _rowHeight;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _gridBorderColor, width: 1),
          color: Colors.white,
        ),
        // اتجاه الرسم LTR ثابت؛ عمود الوقت يُوضع يمين/يسار حسب اللغة،
        // وترتيب أعمدة الأيام يُعكس في العربية حتى يكون الأحد يمين الجدول.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildDaysHeader(dayWidth),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!isRtl)
                    SizedBox(
                      width: _timeColWidth,
                      height: tableHeight,
                      child: _buildTimeColumn(),
                    ),
                  ..._daysInTableOrder(isRtl).map((day) {
                    return SizedBox(
                      width: dayWidth,
                      height: tableHeight,
                      child: _buildDayStack(day, dayWidth, tableHeight, courses),
                    );
                  }),
                  if (isRtl)
                    SizedBox(
                      width: _timeColWidth,
                      height: tableHeight,
                      child: _buildTimeColumn(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaysHeader(double dayWidth) {
    final translation = TranslationController.instance;
    final isRtl = translation.textDirection == TextDirection.rtl;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: <Widget>[
          if (!isRtl)
            SizedBox(
              width: _timeColWidth,
              child: Container(
                height: 48,
                decoration: const BoxDecoration(color: _headerCellColor),
              ),
            ),
          ..._daysInTableOrder(isRtl).map((String day) {
            return SizedBox(
              width: dayWidth,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: _headerCellColor),
                child: TText(
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
          if (isRtl)
            SizedBox(
              width: _timeColWidth,
              child: Container(
                height: 48,
                decoration: const BoxDecoration(color: _headerCellColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn() {
    final translation = TranslationController.instance;
    final isRtl = translation.textDirection == TextDirection.rtl;
    return Column(
      children: _timeSlots.map((TimeSlot slot) {
        return Container(
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
          decoration: const BoxDecoration(color: _headerCellColor),
          child: Text(
            _formatSlotLabel(slot),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
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

  Widget _buildDayStack(
    String day,
    double dayWidth,
    double tableHeight,
    List<CourseSchedule> courses,
  ) {
    final firstSlotMinutes = _parseTimeToMinutes(_timeSlots.first.start);
    const int slotMinutes = 60;

    final dayCourses = courses.where((c) => c.day == day).toList();
    dayCourses.sort(
      (a, b) =>
          _parseTimeToMinutes(a.startTime) - _parseTimeToMinutes(b.startTime),
    );

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
          var endMin = _parseTimeToMinutes(course.endTime);
          // Support schedules that cross midnight (e.g. 18:00 -> 00:00).
          if (endMin <= startMin) {
            endMin += 24 * 60;
          }
          final durationMin = (endMin - startMin).clamp(0, 24 * 60);
          final slotCount = (durationMin / slotMinutes).ceil().clamp(
            1,
            _timeSlots.length,
          );
          final slotIndex = ((startMin - firstSlotMinutes) / slotMinutes)
              .floor()
              .clamp(0, _timeSlots.length - 1);
          final top = slotIndex * _rowHeight;
          final visibleSlots = (_timeSlots.length - slotIndex).clamp(1, _timeSlots.length);
          final blockHeight = slotCount.clamp(1, visibleSlots) * _rowHeight;

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TText(
                                course.courseName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (course.location.isNotEmpty &&
                                  course.location != '—') ...[
                                const SizedBox(height: 2),
                                TText(
                                  course.location,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white70,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
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
    final t = time.trim();
    final parts = t.split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0].trim()) ?? 0;
    final minute = int.tryParse(parts[1].trim()) ?? 0;
    return hour * 60 + minute;
  }

  void _showCourseDetails(CourseSchedule course) {
    final translation = TranslationController.instance;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: translation.textDirection,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 48,
            ),
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
                        padding: const EdgeInsets.only(
                          top: 12,
                          left: 12,
                          right: 12,
                        ),
                        child: Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text('', textAlign: TextAlign.center),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 22),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TText(
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
    final translation = TranslationController.instance;
    final isLtr = translation.textDirection == TextDirection.ltr;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: TText(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: isLtr ? TextAlign.left : TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TText(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: isLtr ? TextAlign.left : TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
