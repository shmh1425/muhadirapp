import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

// ignore: depend_on_referenced_packages
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';
import '../../services/attendance/nfc_attendance_service.dart';
import '../../services/attendance/qr_attendance_service.dart';
import '../../services/student_auth_service.dart';
import '../../services/student_notifications_service.dart';
import '../../shared/widgets/chat_fab.dart';
import '../../shared/widgets/attendance_result_popup.dart';
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
  final QrAttendanceService _qrAttendance = QrAttendanceService.instance;
  final GlobalKey _qrViewKey = GlobalKey(debugLabel: 'student-qr-scanner');
  final TextEditingController _attendanceCodeController =
      TextEditingController();

  String _tr(String ar, String en) {
    return TranslationController.instance.translateToEnglish ? en : ar;
  }

  bool _isNfc = true;
  int selectedIndex = 2;
  AnimationController? _pulseController;
  QRViewController? _qrScannerController;

  bool _nfcAvailable = false;
  bool _checkingNfcAvailability = true;
  bool _isScanning = false;
  bool _isStartingQrScanner = false;
  bool _isProcessingQrScan = false;
  bool _isQrScanPaused = false;
  bool _qrPermissionDenied = false;
  bool _qrCameraUnavailable = false;
  bool _checkingQrAvailability = false;
  bool _qrScannerInitialized = false;
  bool _isEnteringQrCode = false;
  bool _isSubmittingAttendanceCode = false;

  late String _statusMessage = _tr(
    'اضغط "بدء التحضير" ثم قرّب الجهاز من بطاقة المحاضر.',
    'Tap "Start attendance" then hold your device near the lecturer card.',
  );
  bool _statusError = false;
  late String _qrStatusMessage = _tr(
    'وجّه الكاميرا نحو رمز التحضير المعروض لدى المحاضر.',
    'Point the camera at the attendance QR shown by the lecturer.',
  );
  bool _qrStatusError = false;

  String _nfcUnavailableMessage({required bool english}) {
    if (kIsWeb) {
      return english
          ? 'NFC is not supported in the browser. Use the iOS/Android app on a real device.'
          : 'NFC غير مدعوم على المتصفح. استخدمي التطبيق على iOS/Android في جهاز حقيقي.';
    }
    return english
        ? 'NFC is not available. On iPhone, enable Near Field Communication Tag Reading.'
        : 'NFC غير متاح. على iPhone يلزم تفعيل Near Field Communication Tag Reading في التوقيع.';
  }

  void _toggleMode(bool nfc) {
    setState(() {
      _isNfc = nfc;
      _statusError = false;
      if (!nfc) {
        _qrStatusError = false;
        _isEnteringQrCode = false;
        _qrCameraUnavailable = false;
        _qrPermissionDenied = false;
        _qrScannerInitialized = false;
        _qrStatusMessage = _tr(
          'وجّه الكاميرا نحو رمز التحضير المعروض لدى المحاضر.',
          'Point the camera at the attendance QR shown by the lecturer.',
        );
      } else {
        _statusMessage = _tr(
          'اضغط "بدء التحضير" ثم قرّب الجهاز من بطاقة المحاضر.',
          'Tap "Start attendance" then hold your device near the lecturer card.',
        );
      }
    });

    if (nfc) {
      _stopQrScanner();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isNfc) return;
      _prepareQrScanner();
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
    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _nfcAvailable = false;
        _checkingNfcAvailability = false;
        _statusError = true;
        _statusMessage = _nfcUnavailableMessage(english: false);
      });
      return;
    }
    try {
      final available = await NfcManager.instance.isAvailable();
      if (!mounted) return;
      setState(() {
        _nfcAvailable = available;
        _checkingNfcAvailability = false;
        if (!available) {
          _statusError = true;
          _statusMessage = _nfcUnavailableMessage(english: false);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nfcAvailable = false;
        _checkingNfcAvailability = false;
        _statusError = true;
        _statusMessage = _tr(
          'تعذر التحقق من حالة NFC. يرجى المحاولة مرة أخرى.',
          'Unable to check NFC status. Please try again.',
        );
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
        _statusMessage = _tr(
          _nfcUnavailableMessage(english: false),
          _nfcUnavailableMessage(english: true),
        );
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _statusError = false;
      _statusMessage = _tr(
        'جاري انتظار بطاقة المحاضر...',
        'Waiting for the lecturer card...',
      );
    });

    bool handled = false;
    final sessionDone = Completer<void>();
    final pollingOptions = Platform.isIOS
        ? <NfcPollingOption>{
            NfcPollingOption.iso14443,
            NfcPollingOption.iso15693,
          }
        : null;

    try {
      await NfcManager.instance.startSession(
        pollingOptions: pollingOptions,
        alertMessage: _tr(
          'قرّبي أعلى الهاتف من بطاقة المحاضر.',
          'Hold the top of your phone near the lecturer card.',
        ),
        onDiscovered: (NfcTag tag) async {
          if (handled) return;
          handled = true;

          final cardId = _extractCardId(tag);
          if (cardId.isEmpty) {
            await NfcManager.instance.stopSession(
              errorMessage: _tr(
                'تعذر قراءة معرّف البطاقة.',
                'Unable to read the card identifier.',
              ),
            );
            if (!mounted) return;
            setState(() {
              _isScanning = false;
              _statusError = true;
              _statusMessage = _tr(
                'تعذر قراءة البطاقة. يرجى إعادة المحاولة.',
                'Failed to read the card. Please try again.',
              );
            });
            if (!sessionDone.isCompleted) {
              sessionDone.complete();
            }
            return;
          }

          try {
            final result = await _nfcAttendance.submitAttendanceFromCard(
              lecturerCardId: cardId,
              studentId: student.studentId,
              currentTime: DateTime.now(),
            );

            await NfcManager.instance.stopSession(
              alertMessage: TranslationController.instance.translateToEnglish
                  ? 'Attendance recorded successfully.'
                  : result.message,
            );
            if (!mounted) return;
            setState(() {
              _isScanning = false;
              _statusError = false;
              _statusMessage = result.message;
            });
            final session = result.session;
            // Best-effort: store in-app notification (ignore failures).
            try {
              await StudentNotificationsService.instance
                  .addAttendanceSuccessNotification(
                    studentId: student.studentId,
                    attendanceMethod: 'nfc',
                    courseName: session?.courseName,
                    section: session?.sectionLabel,
                    sectionId: session?.sectionId,
                    sessionId: session?.sessionId,
                    lectureDate: session?.lectureDate,
                    lectureStartTime: session?.lectureStartTime,
                    lectureEndTime: session?.lectureEndTime,
                  );
            } catch (_) {}
            if (!mounted) return;
            await AttendanceResultPopup.show(
              context,
              success: true,
              message: _tr(
                'تم تسجيل حضورك بنجاح',
                'Attendance recorded successfully',
              ),
              subtitle: TranslationController.instance.translateToEnglish
                  ? 'Your attendance has been recorded.'
                  : result.message,
            );
            if (!sessionDone.isCompleted) {
              sessionDone.complete();
            }
          } on NfcAttendanceException catch (e) {
            final message = _friendlyErrorMessage(e);
            await NfcManager.instance.stopSession(errorMessage: message);
            if (!mounted) return;
            setState(() {
              _isScanning = false;
              _statusError = true;
              _statusMessage = message;
            });
            await AttendanceResultPopup.show(
              context,
              success: false,
              message: _tr('فشل تسجيل الحضور', 'Attendance failed'),
              subtitle: message,
              autoDismiss: false,
            );
            if (!sessionDone.isCompleted) {
              sessionDone.complete();
            }
          } catch (e) {
            final message = _tr(
              'حدث خطأ غير متوقع أثناء تسجيل الحضور.',
              'An unexpected error occurred while recording attendance.',
            );
            await NfcManager.instance.stopSession(errorMessage: message);
            if (!mounted) return;
            setState(() {
              _isScanning = false;
              _statusError = true;
              _statusMessage = '$message\n$e';
            });
            await AttendanceResultPopup.show(
              context,
              success: false,
              message: _tr('فشل تسجيل الحضور', 'Attendance failed'),
              subtitle: message,
              autoDismiss: false,
            );
            if (!sessionDone.isCompleted) {
              sessionDone.complete();
            }
          }
        },
        onError: (error) async {
          if (handled) return;
          handled = true;
          final message = _friendlySessionErrorMessage(error);
          if (mounted) {
            setState(() {
              _isScanning = false;
              _statusError = error.type != NfcErrorType.userCanceled;
              _statusMessage = message;
            });
          }
          if (!sessionDone.isCompleted) {
            sessionDone.complete();
          }
        },
      );

      await sessionDone.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () async {
          if (handled) return;
          handled = true;
          final message = _tr(
            'لم يتم اكتشاف بطاقة خلال 20 ثانية. قرّبي أعلى iPhone من البطاقة أو جرّبي بطاقة أخرى.',
            'No NFC tag detected within 20 seconds. Move the top of the iPhone closer to the card or try another card.',
          );
          try {
            await NfcManager.instance.stopSession(errorMessage: message);
          } catch (_) {
            // no-op
          }
          if (mounted) {
            setState(() {
              _isScanning = false;
              _statusError = true;
              _statusMessage = message;
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
        return 'لا توجد جلسة تحضير مفتوحة حالياً لهذه المحاضرة. تأكدي أن المحاضر فتح التحضير.';
      case NfcAttendanceErrorCode.outsideLectureWindow:
        return 'محاولة تسجيل حضور خارج وقت المحاضرة، لا يمكن تسجيل الحضور قبل أو بعد الوقت المحدد.';
      case NfcAttendanceErrorCode.studentNotEnrolled:
        return 'أنت غير مسجل/ـة في هذه الشعبة، لذلك لا يمكن تسجيل حضورك.';
      case NfcAttendanceErrorCode.alreadyMarked:
        return 'تم تسجيل حضورك مسبقاً.';
      default:
        return e.message;
    }
  }

  String _friendlyQrCodeMessage(QrAttendanceException e) {
    switch (e.code) {
      case QrAttendanceErrorCode.invalidNumericCode:
        return _tr('الرمز غير صحيح', 'Invalid code');
      case QrAttendanceErrorCode.numericCodeExpired:
      case QrAttendanceErrorCode.qrExpired:
      case QrAttendanceErrorCode.tokenMismatch:
        return _tr('انتهت صلاحية الرمز', 'Code expired');
      case QrAttendanceErrorCode.sessionClosed:
        return _tr('تم إغلاق الجلسة', 'Session closed');
      case QrAttendanceErrorCode.studentNotEnrolled:
        return _tr(
          'الطالبة غير مسجلة في هذه الشعبة',
          'You are not enrolled in this section',
        );
      case QrAttendanceErrorCode.alreadyMarked:
        return _tr('تم تسجيل الحضور مسبقًا', 'Attendance already recorded');
      default:
        return e.message;
    }
  }

  String _friendlySessionErrorMessage(NfcError error) {
    if (error.type == NfcErrorType.userCanceled) {
      return _tr('تم إلغاء جلسة NFC.', 'NFC session was canceled.');
    }

    final raw = error.message.trim();
    final lowered = raw.toLowerCase();

    if (Platform.isIOS && lowered.contains('missing required entitlement')) {
      return _tr(
        'تعذر بدء NFC بسبب إعدادات iOS. فعّلي Near Field Communication Tag Reading في Signing & Capabilities ثم أعيدي البناء على الجهاز.',
        'NFC failed to start due to iOS app capabilities. Enable Near Field Communication Tag Reading in Signing & Capabilities, then rebuild on the device.',
      );
    }

    if (raw.isNotEmpty) {
      return raw;
    }

    return _tr(
      'تم إيقاف جلسة NFC. أعيدي المحاولة.',
      'NFC session was stopped. Please try again.',
    );
  }

  String _extractCardId(NfcTag tag) {
    final fromNdef = _extractCardIdFromNdef(tag);
    if (fromNdef.isNotEmpty) {
      return _extractLecturerCardIdFromText(fromNdef);
    }

    final data = tag.data;
    final candidates = <dynamic>[
      _dig(data, ['mifare', 'identifier']),
      _dig(data, ['iso15693', 'identifier']),
      _dig(data, ['iso7816', 'identifier']),
      _dig(data, ['iso15693', 'icSerialNumber']),
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

  String _extractLecturerCardIdFromText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return '';

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final payload = Map<String, dynamic>.from(decoded);
        final type = (payload['type'] ?? '').toString().trim().toLowerCase();
        final id = (payload['id'] ?? '').toString().trim();
        if (type == 'lecturer_card' && id.isNotEmpty) {
          return NfcAttendanceService.normalizeLecturerCardId(id);
        }
      }
    } catch (_) {
      // Fallback to legacy plain text card payload.
    }

    return NfcAttendanceService.normalizeLecturerCardId(text);
  }

  String _extractCardIdFromNdef(NfcTag tag) {
    final ndef = Ndef.from(tag);
    final message = ndef?.cachedMessage;
    if (message == null) return '';

    for (final record in message.records) {
      final textValue = _decodeNdefRecordAsText(record);
      if (textValue.isNotEmpty) {
        return textValue;
      }
    }

    return '';
  }

  String _decodeNdefRecordAsText(NdefRecord record) {
    final payload = record.payload;
    if (payload.isEmpty) return '';

    final type = ascii.decode(record.type, allowInvalid: true);
    if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
        type == 'T') {
      final status = payload.first;
      final languageLength = status & 0x3F;
      if (payload.length <= languageLength + 1) return '';
      final textBytes = payload.sublist(languageLength + 1);
      return utf8.decode(textBytes, allowMalformed: true).trim();
    }

    return utf8.decode(payload, allowMalformed: true).trim();
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

  Future<void> _startQrScanner() async {
    if (_isNfc || _isStartingQrScanner || _isProcessingQrScan) return;
    if (_qrCameraUnavailable || _qrPermissionDenied || !_qrScannerInitialized) {
      return;
    }

    setState(() {
      _isStartingQrScanner = true;
      _qrPermissionDenied = false;
      _qrCameraUnavailable = false;
      _isQrScanPaused = false;
    });

    try {
      await _qrScannerController?.resumeCamera();
      if (!mounted) return;
      setState(() {
        if (!_qrStatusError) {
          _qrStatusMessage = _tr(
            'وجّه الكاميرا نحو رمز التحضير المعروض لدى المحاضر.',
            'Point the camera at the attendance QR shown by the lecturer.',
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _qrStatusError = true;
        _isQrScanPaused = true;
        _qrCameraUnavailable = true;
        _qrStatusMessage = _tr(
          'الكاميرا غير متاحة حالياً على هذا الجهاز.',
          'Camera is not available on this device right now.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isStartingQrScanner = false);
      }
    }
  }

  Future<void> _stopQrScanner() async {
    try {
      await _qrScannerController?.pauseCamera();
    } catch (_) {
      // no-op
    }
  }

  Future<void> _retryQrScan() async {
    if (!mounted) return;
    setState(() {
      _isEnteringQrCode = false;
      _qrStatusError = false;
      _isProcessingQrScan = false;
      _isQrScanPaused = false;
    });
    await _prepareQrScanner();
  }

  Future<void> _showAttendanceCodeEntry() async {
    if (!mounted || _isNfc) return;
    await _stopQrScanner();
    setState(() {
      _isEnteringQrCode = true;
      _isQrScanPaused = true;
      _qrStatusError = false;
      _qrStatusMessage = _tr(
        'أدخلي رمز الحضور المعروض لدى المحاضر.',
        'Enter the attendance code shown by the lecturer.',
      );
    });
  }

  Future<void> _submitAttendanceCode() async {
    if (_isSubmittingAttendanceCode || _isNfc) return;
    final code = _attendanceCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _qrStatusError = true;
        _qrStatusMessage = _tr('رمز الحضور مطلوب', 'Code is required');
      });
      return;
    }

    setState(() {
      _isSubmittingAttendanceCode = true;
      _qrStatusError = false;
      _qrStatusMessage = _tr('جاري التحقق من الرمز...', 'Verifying code...');
    });

    try {
      final result = await _qrAttendance.submitAttendanceFromNumericCode(
        code,
        currentTime: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _isSubmittingAttendanceCode = false;
        _qrStatusError = false;
        _qrStatusMessage = _tr(
          'تم تسجيل الحضور بنجاح',
          'Attendance recorded successfully',
        );
      });
      try {
        await StudentNotificationsService.instance
            .addAttendanceSuccessNotification(
              studentId:
                  StudentAuthService.instance.currentStudent?.studentId ?? 0,
              attendanceMethod: 'qr',
              courseName: result.session.courseName,
              section: result.session.section,
              sectionId: result.session.sectionId,
              sessionId: result.session.sessionId,
              lectureDate: result.session.lectureDate,
              lectureStartTime: result.session.lectureStartTime,
              lectureEndTime: result.session.lectureEndTime,
            );
      } catch (_) {}
      if (!mounted) return;
      await AttendanceResultPopup.show(
        context,
        success: true,
        message: _tr(
          'تم تسجيل حضورك بنجاح',
          'Attendance recorded successfully',
        ),
        subtitle: _tr(
          'تم تسجيل الحضور بنجاح',
          'Attendance recorded successfully',
        ),
      );
    } on QrAttendanceException catch (e) {
      if (!mounted) return;
      final message = _friendlyQrCodeMessage(e);
      setState(() {
        _isSubmittingAttendanceCode = false;
        _qrStatusError = true;
        _qrStatusMessage = message;
      });
      await AttendanceResultPopup.show(
        context,
        success: false,
        message: _tr('فشل تسجيل الحضور', 'Attendance failed'),
        subtitle: message,
        autoDismiss: false,
      );
    } catch (_) {
      if (!mounted) return;
      final message = _tr(
        'تعذر تسجيل الحضور حالياً. يرجى المحاولة مرة أخرى.',
        'Unable to record attendance right now. Please try again.',
      );
      setState(() {
        _isSubmittingAttendanceCode = false;
        _qrStatusError = true;
        _qrStatusMessage = message;
      });
      await AttendanceResultPopup.show(
        context,
        success: false,
        message: _tr('فشل تسجيل الحضور', 'Attendance failed'),
        subtitle: message,
        autoDismiss: false,
      );
    }
  }

  Future<void> _prepareQrScanner() async {
    if (!mounted || _isNfc || _checkingQrAvailability) return;

    setState(() {
      _checkingQrAvailability = true;
      _qrStatusError = false;
      _qrPermissionDenied = false;
      _qrCameraUnavailable = false;
      _qrStatusMessage = _tr(
        'جاري تجهيز ماسح QR...',
        'Preparing QR scanner...',
      );
    });

    final availability = await _resolveQrCameraAvailability();
    if (!mounted || _isNfc) return;

    setState(() {
      _checkingQrAvailability = false;
      _qrCameraUnavailable = !availability.available;
      _qrScannerInitialized = availability.available;
      _isQrScanPaused = !availability.available;
      _qrStatusError = !availability.available;
      _qrStatusMessage =
          availability.message ??
          _tr(
            'وجّه الكاميرا نحو رمز التحضير المعروض لدى المحاضر.',
            'Point the camera at the attendance QR shown by the lecturer.',
          );
    });

    if (availability.available) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isNfc) return;
        _startQrScanner();
      });
    }
  }

  Future<_QrCameraAvailability> _resolveQrCameraAvailability() async {
    if (!Platform.isIOS) {
      return const _QrCameraAvailability.available();
    }

    try {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      if (!iosInfo.isPhysicalDevice) {
        return const _QrCameraAvailability.unavailable(
          'الكاميرا غير متاحة على المحاكي. الرجاء التجربة على جهاز حقيقي أو استخدام جهاز يدعم الكاميرا.',
        );
      }
    } catch (_) {
      // If simulator detection fails, fall back to trying the real scanner.
    }

    return const _QrCameraAvailability.available();
  }

  Future<void> _handleQrDetect(Barcode scanData) async {
    if (_isProcessingQrScan || _isNfc) return;

    final rawValue = scanData.code?.trim() ?? '';
    if (rawValue.isEmpty) {
      await _stopQrScanner();
      if (!mounted) return;
      setState(() {
        _isQrScanPaused = true;
        _qrStatusError = true;
        _qrStatusMessage =
            'رمز QR غير صالح. الرجاء مسح رمز التحضير من شاشة المحاضر.';
      });
      return;
    }

    setState(() {
      _isProcessingQrScan = true;
      _isQrScanPaused = true;
    });

    await _stopQrScanner();

    final payload = _tryParseQrPayload(rawValue);
    if (!mounted) return;

    if (payload == null) {
      setState(() {
        _isProcessingQrScan = false;
        _qrStatusError = true;
        _qrStatusMessage =
            'رمز QR غير صالح. الرجاء مسح رمز التحضير من شاشة المحاضر.';
      });
      return;
    }

    if (kDebugMode) {
      debugPrint(
        'QR scan read successfully for session ${payload['sessionId']} / section ${payload['sectionId']}',
      );
    }

    try {
      final result = await _qrAttendance.submitAttendanceFromQrPayload(
        payload,
        currentTime: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _isProcessingQrScan = false;
        _qrStatusError = false;
        _qrStatusMessage = result.message;
      });
      try {
        await StudentNotificationsService.instance
            .addAttendanceSuccessNotification(
              studentId:
                  StudentAuthService.instance.currentStudent?.studentId ?? 0,
              attendanceMethod: 'qr',
              courseName: result.session.courseName,
              section: result.session.section,
              sectionId: result.session.sectionId,
              sessionId: result.session.sessionId,
              lectureDate: result.session.lectureDate,
              lectureStartTime: result.session.lectureStartTime,
              lectureEndTime: result.session.lectureEndTime,
            );
      } catch (_) {}
      if (!mounted) return;
      await AttendanceResultPopup.show(
        context,
        success: true,
        message: _tr(
          'تم تسجيل حضورك بنجاح',
          'Attendance recorded successfully',
        ),
        subtitle: TranslationController.instance.translateToEnglish
            ? 'Your attendance has been recorded.'
            : result.message,
      );
    } on QrAttendanceException catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingQrScan = false;
        _qrStatusError = true;
        _qrStatusMessage = e.message;
      });
      await AttendanceResultPopup.show(
        context,
        success: false,
        message: _tr('فشل تسجيل الحضور', 'Attendance failed'),
        subtitle: e.message,
        autoDismiss: false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessingQrScan = false;
        _qrStatusError = true;
        _qrStatusMessage = _tr(
          'تعذر تسجيل الحضور حالياً. يرجى المحاولة مرة أخرى.',
          'Unable to record attendance right now. Please try again.',
        );
      });
      await AttendanceResultPopup.show(
        context,
        success: false,
        message: _tr('فشل تسجيل الحضور', 'Attendance failed'),
        subtitle: _tr(
          'تعذر تسجيل الحضور حالياً. يرجى المحاولة مرة أخرى.',
          'Unable to record attendance right now. Please try again.',
        ),
        autoDismiss: false,
      );
    }
  }

  void _onQrViewCreated(QRViewController controller) {
    _qrScannerController = controller;

    controller.scannedDataStream.listen(
      (scanData) {
        _handleQrDetect(scanData);
      },
      onError: (_) {
        if (!mounted || _isNfc) return;
        setState(() {
          _isProcessingQrScan = false;
          _isQrScanPaused = true;
          _qrCameraUnavailable = true;
          _qrStatusError = true;
          _qrStatusMessage = _tr(
            'الكاميرا غير متاحة حالياً على هذا الجهاز.',
            'Camera is not available on this device right now.',
          );
        });
      },
    );

    if (!_isNfc && !_qrCameraUnavailable) {
      _startQrScanner();
    }
  }

  void _onQrPermissionSet(QRViewController controller, bool hasPermission) {
    if (!mounted || _isNfc) return;

    if (hasPermission) {
      setState(() {
        _qrPermissionDenied = false;
        _qrCameraUnavailable = false;
        _qrStatusError = false;
        if (!_isProcessingQrScan) {
          _qrStatusMessage = _tr(
            'وجّه الكاميرا نحو رمز التحضير المعروض لدى المحاضر.',
            'Point the camera at the attendance QR shown by the lecturer.',
          );
        }
      });
      return;
    }

    setState(() {
      _qrPermissionDenied = true;
      _qrStatusError = true;
      _isQrScanPaused = true;
      _qrStatusMessage = _tr(
        'لم يتم السماح باستخدام الكاميرا. يرجى تفعيل صلاحية الكاميرا لمسح رمز QR.',
        'Camera permission is not granted. Please enable camera access to scan the QR.',
      );
    });
  }

  Map<String, dynamic>? _tryParseQrPayload(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) return null;
      final payload = Map<String, dynamic>.from(decoded);

      final sessionId = (payload['sessionId'] ?? '').toString().trim();
      final sectionId = (payload['sectionId'] ?? '').toString().trim();
      final tokenId = (payload['tokenId'] ?? '').toString().trim();
      final tokenVersion = payload['tokenVersion'];
      final expiresAt = (payload['expiresAt'] ?? '').toString().trim();

      final hasRequiredValues =
          sessionId.isNotEmpty &&
          sectionId.isNotEmpty &&
          tokenId.isNotEmpty &&
          expiresAt.isNotEmpty &&
          (tokenVersion is int || tokenVersion is num);

      if (!hasRequiredValues) return null;
      return payload;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _attendanceCodeController.dispose();
    try {
      NfcManager.instance.stopSession();
    } catch (_) {
      // no-op
    }
    _qrScannerController = null;
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
                                            ? _tr(
                                                'جاري التحقق...',
                                                'Checking...',
                                              )
                                            : _tr(
                                                'بدء التحضير',
                                                'Start attendance',
                                              ),
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
                            Container(
                              width: 260,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD7F1F1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _ModeChip(
                                      label: _tr('رمز QR', 'QR Code'),
                                      isActive: !_isEnteringQrCode,
                                      onTap: _retryQrScan,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _ModeChip(
                                      label: _tr(
                                        'إدخال رمز الحضور',
                                        'Enter Code',
                                      ),
                                      isActive: _isEnteringQrCode,
                                      onTap: _showAttendanceCodeEntry,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: 290,
                              height: 290,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: const Color(0xFF006571),
                                  width: 2,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (_isEnteringQrCode)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.pin_rounded,
                                            size: 46,
                                            color: Color(0xFF006571),
                                          ),
                                          const SizedBox(height: 14),
                                          TextField(
                                            controller:
                                                _attendanceCodeController,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            maxLength: 6,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 28,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 3,
                                              color: Color(0xFF1F2E33),
                                            ),
                                            decoration: InputDecoration(
                                              counterText: '',
                                              labelText: _tr(
                                                'رمز الحضور',
                                                'Attendance Code',
                                              ),
                                              labelStyle: const TextStyle(
                                                fontFamily: 'Cairo',
                                                color: Color(0xFF5F7A80),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFCCE8EA),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFF006571),
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                            onSubmitted: (_) =>
                                                _submitAttendanceCode(),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (_qrScannerInitialized)
                                    QRView(
                                      key: _qrViewKey,
                                      onQRViewCreated: _onQrViewCreated,
                                      onPermissionSet: _onQrPermissionSet,
                                      overlay: QrScannerOverlayShape(
                                        borderColor: Colors.transparent,
                                        overlayColor: Colors.transparent,
                                        borderWidth: 0,
                                        cutOutSize: 190,
                                      ),
                                    ),
                                  if (!_isEnteringQrCode &&
                                      (!_qrScannerInitialized ||
                                          _qrPermissionDenied ||
                                          _qrCameraUnavailable))
                                    _QrScannerFallback(
                                      message: _checkingQrAvailability
                                          ? _tr(
                                              'جاري تجهيز الكاميرا...',
                                              'Preparing camera...',
                                            )
                                          : _qrPermissionDenied
                                          ? _tr(
                                              'لم يتم السماح باستخدام الكاميرا. يرجى تفعيل صلاحية الكاميرا لمسح رمز QR.',
                                              'Camera permission is not granted. Please enable camera access to scan the QR.',
                                            )
                                          : _qrStatusMessage,
                                      showRetry:
                                          !_checkingQrAvailability &&
                                          !_qrPermissionDenied,
                                      onRetry: _retryQrScan,
                                    ),
                                  if (!_isEnteringQrCode)
                                    IgnorePointer(
                                      child: Container(
                                        width: 190,
                                        height: 190,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_isStartingQrScanner)
                                    Container(
                                      color: Colors.black.withValues(
                                        alpha: 0.22,
                                      ),
                                      alignment: Alignment.center,
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _qrStatusError
                                    ? const Color(0xFFFFEBEE)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _qrStatusError
                                      ? const Color(0xFFE57373)
                                      : const Color(0xFFCCE8EA),
                                ),
                              ),
                              child: Text(
                                _qrStatusMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _qrStatusError
                                      ? const Color(0xFFB71C1C)
                                      : const Color(0xFF35565E),
                                  fontSize: 13,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: 210,
                              height: 44,
                              child: FilledButton(
                                onPressed:
                                    (_isEnteringQrCode
                                        ? _isSubmittingAttendanceCode
                                        : (_isStartingQrScanner ||
                                              _isProcessingQrScan))
                                    ? null
                                    : (_isEnteringQrCode
                                          ? _submitAttendanceCode
                                          : _retryQrScan),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF006571),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: Text(
                                  _isEnteringQrCode
                                      ? _tr('تحقق من الرمز', 'Verify Code')
                                      : _isQrScanPaused
                                      ? _tr('إعادة المسح', 'Scan again')
                                      : _tr('بدء مسح QR', 'Start QR scan'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
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

class _QrScannerFallback extends StatelessWidget {
  const _QrScannerFallback({
    required this.message,
    required this.showRetry,
    required this.onRetry,
  });

  final String message;
  final bool showRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFDBF2F2),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.qr_code_scanner_rounded,
              size: 48,
              color: Color(0xFF006571),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF35565E),
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (showRetry) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF006571),
                  side: const BorderSide(color: Color(0xFF006571)),
                ),
                child: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QrCameraAvailability {
  const _QrCameraAvailability._({required this.available, this.message});

  const _QrCameraAvailability.available() : this._(available: true);

  const _QrCameraAvailability.unavailable(String message)
    : this._(available: false, message: message);

  final bool available;
  final String? message;
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
