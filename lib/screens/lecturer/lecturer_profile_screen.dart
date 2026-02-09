import 'dart:ui';

import 'package:flutter/material.dart';

import 'lecturer_nav_bar.dart';

class LecturerProfile {
  final String name;
  final String email;
  final String college;
  final String department;

  const LecturerProfile({
    required this.name,
    required this.email,
    required this.college,
    required this.department,
  });
}

class LecturerProfileScreen extends StatefulWidget {
  const LecturerProfileScreen({
    super.key,
    required this.lecturer,
  });

  final LecturerProfile lecturer;

  @override
  State<LecturerProfileScreen> createState() => _LecturerProfileScreenState();
}

class _LecturerProfileScreenState extends State<LecturerProfileScreen> {
  int _selectedIndex = 0; // البروفايل هو التاب الأول
  bool _isBlurred = false;

  static const Color _primaryColor = Color(0xFF006571);

  Future<void> _onItemTapped(int index) async {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // نحن بالفعل في شاشة البروفايل
        break;
      case 1:
        Navigator.of(context).pop(); // يرجع للشاشة التي تحتوي QR أو الهوم
        break;
      case 2:
        Navigator.of(context).pop();
        break;
    }
  }

  void _toggleBlur() {
    setState(() {
      _isBlurred = !_isBlurred;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: LecturerNavBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // الهيدر مع الكرت العلوي
              _buildHeaderCard(context),
              const SizedBox(height: 18),
              // الأزرار الرئيسية
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      _ProfileActionButton(
                        icon: Icons.calendar_today_outlined,
                        label: 'محاضراتي',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('شاشة محاضراتي - لاحقاً'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _ProfileActionButton(
                        icon: Icons.insert_chart_outlined_rounded,
                        label: 'تقرير الحضور',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تقرير الحضور - لاحقاً'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _ProfileActionButton(
                        icon: Icons.settings_outlined,
                        label: 'ادارة المحاضرات',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ادارة المحاضرات - لاحقاً'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _ProfileActionButton(
                        icon: Icons.notifications_none_rounded,
                        label: 'التنبيهات',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('التنبيهات - لاحقاً'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _ProfileActionButton(
                        icon: Icons.language,
                        label: 'English | عربي',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تغيير اللغة - لاحقاً'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _ProfileActionButton(
                        icon: Icons.logout,
                        label: 'تسجيل خروج',
                        labelColor: const Color(0xFFD32F2F),
                        iconColor: const Color(0xFFD32F2F),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تسجيل خروج - لاحقاً'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
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

  Widget _buildHeaderCard(BuildContext context) {
    final lecturer = widget.lecturer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [Color(0xFF27A2A9), Color(0xFF006571)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // الأنماط الهندسية البسيطة في الخلفية
            Positioned(
              top: -40,
              left: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(36),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              right: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
            ),
            // محتوى الكرت
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          lecturer.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Cairo',
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lecturer.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          lecturer.college,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.95),
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lecturer.department,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildAvatarWithBlurToggle(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWithBlurToggle() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 3,
              ),
              shape: BoxShape.circle,
            ),
            child: _isBlurred
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: _buildAvatarContent(),
                  )
                : _buildAvatarContent(),
          ),
        ),
        Positioned(
          bottom: -4,
          left: -4,
          child: GestureDetector(
            onTap: _toggleBlur,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _isBlurred ? Icons.visibility_off_rounded : Icons.visibility,
                size: 16,
                color: _primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarContent() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Icon(
          Icons.person,
          size: 40,
          color: _primaryColor,
        ),
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor = const Color(0xFF00474F),
    this.iconColor = const Color(0xFF006571),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color labelColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: iconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            const Icon(
              Icons.chevron_left,
              color: Color(0xFF9E9E9E),
            ),
          ],
        ),
      ),
    );
  }
}

