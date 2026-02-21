import 'package:flutter/material.dart';
import 'female_security_nav_bar.dart';
import 'accepted_screen.dart';
import 'rejected_students_screen.dart';
import 'general_settings_screen.dart';
import '../login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kTealLight = Color(0xFF27A2A9);
const _kTextDark = Color(0xFF2D2D2D);
const _kTextMuted = Color(0xFF757575);
const _kLogoutRed = Color(0xFFC00000);
const _kCardShadow = Color(0x0D000000);

// ─────────────────────────────────────────────────────────────────────────────
// SecuritySettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _notificationsEnabled = false;
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              children: [
                const Text(
                  'الإعدادات',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: _kTealLight,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 24),
                _buildProfileSection(),
                const SizedBox(height: 28),

                _buildOptionCard(
                  icon: Icons.language_rounded,
                  label: 'English | عربي',
                  onTap: () {},
                ),

                const SizedBox(height: 12),

                _buildNotificationsCard(),

                const SizedBox(height: 12),

                _buildOptionCard(
                  icon: Icons.star_rounded,
                  label: 'قيم تجربتك',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      final filled = (i + 1) <= _rating;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 20,
                            color: filled ? _kTealLight : _kTextMuted,
                          ),
                        ),
                      );
                    }),
                  ),
                  onTap: () {},
                ),

                const SizedBox(height: 12),

                _buildOptionCard(
                  icon: Icons.settings_rounded,
                  label: 'الإعدادات العامة',
                  trailing: const Icon(
                    Icons.chevron_left,
                    color: _kTextMuted,
                    size: 24,
                    textDirection: TextDirection.ltr,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GeneralSettingsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                _buildOptionCard(
                  icon: Icons.logout_rounded,
                  label: 'تسجيل خروج',
                  labelColor: _kLogoutRed,
                  trailing: const Icon(
                    Icons.chevron_left,
                    color: _kLogoutRed,
                    size: 24,
                    textDirection: TextDirection.ltr,
                  ),
                  onTap: _showLogoutDialog,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        bottomNavigationBar: FemaleSecurityNavBar(
          selectedIndex: 3,
          onItemTapped: (index) {
            if (index == 0) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AcceptedScreen()),
                (route) => false,
              );
            } else if (index == 1) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const RejectedStudentsScreen(),
                ),
              );
            } else if (index == 3) {
              // already on settings
            }
          },
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _kTealLight, width: 2),
            color: _kTextMuted.withOpacity(0.12),
          ),
          child: const Center(
            child: Icon(Icons.person_rounded, size: 44, color: _kTextMuted),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'حساب الأمن',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _kTextDark,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'username@example.com',
          style: TextStyle(
            fontSize: 14,
            color: _kTextMuted,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 52,
                  color: _kLogoutRed,
                ),
                const SizedBox(height: 20),
                Text(
                  'هل أنت متأكد أنك تريد تسجيل الخروج؟',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: _kTextDark,
                    fontFamily: 'Cairo',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kLogoutRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kLogoutRed,
                      side: const BorderSide(color: _kLogoutRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return _OptionCard(
      icon: Icons.notifications_outlined,
      label: 'الإشعارات',
      trailing: Switch(
        value: _notificationsEnabled,
        onChanged: (v) => setState(() => _notificationsEnabled = v),
        activeColor: _kTealLight,
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String label,
    Widget? trailing,
    Color? labelColor,
    VoidCallback? onTap,
  }) {
    return _OptionCard(
      icon: icon,
      label: label,
      labelColor: labelColor ?? _kTextDark,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _OptionCard
// ─────────────────────────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.label,
    this.trailing,
    this.labelColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, size: 24, color: labelColor ?? _kTextDark),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: labelColor ?? _kTextDark,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: _kCardShadow, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: content,
        ),
      ),
    );
  }
}
