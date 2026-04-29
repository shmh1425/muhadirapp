import 'package:flutter/material.dart';

import '../security_localization.dart';
import '../../../services/female_security/security_gate_scan_service.dart';

const _kTealLight = Color(0xFF27A2A9);
const _kTextDark = Color(0xFF2D2D2D);
const _kTextMuted = Color(0xFF757575);
const _kRejectRed = Color(0xFFC00000);

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SecurityLocalization.controller,
      builder: (context, _) => Directionality(
        textDirection: SecurityLocalization.direction,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildAvatar(),
                  const SizedBox(height: 20),
                  _buildStudentInfo(),
                  const SizedBox(height: 16),
                  _buildRejectionReasonField(),
                  const SizedBox(height: 24),
                  _buildButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close, color: _kTextDark, size: 24),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: _kTextMuted, width: 1),
          shape: const CircleBorder(),
          minimumSize: const Size(40, 40),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: 8,
          top: 0,
          child: _decorationDot(_kTealLight.withValues(alpha: 0.4)),
        ),
        Positioned(
          left: 4,
          top: 12,
          child: _decorationDot(_kTextMuted.withValues(alpha: 0.3)),
        ),
        Positioned(
          left: 20,
          bottom: 8,
          child: _decorationDot(_kTealLight.withValues(alpha: 0.35)),
        ),
        Positioned(
          right: 16,
          bottom: 4,
          child: _decorationDot(_kTextMuted.withValues(alpha: 0.25)),
        ),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _kTealLight, width: 3),
            boxShadow: [
              BoxShadow(
                color: _kTealLight.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child:
              widget.result.photoUrl != null &&
                  widget.result.photoUrl!.isNotEmpty
              ? Image.network(
                  widget.result.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                )
              : _avatarPlaceholder(),
        ),
      ],
    );
  }

  Widget _decorationDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: _kTextMuted.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          widget.result.fullName.isNotEmpty ? widget.result.fullName[0] : '?',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: _kTealLight,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }

  Widget _buildStudentInfo() {
    const labelStyle = TextStyle(
      fontSize: 13,
      color: _kTextMuted,
      fontFamily: 'Cairo',
    );
    const valueStyle = TextStyle(
      fontSize: 14,
      color: _kTextDark,
      fontFamily: 'Cairo',
    );
    const nameValueStyle = TextStyle(
      fontSize: 15,
      color: _kTealLight,
      fontWeight: FontWeight.w600,
      fontFamily: 'Cairo',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoRow(
          '${SecurityLocalization.studentNameFemale}:',
          widget.result.fullName,
          valueStyle: nameValueStyle,
          labelStyle: labelStyle,
        ),
        const SizedBox(height: 10),
        _infoRow(
          '${SecurityLocalization.universityId}:',
          widget.result.universityId,
          valueStyle: valueStyle,
          labelStyle: labelStyle,
        ),
        const SizedBox(height: 10),
        _infoRow(
          '${SecurityLocalization.major}:',
          widget.result.major,
          valueStyle: valueStyle,
          labelStyle: labelStyle,
        ),
        const SizedBox(height: 10),
        _infoRow(
          '${SecurityLocalization.scanTime}:',
          widget.result.scanTime,
          valueStyle: valueStyle,
          labelStyle: labelStyle,
        ),
      ],
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: SecurityLocalization.direction,
      children: [
        Expanded(
          child: Text(value, textAlign: TextAlign.left, style: valueStyle),
        ),
        const SizedBox(width: 8),
        Text(label, style: labelStyle),
      ],
    );
  }

  Widget _buildButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isSavingAcceptedScan ? null : _handleAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTealLight,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              SecurityLocalization.confirm,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
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
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              SecurityLocalization.reject,
              style: TextStyle(
                fontSize: 17,
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
