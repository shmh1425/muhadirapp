import 'package:flutter/material.dart';
import 'components/notification_bell.dart';
import 'notifications_screen.dart';
import 'nfc_attendance_screen.dart';
import 'components/custom_nav_bar_icons.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'excuse_screen.dart';
import 'attendance_tracking_screen.dart';
import 'schedule_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF006571);
    const borderColor = Color(0xFFD9D9D9);

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
            } else if (index == 1) {
              // Stay on services screen
            } else if (index == 2) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            }
          },
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios,
                        color: primaryColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'خدمات الطالب',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const Spacer(),
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
              const SizedBox(height: 36),
              Wrap(
                spacing: 14,
                runSpacing: 18,
                alignment: WrapAlignment.end,
                children: [
                  _ServiceCard(
                    title: 'تتبع الحضور',
                    icon: Icons.access_time,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AttendanceTrackingScreen(),
                        ),
                      );
                    },
                  ),
                  _ServiceCard(
                    title: 'الجدول الدراسي',
                    icon: Icons.calendar_today,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ScheduleScreen(),
                        ),
                      );
                    },
                  ),
                  _ServiceCard(
                    title: 'التحضير',
                    icon: Icons.wifi_tethering,
                    backgroundImage: 'assets/images/NFC_logo.jpeg',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NfcAttendanceScreen(),
                        ),
                      );
                    },
                  ),
                  _ServiceCard(
                    title: 'إدارة الأعذار',
                    icon: Icons.insert_chart_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ExcuseScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Builder(
                builder: (context) {
                  final cardWidth =
                      (MediaQuery.of(context).size.width - 24 * 2 - 14) / 2;
                  return Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: cardWidth,
                      child: _ServiceCard(
                        title: 'التنبيهات',
                        icon: Icons.notifications,
                        width: cardWidth,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.title,
    required this.icon,
    this.width,
    this.isWide = false,
    this.onTap,
    this.backgroundImage,
  });

  final String title;
  final IconData icon;
  final double? width;
  final bool isWide;
  final VoidCallback? onTap;
  final String? backgroundImage;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF006571);
    const cardColor = Color(0xFFF8F7F7);
    const borderGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.25, 0.95],
      colors: [Color(0xFF27A2A9), Color(0xFF006571)],
    );
    const iconGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.25, 0.95],
      colors: [Color(0xFF27A2A9), Color(0xFF006571)],
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = width ??
        (isWide ? screenWidth - 24 * 2 : (screenWidth - 24 * 2 - 14) / 2);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth,
        height: 156,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: borderGradient,
              ),
              padding: const EdgeInsets.all(1.2),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    if (backgroundImage != null)
                      Positioned(
                        left: 16,
                        bottom: 12,
                        child: Opacity(
                          opacity: 0.35,
                          child: Image.asset(
                            backgroundImage!,
                            width: 34,
                            height: 34,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF27A2A9), width: 1.2),
                  color: cardColor,
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return iconGradient.createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    );
                  },
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
