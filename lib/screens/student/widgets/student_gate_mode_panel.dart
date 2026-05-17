import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../features/translation/translation_controller.dart';
import '../../../features/translation/widgets/t_text.dart';
import '../../../services/geo/campus_geo_check_mode.dart';
import '../../../services/geo/student_campus_geo_guard.dart';
import '../../../services/student/student_gate_platform.dart';
import 'attendance_mode_chip.dart';
import 'student_gate_hce_banner.dart';
import 'student_gate_qr_card.dart';

/// Gate access on the student card — QR (all phones) and NFC HCE (Android).
class StudentGateModePanel extends StatefulWidget {
  const StudentGateModePanel({
    super.key,
    required this.studentId,
    this.gateCardRev = 0,
  });

  final int studentId;
  final int gateCardRev;

  @override
  State<StudentGateModePanel> createState() => _StudentGateModePanelState();
}

class _StudentGateModePanelState extends State<StudentGateModePanel> {
  /// QR is the default on every platform (iPhone + Android).
  bool _isNfc = false;
  String? _geoBlockMessage;
  bool _geoVerifying = false;

  bool get _iosShowsNfcUnsupportedCard =>
      !kIsWeb &&
      Platform.isIOS &&
      _isNfc &&
      StudentGatePlatform.showNfcModeChip;

  String _tr(String ar, String en) =>
      TranslationController.instance.translateToEnglish ? en : ar;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshCampusGeo());
  }

  Future<void> _refreshCampusGeo({bool invalidateCache = false}) async {
    if (_iosShowsNfcUnsupportedCard || _isNfc) {
      if (!mounted) return;
      setState(() {
        _geoVerifying = false;
        _geoBlockMessage = null;
      });
      return;
    }

    if (invalidateCache) {
      StudentCampusGeoGuard.invalidateGateCache();
    }

    if (!mounted) return;
    setState(() => _geoVerifying = true);

    final blocked = await StudentCampusGeoGuard.blockingOutcome(
      mode: CampusGeoCheckMode.girlsSecurityGate,
    );
    if (!mounted) return;
    setState(() {
      _geoVerifying = false;
      _geoBlockMessage = blocked == null
          ? null
          : StudentCampusGeoGuard.localizedMessage(
              blocked,
              mode: CampusGeoCheckMode.girlsSecurityGate,
            );
    });
  }

  Future<void> _onModeSelected(bool nfc) async {
    if (!StudentGatePlatform.showNfcModeChip && nfc) return;
    if (_isNfc == nfc) return;
    setState(() => _isNfc = nfc);
    unawaited(_refreshCampusGeo());
  }

  @override
  Widget build(BuildContext context) {
    final showNfcChip = StudentGatePlatform.showNfcModeChip;
    final modeTitle = _isNfc && showNfcChip
        ? _tr('البوابة عبر NFC', 'Gate via NFC')
        : _tr('البوابة عبر QR', 'Gate via QR');

    return AnimatedBuilder(
      animation: TranslationController.instance,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: TText(
                _tr('البوابة الأمنية', 'Security gate'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            if (showNfcChip) ...[
              const SizedBox(height: 12),
              Center(
                child: TText(
                  modeTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF35565E),
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 200,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F7F7),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: AttendanceModeChip(
                          label: 'QR',
                          isActive: !_isNfc,
                          onTap: () => unawaited(_onModeSelected(false)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: AttendanceModeChip(
                          label: 'NFC',
                          isActive: _isNfc,
                          onTap: () => unawaited(_onModeSelected(true)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE6FBFB),
                borderRadius: BorderRadius.circular(26),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: _iosShowsNfcUnsupportedCard
                  ? _buildIosNfcUnsupportedPanel()
                  : !_isNfc && _geoBlockMessage != null
                  ? _buildGeoBlockedPanel()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isNfc && _geoVerifying)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              color: Color(0xFF006571),
                              backgroundColor: Color(0xFFCCE8EA),
                            ),
                          ),
                        if (_isNfc && showNfcChip)
                          StudentGateHceBanner(
                            studentId: widget.studentId,
                            gateCardRev: widget.gateCardRev,
                            contentOnly: true,
                            onPreferQr: () => unawaited(_onModeSelected(false)),
                          )
                        else
                          _buildQrPanel(),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIosNfcUnsupportedPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Text(
        _tr(
          'NFC غير متوفر حاليًا على iPhone.',
          'NFC is currently not supported on iPhone.',
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF5D4037),
          fontSize: 13,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildGeoBlockedPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _geoBlockMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFB71C1C),
              fontSize: 13,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _geoVerifying
                ? null
                : () => unawaited(_refreshCampusGeo(invalidateCache: true)),
            child: TText(
              _tr('إعادة التحقق من الموقع', 'Check location again'),
              style: const TextStyle(
                color: Color(0xFF006571),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCCE8EA)),
          ),
          child: Text(
            _tr(
              'اعرضي الرمز لقارئ البوابة.',
              'Show this code to the gate reader.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF35565E),
              fontSize: 13,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 14),
        StudentGateQrCard(
          studentId: widget.studentId,
          gateCardRev: widget.gateCardRev,
          contentOnly: true,
        ),
      ],
    );
  }
}
