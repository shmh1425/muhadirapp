import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' show min;

// ignore: depend_on_referenced_packages
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../../features/attendance/attendance_session_snapshot.dart';
import '../../features/attendance/attendance_submission_result.dart';
import '../../features/attendance/state/attendance_operation_ui_state.dart';
import '../../features/attendance/state/attendance_state_event.dart';
import '../../features/attendance/state/attendance_state_service.dart';
import '../../features/attendance/state/attendance_sync_event_router.dart';
import '../../features/attendance/ui/student_attendance_status_banner.dart';
import '../../features/attendance/bluetooth_attendance_entry_service.dart';
import '../../features/attendance/nfc_attendance_entry_service.dart';
import '../../features/attendance/qr_attendance_entry_service.dart';
import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';
import '../../services/attendance/bluetooth_attendance_service.dart';
import '../../services/attendance/bluetooth_ble_service.dart';
import '../../services/attendance/nfc_attendance_service.dart';
import '../../services/nfc/nfc_tag_identifier.dart';
import '../../services/attendance/qr_attendance_service.dart';
import '../../services/geo/campus_geo_check_mode.dart';
import '../../services/geo/student_campus_geo_guard.dart';
import '../../services/student_auth_service.dart';
import '../../services/student_notifications_service.dart';
import '../../shared/widgets/chat_fab.dart';
import '../../shared/widgets/attendance_result_popup.dart';
import 'components/custom_nav_bar_icons.dart';
import 'components/notification_bell.dart';
import 'components/student_back_chevron_icon.dart';
import 'widgets/attendance_mode_chip.dart';
import 'widgets/student_geo_debug_toggle.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final BluetoothBleService _bluetoothBleService = BluetoothBleService.instance;
  final GlobalKey _qrViewKey = GlobalKey(debugLabel: 'student-qr-scanner');
  final TextEditingController _attendanceCodeController =
      TextEditingController();

  String _tr(String ar, String en) {
    return TranslationController.instance.translateToEnglish ? en : ar;
  }

  Future<void> _notifyAttendanceSuccess({
    required int studentId,
    required String attendanceMethod,
    AttendanceSessionSnapshot? snapshot,
  }) async {
    if (snapshot == null) return;
    try {
      await StudentNotificationsService.instance
          .addAttendanceSuccessNotification(
            studentId: studentId,
            attendanceMethod: attendanceMethod,
            courseName: snapshot.courseName,
            section: snapshot.section,
            sectionId: snapshot.sectionId,
            sessionId: snapshot.sessionId,
            lectureDate: snapshot.lectureDate,
            lectureStartTime: snapshot.lectureStartTime,
            lectureEndTime: snapshot.lectureEndTime,
          );
    } catch (_) {}
  }

  void _applyPipelineUiState(
    AttendanceSubmissionResult result, {
    required String sessionId,
    required String studentId,
  }) {
    final resolvedSession =
        result.sessionSnapshot?.sessionId?.trim().isNotEmpty == true
        ? result.sessionSnapshot!.sessionId!.trim()
        : sessionId.trim();
    final uiState = switch (result.outcome) {
      AttendanceSubmissionOutcome.queuedOffline => AttendanceUIState.pending,
      AttendanceSubmissionOutcome.rejectedOffline => AttendanceUIState.failed,
      AttendanceSubmissionOutcome.duplicateSkipped => AttendanceUIState.synced,
      AttendanceSubmissionOutcome.appliedOnline =>
        result.success ? AttendanceUIState.synced : AttendanceUIState.failed,
    };
    _trackedAttendanceSessionId = resolvedSession.isNotEmpty
        ? resolvedSession
        : _trackedAttendanceSessionId;
    AttendanceStateService.instance.setActiveSession(
      _trackedAttendanceSessionId,
    );
    AttendanceSyncEventRouter.instance.notifyPipelineOutcome(
      sessionId: resolvedSession.isNotEmpty ? resolvedSession : sessionId,
      studentId: studentId,
      state: uiState,
      operationId: result.requestId,
    );
    if (!mounted) return;
    setState(() => _selfAttendanceUiState = uiState);
  }

  String _pipelineUserMessage(AttendanceSubmissionResult result) {
    if (result.message != null && result.message!.trim().isNotEmpty) {
      return result.message!.trim();
    }
    switch (result.outcome) {
      case AttendanceSubmissionOutcome.queuedOffline:
        return _tr(
          'تم حفظ الحضور وسيتم مزامنته عند الاتصال',
          'Attendance saved and will sync when online',
        );
      case AttendanceSubmissionOutcome.duplicateSkipped:
        return _tr(
          'تم تسجيل هذا الحضور مسبقاً',
          'This attendance was already recorded',
        );
      case AttendanceSubmissionOutcome.rejectedOffline:
        return _tr(
          'يتطلب مسح QR اتصالاً بالإنترنت',
          'QR attendance requires an internet connection',
        );
      case AttendanceSubmissionOutcome.appliedOnline:
        return _tr('تم تسجيل الحضور بنجاح', 'Attendance recorded successfully');
    }
  }

  Future<String?> _campusGeoBlockMessage() async {
    const mode = CampusGeoCheckMode.todaySchedule;
    final blocked = await StudentCampusGeoGuard.blockingOutcome(mode: mode);
    if (blocked == null) return null;
    return StudentCampusGeoGuard.localizedMessage(blocked, mode: mode);
  }

  Future<void> _refreshCampusGeo() async {
    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _geoVerifying = false;
        _geoRequiredToday = false;
        _geoBlockMessage = null;
      });
      return;
    }

    setState(() => _geoVerifying = true);
    final required = await StudentCampusGeoGuard.attendanceGeoRequiredToday();
    if (!mounted) return;

    if (!required) {
      setState(() {
        _geoVerifying = false;
        _geoRequiredToday = false;
        _geoBlockMessage = null;
      });
      return;
    }

    const mode = CampusGeoCheckMode.todaySchedule;
    final blocked = await StudentCampusGeoGuard.blockingOutcome(mode: mode);
    if (!mounted) return;

    setState(() {
      _geoVerifying = false;
      _geoRequiredToday = true;
      _geoBlockMessage = blocked == null
          ? null
          : StudentCampusGeoGuard.localizedMessage(blocked, mode: mode);
    });

    if (_isAttendanceGeoBlocked) {
      if (_isScanning) {
        unawaited(_stopNfcSessionQuietly());
      }
      unawaited(_stopBluetoothScan());
      unawaited(_stopQrScanner());
    }
  }

  Future<void> _stopNfcSessionQuietly() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // no-op
    }
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _statusError = true;
      _statusMessage =
          _geoBlockMessage ??
          _tr(
            'أنت خارج حدود الحرم الجامعي.',
            'You are outside the university campus boundary.',
          );
    });
  }

  bool _isNfc = true;
  bool _isBluetooth = false;
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
  bool _isBluetoothScanning = false;
  bool _isSubmittingBluetoothAttendance = false;
  BluetoothScanResult? _bluetoothScanResult;
  StreamSubscription<BluetoothScanResult>? _bluetoothScanSub;

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

  bool _geoVerifying = true;
  bool _geoRequiredToday = false;
  String? _geoBlockMessage;
  AttendanceUIState _selfAttendanceUiState = AttendanceUIState.idle;
  String? _trackedAttendanceSessionId;
  StreamSubscription<AttendanceStateEvent>? _attendanceStateEventsSub;

  /// Geo-fence applies to QR attendance only (not NFC or Bluetooth).
  bool get _isAttendanceGeoBlocked =>
      !_isNfc &&
      !_isBluetooth &&
      _geoRequiredToday &&
      _geoBlockMessage != null &&
      !_geoVerifying;

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
    _stopBluetoothScan();
    setState(() {
      _isNfc = nfc;
      _isBluetooth = false;
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

    unawaited(_refreshCampusGeo());

    if (nfc) {
      _stopQrScanner();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isNfc || _isBluetooth || _isAttendanceGeoBlocked) return;
      _prepareQrScanner();
    });
  }

  void _toggleBluetoothMode() {
    setState(() {
      _isNfc = false;
      _isBluetooth = true;
      _statusError = false;
      _qrStatusError = false;
      _isEnteringQrCode = false;
      _isProcessingQrScan = false;
      _isQrScanPaused = true;
      _bluetoothScanResult = null;
      _qrStatusMessage = _tr(
        'اضغط «بدء البحث» لاكتشاف إشارة المحاضرة القريبة.',
        'Tap Start Scan to find a nearby lecture signal.',
      );
    });
    _stopQrScanner();
    unawaited(_refreshCampusGeo());
    unawaited(_refreshBluetoothAvailability());
  }

  Future<void> _refreshBluetoothAvailability() async {
    if (!mounted || !_isBluetooth || kIsWeb) return;
    final support = await _bluetoothBleService.checkPlatformSupport(
      BluetoothBleRole.scanner,
    );
    if (!mounted || !_isBluetooth) return;
    if (support.status == BluetoothBleSupportStatus.off) {
      setState(() {
        _bluetoothScanResult = BluetoothScanResult(
          state: BluetoothScanState.error,
          message: support.message,
        );
        _isBluetoothScanning = false;
      });
    }
  }

  bool _shouldShowBluetoothLecturerHint(BluetoothScanResult? result) {
    return result?.state == BluetoothScanState.notFound;
  }

  Future<void> _startBluetoothScan() async {
    if (_isBluetoothScanning) return;
    await _bluetoothScanSub?.cancel();
    setState(() {
      _isBluetoothScanning = true;
      _bluetoothScanResult = BluetoothScanResult(
        state: BluetoothScanState.scanning,
        message: _tr(
          'جارٍ البحث عن إشارة المحاضرة...',
          'Searching for lecture signal...',
        ),
      );
    });

    _bluetoothScanSub = _bluetoothBleService
        .startScanningForMuhadirSession(timeout: const Duration(seconds: 18))
        .listen(
          (result) {
            if (!mounted) return;
            setState(() {
              _bluetoothScanResult = result;
              _isBluetoothScanning =
                  result.state == BluetoothScanState.scanning;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _isBluetoothScanning = false;
              _bluetoothScanResult = BluetoothScanResult(
                state: BluetoothScanState.error,
                message: _tr(
                  'تعذر البحث عبر البلوتوث حالياً.',
                  'Unable to scan with Bluetooth right now.',
                ),
              );
            });
          },
          onDone: () {
            if (!mounted) return;
            setState(() => _isBluetoothScanning = false);
          },
        );
  }

  Future<void> _stopBluetoothScan() async {
    await _bluetoothScanSub?.cancel();
    _bluetoothScanSub = null;
    await _bluetoothBleService.stopScanning();
    if (!mounted) return;
    setState(() => _isBluetoothScanning = false);
  }

  Future<void> _submitBluetoothAttendance() async {
    if (_isSubmittingBluetoothAttendance) return;
    final detection = _bluetoothScanResult?.detection;
    if (detection == null) {
      await AttendanceResultPopup.show(
        context,
        success: false,
        message: _tr(
          'لم يتم العثور على جلسة بلوتوث صالحة',
          'No valid Bluetooth session found',
        ),
      );
      return;
    }

    setState(() => _isSubmittingBluetoothAttendance = true);
    try {
      final student = StudentAuthService.instance.currentStudent;
      final pipelineResult =
          await BluetoothAttendanceEntryService.submitFromSignal(
            sessionId: '',
            courseId: '',
            studentId: (student?.studentId ?? 0).toString(),
            sessionIdHash: detection.sessionIdHash,
            tokenFragment: detection.tokenFragment,
            tokenVersion: detection.tokenVersion,
            detectedSignalStrength: detection.rssi,
            detectedSignalId: detection.sessionIdHash ?? detection.deviceName,
            rawPayload: detection.rawPayload,
          );
      final resultMessage = pipelineResult.message ?? '';
      _applyPipelineUiState(
        pipelineResult,
        sessionId: pipelineResult.sessionSnapshot?.sessionId ?? '',
        studentId: (student?.studentId ?? 0).toString(),
      );

      await _stopBluetoothScan();
      if (!mounted) return;
      setState(() {
        _bluetoothScanResult = BluetoothScanResult(
          state: BluetoothScanState.detected,
          message: resultMessage,
          detection: detection,
        );
      });

      if (student != null) {
        await _notifyAttendanceSuccess(
          studentId: student.studentId,
          attendanceMethod: 'bluetooth',
          snapshot: pipelineResult.sessionSnapshot,
        );
      }

      if (!mounted) return;
      if (!pipelineResult.success) {
        final message = _pipelineUserMessage(pipelineResult);
        setState(() {
          _bluetoothScanResult = BluetoothScanResult(
            state: BluetoothScanState.error,
            message: message,
            detection: detection,
          );
        });
        await AttendanceResultPopup.show(
          context,
          success: false,
          message: message,
        );
        return;
      }

      await AttendanceResultPopup.show(
        context,
        success: true,
        message: _pipelineUserMessage(pipelineResult),
      );
    } on BluetoothAttendanceException catch (e) {
      if (!mounted) return;
      final message = _localizedBluetoothSubmitError(e);
      setState(() {
        _bluetoothScanResult = BluetoothScanResult(
          state: BluetoothScanState.error,
          message: message,
          detection: detection,
        );
      });
      await AttendanceResultPopup.show(
        context,
        success: false,
        message: message,
      );
    } catch (_) {
      if (!mounted) return;
      final message = _tr(
        'تعذر تسجيل الحضور عبر البلوتوث حالياً.',
        'Unable to record Bluetooth attendance right now.',
      );
      setState(() {
        _bluetoothScanResult = BluetoothScanResult(
          state: BluetoothScanState.error,
          message: message,
          detection: detection,
        );
      });
      await AttendanceResultPopup.show(
        context,
        success: false,
        message: message,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingBluetoothAttendance = false);
      }
    }
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
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _checkNfcAvailability();
    unawaited(_refreshCampusGeo());
    StudentCampusGeoGuard.debugSkipGeoFenceForTesting.addListener(
      _onAttendanceGeoDebugToggle,
    );
    final student = StudentAuthService.instance.currentStudent;
    if (student != null) {
      final studentId = student.studentId.toString();
      AttendanceSyncEventRouter.instance.attachStudent(studentId: studentId);
      _attendanceStateEventsSub?.cancel();
      _attendanceStateEventsSub = AttendanceStateService
          .instance
          .attendanceStateEvents
          .listen((event) {
            if (!mounted || event.studentId != studentId) return;
            setState(() {
              _selfAttendanceUiState = event.model.state;
              _trackedAttendanceSessionId = event.sessionId;
            });
          });
    }
  }

  void _onAttendanceGeoDebugToggle() {
    if (!mounted) return;
    unawaited(_refreshCampusGeo());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshCampusGeo());
    }
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
    if (_isScanning || !_isNfc || _isBluetooth) return;

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
            final pipelineResult =
                await NfcAttendanceEntryService.submitFromCardTap(
                  lecturerCardId: cardId,
                  studentId: student.studentId,
                  sessionId: 'nfc_pending',
                  courseId: 'nfc',
                  requestId:
                      'nfc_${cardId}_${student.studentId}_${DateTime.now().millisecondsSinceEpoch}',
                );
            final userMessage = _pipelineUserMessage(pipelineResult);
            _applyPipelineUiState(
              pipelineResult,
              sessionId: 'nfc_pending',
              studentId: student.studentId.toString(),
            );

            await NfcManager.instance.stopSession(
              alertMessage: TranslationController.instance.translateToEnglish
                  ? 'Attendance recorded successfully.'
                  : userMessage,
            );
            if (!mounted) return;
            setState(() {
              _isScanning = false;
              _statusError = !pipelineResult.success;
              _statusMessage = userMessage;
            });
            await _notifyAttendanceSuccess(
              studentId: student.studentId,
              attendanceMethod: 'nfc',
              snapshot: pipelineResult.sessionSnapshot,
            );
            if (!mounted) return;
            await AttendanceResultPopup.show(
              context,
              success: pipelineResult.success,
              message: pipelineResult.success
                  ? _tr(
                      'تم تسجيل حضورك بنجاح',
                      'Attendance recorded successfully',
                    )
                  : _tr('فشل تسجيل الحضور', 'Attendance failed'),
              subtitle: userMessage,
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

  String _extractCardId(NfcTag tag) =>
      NfcTagIdentifier.extractNormalizedId(tag);

  Future<void> _startQrScanner() async {
    if (_isNfc ||
        _isBluetooth ||
        _isStartingQrScanner ||
        _isProcessingQrScan ||
        _isAttendanceGeoBlocked) {
      return;
    }
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
    if (_isBluetooth) return;
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
    if (!mounted || _isNfc || _isBluetooth) return;
    await _stopQrScanner();
    setState(() {
      _isEnteringQrCode = true;
      _isQrScanPaused = true;
      _qrStatusError = false;
    });
  }

  Future<void> _submitAttendanceCode() async {
    if (_isSubmittingAttendanceCode ||
        _isNfc ||
        _isBluetooth ||
        _isAttendanceGeoBlocked) {
      return;
    }
    final code = _attendanceCodeController.text.trim();
    if (code.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('رمز الحضور مطلوب', 'Code is required'),
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
          ),
          backgroundColor: const Color(0xFF006571),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final geoMsg = await _campusGeoBlockMessage();
    if (!mounted) return;
    if (geoMsg != null) {
      setState(() {
        _qrStatusError = true;
        _qrStatusMessage = geoMsg;
      });
      return;
    }

    setState(() {
      _isSubmittingAttendanceCode = true;
      _qrStatusError = false;
    });

    try {
      final pipelineResult =
          await QrAttendanceEntryService.submitFromNumericCode(
            numericCode: code,
            requestId: 'qr_code_${DateTime.now().millisecondsSinceEpoch}',
          );
      final userMessage = _pipelineUserMessage(pipelineResult);
      final student = StudentAuthService.instance.currentStudent;
      if (student != null) {
        _applyPipelineUiState(
          pipelineResult,
          sessionId: '',
          studentId: student.studentId.toString(),
        );
      }
      if (!mounted) return;
      setState(() {
        _isSubmittingAttendanceCode = false;
        _qrStatusError = !pipelineResult.success;
        _qrStatusMessage = userMessage;
      });
      if (student != null) {
        await _notifyAttendanceSuccess(
          studentId: student.studentId,
          attendanceMethod: 'qr',
          snapshot: pipelineResult.sessionSnapshot,
        );
      }
      if (!mounted) return;
      await AttendanceResultPopup.show(
        context,
        success: pipelineResult.success,
        message: pipelineResult.success
            ? _tr('تم تسجيل حضورك بنجاح', 'Attendance recorded successfully')
            : _tr('فشل تسجيل الحضور', 'Attendance failed'),
        subtitle: userMessage,
        autoDismiss: pipelineResult.success,
      );
      if (!pipelineResult.success) return;
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
    if (!mounted ||
        _isNfc ||
        _isBluetooth ||
        _checkingQrAvailability ||
        _isAttendanceGeoBlocked) {
      return;
    }

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
    if (!mounted || _isNfc || _isBluetooth) return;

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
        if (!mounted || _isNfc || _isBluetooth) return;
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
    if (_isProcessingQrScan || _isNfc || _isBluetooth) return;

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

    final geoMsg = await _campusGeoBlockMessage();
    if (!mounted) return;
    if (geoMsg != null) {
      setState(() {
        _isQrScanPaused = true;
        _qrStatusError = true;
        _qrStatusMessage = geoMsg;
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
      final pipelineResult = await QrAttendanceEntryService.submitFromQrPayload(
        qrPayload: payload,
        requestId:
            'qr_${payload['sessionId']}_${DateTime.now().millisecondsSinceEpoch}',
      );
      final userMessage = _pipelineUserMessage(pipelineResult);
      final student = StudentAuthService.instance.currentStudent;
      if (student != null) {
        _applyPipelineUiState(
          pipelineResult,
          sessionId: (payload['sessionId'] ?? '').toString(),
          studentId: student.studentId.toString(),
        );
      }
      if (!mounted) return;
      setState(() {
        _isProcessingQrScan = false;
        _qrStatusError = !pipelineResult.success;
        _qrStatusMessage = userMessage;
      });
      if (student != null) {
        await _notifyAttendanceSuccess(
          studentId: student.studentId,
          attendanceMethod: 'qr',
          snapshot: pipelineResult.sessionSnapshot,
        );
      }
      if (!mounted) return;
      await AttendanceResultPopup.show(
        context,
        success: pipelineResult.success,
        message: pipelineResult.success
            ? _tr('تم تسجيل حضورك بنجاح', 'Attendance recorded successfully')
            : _tr('فشل تسجيل الحضور', 'Attendance failed'),
        subtitle: userMessage,
        autoDismiss: pipelineResult.success,
      );
      if (!pipelineResult.success) return;
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
        if (!mounted || _isNfc || _isBluetooth) return;
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

    if (!_isNfc && !_isBluetooth && !_qrCameraUnavailable) {
      _startQrScanner();
    }
  }

  void _onQrPermissionSet(QRViewController controller, bool hasPermission) {
    if (!mounted || _isNfc || _isBluetooth) return;

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
    StudentCampusGeoGuard.debugSkipGeoFenceForTesting.removeListener(
      _onAttendanceGeoDebugToggle,
    );
    WidgetsBinding.instance.removeObserver(this);
    _pulseController?.dispose();
    _attendanceCodeController.dispose();
    _bluetoothScanSub?.cancel();
    _bluetoothBleService.stopScanning();
    try {
      NfcManager.instance.stopSession();
    } catch (_) {
      // no-op
    }
    _qrScannerController = null;
    _attendanceStateEventsSub?.cancel();
    AttendanceSyncEventRouter.instance.detach();
    super.dispose();
  }

  Widget _buildGeoVerifyingPanel() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF006571),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _tr('جاري التحقق من موقعك...', 'Checking your location...'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeoBlockedPanel() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_off_rounded,
            size: 52,
            color: Color(0xFFB71C1C),
          ),
          const SizedBox(height: 14),
          Text(
            _tr('خارج الحرم الجامعي', 'Outside campus'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB71C1C),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFFB71C1C).withValues(alpha: 0.16)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE57373)),
            ),
            child: Text(
              _geoBlockMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB71C1C),
                fontSize: 13,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: _geoVerifying
                ? null
                : () => unawaited(_refreshCampusGeo()),
            icon: const Icon(
              Icons.my_location_rounded,
              color: Color(0xFF006571),
            ),
            label: Text(
              _tr('إعادة التحقق من الموقع', 'Check location again'),
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothPlaceholderPanel() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = _bluetoothScanResult;
    final detection = result?.detection;
    final statusColor = switch (result?.state) {
      BluetoothScanState.detected => const Color(0xFF2B9E56),
      BluetoothScanState.error ||
      BluetoothScanState.unsupported ||
      BluetoothScanState.notFound => const Color(0xFFD14A4A),
      _ => const Color(0xFF35565E),
    };
    final statusMessage = result == null
        ? (kIsWeb
              ? _tr(
                  'مسح البلوتوث يتطلب جهازًا محمولًا مدعومًا.',
                  'Bluetooth scanning requires a supported mobile device.',
                )
              : _tr(
                  'تأكّد من تشغيل البلوتوث ثم ابدأ البحث عن إشارة المحاضرة.',
                  'Make sure Bluetooth is turned on, then start searching for the lecture signal.',
                ))
        : _localizedBluetoothScanMessage(result);
    final showLecturerHint = _shouldShowBluetoothLecturerHint(result);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 122,
            height: 122,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surface,
              border: Border.all(color: const Color(0xFF006571), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF006571).withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.bluetooth_rounded,
              size: 56,
              color: Color(0xFF006571),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _tr('التحضير عبر البلوتوث', 'Bluetooth Attendance'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? scheme.outlineVariant.withValues(alpha: 0.55)
                    : const Color(0xFFCCE8EA),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                if (showLecturerHint) ...[
                  const SizedBox(height: 10),
                  Text(
                    _tr(
                      'اطلب من المحاضر تفعيل جلسة البلوتوث وبدء البث.',
                      'Ask your lecturer to activate Bluetooth attendance and start broadcasting.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
                if (detection != null) ...[
                  const SizedBox(height: 12),
                  _BluetoothDetectionLine(
                    label: _tr('قوة الإشارة', 'Signal strength'),
                    value: '${detection.rssi} dBm',
                  ),
                  const SizedBox(height: 6),
                  if (detection.tokenVersion != null)
                    _BluetoothDetectionLine(
                      label: _tr('إصدار الرمز', 'Token version'),
                      value: detection.tokenVersion.toString(),
                    )
                  else
                    _BluetoothDetectionLine(
                      label: _tr('حالة الجلسة', 'Session status'),
                      value: _tr(
                        'تم العثور على إشارة المحاضرة، سيتم التحقق من الجلسة النشطة',
                        'Lecture signal found. The active session will be verified.',
                      ),
                    ),
                  const SizedBox(height: 6),
                  _BluetoothDetectionLine(
                    label: _tr('معرّف الإشارة', 'Signal ID'),
                    value: detection.sessionIdHash ?? detection.deviceName,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 240,
            height: 44,
            child: FilledButton.icon(
              onPressed: _isAttendanceGeoBlocked
                  ? null
                  : _isSubmittingBluetoothAttendance
                  ? null
                  : _isBluetoothScanning
                  ? _stopBluetoothScan
                  : _startBluetoothScan,
              icon: _isBluetoothScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bluetooth_searching_rounded, size: 18),
              label: Text(
                _isBluetoothScanning
                    ? _tr('إيقاف البحث', 'Stop Scan')
                    : _tr('بدء البحث', 'Start Scan'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                  color: Colors.white,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF006571),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white70,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          if (detection != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 280,
              height: 46,
              child: FilledButton.icon(
                onPressed:
                    _isSubmittingBluetoothAttendance || _isBluetoothScanning
                    ? null
                    : _submitBluetoothAttendance,
                icon: _isSubmittingBluetoothAttendance
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.how_to_reg_rounded, size: 18),
                label: Text(
                  _isSubmittingBluetoothAttendance
                      ? _tr('جاري التسجيل...', 'Submitting...')
                      : _tr(
                          'تسجيل الحضور عبر البلوتوث',
                          'Submit Bluetooth Attendance',
                        ),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                    color: Colors.white,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2B9E56),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  disabledBackgroundColor: const Color(0xFFB6C7C9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _localizedBluetoothScanMessage(BluetoothScanResult result) {
    switch (result.state) {
      case BluetoothScanState.scanning:
      case BluetoothScanState.requestingPermission:
        return _tr(
          'جارٍ البحث عن إشارة المحاضرة...',
          'Searching for lecture signal...',
        );
      case BluetoothScanState.detected:
        return _tr(
          'تم العثور على إشارة المحاضرة. اضغط «تسجيل الحضور» للمتابعة.',
          'Lecture signal found. Tap Submit Bluetooth Attendance to continue.',
        );
      case BluetoothScanState.notFound:
        return _tr(
          'تعذّر العثور على إشارة المحاضرة.',
          'Could not find the lecture signal.',
        );
      case BluetoothScanState.unsupported:
        return _tr(
          'البلوتوث غير مدعوم على هذا الجهاز.',
          'Bluetooth is not supported on this device.',
        );
      case BluetoothScanState.error:
        final lower = result.message.toLowerCase();
        if (lower.contains('permission')) {
          return _tr(
            'يحتاج التطبيق إلى صلاحية البلوتوث للبحث.',
            'Bluetooth permission is required for scanning.',
          );
        }
        if (lower.contains('turned off') ||
            lower.contains('powered off') ||
            lower.contains('location services')) {
          return lower.contains('location services')
              ? _tr(
                  'خدمات الموقع معطّلة. فعّلها للبحث عبر البلوتوث.',
                  'Location services are disabled. Enable them for Bluetooth scanning.',
                )
              : _tr(
                  'البلوتوث غير مفعّل. يرجى تفعيل البلوتوث.',
                  'Bluetooth is off. Please turn on Bluetooth.',
                );
        }
        return _tr(
          'تعذر البحث عبر البلوتوث حالياً.',
          'Unable to scan with Bluetooth right now.',
        );
      case BluetoothScanState.idle:
        return _tr(
          'اضغط «بدء البحث» لاكتشاف إشارة المحاضرة القريبة.',
          'Tap Start Scan to find a nearby lecture signal.',
        );
    }
  }

  String _localizedBluetoothSubmitError(BluetoothAttendanceException error) {
    final lower = error.message.toLowerCase();
    if (lower.contains('أكثر من جلسة') ||
        lower.contains('multiple active bluetooth sessions')) {
      return _tr(
        'توجد أكثر من جلسة بلوتوث نشطة، يرجى اختيار المحاضرة أو استخدام QR',
        'Multiple active Bluetooth sessions were found. Please use QR or select the lecture.',
      );
    }
    if (lower.contains('جلسة بلوتوث نشطة') ||
        lower.contains('active bluetooth session')) {
      return _tr(
        'لم يتم العثور على جلسة بلوتوث نشطة لهذه المحاضرة',
        'No active Bluetooth session was found for this lecture.',
      );
    }
    switch (error.code) {
      case BluetoothAttendanceErrorCode.sessionNotFound:
      case BluetoothAttendanceErrorCode.tokenMismatch:
      case BluetoothAttendanceErrorCode.weakSignal:
        return _tr(
          'لم يتم العثور على جلسة بلوتوث صالحة',
          'No valid Bluetooth session found',
        );
      case BluetoothAttendanceErrorCode.sessionClosed:
        return _tr('جلسة البلوتوث مغلقة', 'Bluetooth session is closed');
      case BluetoothAttendanceErrorCode.sessionExpired:
      case BluetoothAttendanceErrorCode.attendanceWindowClosed:
        return _tr('انتهت صلاحية جلسة البلوتوث', 'Bluetooth session expired');
      case BluetoothAttendanceErrorCode.studentNotEnrolled:
        return _tr(
          'غير مسجل في هذه الشعبة',
          'You are not enrolled in this section',
        );
      case BluetoothAttendanceErrorCode.alreadyMarked:
        return _tr('تم تسجيل الحضور مسبقًا', 'Attendance already recorded');
      case BluetoothAttendanceErrorCode.invalidInput:
      case BluetoothAttendanceErrorCode.missingLecturerSession:
      case BluetoothAttendanceErrorCode.unknown:
        return error.message.trim().isNotEmpty
            ? error.message
            : _tr(
                'تعذر تسجيل الحضور عبر البلوتوث حالياً.',
                'Unable to record Bluetooth attendance right now.',
              );
    }
  }

  Widget _buildQrAttendanceContent(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scanSize = min(280.0, MediaQuery.sizeOf(context).width - 72);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? scheme.surfaceContainerHighest
                  : const Color(0xFFD7F1F1),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: AttendanceModeChip(
                    label: _tr('مسح QR', 'Scan QR'),
                    isActive: !_isEnteringQrCode,
                    onTap: _retryQrScan,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AttendanceModeChip(
                    label: _tr('إدخال يدوي', 'Manual code'),
                    isActive: _isEnteringQrCode,
                    onTap: _showAttendanceCodeEntry,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_isEnteringQrCode)
          _buildQrManualEntryCard()
        else
          _buildQrScannerCard(scanSize),
        if (!_isEnteringQrCode) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _buildQrStatusBanner(),
          ),
        ],
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: _qrPrimaryActionEnabled ? _onQrPrimaryAction : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF006571),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white70,
                disabledBackgroundColor: const Color(
                  0xFF006571,
                ).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _qrPrimaryActionChild,
            ),
          ),
        ),
      ],
    );
  }

  bool get _qrPrimaryActionEnabled {
    if (_isAttendanceGeoBlocked) return false;
    if (_isEnteringQrCode) return !_isSubmittingAttendanceCode;
    return !_isStartingQrScanner && !_isProcessingQrScan;
  }

  void _onQrPrimaryAction() {
    if (_isEnteringQrCode) {
      unawaited(_submitAttendanceCode());
    } else {
      unawaited(_retryQrScan());
    }
  }

  Widget get _qrPrimaryActionChild {
    if (_isEnteringQrCode) {
      if (_isSubmittingAttendanceCode) {
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        );
      }
      return Text(
        _tr('تحقق من الرمز', 'Verify code'),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontFamily: 'Cairo',
          color: Colors.white,
        ),
      );
    }
    return Text(
      _isQrScanPaused
          ? _tr('إعادة المسح', 'Scan again')
          : _tr('بدء مسح QR', 'Start QR scan'),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontFamily: 'Cairo',
        color: Colors.white,
      ),
    );
  }

  Widget _buildQrStatusBanner() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _qrStatusError
            ? theme.brightness == Brightness.dark
                  ? const Color(0xFFB71C1C).withValues(alpha: 0.16)
                  : const Color(0xFFFFEBEE)
            : scheme.surface,
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
              : scheme.onSurfaceVariant,
          fontSize: 13,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildQrManualEntryCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF006571), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF006571).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? scheme.primary.withValues(alpha: 0.16)
                    : const Color(0xFFE6FBFB),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pin_rounded,
                size: 32,
                color: Color(0xFF006571),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _tr('رمز الحضور', 'Attendance code'),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _tr(
                'أدخل الرمز المكوّن من 6 أرقام كما يظهر لدى المحاضر',
                'Enter the 6-digit code shown by your lecturer',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _attendanceCodeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                color: scheme.onSurface,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 28,
                  letterSpacing: 6,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600,
                ),
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? scheme.surfaceContainerHighest
                    : const Color(0xFFF7FAFB),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFCCE8EA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF006571),
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (_) => unawaited(_submitAttendanceCode()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrScannerCard(double scanSize) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cutOut = scanSize * 0.68;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: scanSize,
            height: scanSize,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF006571), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_qrScannerInitialized)
                  QRView(
                    key: _qrViewKey,
                    onQRViewCreated: _onQrViewCreated,
                    onPermissionSet: _onQrPermissionSet,
                    overlay: QrScannerOverlayShape(
                      borderColor: Colors.transparent,
                      overlayColor: Colors.transparent,
                      borderWidth: 0,
                      cutOutSize: cutOut,
                    ),
                  ),
                if (!_qrScannerInitialized ||
                    _qrPermissionDenied ||
                    _qrCameraUnavailable)
                  _QrScannerFallback(
                    message: _checkingQrAvailability
                        ? _tr('جاري تجهيز الكاميرا...', 'Preparing camera...')
                        : _qrPermissionDenied
                        ? _tr(
                            'فعّل صلاحية الكاميرا من إعدادات الجهاز لمسح الرمز.',
                            'Enable camera access in device settings to scan.',
                          )
                        : _qrStatusMessage,
                    showRetry: !_checkingQrAvailability && !_qrPermissionDenied,
                    onRetry: _retryQrScan,
                  ),
                IgnorePointer(
                  child: Container(
                    width: cutOut,
                    height: cutOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
                if (_isStartingQrScanner)
                  Container(
                    color: Colors.black.withValues(alpha: 0.22),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translation = TranslationController.instance;
    final attendanceModeTitle = _isBluetooth
        ? _tr('التحضير عبر البلوتوث', 'Bluetooth Attendance')
        : _isNfc
        ? _tr('التحضير عبر NFC', 'NFC Attendance')
        : _tr('التحضير عبر QR', 'QR Attendance');

    return AnimatedBuilder(
      animation: translation,
      builder: (context, _) => Directionality(
        textDirection: translation.textDirection,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      icon: StudentBackChevronIcon(color: Color(0xFF006571)),
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
                StudentAttendanceStatusBanner(
                  state: _selfAttendanceUiState,
                  translate: _tr,
                ),
                Center(
                  child: TText(
                    attendanceModeTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 270,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
                          : const Color(0xFFE1F7F7),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: AttendanceModeChip(
                            label: 'QR',
                            isActive: !_isNfc && !_isBluetooth,
                            onTap: () => _toggleMode(false),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AttendanceModeChip(
                            label: 'NFC',
                            isActive: _isNfc,
                            onTap: () => _toggleMode(true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AttendanceModeChip(
                            label: _tr('بلوتوث', 'Bluetooth'),
                            isActive: _isBluetooth,
                            onTap: _toggleBluetoothMode,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (kDebugMode) const StudentGeoDebugToggle(),
                if (kDebugMode) const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : const Color(0xFFE6FBFB),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_geoVerifying && !_isNfc && !_isBluetooth)
                        _buildGeoVerifyingPanel()
                      else if (_isAttendanceGeoBlocked)
                        _buildGeoBlockedPanel()
                      else if (_isNfc) ...[
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
                                    ? Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(
                                              0xFFB71C1C,
                                            ).withValues(alpha: 0.16)
                                          : const Color(0xFFFFEBEE)
                                    : Theme.of(context).colorScheme.surface,
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
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
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
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: Colors.white70,
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
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (_isBluetooth) ...[
                        _buildBluetoothPlaceholderPanel(),
                      ] else ...[
                        _buildQrAttendanceContent(context),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      color: theme.brightness == Brightness.dark
          ? scheme.surfaceContainerHighest
          : const Color(0xFFDBF2F2),
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
              style: TextStyle(
                color: scheme.onSurfaceVariant,
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

class _BluetoothDetectionLine extends StatelessWidget {
  const _BluetoothDetectionLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 12,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
