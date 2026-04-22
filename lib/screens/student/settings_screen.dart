import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_settings.dart';
import 'components/notification_bell.dart';
import 'notifications_screen.dart';
import 'components/custom_nav_bar_icons.dart';
import '../../services/student_auth_service.dart';
import '../../shared/widgets/student_profile_avatar.dart';
import '../../shared/widgets/chat_fab.dart';
import 'home_screen.dart';
import 'services_screen.dart';
import '../login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _onItemTapped(BuildContext context, int index) {
    if (index == 0) {
      // Stay on settings
      return;
    }
    if (index == 1) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ServicesScreen()),
        (route) => false,
      );
      return;
    }
    if (index == 2) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      return;
    }
  }

  Widget _buildStudentDataSection() {
    final student = StudentAuthService.instance.currentStudent;
    if (student == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          student.name.isNotEmpty ? student.name : '-',
          style: const TextStyle(
            color: Color(0xFF444444),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          student.major,
          style: const TextStyle(
            color: Color(0xFF444444),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout, color: Color(0xFFB71C1C)),
              ),
              const SizedBox(height: 12),
              const Text(
                'هل أنت متأكد أنك تريد تسجيل الخروج؟',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).maybePop();
                    await FirebaseAuth.instance.signOut();
                    StudentAuthService.instance.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'تسجيل الخروج',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFB71C1C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: Color(0xFFB71C1C)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: const ChatFAB(),
        bottomNavigationBar: NavBarSettingsArabic(
          selectedIndex: 0,
          onItemTapped: (i) => _onItemTapped(context, i),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios,
                        color: Color(0xFF006571)),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'الإعدادات',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006571),
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
              const SizedBox(height: 12),
              Center(
                child: const StudentProfileAvatar(size: 120),
              ),
              const SizedBox(height: 12),
              Center(
                child: Builder(
                  builder: (context) {
                    final s = StudentAuthService.instance.currentStudent;
                    final nameAr = s?.nameAr ?? '';
                    final nameDisplay = nameAr.isNotEmpty ? nameAr : (s?.name ?? 'لم يتم تحميل البيانات');
                    return Text(
                      nameDisplay,
                      style: const TextStyle(
                        color: Color(0xFF006571),
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Center(child: _buildStudentDataSection()),
              const SizedBox(height: 24),
              _SettingsTile(
                child: Row(
                  children: const [
                    Icon(Icons.language, color: Color(0xFF006571)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'عربي | English',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Color(0xFF006571)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<bool>(
                valueListenable: AppSettings.instance.blurProfileImage,
                builder: (context, isBlurred, child) {
                  return _SettingsTile(
                    child: Row(
                      children: [
                        const Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'تغبيش الصورة',
                              textAlign: TextAlign.right,
                              style: TextStyle(color: Color(0xFF006571)),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: isBlurred,
                          onChanged: (value) {
                            AppSettings.instance.blurProfileImage.value = value;
                          },
                          activeColor: const Color(0xFF006571),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                child: Row(
                  children: [
                    const Icon(Icons.star_border, color: Color(0xFF006571)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'قيم تجربتك',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Color(0xFF006571)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const _StarRatingRow(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showLogoutDialog(context),
                child: _SettingsTile(
                  child: Row(
                    children: const [
                      Icon(Icons.logout, color: Color(0xFFD32F2F)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'تسجيل خروج',
                            textAlign: TextAlign.right,
                            style: TextStyle(color: Color(0xFFD32F2F)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF006571),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: const TextStyle(color: Color(0xFF444444)),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StarRatingRow extends StatelessWidget {
  const _StarRatingRow();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppSettings.instance.rating,
      builder: (context, rating, child) {
        return Row(
          children: List.generate(5, (index) {
            final isSelected = index < rating;
            return GestureDetector(
              onTap: () {
                AppSettings.instance.rating.value = index + 1;
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.star,
                  size: 16,
                  color: isSelected ? const Color(0xFFFFC107) : const Color(0xFFB0B0B0),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
