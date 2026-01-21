import 'dart:ui';

import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'components/notification_bell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: إضافة منطق تسجيل الخروج هنا
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
                  onPressed: () => Navigator.pop(context),
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
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios,
                        color: Color(0xFF006571)),
                    onPressed: () => Navigator.pop(context),
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
                  const NotificationBell(),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: ValueListenableBuilder<bool>(
                  valueListenable: AppSettings.instance.blurProfileImage,
                  builder: (context, isBlurred, child) {
                    return Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFF006571),
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: isBlurred ? 8 : 0,
                                sigmaY: isBlurred ? 8 : 0,
                              ),
                              child: Image.asset(
                                'assets/images/avatar.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'نورة محمد - Noura Mohamed',
                  style: TextStyle(
                    color: Color(0xFF006571),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
