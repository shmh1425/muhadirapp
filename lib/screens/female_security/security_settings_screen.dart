import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'female_security_nav_bar.dart';
import 'general_settings_screen.dart';
import 'security_localization.dart';
import 'security_nfc_verification_screen.dart';
import 'security_records_screen.dart';
import '../login_screen.dart';
import '../../services/auth/app_session_store.dart';
import '../../services/profile_photo_session_service.dart';
import '../../shared/profile/user_profile_image_url.dart';
import '../../shared/widgets/cached_user_network_image.dart';
import '../../services/female_security_auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kTealLight = Color(0xFF27A2A9);
const _kLogoutRed = Color(0xFFD32F2F);
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
  final FemaleSecurityAuthService _authService =
      FemaleSecurityAuthService.instance;

  bool _notificationsEnabled = false;
  int _rating = 0;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingPhoto = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: SecurityLocalization.controller,
      builder: (context, _) => Directionality(
        textDirection: SecurityLocalization.direction,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                children: [
                  Text(
                    SecurityLocalization.settings,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileSection(),
                  const SizedBox(height: 18),

                  _buildOptionCard(
                    icon: Icons.language_rounded,
                    label: SecurityLocalization.language,
                    trailing: Text(
                      SecurityLocalization.isEnglish
                          ? SecurityLocalization.english
                          : SecurityLocalization.arabic,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    onTap: SecurityLocalization.controller.toggle,
                  ),

                  const SizedBox(height: 10),

                  _buildNotificationsCard(),

                  const SizedBox(height: 10),

                  _buildOptionCard(
                    icon: Icons.star_rounded,
                    label: SecurityLocalization.rateExperience,
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
                              color: filled
                                  ? _kTealLight
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }),
                    ),
                    onTap: () {},
                  ),

                  const SizedBox(height: 10),

                  _buildOptionCard(
                    icon: Icons.settings_rounded,
                    label: SecurityLocalization.generalSettings,
                    trailing: Icon(
                      SecurityLocalization.isEnglish
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                      color: theme.colorScheme.onSurfaceVariant,
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

                  const SizedBox(height: 10),

                  _buildOptionCard(
                    icon: Icons.logout_rounded,
                    label: SecurityLocalization.logout,
                    labelColor: _kLogoutRed,
                    trailing: Icon(
                      SecurityLocalization.isEnglish
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                      color: _kLogoutRed,
                      size: 24,
                      textDirection: TextDirection.ltr,
                    ),
                    onTap: _showLogoutDialog,
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          bottomNavigationBar: FemaleSecurityNavBar(
            selectedIndex: 2,
            onItemTapped: (index) {
              if (index == 0) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const SecurityRecordsScreen(),
                  ),
                  (route) => false,
                );
              } else if (index == 1) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SecurityNfcVerificationScreen(),
                  ),
                );
              } else if (index == 2) {
                // already on settings
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _authService.watchCurrentSecurityStaff().map((doc) => doc.data()),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        if (UserProfileImageUrl.pickRawUrl(data).isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ProfilePhotoSessionService.instance.persistFromFirestoreMap(
              data,
              role: AppSessionRole.security,
            );
          });
        }
        final photoUrl = ProfilePhotoSessionService.instance
                .resolveSecurityDisplayUrl(firestoreData: data) ??
            '';
        final fullName =
            (data['fullName'] ??
                    data['name'] ??
                    SecurityLocalization.securityAccount)
                .toString();
        final email = _authService.currentUserEmail ?? 'username@example.com';

        final scheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : _kCardShadow,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _isUploadingPhoto ? null : _pickAndUploadProfileImage,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _kTealLight, width: 2),
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.12),
                      ),
                      child: ClipOval(
                        child: photoUrl.isNotEmpty
                            ? CachedUserNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                width: 76,
                                height: 76,
                                errorWidget: const _SecurityProfilePlaceholder(),
                              )
                            : const _SecurityProfilePlaceholder(),
                      ),
                    ),
                    if (_isUploadingPhoto)
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: _kTealLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                fullName.isEmpty
                    ? SecurityLocalization.securityAccount
                    : fullName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.68),
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadProfileImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;

      setState(() => _isUploadingPhoto = true);
      final downloadUrl = await _authService.uploadCurrentUserProfileImage(
        pickedFile,
      );
      await ProfilePhotoSessionService.instance.persistExplicit(
        role: AppSessionRole.security,
        rawPhotoUrl: downloadUrl,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SecurityLocalization.photoUpdated)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SecurityLocalization.photoUploadFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => Directionality(
        textDirection: SecurityLocalization.direction,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 42),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _kLogoutRed.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 27,
                    color: _kLogoutRed,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  SecurityLocalization.confirmLogout,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'Cairo',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _authService.signOut();
                      if (!mounted) return;
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      SecurityLocalization.logout,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kLogoutRed,
                      side: const BorderSide(color: _kLogoutRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      SecurityLocalization.cancel,
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
      label: SecurityLocalization.notifications,
      trailing: Switch(
        value: _notificationsEnabled,
        onChanged: (v) => setState(() => _notificationsEnabled = v),
        activeThumbColor: _kTealLight,
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
      labelColor: labelColor,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final effectiveLabelColor = labelColor ?? scheme.onSurface;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        textDirection: SecurityLocalization.direction,
        children: [
          Icon(icon, size: 22, color: effectiveLabelColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              textAlign: SecurityLocalization.isEnglish
                  ? TextAlign.left
                  : TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: effectiveLabelColor,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.2)
                : _kCardShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      ),
    );
  }
}

class _SecurityProfilePlaceholder extends StatelessWidget {
  const _SecurityProfilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.person_rounded,
        size: 38,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
