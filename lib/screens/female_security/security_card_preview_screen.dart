import 'package:flutter/material.dart';
import 'models/student_card_info.dart';
import 'security_localization.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colors (aligned with accepted_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────

const _kTealLight = Color(0xFF27A2A9);
const _kTealDark = Color(0xFF006571);
const _kTextDark = Color(0xFF2D2D2D);
const _kTextMuted = Color(0xFF757575);
const _kRejectRed = Color(0xFFD32F2F);
const _kGreyBorder = Color(0xFFE0E0E0);

// ─────────────────────────────────────────────────────────────────────────────
// SecurityCardPreviewScreen
// ─────────────────────────────────────────────────────────────────────────────

class SecurityCardPreviewScreen extends StatelessWidget {
  const SecurityCardPreviewScreen({
    super.key,
    required this.student,
    required this.isAccepted,
  });

  final StudentCardInfo student;
  final bool isAccepted;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SecurityLocalization.controller,
      builder: (context, _) => Directionality(
        textDirection: SecurityLocalization.direction,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildAppBar(context),
                  const SizedBox(height: 8),
                  _buildStatusPill(),
                  const SizedBox(height: 18),
                  _buildCard(context),
                ],
              ),
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
          icon: Icon(
            SecurityLocalization.isEnglish
                ? Icons.arrow_back_ios_new_rounded
                : Icons.arrow_forward_ios_rounded,
            size: 19,
            color: _kTextDark,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        Expanded(
          child: Text(
            SecurityLocalization.previewCard,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: _kTextDark,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildStatusPill() {
    final isAcceptedStyle = isAccepted;
    final borderColor = isAcceptedStyle ? _kTealLight : _kRejectRed;
    final fillColor = isAcceptedStyle
        ? _kTealLight.withValues(alpha: 0.08)
        : _kRejectRed.withValues(alpha: 0.08);
    final label = isAcceptedStyle
        ? SecurityLocalization.acceptedStatus
        : SecurityLocalization.rejectedStatus;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: borderColor,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 38),
          padding: const EdgeInsets.fromLTRB(18, 50, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kTealLight, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _buildCardContent(),
        ),
        _buildGateIconBadge(),
      ],
    );
  }

  Widget _buildGateIconBadge() {
    const size = 78.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kTealLight.withValues(alpha: 0.1),
        border: Border.all(color: _kTealLight, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: _kTealLight.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.badge_outlined,
        size: 38,
        color: _kTealLight,
      ),
    );
  }

  Widget _buildCardContent() {
    const boldStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: _kTextDark,
      fontFamily: 'Cairo',
    );
    const regularStyle = TextStyle(
      fontSize: 13,
      color: _kTextDark,
      fontFamily: 'Cairo',
    );
    const mutedStyle = TextStyle(
      fontSize: 12,
      color: _kTextMuted,
      fontFamily: 'Cairo',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(student.fullName, textAlign: TextAlign.center, style: boldStyle),
        const SizedBox(height: 6),
        Text(
          student.universityId,
          textAlign: TextAlign.center,
          style: boldStyle,
        ),
        const SizedBox(height: 10),
        Text(
          '${SecurityLocalization.entryTime}: ${student.entryTime}',
          style: regularStyle,
        ),
        const SizedBox(height: 4),
        Text(student.dayLabel, style: regularStyle),
        const SizedBox(height: 4),
        Text(student.dateLabel, style: regularStyle),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          decoration: BoxDecoration(
            color: _kTealDark,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            student.attendanceStatus,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(student.college, style: boldStyle),
        const SizedBox(height: 4),
        Text(student.major, style: regularStyle),
        const SizedBox(height: 4),
        Text(student.degree, style: regularStyle),
        const SizedBox(height: 6),
        Text(student.nationality, style: boldStyle),
        const SizedBox(height: 4),
        Text(student.extraId, style: boldStyle),
        const SizedBox(height: 14),
        Divider(height: 1, color: _kGreyBorder),
        const SizedBox(height: 12),
        Text(student.gateLabel, textAlign: TextAlign.center, style: mutedStyle),
      ],
    );
  }
}
