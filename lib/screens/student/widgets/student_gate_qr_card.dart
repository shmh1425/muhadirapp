import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../features/translation/translation_controller.dart';
import '../../../services/student/student_gate_payload.dart';

/// Moving highlight segments along a rounded-rect path (gate QR frame).
class _MovingScanBorderPainter extends CustomPainter {
  _MovingScanBorderPainter({
    required this.progress,
    required this.cornerRadius,
  });

  /// 0..1, one lap around the perimeter.
  final double progress;
  final double cornerRadius;

  static const Color _light = Color(0xFF9FD4D9);
  static const Color _dark = Color(0xFF006571);

  @override
  void paint(Canvas canvas, Size size) {
    final strokePad = 2.0;
    final rect = Rect.fromLTWH(
      strokePad,
      strokePad,
      size.width - strokePad * 2,
      size.height - strokePad * 2,
    );
    final r = cornerRadius.clamp(0.0, math.min(rect.width, rect.height) / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));
    final outline = Path()..addRRect(rrect);

    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _light,
    );

    final metrics = outline.computeMetrics();
    for (final m in metrics) {
      final len = m.length;
      if (len <= 0) return;

      final sweep = len * 0.2;
      final start = (progress * len) % len;
      final scanPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = _dark;

      void drawSeg(double from) {
        final a = from % len;
        final b = a + sweep;
        final seg = m.extractPath(a, b, startWithMoveTo: true);
        canvas.drawPath(seg, scanPaint);
      }

      drawSeg(start);
      drawSeg(start + len * 0.5);
      return;
    }
  }

  @override
  bool shouldRepaint(covariant _MovingScanBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}

/// Gate QR on the student card (same JSON as HCE) for devices without HCE.
/// Animated scan-style border + live clock and date (matches campus card look).
class StudentGateQrCard extends StatefulWidget {
  const StudentGateQrCard({
    super.key,
    required this.studentId,
    this.embeddedInIdCard = false,
    this.contentOnly = false,
    this.gateCardRev = 0,
  });

  final int studentId;

  /// When true, only the inner white panel (QR + clock + id) — no section titles above.
  final bool embeddedInIdCard;

  /// When true, only the QR panel (for use inside [StudentCardSectionShell]).
  final bool contentOnly;

  /// Must match Firestore `external_students.gateCardRev` for gate acceptance.
  final int gateCardRev;

  @override
  State<StudentGateQrCard> createState() => _StudentGateQrCardState();
}

class _StudentGateQrCardState extends State<StudentGateQrCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _borderCtrl;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  static const Color _goldClock = Color(0xFFD4AF37);

  static const List<String> _arWeekdays = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  static const List<String> _enWeekdays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _borderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _borderCtrl.dispose();
    super.dispose();
  }

  String _tr(String ar, String en) =>
      TranslationController.instance.translateToEnglish ? en : ar;

  String _two(int v) => v.toString().padLeft(2, '0');

  String _formatTime() {
    final en = TranslationController.instance.translateToEnglish;
    final h = _now.hour;
    final m = _now.minute;
    final s = _now.second;
    if (en) {
      final isAm = h < 12;
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '${_two(h12)}:${_two(m)}:${_two(s)} ${isAm ? 'AM' : 'PM'}';
    }
    final isAm = h < 12;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '${_two(h12)}:${_two(m)}:${_two(s)} ${isAm ? 'ص' : 'م'}';
  }

  String _formatDate() {
    final en = TranslationController.instance.translateToEnglish;
    final y = _now.year;
    final mo = _now.month;
    final d = _now.day;
    if (en) {
      final wd = _enWeekdays[_now.weekday % 7];
      return '$wd $y/$mo/$d';
    }
    final wd = _arWeekdays[_now.weekday % 7];
    return '$wd $y/$mo/$d';
  }

  Widget _buildQrWhitePanel(
    BuildContext context, {
    required String payload,
    required String idLabel,
    required double qrSize,
  }) {
    const framePad = 12.0;
    final boxSide = qrSize + framePad * 2;
    const borderRadius = 14.0;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF27A2A9).withValues(
              alpha: (widget.embeddedInIdCard && !widget.contentOnly)
                  ? 0.12
                  : 0.06,
            ),
            blurRadius: (widget.embeddedInIdCard && !widget.contentOnly)
                ? 16
                : 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        (widget.embeddedInIdCard && !widget.contentOnly) ? 12 : 16,
        (widget.embeddedInIdCard && !widget.contentOnly) ? 14 : 18,
        (widget.embeddedInIdCard && !widget.contentOnly) ? 12 : 16,
        (widget.embeddedInIdCard && !widget.contentOnly) ? 14 : 16,
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _borderCtrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _MovingScanBorderPainter(
                  progress: _borderCtrl.value,
                  cornerRadius: borderRadius,
                ),
                child: SizedBox(
                  width: boxSide,
                  height: boxSide,
                  child: Center(
                    child: SizedBox(
                      width: qrSize,
                      height: qrSize,
                      child: QrImageView(
                        key: ValueKey(payload),
                        data: payload,
                        size: qrSize,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF006571),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF006571),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            _formatTime(),
            textAlign: TextAlign.center,
            textDirection: ui.TextDirection.ltr,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _goldClock,
              letterSpacing: 0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatDate(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
              height: 1.2,
            ),
          ),
          if (!widget.embeddedInIdCard && !widget.contentOnly) ...[
            const SizedBox(height: 12),
            Text(
              _tr('رقم البطاقة', 'Card number'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                idLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color(0xFF006571),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              _tr('رمز البطاقة', 'Card code'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                idLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: Color(0xFF006571),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = StudentGatePayload.buildJsonString(
      widget.studentId,
      gateCardRev: widget.gateCardRev,
      at: _now,
    );
    final idLabel = widget.studentId.toString();
    final compact = widget.embeddedInIdCard && !widget.contentOnly;
    final qrSize = compact
        ? math.min(176.0, MediaQuery.sizeOf(context).width * 0.42)
        : math.min(200.0, MediaQuery.sizeOf(context).width * 0.48);

    return AnimatedBuilder(
      animation: TranslationController.instance,
      builder: (context, _) {
        final panel = _buildQrWhitePanel(
          context,
          payload: payload,
          idLabel: idLabel,
          qrSize: qrSize,
        );
        if (widget.embeddedInIdCard || widget.contentOnly) {
          return panel;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _tr('رمز الدخول (QR)', 'Gate QR code'),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _tr(
                'للأجهزة التي لا تدعم محاكاة البطاقة عبر NFC.',
                'For phones that do not support NFC card emulation.',
              ),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            panel,
          ],
        );
      },
    );
  }
}
