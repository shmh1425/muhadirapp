import 'package:flutter/material.dart';
import 'student_card_page.dart';
import 'components/custom_nav_bar_icons.dart';
import 'notifications_screen.dart';
import 'components/notification_bell.dart';
import 'settings_screen.dart';
import 'services_screen.dart';
import 'nfc_attendance_screen.dart';
import 'schedule_screen.dart';
import 'excuse_screen.dart';
import 'pending_detail_screen.dart';
import 'submit_excuse_screen.dart';
import 'rejection_detail_screen.dart';
import '../../services/student_auth_service.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/excuse/excuse_service.dart';
import '../../services/excuse/excuse_attendance_merge.dart';
import '../../models/excuse/excuse_request.dart';
import '../../models/attendance/manual_attendance_record.dart';
import '../../shared/widgets/student_profile_avatar.dart';
import '../../shared/widgets/chat_fab.dart';
import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _textStrong = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  int selectedIndex = 2; // Start with Home selected (index 2 for Home)
  final ManualAttendanceService _attendance = ManualAttendanceService.instance;
  final ExcuseService _excuses = ExcuseService.instance;

  static const Set<String> _activeAbsenceStatuses = <String>{
    'معلقة',
    'قيد الانتظار',
    'تم الرفض',
  };

  ({String text, Color color}) _badgeForMergedExcuseStatus(String status) {
    switch (status) {
      case 'معلقة':
        return (text: 'إرفاق عذر', color: Colors.grey);
      case 'قيد الانتظار':
        return (text: 'قيد الانتظار', color: Colors.amber);
      case 'تم الرفض':
        return (text: 'مرفوض', color: Colors.red);
      case 'مغلق':
        return (text: 'مغلق', color: Colors.blueGrey);
      case 'منتهي':
        return (text: 'منتهي', color: Colors.brown);
      case 'تم القبول':
        return (text: 'مقبول', color: Colors.green);
      default:
        return (text: '—', color: Colors.grey);
    }
  }

  Future<void> _onItemTapped(int index) async {
    setState(() {
      selectedIndex = index;
    });

    // Handle navigation based on selected index
    switch (index) {
      case 0: // Settings (Left)
        await Future.delayed(const Duration(milliseconds: 180));
        if (!mounted) {
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      if (!mounted) {
        return;
      }
      setState(() {
        selectedIndex = 2;
      });
        break;
      case 1: // Services/Grid (Center)
        await Future.delayed(const Duration(milliseconds: 180));
        if (!mounted) {
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServicesScreen()),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          selectedIndex = 2;
        });
        break;
      case 2:
        // Stay on Home
        break;
    }
  }

  /// أول كلمة من الاسم للترحيب (عربي إن وُجد)
  String _greetingName() {
    final s = StudentAuthService.instance.currentStudent;
    if (s == null) return 'طالب';
    final isEn = TranslationController.instance.translateToEnglish;
    final nameAr = (s.nameAr).trim();
    final nameEn = (s.name).trim();
    final raw = isEn
        ? (nameEn.isNotEmpty ? nameEn : nameAr)
        : (nameAr.isNotEmpty ? nameAr : nameEn);
    if (raw.isEmpty) return 'طالب';
    return raw.split(' ').first;
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
            backgroundColor: Colors.white,
            floatingActionButton: const ChatFAB(),
            bottomNavigationBar: NavBarSettingsArabic(
              selectedIndex: selectedIndex,
              onItemTapped: _onItemTapped,
            ),
            body: SafeArea(
              child: ListView(
                clipBehavior: Clip.none,
                padding: const EdgeInsets.only(
                  top: 36,
                  left: 30,
                  right: 16,
                  bottom: 16,
                ),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TText(
                        'أهلاً ${_greetingName()}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _textStrong,
                        ),
                      ),
                      Row(
                        children: [
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
                    ],
                  ),
              const SizedBox(height: 30),

              // زر التحضير الآن بعرض مرن (يتجنب overflow على الشاشات الصغيرة)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 296),
                  child: SizedBox(
                    width: double.infinity,
                    height: 73,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                      stops: [0.25, 0.95], // 25% and 95%
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(45),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NfcAttendanceScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(45),
                          ),
                        ),
                        child: TText(
                          translation.translateToEnglish
                              ? 'Mark Attendance'
                              : 'التحضير الآن',
                          style: const TextStyle(
                            fontSize: 23,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              buildStudentCard(context),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const TText(
                    'محاضرات اليوم:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _textStrong,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScheduleScreen(),
                        ),
                      );
                    },
                    style: ButtonStyle(
                      foregroundColor:
                          WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.pressed)) {
                          return const Color(0xFF006571); // اللون عند الضغط
                        }
                        return const Color(0xFF006571); // اللون العادي
                      }),
                      overlayColor: WidgetStateProperty.all(
                        const Color(0x22006571),
                      ),
                    ),
                    child: const TText(
                      ' الجدول الأسبوعي >',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildTodayLecturesSection(context),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const TText(
                    'الغيابات النشطة:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _textStrong,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExcuseScreen(),
                        ),
                      );
                    },
                    style: ButtonStyle(
                      foregroundColor:
                          WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.pressed)) {
                          return const Color(0xFF006571); // اللون عند الضغط
                        }
                        return const Color(0xFF006571); // اللون العادي
                      }),
                      overlayColor: WidgetStateProperty.all(
                        const Color(0x22006571),
                      ),
                    ),
                    child: const TText(
                      ' عرض الغيابات >',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 5),

              SizedBox(
                // Cards can grow slightly when showing status badges / longer text.
                // Keep a bit of extra vertical space to avoid bottom overflow on small devices.
                height: 208,
                child: _buildActiveAbsencesSection(context),
              ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveAbsencesSection(BuildContext context) {
    final studentId = StudentAuthService.instance.currentStudent?.studentId ?? 0;
    if (studentId <= 0) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<ManualAttendanceRecord>>(
      stream: _attendance.watchStudentRecords(studentId),
      builder: (context, recordsSnap) {
        final records = recordsSnap.data ?? <ManualAttendanceRecord>[];
        return StreamBuilder<List<ExcuseRequest>>(
          stream: _excuses.watchStudentRequests(studentId),
          builder: (context, reqSnap) {
            final requests = reqSnap.data ?? <ExcuseRequest>[];
            final reqMap = ExcuseAttendanceMerge.indexRequestsByLectureKey(requests);
            return StreamBuilder<Set<String>>(
              stream: _excuses.watchPendingExcuseAttendanceRecordIds(studentId),
              builder: (context, pendingSnap) {
                final pending = pendingSnap.data ?? <String>{};
                final candidates = records
                    .where((r) =>
                        r.status == ManualAttendanceStatus.absent ||
                        r.status == ManualAttendanceStatus.excused)
                    .map((r) {
                  final k = ExcuseAttendanceMerge.lectureKey(
                    r.lectureDate,
                    r.lectureStartTime,
                    r.sectionId,
                  );
                  final req = reqMap[k];
                  final merged = ExcuseAttendanceMerge.mergedStatus(
                    attendance: r,
                    request: req,
                    pendingAttendanceRecordIds: pending,
                  );
                  return (record: r, merged: merged, request: req);
                })
                    .where((e) => _activeAbsenceStatuses.contains(e.merged))
                    .toList()
                  ..sort((a, b) {
                    final byDate = b.record.lectureDate.compareTo(a.record.lectureDate);
                    if (byDate != 0) return byDate;
                    return b.record.lectureStartTime.compareTo(a.record.lectureStartTime);
                  });

                final shown = candidates.take(6).toList();
                if (shown.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'لا توجد غيابات نشطة حاليًا',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView(
                  scrollDirection: Axis.horizontal,
                  children: shown.map((e) {
                    final r = e.record;
                    final merged = e.merged;
                    final req = e.request;
                    final courseLabel =
                        ExcuseAttendanceMerge.mergedCourseNameArOverride(req) ??
                            (r.courseName.trim().isEmpty ? '—' : r.courseName.trim());
                    final dateText =
                        ExcuseAttendanceMerge.formatArabicLectureDate(r.lectureDate);
                    final timeRange =
                        '${r.lectureStartTime}-${r.lectureEndTime}';
                    final badge = _badgeForMergedExcuseStatus(merged);
                    final card = buildLectureCard(
                      courseLabel,
                      r.sectionLabel,
                      r.lectureEndTime.isNotEmpty ? r.lectureEndTime : '—',
                      statusText: badge.text,
                      statusColor: badge.color,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        onTap: () {
                          if (merged == 'معلقة') {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => SubmitExcuseScreen(
                                  course: courseLabel,
                                  dateText: dateText,
                                  timeRange: timeRange,
                                  sectionId: r.sectionId,
                                  lectureDate: r.lectureDate,
                                  sessionId: r.sessionId,
                                  attendanceRecordId: r.recordId,
                                ),
                              ),
                            );
                          } else if (merged == 'قيد الانتظار') {
                            final sid = studentId;
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => PendingDetailScreen(
                                  studentId: sid,
                                  attendanceRecordId: r.recordId,
                                  course: courseLabel,
                                  dateText: dateText,
                                  timeRange: timeRange,
                                ),
                              ),
                            );
                          } else if (merged == 'تم الرفض') {
                            final reason = req?.rejectionReason?.trim().isNotEmpty == true
                                ? req!.rejectionReason!.trim()
                                : 'السبب: العذر غير مقبول - يُشترط تقديم عذر صحي رسمي.';
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => RejectionDetailScreen(
                                  course: courseLabel,
                                  dateText: dateText,
                                  timeRange: timeRange,
                                  reason: reason,
                                  sectionId: r.sectionId,
                                  lectureDate: r.lectureDate,
                                  sessionId: r.sessionId,
                                  attendanceRecordId: r.recordId,
                                  attachmentUrl: req?.attachmentUrl,
                                  attachmentName: req?.attachmentName,
                                ),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: card,
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTodayLecturesSection(BuildContext context) {
    final studentId = StudentAuthService.instance.currentStudent?.studentId ?? 0;
    return SizedBox(
      height: 150,
      child: FutureBuilder<List<CourseSchedule>>(
        future: studentId <= 0
            ? Future.value(<CourseSchedule>[])
            : fetchTodayCoursesForStudent(studentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF006571)),
              ),
            );
          }
          final courses = snapshot.data ?? [];
          if (courses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: TText(
                  'لا توجد محاضرات اليوم',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
              ),
            );
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScheduleScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: buildLectureCard(
                    course.courseName,
                    course.section,
                    course.room,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget buildStudentCard(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentCardPage()),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // الكرت الأبيض
              Container(
                margin: const EdgeInsets.only(top: 32),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(28),
                    topLeft: Radius.circular(28),
                    bottomLeft: Radius.circular(0),
                    bottomRight: Radius.circular(0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                  const StudentProfileAvatar(
                    size: 48,
                    borderWidth: 0,
                  ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (() {
                              final s = StudentAuthService.instance.currentStudent;
                              if (s == null) return '-';
                              final isEn =
                                  TranslationController.instance.translateToEnglish;
                              final ar = (s.nameAr).trim();
                              final en = (s.name).trim();
                              final chosen = isEn
                                  ? (en.isNotEmpty ? en : ar)
                                  : (ar.isNotEmpty ? ar : en);
                              return chosen.isEmpty ? '-' : chosen;
                            })(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF111827),
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 4),
                          TText(
                            'رقم الطالب : ${StudentAuthService.instance.currentStudent?.studentId ?? '-'}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Image.asset(
                      'assets/images/NFC_logo.jpeg',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
              // المحفظة الإلكترونية
              Positioned(
                bottom: -12,
                left: 0,
                right: 0,
                child: Container(
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00666D),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                      bottomLeft: Radius.circular(0),
                      bottomRight: Radius.circular(0),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const TText(
                    'المحفظة الإلكترونية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8), // تقليل الفراغ أسفل البطاقة
      ],
    );
  }

  static Widget buildLectureCard(
    String title,
    String section,
    String room, {
    String? statusText,
    Color? statusColor,
  }) {
    final isEn = TranslationController.instance.translateToEnglish;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TText(
            title,
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _textStrong,
            ),
          ),
          const SizedBox(height: 8),
          TText(
            isEn ? 'Lecture' : 'نظري',
            textAlign: TextAlign.start,
            style: const TextStyle(color: _textMuted),
          ),
          TText(
            isEn ? 'Section $section' : 'الشعبة $section',
            textAlign: TextAlign.start,
            style: const TextStyle(color: _textMuted),
          ),
          TText(
            isEn ? 'Room $room' : 'القاعة $room',
            textAlign: TextAlign.start,
            style: const TextStyle(color: _textMuted),
          ),
          if (statusText != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: statusColor ?? Colors.grey[400],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: TText(
                  statusText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, 0);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
