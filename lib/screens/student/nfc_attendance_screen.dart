import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';
import '../../services/attendance/nfc_attendance_service.dart';
import '../../services/student_auth_service.dart';
import '../../shared/widgets/chat_fab.dart';
import 'components/custom_nav_bar_icons.dart';
import 'components/notification_bell.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';

class NfcAttendanceScreen extends StatefulWidget {
  const NfcAttendanceScreen({super.key});

  @override
  State<NfcAttendanceScreen> createState() => _NfcAttendanceScreenState();
}

class _NfcAttendanceScreenState extends State<NfcAttendanceScreen>
    with SingleTickerProviderStateMixin {
  final NfcAttendanceService _nfcAttendance = NfcAttendanceService.instance;

  bool _isNfc = true;
  int selectedIndex = 2;
  AnimationController? _pulseController;

  bool _nfcAvailable = false;
  bool _checkingNfcAvailability = true;
  bool _isScanning = false;

  String _statusMessage =
      'اضغطي "ابدئي التحضير" ثم مرري الجوال على بطاقة المحاضر.';
  bool _statusError = false;

  void _toggleMode(bool nfc) {
    setState(() {
      _isNfc = nfc;
      _statusError = false;
      if (!nfc) {
        _statusMessage = 'ميزة QR قيد التطوير حالياً. استخدمي NFC للتحضير.';
      } else {
        _statusMessage =
            'اضغطي "ابدئي التحضير" ثم مرري الجوال على بطاقة المحاضر.';
      }
    });
  }

  Future<void> _onItemTapped(int index) async {
    setState(() {
      selectedIndex = index;
    });

    switch (index) {
      case 0:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        if (!mounted) return;
        setState(() => selectedIndex = 2);
        break;
      case 1:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServicesScreen()),
        );
        if (!mounted) return;
        setState(() => selectedIndex = 2);
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _checkNfcAvailability();
  }

  Future<void> _checkNfcAvailability() async {
    setState(() => _checkingNfcAvailability = true);
    try {
      final available = await NfcManager.instance.isAvailable();
      if (!mounted) return;
      setState(() {
        _nfcAvailable = available;
        _checkingNfcAvailability = false;
        if (!available) {
          _statusError = true;
          _statusMessage =
              'NFC غير متاح. على iPhone يلزم تفعيل Near Field Communication Tag Reading في التوقيع.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nfcAvailable = false;
        _checkingNfcAvailability = false;
        _statusError = true;
        _statusMessage = 'تعذر التحقق من حالة NFC. حاولي مرة أخرى.';
      });
    }
  }

  Future<void> _startNfcAttendance() async {
    if (_isScanning || !_isNfc) return;

    final student = StudentAuthService.instance.currentStudent;
    if (student == null) {
      setState(() {
        _statusError = true;
        _statusMessage = 'انتهت جلسة الطالب. سجلي الدخول من جديد.';
      });
      return;
    }

    if (!_nfcAvailable) {
      setState(() {
        _statusError = true;
        _statusMessage =
            'NFC غير متاح. على iPhone يلزم تفعيل Near Field Communication Tag Reading في التوقيع.';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _statusError = false;
      _statusMessage = 'جاري انتظار بطاقة المحاضر...';
    });

    bool handled = false;

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          if (handled) return;
          handled = true;

          final cardId = _extractCardId(tag);
          if (cardId.isEmpty) {
            await NfcManager.instance.stopSession(
              errorMessage: 'تعذر قراءة معرّف البطاقة.',
            );
            if (!mounted) return;
            setState(() {
              _isScanning = false;
              _statusError = true;
              _statusMessage =
                  'تعذر قراءة البطاقة. أعيدي تمرير الجهاز مرة أخرى.';
            });
            return;
          }

          try {
            final result = await _nfcAttendance.submitAttendanceFromCard(
              lecturerCardId: cardId,
              studentId: student.studentId,
              currentTime: DateTime.now(),
            );

            await NfcManager.instance.stopSession(alertMessage: result.message);
            if (!mounted) return;
            setState(() {
              _isScanning = false;
              _statusError = false;
              _statusMessage = result.message;
            });
          } on NfcAttendanceException catch (e) {
            final message = _friendlyErrorMessage(e);
            await NfcManager.instance.stopSession(errorMessage: message);
            if (!mounted) return;
            setState(() {
              _isScanning = false;
              _statusError = true;
              _statusMessage = message;
            });
          } catch (e) {
            final message = 'حدث خطأ غير متوقع أثناء تسجيل الحضور.';
            await NfcManager.instance.stopSession(errorMessage: message);
            if (!mounted) return;
            setState(() {
              _isScanning = false;
              _statusError = true;
              _statusMessage = '$message\n$e';
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _statusError = true;
        _statusMessage = 'فشل بدء جلسة NFC: $e';
      });
    }
  }

  String _friendlyErrorMessage(NfcAttendanceException e) {
    switch (e.code) {
      case NfcAttendanceErrorCode.invalidLecturerCard:
        return 'البطاقة غير معروفة. يرجى التواصل مع المحاضر أو الدعم.';
      case NfcAttendanceErrorCode.noActiveSession:
        return 'لا توجد جلسة تحضير مفتوحة الآن. انتظري حتى يفتح المحاضر الجلسة.';
      case NfcAttendanceErrorCode.studentNotEnrolled:
        return 'أنتِ غير مسجلة في هذه الشعبة.';
      case NfcAttendanceErrorCode.alreadyMarked:
        return 'تم تسجيل حضورك مسبقاً.';
      default:
        return e.message;
    }
  }

  String _extractCardId(NfcTag tag) {
    final data = tag.data;
    final candidates = <dynamic>[
      _dig(data, ['nfca', 'identifier']),
      _dig(data, ['mifareclassic', 'identifier']),
      _dig(data, ['mifareultralight', 'identifier']),
      _dig(data, ['nfcv', 'identifier']),
      _dig(data, ['nfcb', 'identifier']),
      _dig(data, ['isodep', 'identifier']),
      _dig(data, ['felica', 'currentIDm']),
      _dig(data, ['ndef', 'identifier']),
    ];

    for (final candidate in candidates) {
      final id = _bytesToHex(candidate);
      if (id.isNotEmpty) {
        return NfcAttendanceService.normalizeLecturerCardId(id);
      }
    }
    return '';
  }

  dynamic _dig(Map<dynamic, dynamic> map, List<String> path) {
    dynamic current = map;
    for (final key in path) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  String _bytesToHex(dynamic value) {
    List<int> bytes = <int>[];

    if (value is Uint8List) {
      bytes = value.toList();
    } else if (value is List) {
      bytes = value.whereType<num>().map((e) => e.toInt()).toList();
    } else if (value is String) {
      final normalized = value.trim().replaceAll(' ', '');
      final isHex = RegExp(r'^[A-Fa-f0-9]+$').hasMatch(normalized);
      if (isHex) {
        return normalized.toUpperCase();
      }
    }

    if (bytes.isEmpty) return '';

    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    try {
      NfcManager.instance.stopSession();
    } catch (_) {
      // no-op
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translation = TranslationController.instance;

    return AnimatedBuilder(
      animation: translation,
      builder: (context, _) => Directionality(
        textDirection: translation.textDirection,
        child: Scaffold(
          backgroundColor: Colors.white,
          floatingActionButton: const ChatFAB(),
          bottomNavigationBar: NavBarSettingsArabic(
            selectedIndex: selectedIndex,
            onItemTapped: _onItemTapped,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        translation.translateToEnglish
                            ? Icons.arrow_back_ios_new
                            : Icons.arrow_forward_ios,
                        color: const Color(0xFF006571),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const TText(
                      'تسجيل الحضور',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006571),
                      ),
                    ),
                    const Spacer(),
                    NotificationBell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Center(
                  child: TText(
                    'التحضير عبر NFC',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF222222),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 140,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F7F7),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ModeChip(
                            label: 'QR',
                            isActive: !_isNfc,
                            onTap: () => _toggleMode(false),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _ModeChip(
                            label: 'NFC',
                            isActive: _isNfc,
                            onTap: () => _toggleMode(true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: MediaQuery.of(context).size.height * 0.68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6FBFB),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isNfc) ...[
                        AnimatedBuilder(
                          animation:
                              _pulseController ??
                              const AlwaysStoppedAnimation(0),
                          builder: (context, child) {
                            const ringCount = 12;
                            final t = CurvedAnimation(
                              parent:
                                  _pulseController ??
                                  const AlwaysStoppedAnimation(0),
                              curve: Curves.easeInOut,
                            ).value;
                            return Stack(
                              alignment: Alignment.center,
                              children: List.generate(ringCount, (index) {
                                final baseSize = 90.0 + (index * 36);
                                final phase = (t + (index * 0.12)) % 1.0;
                                final eased = Curves.easeInOut.transform(phase);
                                final size = baseSize + (eased * 28);
                                final opacity = 0.05 + ((1 - eased) * 0.18);
                                return Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(
                                        0xFF6FB2B7,
                                      ).withValues(alpha: opacity),
                                      width: 1,
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF006571),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.phone_iphone,
                                size: 52,
                                color: Color(0xFF006571),
                              ),
                            ),
                            const SizedBox(height: 26),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _statusError
                                    ? const Color(0xFFFFEBEE)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _statusError
                                      ? const Color(0xFFE57373)
                                      : const Color(0xFFCCE8EA),
                                ),
                              ),
                              child: Text(
                                _statusMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _statusError
                                      ? const Color(0xFFB71C1C)
                                      : const Color(0xFF35565E),
                                  fontSize: 13,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 210,
                              height: 44,
                              child: FilledButton(
                                onPressed:
                                    (_isScanning ||
                                        _checkingNfcAvailability ||
                                        !_nfcAvailable)
                                    ? null
                                    : _startNfcAttendance,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF006571),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: _isScanning
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _checkingNfcAvailability
                                            ? 'جاري التحقق...'
                                            : 'ابدئي التحضير',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 280,
                              height: 280,
                              child: Image.asset(
                                'assets/images/QR.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const TText(
                              'ميزة QR ستتوفر قريباً',
                              style: TextStyle(
                                color: Color(0xFF35565E),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF006571) : const Color(0xFF4CAEB7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
