import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/lecturer/lecturer_cold_start_warmup.dart';
import 'lecturer_nav_bar.dart';
import 'lecturer_home_screen.dart';
import 'lecturer_language.dart';
import 'lecturer_qr_screen.dart';
import '../../services/lecturer_auth_service.dart';
import 'lecturer_profile_screen.dart';

/// Shell واحد للتنقل: يحتوي على الـ Bottom Nav وثلاثة تبويبات (Profile, QR, Home).
/// التنقل بين التبويبات بتغيير الـ index فقط — لا push للتبويبات.
/// الصفحات الفرعية (مثل التحضير، التقارير) تُفتح داخل نفس التبويب عبر الـ Navigator المخصص لكل تبويب.
class LecturerMainShell extends ConsumerStatefulWidget {
  const LecturerMainShell({super.key, this.initialIndex = 2, this.profile});

  /// 0 = Profile, 1 = QR, 2 = Home. افتراضي 2 (Home).
  final int initialIndex;
  final LecturerProfile? profile;

  @override
  ConsumerState<LecturerMainShell> createState() => _LecturerMainShellState();
}

class _LecturerMainShellState extends ConsumerState<LecturerMainShell> {
  late int _selectedIndex;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 2);
    _navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
      3,
      (_) => GlobalKey<NavigatorState>(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        LecturerColdStartWarmup.run(
          ProviderScope.containerOf(context, listen: false),
        ),
      );
    });
  }

  Widget _buildTabNavigator(int index, Widget screen) {
    return Navigator(
      key: _navigatorKeys[index],
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/' || settings.name == null) {
          return MaterialPageRoute<void>(builder: (_) => screen);
        }
        return null;
      },
    );
  }

  void _handleBlockedRootPop() {
    final currentNavigator = _navigatorKeys[_selectedIndex].currentState;
    if (currentNavigator?.canPop() == true) {
      currentNavigator!.pop();
      return;
    }

    if (_selectedIndex != 2) {
      setState(() => _selectedIndex = 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) {
        final profile =
            widget.profile ??
            LecturerProfile(
              nameAr: LecturerLanguageController.tr('محاضر', 'Lecturer'),
              nameEn: LecturerLanguageController.tr('محاضر', 'Lecturer'),
              email: 'lecturer@uqu.edu.sa',
              college: LecturerLanguageController.tr(
                'كلية الحاسبات',
                'College of Computing',
              ),
              department: LecturerLanguageController.tr('غير محدد', 'Unknown'),
            );
        final lecturerDisplayName =
            LecturerAuthService.instance.currentLecturer?.displayNameFor(
              LecturerLanguageController.isArabic,
            ) ??
            profile.displayName();

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBlockedRootPop();
          },
          child: Directionality(
            textDirection: LecturerLanguageController.direction(),
            child: Scaffold(
              backgroundColor: Colors.white,
              body: IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildTabNavigator(
                    0,
                    LecturerProfileScreen(lecturer: profile),
                  ),
                  _buildTabNavigator(1, const LecturerQrScreen(lecture: null)),
                  _buildTabNavigator(
                    2,
                    LecturerHomeScreen(lecturerName: lecturerDisplayName),
                  ),
                ],
              ),
              bottomNavigationBar: LecturerNavBar(
                selectedIndex: _selectedIndex,
                onItemTapped: (index) {
                  if (index == _selectedIndex) {
                    final navigator = _navigatorKeys[index].currentState;
                    navigator?.popUntil((route) => route.isFirst);
                    return;
                  }
                  setState(() => _selectedIndex = index);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
