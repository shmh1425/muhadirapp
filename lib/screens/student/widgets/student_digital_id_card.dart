import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../features/translation/translation_controller.dart';
import '../../../models/external_student.dart';
import '../../../screens/student/app_settings.dart';
import '../../../services/student_auth_service.dart';
import '../../../shared/widgets/web_network_image_blur.dart';

/// Digital student ID: photo, name, academics (QR and NFC are separate sections).
class StudentDigitalIdCard extends StatefulWidget {
  const StudentDigitalIdCard({super.key, required this.student});

  final ExternalStudent student;

  @override
  State<StudentDigitalIdCard> createState() => _StudentDigitalIdCardState();
}

class _StudentDigitalIdCardState extends State<StudentDigitalIdCard> {
  /// Matches app-wide teal (see lecturer profile, security nav, student screens).
  static const Color _darkTeal = Color(0xFF006571);
  static const Color _bodyText = Color(0xFF2D2D2D);

  /// Fixed card footprint — long names/majors ellipsize instead of resizing the card.
  static const double _cardHeight = 198;
  static const double _detailsBlockHeight = 70;

  String _normalizeMajorAr(String rawAr, String rawEn) {
    final ar = rawAr.trim();
    final en = rawEn.trim().toLowerCase();
    if (ar == 'ايكونومك' || ar.contains('ايكونوم')) return 'اقتصاد';
    if (en == 'economics' || en == 'economic') return 'اقتصاد';
    return ar;
  }

  static String _monthYear(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Resolves MM/YYYY from Firestore strings, [Timestamp], or ISO; else current month.
  static String _resolvedIssueMmYyyy(Map<String, dynamic> data) {
    bool looksLikeMmYyyy(String s) =>
        RegExp(r'^\d{1,2}/\d{4}$').hasMatch(s.trim());

    String normalized(String raw) {
      final t = raw.trim();
      if (t.isEmpty) return '';
      if (looksLikeMmYyyy(t)) {
        final p = t.split('/');
        final m = int.tryParse(p[0]) ?? 0;
        final y = int.tryParse(p[1]) ?? 0;
        if (m >= 1 && m <= 12 && y >= 1900) {
          return '${m.toString().padLeft(2, '0')}/$y';
        }
      }
      final iso = DateTime.tryParse(t);
      if (iso != null) return _monthYear(iso);
      return t;
    }

    dynamic field(String k) => data[k];

    final candidates = <dynamic>[
      field('cardIssueDate'),
      field('issueDateMmYyyy'),
      field('issue_date'),
      field('cardIssuedMmYyyy'),
      field('issuedAtMmYyyy'),
      field('cardIssueAt'),
      field('cardIssuedAt'),
      field('issuedAt'),
    ];

    for (final c in candidates) {
      if (c == null) continue;
      if (c is Timestamp) {
        return _monthYear(c.toDate());
      }
      final s = normalized(c.toString());
      if (s.isNotEmpty) return s;
    }

    return _monthYear(DateTime.now());
  }

  String _studentIdLabel(ExternalStudent student) {
    final sid = '${student.studentId}';
    if (TranslationController.instance.translateToEnglish) {
      return 'Student ID: $sid';
    }
    return '${student.isFemale ? 'رقم الطالبة' : 'رقم الطالب'} : $sid';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final nameAr = s.nameAr.trim().isNotEmpty ? s.nameAr.trim() : s.name;
    final nameEn = s.name.trim().isNotEmpty ? s.name.trim() : s.nameAr;
    final collegeAr = s.collegeArSafe.trim();
    final collegeEn = s.collegeSafe.trim();
    final majorArNormalized = _normalizeMajorAr(s.majorArSafe, s.major);
    final majorEn = s.major.trim();

    return AnimatedBuilder(
      animation: TranslationController.instance,
      builder: (context, _) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: StudentAuthService.instance.watchCurrentStudentDoc(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? const <String, dynamic>{};
            var photoUrlRaw =
                (data['photoUrl'] ??
                        data['photoURL'] ??
                        data['photo_url'] ??
                        '')
                    .toString()
                    .trim();
            if (photoUrlRaw.isEmpty) {
              photoUrlRaw = s.photoUrl.trim();
            }
            var photoVersion = (data['photoVersion'] ?? s.photoVersion)
                .toString()
                .trim();
            final imageUrl = photoUrlRaw.isEmpty
                ? ''
                : photoVersion.isEmpty
                ? photoUrlRaw
                : '$photoUrlRaw${photoUrlRaw.contains('?') ? '&' : '?'}v=$photoVersion';

            final deptEnRaw = s.departmentSafe.trim();
            final deptArRaw = s.departmentArSafe.trim();
            final facultyEn = collegeEn.isNotEmpty
                ? collegeEn
                : (collegeAr.isNotEmpty ? collegeAr : '—');
            final facultyAr = collegeAr.isNotEmpty
                ? collegeAr
                : (collegeEn.isNotEmpty ? collegeEn : '—');
            final deptEnDisp = deptEnRaw.isNotEmpty
                ? deptEnRaw
                : (majorEn.isNotEmpty ? majorEn : '—');
            final deptArDisp = deptArRaw.isNotEmpty
                ? deptArRaw
                : (majorArNormalized.isNotEmpty ? majorArNormalized : '—');
            final majorEnDisp = majorEn.isNotEmpty
                ? majorEn
                : (majorArNormalized.isNotEmpty ? majorArNormalized : '—');
            final majorArDisp = majorArNormalized.isNotEmpty
                ? majorArNormalized
                : (majorEn.isNotEmpty ? majorEn : '—');

            final displayIssue = _resolvedIssueMmYyyy(data);

            const detailSideStyle = TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              height: 1.32,
              fontWeight: FontWeight.w400,
              color: _bodyText,
            );

            const nameLineStyle = TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              height: 1.28,
              fontWeight: FontWeight.w700,
              color: _bodyText,
            );

            const footerMuted = TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              height: 1.35,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            );

            final isEnUi = TranslationController.instance.translateToEnglish;
            // Expanded Column follows ambient RTL; force LTR here so end == visual right next to photo.
            final headerColumnCross = isEnUi
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end;
            final headerAlign = isEnUi ? TextAlign.left : TextAlign.right;

            final displayName = isEnUi
                ? (nameEn.isNotEmpty ? nameEn : nameAr)
                : (nameAr.isNotEmpty ? nameAr : nameEn);

            final nameBlock = Directionality(
              textDirection: isEnUi ? TextDirection.ltr : TextDirection.rtl,
              child: Text(
                displayName,
                textAlign: headerAlign,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: nameLineStyle,
              ),
            );

            Widget detailLine(String text, TextAlign align, TextDirection dir) {
              return SizedBox(
                height: 17,
                child: Align(
                  alignment: align == TextAlign.right
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Directionality(
                    textDirection: dir,
                    child: Text(
                      text,
                      textAlign: align,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: detailSideStyle,
                    ),
                  ),
                ),
              );
            }

            Widget buildHeaderRow() {
              final gap = const SizedBox(width: 8);
              final logo = Image.asset(
                'assets/images/NFC_logo.jpeg',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.school_outlined,
                    color: _bodyText,
                    size: 22,
                  ),
                ),
              );
              final nameSection = Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    crossAxisAlignment: headerColumnCross,
                    children: [
                      SizedBox(
                        height: 36,
                        child: Align(
                          alignment: isEnUi
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: nameBlock,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _studentIdLabel(s),
                        textAlign: headerAlign,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: _bodyText,
                          height: 1.28,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              final photo = _CardProfilePhoto(
                imageUrl: imageUrl,
                size: 56,
                isFemale: s.isFemale,
              );
              return Row(
                textDirection: TextDirection.ltr,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: isEnUi
                    ? [photo, gap, nameSection, gap, logo]
                    : [logo, gap, nameSection, gap, photo],
              );
            }

            return Container(
              width: double.infinity,
              height: _cardHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                child: Column(
                  children: [
                    buildHeaderRow(),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: _detailsBlockHeight,
                      child: Row(
                        textDirection: TextDirection.ltr,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                detailLine(
                                  'Faculty: $facultyEn',
                                  TextAlign.left,
                                  TextDirection.ltr,
                                ),
                                const SizedBox(height: 4),
                                detailLine(
                                  'Department: $deptEnDisp',
                                  TextAlign.left,
                                  TextDirection.ltr,
                                ),
                                const SizedBox(height: 4),
                                detailLine(
                                  'Major: $majorEnDisp',
                                  TextAlign.left,
                                  TextDirection.ltr,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              children: [
                                detailLine(
                                  'الكلية: $facultyAr',
                                  TextAlign.right,
                                  TextDirection.rtl,
                                ),
                                const SizedBox(height: 4),
                                detailLine(
                                  'قسم $deptArDisp',
                                  TextAlign.right,
                                  TextDirection.rtl,
                                ),
                                const SizedBox(height: 4),
                                detailLine(
                                  'التخصص: $majorArDisp',
                                  TextAlign.right,
                                  TextDirection.rtl,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      isEnUi
                          ? 'Issue Date: $displayIssue'
                          : 'تاريخ الإصدار: $displayIssue',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: footerMuted,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Circular profile image for the digital card (respects privacy blur setting).
class _CardProfilePhoto extends StatelessWidget {
  const _CardProfilePhoto({
    required this.imageUrl,
    required this.isFemale,
    this.size = 96,
  });

  final String imageUrl;
  final bool isFemale;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.instance.blurProfileImage,
      builder: (context, isBlurred, _) {
        final blurSigma = (isFemale && isBlurred) ? 5.0 : 0.0;
        return _CardProfilePhotoContent(
          imageUrl: imageUrl,
          size: size,
          blurSigma: blurSigma,
        );
      },
    );
  }
}

class _CardProfilePhotoContent extends StatelessWidget {
  const _CardProfilePhotoContent({
    required this.imageUrl,
    required this.size,
    required this.blurSigma,
  });

  final String imageUrl;
  final double size;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF006571);
    final dimension = size;
    final sized = Size.square(dimension);
    final borderW = dimension <= 62 ? 2.0 : 2.5;
    final iconSz = (dimension * 0.42).clamp(22.0, 40.0);
    final progSz = (dimension * 0.36).clamp(20.0, 28.0);
    final preferHtmlElement = blurSigma <= 0;

    Widget core;
    if (imageUrl.isEmpty) {
      core = ColoredBox(
        color: const Color(0xFFECEFF1),
        child: Icon(Icons.person, size: iconSz, color: const Color(0xFF9AA0A6)),
      );
    } else if (kIsWeb && blurSigma > 0) {
      core = WebNetworkImageBlur(
        url: imageUrl,
        blurSigma: blurSigma,
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
        webHtmlElementStrategy: preferHtmlElement
            ? WebHtmlElementStrategy.prefer
            : WebHtmlElementStrategy.never,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: const Color(0xFFECEFF1),
          child: Icon(
            Icons.person,
            size: iconSz,
            color: const Color(0xFF9AA0A6),
          ),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return ColoredBox(
            color: const Color(0xFFECEFF1),
            child: Center(
              child: SizedBox(
                width: progSz,
                height: progSz,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
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
      width: dimension,
      height: dimension,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: borderColor, width: borderW),
        ),
        child: ClipOval(
          child: (kIsWeb && blurSigma > 0)
              ? core
              : ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: core,
                ),
        ),
      ),
    );
  }
}
