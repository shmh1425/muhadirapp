import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../features/translation/translation_controller.dart';
import '../../../services/geo/student_campus_geo_guard.dart';
import '../../../services/student/student_gate_hce_service.dart';
import 'student_card_section_shell.dart';

/// Lets the student turn on Android NFC card emulation so security can read the gate payload.
class StudentGateHceBanner extends StatefulWidget {
  const StudentGateHceBanner({
    super.key,
    required this.studentId,
    this.gateCardRev = 0,
    this.contentOnly = false,
  });

  final int studentId;
  final int gateCardRev;

  /// When true, inner body only (inside attendance-style teal panel).
  final bool contentOnly;
  @override
  State<StudentGateHceBanner> createState() => _StudentGateHceBannerState();
}

class _StudentGateHceBannerState extends State<StudentGateHceBanner>
    with SingleTickerProviderStateMixin {
  static const Color _darkTeal = Color(0xFF006571);
  static const Color _titleTeal = Color(0xFF00525D);
  static const Color _ringTeal = Color(0xFF6FB2B7);
  static const Color _panelBg = Color(0xFFE6FBFB);

  bool _loading = true;
  bool _hceSupported = false;
  bool _emulating = false;
  String? _error;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _bootstrap();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (StudentGateHceService.instance.isPlatformSupported && _emulating) {
      StudentGateHceService.instance.stop();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StudentGateHceBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gateCardRev != widget.gateCardRev && _emulating) {
      unawaited(_restartHcePayload());
    }
  }

  Future<void> _restartHcePayload() async {
    if (!_emulating || widget.studentId <= 0) return;
    if (!StudentGateHceService.instance.isPlatformSupported) return;
    setState(() => _loading = true);
    try {
      await StudentGateHceService.instance.stop();
      await StudentGateHceService.instance.start(
        studentId: widget.studentId,
        gateCardRev: widget.gateCardRev,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _emulating = false;
        _error = _tr(
          'تعذر تحديث بيانات البطاقة. أعيدي التفعيل.',
          'Could not refresh card data. Tap to activate again.',
        );
      });
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _bootstrap() async {
    final svc = StudentGateHceService.instance;
    if (!svc.isPlatformSupported) {
      setState(() => _loading = false);
      return;
    }
    try {
      final supported = await svc.isHceSupported();
      if (!mounted) return;
      setState(() {
        _hceSupported = supported;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  String _tr(String ar, String en) =>
      TranslationController.instance.translateToEnglish ? en : ar;

  Future<void> _setEmulating(bool value) async {
    if (value == _emulating) return;
    final svc = StudentGateHceService.instance;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      if (value) {
        final geoBlocked = await StudentCampusGeoGuard.blockingOutcome();
        if (!mounted) return;
        if (geoBlocked != null) {
          setState(() {
            _loading = false;
            _error = StudentCampusGeoGuard.localizedMessage(geoBlocked);
          });
          return;
        }
        final nfc = await svc.isNfcAdapterEnabled();
        if (!nfc) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = _tr(
              'فعّلي NFC من إعدادات الجهاز ثم أعيدي المحاولة.',
              'Turn on NFC in device settings, then try again.',
            );
          });
          return;
        }
        await svc.start(
          studentId: widget.studentId,
          gateCardRev: widget.gateCardRev,
        );
        if (!mounted) return;
        setState(() {
          _emulating = true;
          _loading = false;
        });
      } else {
        await svc.stop();
        if (!mounted) return;
        setState(() {
          _emulating = false;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _tr(
          'تعذر تفعيل وضع البطاقة. حاولي مرة أخرى.',
          'Could not activate card mode. Please try again.',
        );
      });
    }
  }

  void _onTapZone() {
    if (_loading) return;
    if (_emulating) return;
    unawaited(_setEmulating(true));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TranslationController.instance,
      builder: (context, _) {
        if (widget.studentId <= 0) {
          return const SizedBox.shrink();
        }

        if (kIsWeb || !Platform.isAndroid) {
          return _infoCard(
            _tr(
              'محاكاة بطاقة NFC للبوابة متاحة على أندرويد فقط.',
              'NFC card emulation for the gate is available on Android only.',
            ),
          );
        }

        if (_loading && !_emulating && !_hceSupported) {
          if (widget.contentOnly) {
            return const _GateLoadingBody();
          }
          return StudentCardSectionShell(
            title: _tr('البوابة الأمنية', 'Security gate'),
            icon: Icons.nfc_rounded,
            child: const _GateLoadingBody(),
          );
        }

        if (!_hceSupported && !_loading) {
          return _infoCard(
            _tr(
              'هذا الجهاز لا يدعم محاكاة بطاقة NFC (HCE) المطلوبة للبوابة.',
              'This device does not support NFC card emulation (HCE) for the gate.',
            ),
          );
        }

        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _tr(
                'قرّب ظهر الجهاز من قارئ البوابة حتى يتم المسح، ثم أوقف البطاقة بعد الدخول.',
                'Hold the back of your phone to the gate reader until it scans, then turn off the card after entry.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 14),
            _buildTapZone(),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _buildErrorBanner(_error!),
            ],
            if (_emulating) ...[
              const SizedBox(height: 12),
              _buildStopButton(),
            ],
          ],
        );

        if (widget.contentOnly) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: body,
          );
        }

        return StudentCardSectionShell(
          title: _tr('البوابة الأمنية', 'Security gate'),
          icon: Icons.nfc_rounded,
          child: body,
        );
      },
    );
  }

  Widget _buildTapZone() {
    final isActive = _emulating;
    final isBusy = _loading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isActive || isBusy ? null : _onTapZone,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 200,
          decoration: BoxDecoration(
            color: _panelBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? _darkTeal.withValues(alpha: 0.45)
                  : const Color(0xFFCCE8EA),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isActive) _buildPulsingRings(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCenterBadge(isActive: isActive, isBusy: isBusy),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _zoneLabel(isActive: isActive, isBusy: isBusy),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: isActive ? 15 : 14,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: isActive ? _titleTeal : const Color(0xFF35565E),
                      ),
                    ),
                  ),
                  if (!isActive && !isBusy) ...[
                    const SizedBox(height: 6),
                    Text(
                      _tr('اضغطي هنا', 'Tap here'),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: _darkTeal.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
              if (isBusy)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _darkTeal,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _zoneLabel({required bool isActive, required bool isBusy}) {
    if (isBusy) {
      return _tr('جاري التفعيل...', 'Activating...');
    }
    if (isActive) {
      return _tr(
        'البطاقة جاهزة — قرّبي الجهاز من القارئ',
        'Card ready — hold phone to reader',
      );
    }
    return _tr(
      'اضغطي لتفعيل بطاقة NFC',
      'Tap to activate NFC card',
    );
  }

  Widget _buildCenterBadge({required bool isActive, required bool isBusy}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: isActive ? 88 : 76,
      height: isActive ? 88 : 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isActive
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF27A2A9), _darkTeal],
              )
            : null,
        color: isActive ? null : Colors.white,
        border: isActive
            ? null
            : Border.all(color: _darkTeal, width: 2),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: _darkTeal.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Icon(
        isBusy
            ? Icons.hourglass_top_rounded
            : (isActive ? Icons.contactless : Icons.contactless_outlined),
        size: isActive ? 44 : 38,
        color: isActive ? Colors.white : _darkTeal,
      ),
    );
  }

  Widget _buildPulsingRings() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        const ringCount = 8;
        final t = CurvedAnimation(
          parent: _pulseController,
          curve: Curves.easeInOut,
        ).value;
        return Stack(
          alignment: Alignment.center,
          children: List.generate(ringCount, (index) {
            final baseSize = 56.0 + (index * 22);
            final phase = (t + (index * 0.14)) % 1.0;
            final eased = Curves.easeInOut.transform(phase);
            final size = baseSize + (eased * 18);
            final opacity = 0.06 + ((1 - eased) * 0.22);
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _ringTeal.withValues(alpha: opacity),
                  width: 1.2,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildStopButton() {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : () => unawaited(_setEmulating(false)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB71C1C),
          side: BorderSide(color: Colors.red.shade200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.power_settings_new_rounded, size: 20),
        label: Text(
          _tr('إيقاف البطاقة', 'Turn off card'),
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          height: 1.35,
          color: Color(0xFFB71C1C),
        ),
      ),
    );
  }

  Widget _infoCard(String message) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF6B7280), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GateLoadingBody extends StatelessWidget {
  const _GateLoadingBody();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 80,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF006571),
        ),
      ),
    );
  }
}
