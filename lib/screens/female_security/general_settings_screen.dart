import 'package:flutter/material.dart';

import '../../services/female_security/security_gate_scan_service.dart';
import 'security_prefs.dart';
import '../../theme/app_theme_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kTealLight = Color(0xFF27A2A9);
const _kTextDark = Color(0xFF2D2D2D);
const _kTextMuted = Color(0xFF757575);
const _kCardShadow = Color(0x0D000000);

// ─────────────────────────────────────────────────────────────────────────────
// GeneralSettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  bool _autoUpdatesEnabled = true;

  @override
  void initState() {
    super.initState();
    loadSecurityGatePreferences();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                _buildAppBar(context),
                const SizedBox(height: 28),
                _buildOptionCard(
                  icon: Icons.sync_rounded,
                  iconColor: _kTealLight,
                  label: 'التحديثات التلقائية',
                  trailing: Switch(
                    value: _autoUpdatesEnabled,
                    onChanged: (v) => setState(() => _autoUpdatesEnabled = v),
                    activeThumbColor: _kTealLight,
                  ),
                ),
                const SizedBox(height: 12),
                _buildThemeModeCard(),
                const SizedBox(height: 12),
                _buildGateCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_forward_ios,
            size: 20,
            color: _kTextDark,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        const Expanded(
          child: Text(
            'الإعدادات العامة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _kTealLight,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String label,
    Widget? trailing,
    Color? iconColor,
  }) {
    return _GenOptionCard(
      icon: icon,
      iconColor: iconColor ?? _kTextDark,
      label: label,
      trailing: trailing,
    );
  }

  static const Map<ThemeMode, String> _themeModeLabels = {
    ThemeMode.system: 'تلقائي',
    ThemeMode.dark: 'مفعل',
    ThemeMode.light: 'مغلق',
  };

  Widget _buildThemeModeCard() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
        return _GenOptionCard(
          icon: Icons.dark_mode_rounded,
          iconColor: _kTealLight,
          label: 'الوضع الليلي',
          trailing: DropdownButtonHideUnderline(
            child: DropdownButton<ThemeMode>(
              value: mode,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _kTextMuted,
                size: 24,
              ),
              items: [ThemeMode.system, ThemeMode.dark, ThemeMode.light]
                  .map(
                    (m) => DropdownMenuItem<ThemeMode>(
                      value: m,
                      child: Text(
                        _themeModeLabels[m]!,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: _kTextDark,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) appThemeMode.value = v;
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGateCard() {
    return ValueListenableBuilder<List<SecurityGateOption>>(
      valueListenable: availableSecurityGates,
      builder: (context, gates, _) {
        final options = gates.isNotEmpty
            ? gates
            : <SecurityGateOption>[currentSecurityGateOption];
        final current = options.firstWhere(
          (gate) => gate.gateId == selectedGateId.value,
          orElse: () => options.first,
        );

        return _GenOptionCard(
          icon: Icons.door_front_door_rounded,
          iconColor: _kTealLight,
          label: 'البوابة: ${current.gateNumber}',
          trailing: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: current.gateId,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _kTextMuted,
                size: 24,
              ),
              items: options
                  .map(
                    (gate) => DropdownMenuItem<String>(
                      value: gate.gateId,
                      child: Text(
                        '${gate.gateNumber} - ${gate.campusName}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: _kTextDark,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) async {
                if (value == null) return;
                final selected = options.firstWhere(
                  (gate) => gate.gateId == value,
                );
                await updateSelectedGateOption(selected);
              },
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GenOptionCard
// ─────────────────────────────────────────────────────────────────────────────

class _GenOptionCard extends StatelessWidget {
  const _GenOptionCard({
    required this.icon,
    required this.label,
    this.trailing,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, size: 24, color: iconColor ?? _kTextDark),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _kTextDark,
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
      child: content,
    );
  }
}
