import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colors (aligned with accepted_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────

const _kTealLight = Color(0xFF27A2A9);
const _kTextDark = Color(0xFF2D2D2D);
const _kTextMuted = Color(0xFF757575);
const _kRejectRed = Color(0xFFC00000);

// ─────────────────────────────────────────────────────────────────────────────
// StudentGateScanResult
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// SecurityVerifyStudentDialog
// ─────────────────────────────────────────────────────────────────────────────

/// Reusable NFC scan verification dialog for female security.
/// Displays student details with approve/reject actions.
class SecurityVerifyStudentDialog extends StatelessWidget {
  const SecurityVerifyStudentDialog({
    super.key,
    required this.result,
    required this.onApprove,
    required this.onReject,
    required this.onClose,
  });

  final StudentGateScanResult result;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onClose;

  /// Shows the dialog. Returns nothing; use callbacks for actions.
  static Future<void> show(
    BuildContext context, {
    required StudentGateScanResult result,
    required VoidCallback onApprove,
    required VoidCallback onReject,
    VoidCallback? onClose,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SecurityVerifyStudentDialog(
          result: result,
          onApprove: () {
            Navigator.of(context).pop();
            onApprove();
          },
          onReject: () {
            Navigator.of(context).pop();
            onReject();
          },
          onClose: () {
            Navigator.of(context).pop();
            onClose?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
              const SizedBox(height: 24),
              _buildButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft, // X on "right" in RTL
      child: IconButton(
        onPressed: onClose,
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
        // Decorative circles around avatar
        Positioned(right: 8, top: 0, child: _decorationDot(_kTealLight.withOpacity(0.4))),
        Positioned(left: 4, top: 12, child: _decorationDot(_kTextMuted.withOpacity(0.3))),
        Positioned(left: 20, bottom: 8, child: _decorationDot(_kTealLight.withOpacity(0.35))),
        Positioned(right: 16, bottom: 4, child: _decorationDot(_kTextMuted.withOpacity(0.25))),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _kTealLight, width: 3),
            boxShadow: [
              BoxShadow(
                color: _kTealLight.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: result.photoUrl != null && result.photoUrl!.isNotEmpty
              ? Image.network(
                  result.photoUrl!,
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
      color: _kTextMuted.withOpacity(0.15),
      child: Center(
        child: Text(
          result.fullName.isNotEmpty ? result.fullName[0] : '?',
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
        _infoRow('اسم الطالبة:', result.fullName, valueStyle: nameValueStyle, labelStyle: labelStyle),
        const SizedBox(height: 10),
        _infoRow('رقمها الجامعي:', result.universityId, valueStyle: valueStyle, labelStyle: labelStyle),
        const SizedBox(height: 10),
        _infoRow('التخصص:', result.major, valueStyle: valueStyle, labelStyle: labelStyle),
        const SizedBox(height: 10),
        _infoRow('الوقت:', result.scanTime, valueStyle: valueStyle, labelStyle: labelStyle),
      ],
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
      textDirection: TextDirection.rtl,
      children: [
        Text(value, style: valueStyle),
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
            onPressed: onApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTealLight,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'تأكيد',
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
            onPressed: onReject,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRejectRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'رفض',
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
}
