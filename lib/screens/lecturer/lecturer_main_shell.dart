import 'package:flutter/material.dart';

import 'lecturer_nav_bar.dart';
import 'lecturer_home_screen.dart';
import 'lecturer_qr_screen.dart';
import 'lecturer_profile_screen.dart';

/// Shell واحد للتنقل: يحتوي على الـ Bottom Nav وثلاثة تبويبات (Profile, QR, Home).
/// التنقل بين التبويبات بتغيير الـ index فقط — لا push للتبويبات.
/// الصفحات الفرعية (مثل التحضير، التقارير) تُفتح داخل نفس التبويب عبر الـ Navigator المخصص لكل تبويب.
class LecturerMainShell extends StatefulWidget {
  const LecturerMainShell({super.key, this.initialIndex = 2, this.profile});

  /// 0 = Profile, 1 = QR, 2 = Home. افتراضي 2 (Home).
  final int initialIndex;
  final LecturerProfile? profile;

  @override
  State<LecturerMainShell> createState() => _LecturerMainShellState();
}

class _LecturerMainShellState extends State<LecturerMainShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 2);
  }

  Widget _buildTabNavigator(int index, Widget screen) {
    return Navigator(
      key: ValueKey<int>(index),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/' || settings.name == null) {
          return MaterialPageRoute<void>(builder: (_) => screen);
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile =
        widget.profile ??
        const LecturerProfile(
          name: 'محاضر',
          email: 'lecturer@uqu.edu.sa',
          college: 'كلية الحاسبات',
          department: 'غير محدد',
        );

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildTabNavigator(0, LecturerProfileScreen(lecturer: profile)),
          _buildTabNavigator(1, const LecturerQrScreen(lecture: null)),
          _buildTabNavigator(2, LecturerHomeScreen(lecturerName: profile.name)),
        ],
      ),
      bottomNavigationBar: LecturerNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          if (index == _selectedIndex) return;
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}
