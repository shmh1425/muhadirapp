import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../features/translation/translation_controller.dart';
import '../../../services/student/student_gate_hce_service.dart';

/// Lets the student turn on Android NFC card emulation so security can read the gate payload.
class StudentGateHceBanner extends StatefulWidget {
  const StudentGateHceBanner({
    super.key,
    required this.studentId,
    this.gateCardRev = 0,
  });

  final int studentId;
  final int gateCardRev;
  @override
  State<StudentGateHceBanner> createState() => _StudentGateHceBannerState();
}

class _StudentGateHceBannerState extends State<StudentGateHceBanner> {
  bool _loading = true;
  bool _hceSupported = false;
  bool _emulating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
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
          'Could not refresh card data. Toggle off and on again.',
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TranslationController.instance,
      builder: (context, _) {
        if (kIsWeb || !Platform.isAndroid) {
          return _infoCard(
            _tr(
              'محاكاة بطاقة NFC للبوابة متاحة على أندرويد فقط.',
              'NFC card emulation for the gate is available on Android only.',
            ),
          );
        }

        if (widget.studentId <= 0) {
          return const SizedBox.shrink();
        }

        if (_loading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (!_hceSupported) {
          return _infoCard(
            _tr(
              'هذا الجهاز لا يدعم محاكاة بطاقة NFC (HCE) المطلوبة للبوابة.',
              'This device does not support NFC card emulation (HCE) for the gate.',
            ),
          );
        }

        return Card(
          elevation: 0,
          color: const Color(0xFFE8F6F7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.nfc_rounded, color: Color(0xFF00525D)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _tr('البوابة الأمنية', 'Security gate'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF00525D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _tr(
                    'فعّلي «بطاقة NFC» ثم قرّبي ظهر الجهاز من جهاز الأمن حتى يتم المسح. أوقفيها بعد الدخول.',
                    'Turn on «NFC card», then hold the back of your phone to the security reader until it scans. Turn off after entry.',
                  ),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _emulating,
                  onChanged: _loading ? null : _setEmulating,
                  title: Text(
                    _tr('تفعيل بطاقة NFC للبوابة', 'Enable NFC card for gate'),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  secondary: Icon(
                    _emulating ? Icons.contactless : Icons.contactless_outlined,
                    color: const Color(0xFF00525D),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Color(0xFFB71C1C),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoCard(String message) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            height: 1.35,
            color: Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}
