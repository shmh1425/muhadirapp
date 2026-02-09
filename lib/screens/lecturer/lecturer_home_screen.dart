import 'package:flutter/material.dart';
import 'lecturer_nav_bar.dart';
import '../student/components/notification_bell.dart';
import '../student/notifications_screen.dart';
import 'lecturer_qr_screen.dart';
import 'lecturer_profile_screen.dart';

class LecturerHomeScreen extends StatefulWidget {
  const LecturerHomeScreen({super.key});

  @override
  State<LecturerHomeScreen> createState() => _LecturerHomeScreenState();
}

class _LecturerHomeScreenState extends State<LecturerHomeScreen> {
  int selectedIndex = 2; // Home selected by default
  String _selectedFilter = 'اليوم'; // اليوم، غدًا، الكل

  // Mock data for lectures
  final List<LectureItem> _lectures = [
    LectureItem(
      courseName: 'هندسة البرمجيات',
      crn: 'SE3310',
      hall: 'DEN01',
      section: '1',
      activity: 'نظري',
      startTime: '8:00',
      isDouble: true, // محاضرة زوجية: 8:00-8:50 و 9:00-9:50
    ),
    LectureItem(
      courseName: 'قواعد البيانات',
      crn: 'CS3320',
      hall: 'DEN02',
      section: '2',
      activity: 'نظري',
      startTime: '10:00',
      isDouble: true, // محاضرة زوجية: 10:00-10:50 و 11:00-11:50
    ),
    LectureItem(
      courseName: 'الذكاء الاصطناعي',
      crn: 'CS3330',
      hall: 'DEN03',
      section: '1',
      activity: 'نظري',
      startTime: '12:00',
      isDouble: false, // محاضرة فردية: 12:00-12:50
    ),
    LectureItem(
      courseName: 'أمن المعلومات',
      crn: 'CS3340',
      hall: 'DEN04',
      section: '3',
      activity: 'نظري',
      startTime: '2:00',
      isDouble: true, // محاضرة زوجية: 2:00-2:50 و 3:00-3:50
    ),
    LectureItem(
      courseName: 'الشبكات الحاسوبية',
      crn: 'CS3350',
      hall: 'DEN05',
      section: '2',
      activity: 'نظري',
      startTime: '4:00',
      isDouble: false, // محاضرة فردية: 4:00-4:50
    ),
    LectureItem(
      courseName: 'تطوير التطبيقات',
      crn: 'SE3360',
      hall: 'DEN06',
      section: '1',
      activity: 'نظري',
      startTime: '6:00',
      isDouble: true, // محاضرة زوجية: 6:00-6:50 و 7:00-7:50
    ),
    LectureItem(
      courseName: 'الخوارزميات المتقدمة',
      crn: 'CS3370',
      hall: 'DEN07',
      section: '2',
      activity: 'نظري',
      startTime: '8:00',
      isDouble: false, // محاضرة فردية: 8:00-8:50
    ),
    LectureItem(
      courseName: 'أنظمة التشغيل',
      crn: 'CS3380',
      hall: 'DEN08',
      section: '3',
      activity: 'نظري',
      startTime: '10:00',
      isDouble: true, // محاضرة زوجية: 10:00-10:50 و 11:00-11:50
    ),
    LectureItem(
      courseName: 'البرمجة المتقدمة',
      crn: 'CS3390',
      hall: 'DEN09',
      section: '1',
      activity: 'نظري',
      startTime: '12:00',
      isDouble: false, // محاضرة فردية: 12:00-12:50
    ),
    LectureItem(
      courseName: 'مشروع التخرج',
      crn: 'CS3400',
      hall: 'DEN10',
      section: '1',
      activity: 'عملي',
      startTime: '2:00',
      isDouble: true, // محاضرة زوجية: 2:00-2:50 و 3:00-3:50
    ),
  ];

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

  // Cache greeting to avoid recalculation on every build
  String? _cachedGreeting;
  int? _lastHourChecked;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    // Only recalculate if hour changed
    if (_lastHourChecked != hour) {
      _lastHourChecked = hour;
      if (hour < 12) {
        _cachedGreeting = 'صباح الخير';
      } else {
        _cachedGreeting = 'مساء الخير';
      }
    }
    return _cachedGreeting ?? 'مرحباً';
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006571),
                            fontFamily: 'Cairo',
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Date information integrated with greeting
                        _buildDateSection(),
                      ],
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

              // Filter buttons
              _buildFilterButtons(),
              const SizedBox(height: 16),

              // Manage Lectures button
              _buildManageLecturesButton(),
              const SizedBox(height: 28),

              // Section title
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'محاضرات اليوم',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                    fontFamily: 'Cairo',
                  ),
                ),
              ),

              // Timeline with lectures
              _buildTimeline(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    // Mock Hijri date - يمكن استبدالها بـ package للتاريخ الهجري لاحقاً
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'الأحد',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF006571),
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF006571),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '٢٥',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF006571),
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF006571),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'ربيع الأول',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF006571),
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterButtons() {
    final filters = ['اليوم', 'غدًا', 'الكل'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF666666),
                      fontFamily: 'Cairo',
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

  Widget _buildManageLecturesButton() {
    return InkWell(
      onTap: () {
        // Placeholder - يمكن ربطه بشاشة إدارة المحاضرات لاحقاً
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شاشة إدارة المحاضرات - قيد التطوير'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF27A2A9), Color(0xFF006571)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF006571).withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.settings,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'ادارة المحاضرات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لتحويل String إلى (hour, minute)
  (int, int) _parseTimeString(String time) {
    final parts = time.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  Widget _buildTimeline() {
    if (_lectures.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'لا توجد محاضرات',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF999999),
              fontFamily: 'Cairo',
            ),
          ),
        ),
      );
    }

    // ترتيب المحاضرات حسب وقت البداية (من الأقدم للأحدث - الصبح فوق)
    final sortedLectures = List<LectureItem>.from(_lectures);
    sortedLectures.sort((a, b) {
      final aTime = _parseTimeString(a.startTime);
      final bTime = _parseTimeString(b.startTime);
      final aMinutes = aTime.$1 * 60 + aTime.$2;
      final bMinutes = bTime.$1 * 60 + bTime.$2;
      return aMinutes.compareTo(bMinutes);
    });

    // عرض المحاضرات مع أوقاتها مرتبطة بكل كارد
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedLectures.asMap().entries.map((entry) {
        final index = entry.key;
        final lecture = entry.value;
        final isLast = index == sortedLectures.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
          child: _buildLectureCardWithTime(lecture),
        );
      }).toList(),
    );
  }

  Widget _buildLectureCardWithTime(LectureItem lecture) {
    final timeSlots = lecture.timeSlots;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عرض الأوقات فوق الكارد مباشرة
        Padding(
          padding: const EdgeInsets.only(bottom: 10, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: timeSlots.map((timeRange) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF006571),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF006571).withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeRange,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF006571),
                        fontFamily: 'Cairo',
                      ),
                      textDirection: TextDirection.ltr, // ضمان عرض الوقت من اليسار لليمين
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        // الكارد
        _buildLectureCard(lecture),
      ],
    );
  }


  Widget _buildLectureCard(LectureItem lecture) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE8E8E8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course name
          Text(
            lecture.courseName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
              fontFamily: 'Cairo',
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          // Details row
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  Icons.location_on_outlined,
                  'القاعة ${lecture.hall}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailItem(
                  Icons.group_outlined,
                  'الشعبة ${lecture.section}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // CRN and activity
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  lecture.crn,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF006571),
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  lecture.activity,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF006571),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              fontFamily: 'Cairo',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class LectureItem {
  final String courseName;
  final String crn;
  final String hall;
  final String section;
  final String activity;
  final String startTime;
  final bool isDouble; // true = محاضرة زوجية (حصتان), false = محاضرة فردية (حصة واحدة)

  LectureItem({
    required this.courseName,
    required this.crn,
    required this.hall,
    required this.section,
    required this.activity,
    required this.startTime,
    this.isDouble = false, // افتراضياً محاضرة فردية
  });

  // حساب الوقت النهائي للمحاضرة
  String get endTime {
    if (isDouble) {
      // محاضرة زوجية: من startTime إلى startTime+50 ثم من startTime+60 إلى startTime+110
      final start = _parseTime(startTime);
      final secondEnd = _addMinutes(start, 110);
      return _formatTime(secondEnd);
    } else {
      // محاضرة فردية: من startTime إلى startTime+50
      final start = _parseTime(startTime);
      final end = _addMinutes(start, 50);
      return _formatTime(end);
    }
  }

  // الحصول على جميع الحصص للمحاضرة (بداية - نهاية)
  List<String> get timeSlots {
    final start = _parseTime(startTime);
    if (isDouble) {
      // محاضرة زوجية: حصتان
      // الحصة الأولى: من startTime إلى startTime+50
      final firstStart = start;
      final firstEnd = _addMinutes(start, 50);
      // الحصة الثانية: من startTime+60 إلى startTime+110
      final secondStart = _addMinutes(start, 60);
      final secondEnd = _addMinutes(start, 110);
      return [
        '${_formatTime(firstStart)} - ${_formatTime(firstEnd)}',
        '${_formatTime(secondStart)} - ${_formatTime(secondEnd)}',
      ];
    } else {
      // محاضرة فردية: حصة واحدة
      // من startTime إلى startTime+50
      final end = _addMinutes(start, 50);
      return ['${_formatTime(start)} - ${_formatTime(end)}'];
    }
  }
  
  // الحصول على وقت بداية حصة معينة
  String getSlotStartTime(int slotIndex) {
    final start = _parseTime(startTime);
    if (isDouble) {
      if (slotIndex == 0) {
        return _formatTime(start);
      } else {
        return _formatTime(_addMinutes(start, 60));
      }
    } else {
      return _formatTime(start);
    }
  }

  // تحويل الوقت من String إلى (hour, minute)
  (int, int) _parseTime(String time) {
    final parts = time.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  // إضافة دقائق للوقت
  (int, int) _addMinutes((int, int) time, int minutes) {
    final (hour, minute) = time;
    final totalMinutes = hour * 60 + minute + minutes;
    final newHour = (totalMinutes ~/ 60) % 24;
    final newMinute = totalMinutes % 60;
    return (newHour, newMinute);
  }

  // تحويل الوقت من (hour, minute) إلى String
  String _formatTime((int, int) time) {
    final (hour, minute) = time;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

// Class لتمثيل حصة زمنية في Timeline
class TimeSlot {
  final LectureItem lecture;
  final int slotIndex;
  final String timeRange;
  final String startTime; // وقت بداية الحصة للترتيب

  TimeSlot({
    required this.lecture,
    required this.slotIndex,
    required this.timeRange,
    required this.startTime,
  });
}

