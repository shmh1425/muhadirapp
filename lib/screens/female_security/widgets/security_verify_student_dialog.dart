import 'package:flutter/material.dart';

import '../security_localization.dart';
import '../../../services/female_security/security_gate_scan_service.dart';

const _kTealLight = Color(0xFF27A2A9);
const _kTextDark = Color(0xFF2D2D2D);
const _kTextMuted = Color(0xFF757575);
const _kRejectRed = Color(0xFFD32F2F);
const _kPrivacyBg = Color(0xFFEFF8F8);

class StudentGateScanResult {
  const StudentGateScanResult({
    required this.fullName,
    required this.universityId,
    required this.major,
    required this.scanTime,
    this.photoUrl,
  });

  final String fullName;
  final String universityId;
  final String major;
  final String scanTime;
  final String? photoUrl;
}

class SecurityVerifyStudentDialog extends StatelessWidget {
  const SecurityVerifyStudentDialog({
    super.key,
    required this.result,
    required this.rejectionReasons,
  });

  final StudentGateScanResult result;
  final List<SecurityRejectionReason> rejectionReasons;

  static Future<SecurityVerificationDecision?> show(
    BuildContext context, {
    required StudentGateScanResult result,
    required List<SecurityRejectionReason> rejectionReasons,
  }) {
    return showDialog<SecurityVerificationDecision>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: SecurityLocalization.direction,
        child: _SecurityVerifyDialogBody(
          result: result,
          rejectionReasons: rejectionReasons,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SecurityVerifyDialogBody(
      result: result,
      rejectionReasons: rejectionReasons,
    );
  }
}

class _SecurityVerifyDialogBody extends StatefulWidget {
  const _SecurityVerifyDialogBody({
    required this.result,
    required this.rejectionReasons,
  });

  final StudentGateScanResult result;
  final List<SecurityRejectionReason> rejectionReasons;

  @override
  State<_SecurityVerifyDialogBody> createState() =>
      _SecurityVerifyDialogBodyState();
}

class _SecurityVerifyDialogBodyState extends State<_SecurityVerifyDialogBody> {
  SecurityRejectionReason? _selectedReason;
  bool _isSavingAcceptedScan = false;
  bool _showFullDetails = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SecurityLocalization.controller,
      builder: (context, _) => Directionality(
        textDirection: SecurityLocalization.direction,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.86,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 12),
                    _buildCardIcon(),
                    const SizedBox(height: 10),
                    Text(
                      SecurityLocalization.cardDataSectionTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kTealLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPrivacyNotice(),
                    const SizedBox(height: 10),
                    _buildStudentInfo(),
                    const SizedBox(height: 10),
                    _buildDetailsToggle(),
                    const SizedBox(height: 12),
                    _buildRejectionReasonField(),
                    const SizedBox(height: 16),
                    _buildButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 40, height: 40),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              SecurityLocalization.gateCardVerificationTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _kTextDark,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: _kTextDark, size: 22),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: _kTextMuted, width: 1),
            shape: const CircleBorder(),
            minimumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildCardIcon() {
    final photoUrl = widget.result.photoUrl?.trim() ?? '';
    const size = 88.0;
    const borderWidth = 1.0;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _kTealLight.withValues(alpha: 0.28),
              width: borderWidth,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(borderWidth),
            child: ClipOval(
              child: ColoredBox(
                color: _kTealLight.withValues(alpha: 0.06),
                child: photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _GatePhotoFallback(),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _kTealLight,
                              ),
                            ),
                          );
                        },
                      )
                    : const _GatePhotoFallback(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentInfo() {
    const labelStyle = TextStyle(
      fontSize: 12,
      color: _kTextMuted,
      fontFamily: 'Cairo',
    );
    const valueStyle = TextStyle(
      fontSize: 13,
      color: _kTextDark,
      fontFamily: 'Cairo',
    );
    const nameValueStyle = TextStyle(
      fontSize: 14,
      color: _kTealLight,
      fontWeight: FontWeight.w600,
      fontFamily: 'Cairo',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(
          '${SecurityLocalization.studentNameFemale}:',
          _showFullDetails
              ? widget.result.fullName
              : _shortName(widget.result.fullName),
          valueStyle: nameValueStyle,
          labelStyle: labelStyle,
        ),
        const SizedBox(height: 8),
        _infoRow(
          '${SecurityLocalization.universityId}:',
          _showFullDetails
              ? widget.result.universityId
              : _maskTrailing(widget.result.universityId),
          valueStyle: valueStyle,
          labelStyle: labelStyle,
        ),
        if (_showFullDetails) ...[
          const SizedBox(height: 8),
          _infoRow(
            '${SecurityLocalization.major}:',
            widget.result.major,
            valueStyle: valueStyle,
            labelStyle: labelStyle,
          ),
        ],
        const SizedBox(height: 8),
        _infoRow(
          '${SecurityLocalization.scanTime}:',
          widget.result.scanTime,
          valueStyle: valueStyle,
          labelStyle: labelStyle,
        ),
      ],
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _kPrivacyBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kTealLight.withValues(alpha: 0.28)),
      ),
      child: Row(
        textDirection: SecurityLocalization.direction,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.visibility_off_outlined,
            color: _kTealLight,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SecurityLocalization.confidentialMode,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kTealLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  SecurityLocalization.sensitiveInfoHiddenForPrivacy,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: _kTextMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsToggle() {
    return Align(
      alignment: SecurityLocalization.isEnglish
          ? Alignment.centerLeft
          : Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => setState(() => _showFullDetails = !_showFullDetails),
        icon: Icon(
          _showFullDetails
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 18,
          color: _kTealLight,
        ),
        label: Text(
          _showFullDetails
              ? SecurityLocalization.hideDetails
              : SecurityLocalization.showDetails,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            color: _kTealLight,
          ),
        ),
      ),
    );
  }

  Widget _buildRejectionReasonField() {
    return DropdownButtonFormField<SecurityRejectionReason>(
      initialValue: _selectedReason,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: SecurityLocalization.rejectionReasonWhenNeeded,
        labelStyle: const TextStyle(color: _kTextMuted, fontFamily: 'Cairo'),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kTextMuted, width: 1),
        ),
      ),
      items: widget.rejectionReasons
          .map(
            (reason) => DropdownMenuItem<SecurityRejectionReason>(
              value: reason,
              child: Text(
                SecurityLocalization.isEnglish && reason.titleEn.isNotEmpty
                    ? reason.titleEn
                    : reason.titleAr,
                style: const TextStyle(color: _kTextDark, fontFamily: 'Cairo'),
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (value) => setState(() => _selectedReason = value),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    required TextStyle labelStyle,
    required TextStyle valueStyle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(width: 6),
        Flexible(
          fit: FlexFit.loose,
          child: Text(value, textAlign: TextAlign.start, style: valueStyle),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: _isSavingAcceptedScan ? null : _handleAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTealLight,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              SecurityLocalization.confirmEntry,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: () {
              if (_selectedReason == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(SecurityLocalization.selectRejectionReason),
                  ),
                );
                return;
              }
              Navigator.of(
                context,
              ).pop(SecurityVerificationDecision.rejected(_selectedReason!));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRejectRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              SecurityLocalization.rejectEntry,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAccept() async {
    setState(() => _isSavingAcceptedScan = true);
    try {
      if (!mounted) return;
      Navigator.of(context).pop(const SecurityVerificationDecision.approved());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SecurityLocalization.saveEntryError(error))),
      );
      setState(() => _isSavingAcceptedScan = false);
    }
  }
}

String _shortName(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final visible = parts.take(2).join(' ');
  return visible.isEmpty ? name : visible;
}

String _maskTrailing(String value, {int visibleDigits = 4}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final visibleCount = trimmed.length < visibleDigits
      ? trimmed.length
      : visibleDigits;
  final suffix = trimmed.substring(trimmed.length - visibleCount);
  return '•••• $suffix';
}

class _GatePhotoFallback extends StatelessWidget {
  const _GatePhotoFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.badge_outlined, size: 36, color: _kTealLight),
    );
  }
}
