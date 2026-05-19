import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../login_screen.dart';
import 'lecturer_attendance_report_screen.dart'
    show LecturerAttendanceReportScreen, clearLecturerAttendanceReportNavCache;
import 'lecturer_language.dart';
import 'lecturer_my_lectures_screen.dart';
import 'lecturer_navigation.dart';
import 'lecturer_notifications_screen.dart';
import '../../services/lecturer_auth_service.dart';
import '../../models/external_lecturer_model.dart';
import '../../services/lecturer/lecturer_attendance_sessions_warm_cache.dart';
import 'lecturer_screen_session_memory.dart';
import 'widgets/modern_popup_dialog.dart';

class LecturerProfile {
  final String nameAr;
  final String nameEn;
  final String email;
  final String college;
  final String collegeAr;
  final String collegeEn;
  final String department;
  final String departmentAr;
  final String departmentEn;

  const LecturerProfile({
    required this.nameAr,
    required this.nameEn,
    required this.email,
    required this.college,
    this.collegeAr = '',
    this.collegeEn = '',
    required this.department,
    this.departmentAr = '',
    this.departmentEn = '',
  });

  /// Backward-compatible single name (Arabic preferred).
  String get name => nameAr.trim().isNotEmpty ? nameAr : nameEn;

  String displayName({bool? isArabic}) {
    final arabic = isArabic ?? LecturerLanguageController.isArabic;
    if (arabic) {
      return nameAr.trim().isNotEmpty
          ? nameAr
          : (nameEn.trim().isNotEmpty ? nameEn : name);
    }
    return nameEn.trim().isNotEmpty
        ? nameEn
        : (nameAr.trim().isNotEmpty ? nameAr : name);
  }

  Map<String, dynamic> get _localizationMap => {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'college': college,
        'collegeAr': collegeAr,
        'collegeEn': collegeEn,
        'department': department,
        'departmentAr': departmentAr,
        'departmentEn': departmentEn,
      };

  String displayCollege({bool? isArabic}) {
    return LecturerLanguageController.localizedCollege(
      _localizationMap,
      language: isArabic == null
          ? null
          : (isArabic ? LecturerLanguage.arabic : LecturerLanguage.english),
      fallback: college.trim(),
    );
  }

  String displayDepartment({bool? isArabic}) {
    return LecturerLanguageController.localizedDepartment(
      _localizationMap,
      language: isArabic == null
          ? null
          : (isArabic ? LecturerLanguage.arabic : LecturerLanguage.english),
      fallback: department.trim(),
    );
  }

  factory LecturerProfile.fromLecturer(
    ExternalLecturerModel lecturer, {
    String fallbackName = '',
  }) {
    final fb = fallbackName.trim();
    final ar = lecturer.nameAr.trim();
    final en = lecturer.nameEn.trim();
    return LecturerProfile(
      nameAr: ar.isNotEmpty ? ar : fb,
      nameEn: en.isNotEmpty ? en : fb,
      email: lecturer.email,
      college: lecturer.college,
      collegeAr: lecturer.collegeAr,
      collegeEn: lecturer.collegeEn,
      department: lecturer.department,
      departmentAr: lecturer.departmentAr,
      departmentEn: lecturer.departmentEn,
    );
  }
}

class LecturerProfileScreen extends StatefulWidget {
  const LecturerProfileScreen({super.key, required this.lecturer});

  final LecturerProfile lecturer;

  @override
  State<LecturerProfileScreen> createState() => _LecturerProfileScreenState();
}

class _LecturerProfileScreenState extends State<LecturerProfileScreen> {
  bool _isBlurred = false;

  static const Color _primaryColor = Color(0xFF006571);

  bool get _isArabic => LecturerLanguageController.isArabic;

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  String _resolveLecturerDisplayName(LecturerProfile profile) {
    final fromAuth =
        LecturerAuthService.instance.currentLecturer?.displayNameFor(_isArabic);
    if (fromAuth != null && fromAuth.trim().isNotEmpty) {
      return fromAuth;
    }
    return profile.displayName(isArabic: _isArabic);
  }

  String _resolveCollege(LecturerProfile profile) {
    final fromAuth =
        LecturerAuthService.instance.currentLecturer?.displayCollegeFor(_isArabic);
    if (fromAuth != null && fromAuth.trim().isNotEmpty) {
      return fromAuth.trim();
    }
    final fromProfile = profile.displayCollege(isArabic: _isArabic).trim();
    if (fromProfile.isNotEmpty) return fromProfile;
    return _tr('غير محدد', 'Not specified');
  }

  String _resolveDepartment(LecturerProfile profile) {
    final fromAuth =
        LecturerAuthService.instance.currentLecturer?.displayDepartmentFor(
          _isArabic,
        );
    if (fromAuth != null && fromAuth.trim().isNotEmpty) {
      return fromAuth.trim();
    }
    final fromProfile = profile.displayDepartment(isArabic: _isArabic).trim();
    if (fromProfile.isNotEmpty) return fromProfile;
    return _tr('غير محدد', 'Not specified');
  }

  String _resolveLecturerPhotoUrl(Map<String, dynamic>? data) {
    final photoUrl = (data?['photoUrl'] ?? '').toString().trim();
    final rawUrl = photoUrl.isNotEmpty
        ? photoUrl
        : (LecturerAuthService.instance.currentLecturer?.photoUrl ?? '');
    if (rawUrl.isEmpty) return '';
    final version = (data?['photoVersion'] ?? '').toString().trim();
    if (version.isEmpty) return rawUrl;
    final separator = rawUrl.contains('?') ? '&' : '?';
    return '$rawUrl${separator}v=$version';
  }

  void _toggleBlur() {
    setState(() {
      _isBlurred = !_isBlurred;
    });
  }

  Future<void> _showLanguagePicker() async {
    final selected = await showDialog<LecturerLanguage>(
      context: context,
      builder: (ctx) {
        var draftLanguage = LecturerLanguageController.current;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: LecturerLanguageController.direction(
                draftLanguage,
              ),
              child: ModernPopupDialog(
                title: Text(
                  _tr('تغيير اللغة', 'Change Language'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                  ),
                ),
                accentColor: _primaryColor,
                actions: [
                  ModernPopupActionButton(
                    label: LecturerLanguageController.tr(
                      'إلغاء',
                      'Cancel',
                      language: draftLanguage,
                    ),
                    onTap: () => Navigator.of(ctx).pop(),
                    isPrimary: false,
                  ),
                  ModernPopupActionButton(
                    label: LecturerLanguageController.tr(
                      'تأكيد',
                      'Apply',
                      language: draftLanguage,
                    ),
                    onTap: () => Navigator.of(ctx).pop(draftLanguage),
                    isPrimary: true,
                  ),
                ],
                child: Column(
                  children: [
                    _LanguageOptionTile(
                      label: _tr('العربية', 'Arabic'),
                      selected: draftLanguage == LecturerLanguage.arabic,
                      onTap: () => setDialogState(
                        () => draftLanguage = LecturerLanguage.arabic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LanguageOptionTile(
                      label: _tr('English', 'English'),
                      selected: draftLanguage == LecturerLanguage.english,
                      onTap: () => setDialogState(
                        () => draftLanguage = LecturerLanguage.english,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null || selected == LecturerLanguageController.current) {
      return;
    }
    LecturerLanguageController.notifier.value = selected;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr('تم تغيير اللغة بنجاح', 'Language changed successfully'),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: ModernPopupDialog(
            title: Text(
              _tr('تأكيد تسجيل الخروج', 'Confirm Logout'),
              textAlign: TextAlign.center,
            ),
            accentColor: const Color(0xFFD32F2F),
            actions: [
              ModernPopupActionButton(
                label: _tr('إلغاء', 'Cancel'),
                onTap: () => Navigator.of(dialogContext).pop(false),
                isPrimary: false,
              ),
              ModernPopupActionButton(
                label: _tr('تسجيل الخروج', 'Logout'),
                onTap: () => Navigator.of(dialogContext).pop(true),
                isPrimary: true,
                primaryColor: const Color(0xFFD32F2F),
              ),
            ],
            child: Text(
              _tr(
                'هل أنت متأكد أنك تريد تسجيل الخروج؟',
                'Are you sure you want to log out?',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    LecturerAuthService.instance.logout();
    clearLecturerAttendanceReportNavCache();
    LecturerManageScreenSessionMemory.clear();
    LecturerAttendanceSessionsWarmCache.clear();

    // Clear the root stack so auth screens only appear after an explicit logout.
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeaderCard(context),
                  const SizedBox(height: 18),
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
                            label: _tr('محاضراتي', 'My Lectures'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const LecturerMyLecturesScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _ProfileActionButton(
                            icon: Icons.insert_chart_outlined_rounded,
                            label: _tr('تقرير الحضور', 'Attendance Report'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const LecturerAttendanceReportScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _ProfileActionButton(
                            icon: Icons.settings_outlined,
                            label: _tr('إدارة المحاضرات', 'Manage Lectures'),
                            onTap: () =>
                                LecturerNavigation.goToManageLectures(context),
                          ),
                          const SizedBox(height: 10),
                          _ProfileActionButton(
                            icon: Icons.notifications_none_rounded,
                            label: _tr('التنبيهات', 'Notifications'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const LecturerNotificationsScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _ProfileActionButton(
                            icon: Icons.language,
                            label: _isArabic
                                ? 'English | عربي'
                                : 'Arabic | English',
                            onTap: _showLanguagePicker,
                          ),
                          const SizedBox(height: 10),
                          _ProfileActionButton(
                            icon: Icons.logout,
                            label: _tr('تسجيل خروج', 'Logout'),
                            labelColor: const Color(0xFFD32F2F),
                            iconColor: const Color(0xFFD32F2F),
                            onTap: _confirmLogout,
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
      },
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
                  color: Colors.white.withValues(alpha: 0.06),
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
                  color: Colors.black.withValues(alpha: 0.06),
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
                          _resolveLecturerDisplayName(lecturer),
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
                            color: Colors.white.withValues(alpha: 0.9),
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _resolveCollege(lecturer),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.95),
                            fontFamily: 'Cairo',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_tr('القسم', 'Department')}: ${_resolveDepartment(lecturer)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontFamily: 'Cairo',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                color: Colors.white.withValues(alpha: 0.8),
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
                    color: Colors.black.withValues(alpha: 0.18),
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
    return StreamBuilder<Map<String, dynamic>?>(
      stream: LecturerAuthService.instance.watchCurrentLecturerDoc().map(
        (doc) => doc.data(),
      ),
      builder: (context, snapshot) {
        final photoUrl = _resolveLecturerPhotoUrl(snapshot.data);
        if (photoUrl.isNotEmpty) {
          return Image.network(
            photoUrl,
            fit: BoxFit.cover,
            width: 84,
            height: 84,
            errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
          );
        }
        return _buildDefaultAvatar();
      },
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Icon(Icons.person, size: 40, color: _primaryColor),
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
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: iconColor),
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
          ],
        ),
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F3F5) : const Color(0xFFF7FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF006571) : const Color(0xFFDCE7E9),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? const Color(0xFF006571)
                      : const Color(0xFF42575D),
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF006571),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
