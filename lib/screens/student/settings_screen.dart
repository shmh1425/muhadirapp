import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_settings.dart';
import '../../services/notifications/device_notification_permission_service.dart';
import 'components/notification_bell.dart';
import 'notifications_screen.dart';
import 'components/custom_nav_bar_icons.dart';
import '../../features/chatbot/providers/chatbot_provider.dart';
import '../../services/student_auth_service.dart';
import '../../shared/widgets/student_profile_avatar.dart';
import '../../shared/widgets/chat_fab.dart';
import 'home_screen.dart';
import 'services_screen.dart';
import '../login_screen.dart';
import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';

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
    final isEn = TranslationController.instance.translateToEnglish;
    final majorAr = (student.majorArSafe).trim();
    final majorEn = student.major.trim();
    String normalizeMajorAr(String rawAr, String rawEn) {
      final ar = rawAr.trim();
      final en = rawEn.trim().toLowerCase();
      // Fix common transliterations / wrong Arabic labels.
      if (ar == 'ايكونومك' || ar.contains('ايكونوم')) return 'اقتصاد';
      if (en == 'economics' || en == 'economic') return 'اقتصاد';
      return ar;
    }

    final majorArNormalized = normalizeMajorAr(majorAr, majorEn);
    final majorDisplay =
        isEn ? majorEn : (majorArNormalized.isNotEmpty ? majorArNormalized : majorEn);

    final nameEn = student.name.trim();
    final nameArTrim = student.nameAr.trim();
    // Arabic UI: secondary line English. English UI: secondary line Arabic.
    final secondaryName = isEn
        ? (nameArTrim.isNotEmpty ? nameArTrim : (nameEn.isNotEmpty ? nameEn : '-'))
        : (nameEn.isNotEmpty ? nameEn : (nameArTrim.isNotEmpty ? nameArTrim : '-'));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          secondaryName,
          style: const TextStyle(
            color: Color(0xFF444444),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        TText(
          majorDisplay,
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
    final translation = TranslationController.instance;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AnimatedBuilder(
          animation: translation,
          builder: (context, _) {
            return Directionality(
              textDirection: translation.textDirection,
              child: AlertDialog(
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
                    const TText(
                      'هل أنت متأكد أنك تريد تسجيل الخروج؟',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).maybePop();
                          await FirebaseAuth.instance.signOut();
                          ChatbotProvider.instance.clearChat();
                          await StudentAuthService.instance.logout();
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
                        child: const TText(
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
                        child: const TText(
                          'إلغاء',
                          style: TextStyle(color: Color(0xFFB71C1C)),
                        ),
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
  }

  @override
  Widget build(BuildContext context) {
    final translation = TranslationController.instance;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: StudentAuthService.instance.watchCurrentStudentDoc(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          StudentAuthService.instance.applyCurrentStudentSnapshot(snapshot.data!);
        }

        return AnimatedBuilder(
          animation: translation,
          builder: (context, _) {
            return Directionality(
              textDirection: translation.textDirection,
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
                          const SizedBox(width: 96),
                          Expanded(
                            child: Center(
                              child: Text(
                                translation.translateToEnglish
                                    ? 'Personal Profile'
                                    : 'الملف الشخصي',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF006571),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 96,
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: translation.toggle,
                                    icon: const Icon(Icons.language, color: Color(0xFF006571)),
                                    tooltip: translation.toggleLabel,
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Center(child: StudentProfileAvatar(size: 120)),
                      const SizedBox(height: 12),
                      Center(
                        child: Builder(
                          builder: (context) {
                            final s = StudentAuthService.instance.currentStudent;
                            final nameAr = s?.nameAr ?? '';
                            final nameDisplay = nameAr.isNotEmpty
                                ? nameAr
                                : (s?.name ?? 'لم يتم تحميل البيانات');
                            return TText(
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
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: translation.toggle,
                        child: _SettingsTile(
                          child: Row(
                            children: [
                              const Icon(Icons.language, color: Color(0xFF006571)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: _LanguageToggleLabel(
                                    isEnglish: translation.translateToEnglish,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _NotificationPermissionTile(),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final gender = (StudentAuthService.instance.currentStudent?.gender ?? '')
                              .trim()
                              .toLowerCase();
                          final isFemale = gender == 'f' || gender == 'female';
                          if (!isFemale) {
                            if (AppSettings.instance.blurProfileImage.value) {
                              AppSettings.instance.blurProfileImage.value = false;
                            }
                            return const SizedBox.shrink();
                          }
                          return Column(
                            children: [
                              ValueListenableBuilder<bool>(
                                valueListenable: AppSettings.instance.blurProfileImage,
                                builder: (context, isBlurred, child) {
                                  final showPhoto = !isBlurred;
                                  return _SettingsTile(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.account_circle_outlined,
                                          color: Color(0xFF006571),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Align(
                                            alignment:
                                                AlignmentDirectional.centerStart,
                                            child: Text(
                                              translation.translateToEnglish
                                                  ? 'Show Personal Photo'
                                                  : 'إظهار الصورة الشخصية',
                                              textAlign: TextAlign.start,
                                              style: const TextStyle(
                                                color: Color(0xFF006571),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: showPhoto,
                                          onChanged: (value) {
                                            AppSettings.instance.blurProfileImage
                                                .value = !value;
                                          },
                                          activeColor: const Color(0xFF006571),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
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
                                  alignment: AlignmentDirectional.centerStart,
                                  child: TText(
                                    'تسجيل خروج',
                                    textAlign: TextAlign.start,
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
          },
        );
      },
    );
  }
}

class _NotificationPermissionTile extends StatefulWidget {
  const _NotificationPermissionTile();

  @override
  State<_NotificationPermissionTile> createState() =>
      _NotificationPermissionTileState();
}

class _NotificationPermissionTileState extends State<_NotificationPermissionTile>
    with WidgetsBindingObserver {
  final DeviceNotificationPermissionService _permissions =
      DeviceNotificationPermissionService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_permissions.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_permissions.refresh());
    }
  }

  bool get _en => TranslationController.instance.translateToEnglish;

  Future<void> _onToggle(bool wantEnable) async {
    if (!_permissions.isSupported) {
      _showSnack(
        _en
            ? 'Notifications are not supported on this platform.'
            : 'الإشعارات غير مدعومة على هذه المنصة.',
      );
      return;
    }

    if (wantEnable) {
      final status = await _permissions.requestEnable();
      if (!mounted) return;
      if (status.isGranted || status.isLimited) {
        _showSnack(
          _en ? 'Notifications enabled.' : 'تم تفعيل الإشعارات.',
        );
        return;
      }
      if (status.isPermanentlyDenied) {
        await _showOpenSettingsDialog(
          title: _en ? 'Enable notifications' : 'تفعيل الإشعارات',
          message: _en
              ? 'Allow notifications for Muhadir in your device settings.'
              : 'اسمحي للتطبيق بإرسال الإشعارات من إعدادات الجهاز.',
        );
      } else {
        _showSnack(
          _en
              ? 'Notification permission was not granted.'
              : 'لم يتم منح إذن الإشعارات.',
        );
      }
      return;
    }

    await _showOpenSettingsDialog(
      title: _en ? 'Turn off notifications' : 'إيقاف الإشعارات',
      message: _en
          ? 'To stop notifications, turn them off for Muhadir in your device settings.'
          : 'لإيقاف الإشعارات، عطّليها من إعدادات الجهاز للتطبيق.',
    );
    if (mounted) {
      await _permissions.refresh();
    }
  }

  Future<void> _showOpenSettingsDialog({
    required String title,
    required String message,
  }) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TranslationController.instance.textDirection,
          child: AlertDialog(
            title: Text(title, style: const TextStyle(fontFamily: 'Cairo')),
            content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: TText(_en ? 'Cancel' : 'إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: TText(_en ? 'Open settings' : 'فتح الإعدادات'),
              ),
            ],
          ),
        );
      },
    );
    if (open == true) {
      await _permissions.openSystemSettings();
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
        ),
        backgroundColor: const Color(0xFF006571),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translation = TranslationController.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([translation, _permissions.notificationsEnabled]),
      builder: (context, _) {
        final enabled = _permissions.notificationsEnabled.value;
        final supported = _permissions.isSupported;

        return _SettingsTile(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.notifications_outlined, color: Color(0xFF006571)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _en ? 'Notifications' : 'الإشعارات',
                  style: const TextStyle(
                    color: Color(0xFF006571),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              if (enabled == null && supported)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF006571),
                  ),
                )
              else
                Switch(
                  value: enabled ?? false,
                  onChanged: supported ? _onToggle : null,
                  activeTrackColor: const Color(0xFF006571).withValues(alpha: 0.45),
                  activeThumbColor: const Color(0xFF006571),
                ),
            ],
          ),
        );
      },
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

/// Language row label: English | عربي (active side highlighted).
class _LanguageToggleLabel extends StatelessWidget {
  const _LanguageToggleLabel({required this.isEnglish});

  final bool isEnglish;

  static const Color _teal = Color(0xFF006571);
  static const Color _muted = Color(0xFF5F7A80);

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'English',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isEnglish ? _teal : _muted,
            ),
          ),
          const TextSpan(
            text: ' | ',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: _muted,
            ),
          ),
          TextSpan(
            text: 'عربي',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isEnglish ? _muted : _teal,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.start,
    );
  }
}

