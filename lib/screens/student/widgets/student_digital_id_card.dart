import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../features/translation/translation_controller.dart';
import '../../../models/external_student.dart';
import '../../../services/student_auth_service.dart';
import '../../../shared/widgets/web_network_image_blur.dart';
import 'student_gate_qr_card.dart';

/// Digital student ID: teal header, photo, academics, embedded gate QR.
class StudentDigitalIdCard extends StatefulWidget {
  const StudentDigitalIdCard({
    super.key,
    required this.student,
    this.showEnlargeButton = true,
  });

  final ExternalStudent student;
  final bool showEnlargeButton;

  @override
  State<StudentDigitalIdCard> createState() => _StudentDigitalIdCardState();
}

class _StudentDigitalIdCardState extends State<StudentDigitalIdCard> {
  /// Matches app-wide teal (see lecturer profile, security nav, student screens).
  static const Color _darkTeal = Color(0xFF006571);
  static const Color _lightTeal = Color(0xFF27A2A9);
  static const Color _titleTeal = Color(0xFF00525D);
  static const Color _bodyText = Color(0xFF2D2D2D);
  static const Color _mutedTeal = Color(0xFF5F7A80);

  String _tr(String ar, String en) =>
      TranslationController.instance.translateToEnglish ? en : ar;

  void _openEnlarged(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) {
          return Scaffold(
            backgroundColor: Colors.black.withValues(alpha: 0.9),
            body: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: StudentDigitalIdCard(
                            student: widget.student,
                            showEnlargeButton: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _normalizeMajorAr(String rawAr, String rawEn) {
    final ar = rawAr.trim();
    final en = rawEn.trim().toLowerCase();
    if (ar == 'ايكونومك' || ar.contains('ايكونوم')) return 'اقتصاد';
    if (en == 'economics' || en == 'economic') return 'اقتصاد';
    return ar;
  }

  String _bachelorsLabel() => _tr('بكالوريوس', "Bachelor's");

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final nameAr = s.nameAr.trim().isNotEmpty ? s.nameAr.trim() : s.name;
    final nameEn = s.name.trim().isNotEmpty ? s.name.trim() : s.nameAr;
    final studentIdStr = s.studentId.toString();

    final collegeAr = s.collegeArSafe.trim();
    final collegeEn = s.collegeSafe.trim();
    final majorAr = _normalizeMajorAr(s.majorArSafe, s.major);
    final majorEn = s.major.trim();

    final collegeLine = collegeAr.isNotEmpty
        ? collegeAr
        : (collegeEn.isNotEmpty ? collegeEn : '—');
    final majorLine =
        majorAr.isNotEmpty ? majorAr : (majorEn.isNotEmpty ? majorEn : '—');

    return AnimatedBuilder(
      animation: TranslationController.instance,
      builder: (context, _) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: StudentAuthService.instance.watchCurrentStudentDoc(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? const <String, dynamic>{};
            final nationality = (data['nationality'] ?? '').toString().trim();
            final nationalId = (data['nationalIdOrIqama'] ?? data['nationalId'] ?? '')
                .toString()
                .trim();

            var photoUrlRaw =
                (data['photoUrl'] ?? data['photoURL'] ?? data['photo_url'] ?? '')
                    .toString()
                    .trim();
            if (photoUrlRaw.isEmpty) {
              photoUrlRaw = s.photoUrl.trim();
            }
            var photoVersion =
                (data['photoVersion'] ?? s.photoVersion).toString().trim();
            final imageUrl = photoUrlRaw.isEmpty
                ? ''
                : photoVersion.isEmpty
                    ? photoUrlRaw
                    : '$photoUrlRaw${photoUrlRaw.contains('?') ? '&' : '?'}v=$photoVersion';

            final revRaw = data['gateCardRev'];
            final int gateCardRev = revRaw is int
                ? revRaw
                : revRaw is num
                    ? revRaw.toInt()
                    : int.tryParse(revRaw?.toString() ?? '') ?? 0;

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _darkTeal.withValues(alpha: 0.22),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _darkTeal.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 112,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [_lightTeal, _darkTeal],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(13),
                          ),
                        ),
                        child: Stack(
                          children: [
                            if (widget.showEnlargeButton)
                              PositionedDirectional(
                                top: 8,
                                start: 8,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.16),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => _openEnlarged(context),
                                  icon: const Icon(Icons.zoom_out_map, size: 18),
                                  label: Text(
                                    _tr('تكبير', 'Enlarge'),
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 56,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _CardProfilePhoto(imageUrl: imageUrl),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 54),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Column(
                      children: [
                        Text(
                          nameAr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _titleTeal,
                            height: 1.25,
                          ),
                        ),
                        if (nameEn.isNotEmpty && nameEn != nameAr) ...[
                          const SizedBox(height: 4),
                          Text(
                            nameEn,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: _mutedTeal,
                              height: 1.2,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Directionality(
                          textDirection: ui.TextDirection.ltr,
                          child: Text(
                            studentIdStr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _bodyText,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _darkTeal,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _tr('منتظم', 'Active'),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          collegeLine,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _bodyText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          majorLine,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: _mutedTeal,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _darkTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _darkTeal.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            _bachelorsLabel(),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _darkTeal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (s.studentId > 0)
                          StudentGateQrCard(
                            studentId: s.studentId,
                            embeddedInIdCard: true,
                            gateCardRev: gateCardRev,
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _tr(
                                'رقم البطاقة غير جاهز لعرض رمز الدخول.',
                                'Card number is not ready to show the gate code.',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: _mutedTeal,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (nationality.isNotEmpty || nationalId.isNotEmpty) ...[
                          if (nationality.isNotEmpty)
                            Text(
                              nationality,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _mutedTeal,
                              ),
                            ),
                          if (nationalId.isNotEmpty) ...[
                            if (nationality.isNotEmpty)
                              const SizedBox(height: 6),
                            Directionality(
                              textDirection: ui.TextDirection.ltr,
                              child: Text(
                                nationalId,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D2D2D),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                        ] else
                          const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Circular profile image for the digital card (always visible, no blur).
class _CardProfilePhoto extends StatelessWidget {
  const _CardProfilePhoto({required this.imageUrl});

  final String imageUrl;

  static const double _kSize = 96;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF006571);
    const sized = Size.square(_kSize);

    Widget core;
    if (imageUrl.isEmpty) {
      core = const ColoredBox(
        color: Color(0xFFECEFF1),
        child: Icon(Icons.person, size: 48, color: Color(0xFF9AA0A6)),
      );
    } else if (kIsWeb) {
      core = WebNetworkImageBlur(
        url: imageUrl,
        blurSigma: 0,
        fit: BoxFit.cover,
        onErrorFallback: const Center(
          child: Icon(Icons.broken_image_outlined, color: Color(0xFF9AA0A6)),
        ),
      );
    } else {
      core = Image.network(
        imageUrl,
        width: sized.width,
        height: sized.height,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Color(0xFFECEFF1),
          child: Icon(Icons.person, size: 48, color: Color(0xFF9AA0A6)),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return ColoredBox(
            color: const Color(0xFFECEFF1),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: borderColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          );
        },
      );
    }

    core = SizedBox.fromSize(size: sized, child: core);

    return SizedBox(
      width: _kSize,
      height: _kSize,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: borderColor, width: 3),
        ),
        child: ClipOval(child: core),
      ),
    );
  }
}
