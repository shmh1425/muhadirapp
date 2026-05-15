import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/translation/translation_controller.dart';
import '../../../services/geo/student_campus_geo_guard.dart';
import '../../../features/translation/widgets/t_text.dart';
import 'attendance_mode_chip.dart';
import 'student_gate_hce_banner.dart';
import 'student_gate_qr_card.dart';

/// Gate access on the student card — same QR / NFC shell as attendance screen.
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
  bool _isNfc = false;
  String? _geoBlockMessage;
  bool _checkingGeo = true;

  String _tr(String ar, String en) =>
      TranslationController.instance.translateToEnglish ? en : ar;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshCampusGeo());
  }

  Future<void> _refreshCampusGeo() async {
    final blocked = await StudentCampusGeoGuard.blockingOutcome();
    if (!mounted) return;
    setState(() {
      _checkingGeo = false;
      _geoBlockMessage = blocked == null
          ? null
          : StudentCampusGeoGuard.localizedMessage(blocked);
    });
  }

  Future<void> _onModeSelected(bool nfc) async {
    if (_isNfc == nfc) return;
    setState(() {
      _isNfc = nfc;
      _checkingGeo = true;
      _geoBlockMessage = null;
    });
    await _refreshCampusGeo();
  }

  @override
  Widget build(BuildContext context) {
    final modeTitle = _isNfc
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
                modeTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE6FBFB),
                borderRadius: BorderRadius.circular(26),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: _checkingGeo
                  ? const SizedBox(
                      height: 120,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF006571),
                        ),
                      ),
                    )
                  : _geoBlockMessage != null
                  ? _buildGeoBlockedPanel()
                  : _isNfc
                  ? StudentGateHceBanner(
                      studentId: widget.studentId,
                      gateCardRev: widget.gateCardRev,
                      contentOnly: true,
                    )
                  : _buildQrPanel(),
            ),
          ],
        );
      },
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
      child: Text(
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
              'اعرض الرمز على قارئ البوابة حتى يتم التحقق.',
              'Show this code at the gate reader until verified.',
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
