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
  /// عمود الأوقات (يمين الجدول في العربية) — عرض كافٍ لـ «08:00 - 09:00».
  static const double _timeColWidth = 58;
  static const double _rowHeight = 60;
  static const Color _dayHeaderBgLight = Color(0xFFF1F3F4);

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

  /// خطوط شبكة جدول الأيام (واضحة على الخلفية البيضاء).
  Color _dayGridLineColor(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    }
    return const Color(0xFFD8DEE4);
  }

  Color _dayHeaderBackground(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.surfaceContainerHigh;
    }
    return _dayHeaderBgLight;
  }

  /// عربي (RTL): الأحد أول الأسبوع على **يمين** الجدول بجانب عمود الوقت.
  List<String> _daysInTableOrder(bool rtl) {
    return rtl ? _days.reversed.toList() : _days;
  }

  /// Hour rows covering only this student's lecture window (e.g. 10:00–14:00).
  List<TimeSlot> _timeSlotsForCourses(List<CourseSchedule> courses) {
    if (courses.isEmpty) {
      return const <TimeSlot>[
        TimeSlot(start: '08:00', end: '09:00'),
        TimeSlot(start: '09:00', end: '10:00'),
        TimeSlot(start: '10:00', end: '11:00'),
      ];
    }

    var minMinutes = 24 * 60;
    var maxMinutes = 0;
    for (final course in courses) {
      final start = _parseTimeToMinutes(course.startTime);
      var end = _parseTimeToMinutes(course.endTime);
      if (end <= start) end += 24 * 60;
      if (start < minMinutes) minMinutes = start;
      if (end > maxMinutes) maxMinutes = end;
    }

    final startHour = (minMinutes ~/ 60).clamp(0, 23);
    final endHour = ((maxMinutes + 59) ~/ 60).clamp(startHour + 1, 24);

    final slots = <TimeSlot>[];
    for (var h = startHour; h < endHour; h++) {
      final next = h + 1;
      slots.add(
        TimeSlot(
          start: '${h.toString().padLeft(2, '0')}:00',
          end: '${next.toString().padLeft(2, '0')}:00',
        ),
      );
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final translation = TranslationController.instance;
    return AnimatedBuilder(
      animation: translation,
      builder: (context, _) {
        return Directionality(
          textDirection: translation.textDirection,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  Expanded(
                    child: RefreshIndicator(
                      color: _primaryColor,
                      onRefresh: () async {
                        final student =
                            StudentAuthService.instance.currentStudent;
                        if (student == null || student.studentId <= 0) return;
                        final sid = student.studentId.toString();
                        await ref
                            .read(studentRepositoryProvider)
                            .clearCoursesCache(sid);
                        ref.invalidate(studentUnifiedCoursesProvider(sid));
                        await ref.read(
                          studentUnifiedCoursesProvider(sid).future,
                        );
                      },
                      child: _buildScheduleBody(),
                    ),
                  ),
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
            icon: StudentBackChevronIcon(color: _primaryColor, size: 16),
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
    final timeSlots = _timeSlotsForCourses(courses);
    return _buildSchedule(courses, timeSlots);
  }

  Widget _buildSchedule(
    List<CourseSchedule> courses,
    List<TimeSlot> timeSlots,
  ) {
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
                  _buildTable(dayWidth, courses, timeSlots),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSemesterRow() {
    return Builder(
      builder: (context) => Align(
        alignment: Alignment.centerRight,
        child: TText(
          'الفصل الدراسي: الثاني 1447 هـ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildTable(
    double dayWidth,
    List<CourseSchedule> courses,
    List<TimeSlot> timeSlots,
  ) {
    final translation = TranslationController.instance;
    final isRtl = translation.textDirection == TextDirection.rtl;
    final tableHeight = timeSlots.length * _rowHeight;
    final colorScheme = Theme.of(context).colorScheme;
    final gridLine = _dayGridLineColor(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: gridLine),
          color: colorScheme.surface,
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
                      child: _buildTimeColumn(timeSlots),
                    ),
                  ..._daysInTableOrder(isRtl).map((String day) {
                    return SizedBox(
                      width: dayWidth,
                      height: tableHeight,
                      child: _buildDayStack(
                        day,
                        dayWidth,
                        tableHeight,
                        courses,
                        timeSlots,
                      ),
                    );
                  }),
                  if (isRtl)
                    SizedBox(
                      width: _timeColWidth,
                      height: tableHeight,
                      child: _buildTimeColumn(timeSlots),
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
    final colorScheme = Theme.of(context).colorScheme;
    final headerBg = _dayHeaderBackground(context);
    final gridLine = _dayGridLineColor(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: headerBg,
          border: Border(bottom: BorderSide(color: gridLine)),
        ),
        child: Row(
          children: <Widget>[
            if (!isRtl)
              SizedBox(
                width: _timeColWidth,
                child: Container(height: 48, color: headerBg),
              ),
            ..._daysInTableOrder(isRtl).map((String day) {
              return SizedBox(
                width: dayWidth,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  color: headerBg,
                  child: TText(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }),
            if (isRtl)
              SizedBox(
                width: _timeColWidth,
                child: Container(height: 48, color: headerBg),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeColumn(List<TimeSlot> timeSlots) {
    final colorScheme = Theme.of(context).colorScheme;
    final gridLine = _dayGridLineColor(context);
    final timeBg = _dayHeaderBackground(context);
    final timeColor = colorScheme.onSurfaceVariant;
    return Column(
      children: timeSlots.map((TimeSlot slot) {
        return Container(
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: timeBg,
            border: Border(bottom: BorderSide(color: gridLine)),
          ),
          child: Text(
            _formatSlotLabel(slot),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: timeColor,
              height: 1.2,
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
    List<TimeSlot> timeSlots,
  ) {
    final firstSlotMinutes = _parseTimeToMinutes(timeSlots.first.start);
    const int slotMinutes = 60;
    final gridLine = _dayGridLineColor(context);
    final cellBg = Theme.of(context).colorScheme.surface;

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
          children: List<Widget>.generate(timeSlots.length, (int idx) {
            return Container(
              height: _rowHeight,
              decoration: BoxDecoration(
                color: cellBg,
                border: Border(bottom: BorderSide(color: gridLine)),
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
            timeSlots.length,
          );
          final slotIndex = ((startMin - firstSlotMinutes) / slotMinutes)
              .floor()
              .clamp(0, timeSlots.length - 1);
          final top = slotIndex * _rowHeight;
          final visibleSlots = (timeSlots.length - slotIndex).clamp(
            1,
            timeSlots.length,
          );
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
                    borderRadius: BorderRadius.circular(8),
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
                                  height: 1.25,
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
        final colorScheme = Theme.of(context).colorScheme;
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
                  color: colorScheme.surface,
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _dayGridLineColor(context)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: TText(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: isLtr ? TextAlign.left : TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TText(
              value,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              textAlign: isLtr ? TextAlign.left : TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
