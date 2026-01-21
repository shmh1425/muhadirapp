import 'dart:ui';

import 'package:flutter/material.dart';
import 'student_card_page.dart';
import 'components/custom_nav_bar_icons.dart';
import 'components/notification_bell.dart';
import 'settings_screen.dart';
import 'services_screen.dart';
import 'app_settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 2; // Start with Home selected (index 2 for Home)

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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // Force RTL direction
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: NavBarSettingsArabic(
          selectedIndex: selectedIndex,
          onItemTapped: _onItemTapped,
        ),
        body: SafeArea(
          child: ListView(
            clipBehavior: Clip.none,
            padding:
                const EdgeInsets.only(top: 36, left: 30, right: 16, bottom: 16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'أهلاً نورة',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const NotificationBell(),
                ],
              ),
              const SizedBox(height: 30),

              // زر التحضير الآن بأبعاد ثابتة
              Center(
                child: Container(
                  width: 296, // عرض ثابت
                  height: 73, // ارتفاع ثابت
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
                      // الحدث عند الضغط
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(45),
                      ),
                    ),
                    child: const Text(
                      'التحضير الآن',
                      style: TextStyle(
                        fontSize: 23,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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
                  const Text(
                    'محاضرات اليوم:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  TextButton(
                    onPressed: () {
                      // action on press
                    },
                    style: ButtonStyle(
                      foregroundColor:
                          MaterialStateProperty.resolveWith<Color>((states) {
                        if (states.contains(MaterialState.pressed)) {
                          return const Color(0xFF006571); // اللون عند الضغط
                        }
                        return const Color(0xFF006571); // اللون العادي
                      }),
                      overlayColor: MaterialStateProperty.all(
                        const Color(0x22006571),
                      ),
                    ),
                    child: const Text(
                      ' الجدول الأسبوعي >',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 150,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    buildLectureCard('هندسة البيانات', '1', '108'),
                    buildLectureCard('بحوث عمليات', '1', '102 ط'),
                    buildLectureCard('مشروع جماعي 1', '2', 'عن بعد'),
                    buildLectureCard('جودة البرمجيات', '1', '103'),
                  ].map((card) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: card,
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الغيابات النشطة:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  TextButton(
                    onPressed: () {
                      // action on press
                    },
                    style: ButtonStyle(
                      foregroundColor:
                          MaterialStateProperty.resolveWith<Color>((states) {
                        if (states.contains(MaterialState.pressed)) {
                          return const Color(0xFF006571); // اللون عند الضغط
                        }
                        return const Color(0xFF006571); // اللون العادي
                      }),
                      overlayColor: MaterialStateProperty.all(
                        const Color(0x22006571),
                      ),
                    ),
                    child: const Text(
                      ' عرض الغيابات >',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 5),

              SizedBox(
                height: 180,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    buildLectureCard(
                      'جودة البرمجيات',
                      '1',
                      '103',
                      statusText: 'إرفاق عذر',
                      statusColor: Colors.grey,
                    ),
                    buildLectureCard(
                      'بحوث عمليات',
                      '1',
                      '102 ط',
                      statusText: 'قيد المعالجة',
                      statusColor: Colors.amber,
                    ),
                  ].map((card) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: card,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
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
                  ValueListenableBuilder<bool>(
                    valueListenable: AppSettings.instance.blurProfileImage,
                    builder: (context, isBlurred, child) {
                      return CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.transparent,
                        child: ClipOval(
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: isBlurred ? 6 : 0,
                              sigmaY: isBlurred ? 6 : 0,
                            ),
                            child: Image.asset(
                              'assets/images/avatar.png',
                              fit: BoxFit.cover,
                              width: 48,
                              height: 48,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Noura Mohamed Al-Harthi',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'نورة محمد الحارثي',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'رقم الطالبة : 440020446',
                            style:
                                TextStyle(fontSize: 13, color: Colors.black54),
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
                  child: const Text(
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
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text('نظري', textAlign: TextAlign.right),
          Text('الشعبة $section', textAlign: TextAlign.right),
          Text('القاعة $room', textAlign: TextAlign.right),
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
                child: Text(
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
