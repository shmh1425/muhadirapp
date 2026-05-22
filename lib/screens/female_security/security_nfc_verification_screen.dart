import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../../providers/security_scan_providers.dart';
import '../../services/female_security/security_gate_scan_service.dart';
import '../../services/geo/campus_geo_check_mode.dart';
import '../../services/geo/geo_fence_outcome.dart';
import '../../services/geo/student_campus_geo_guard.dart';
import '../../services/nfc/nfc_tag_identifier.dart';
import '../../services/student/student_gate_payload.dart';
import 'security_localization.dart';
import 'security_prefs.dart';
import 'widgets/security_prior_rejection_dialog.dart';
import 'widgets/security_verify_student_dialog.dart';

enum _GateReaderMode { qr, nfc }

enum _GateOutcomeBanner { none, accepted, rejected, duplicate }

/// Security staff: read student NFC / tag UID, resolve profile, then human verify + gate log.
class SecurityNfcVerificationScreen extends ConsumerStatefulWidget {
  const SecurityNfcVerificationScreen({super.key});

  @override
  ConsumerState<SecurityNfcVerificationScreen> createState() =>
      _SecurityNfcVerificationScreenState();
}

class _SecurityNfcVerificationScreenState
    extends ConsumerState<SecurityNfcVerificationScreen>
    with SingleTickerProviderStateMixin {
  bool _checkingNfc = true;
  bool _nfcAvailable = false;
  bool _isScanning = false;
  String? _statusMessage;
  bool _statusError = false;
  String? _lastReadId;

  /// True while the confirm/reject dialog is open or about to open (blocks duplicate QR scans).
  bool _gateDecisionDialogPending = false;
  _GateOutcomeBanner _outcomeBanner = _GateOutcomeBanner.none;

  late _GateReaderMode _scanMode;
  QRViewController? _qrController;
  final GlobalKey _qrViewKey = GlobalKey(debugLabel: 'securityGateQr');
  StreamSubscription<Barcode>? _qrScanSub;
  bool _isQrProcessing = false;
  bool _qrPermissionDenied = false;
  bool _isGeoChecking = false;

  late final AnimationController _pulseController;

  /// Same palette as [NfcAttendanceScreen] (student) for visual consistency.
  static const _kStudentTealDark = Color(0xFF006571);
  static const _kStudentTealRing = Color(0xFF6FB2B7);
  static const _kStudentMsgBorderOk = Color(0xFFCCE8EA);
  static const _kStudentMsgBgError = Color(0xFFFFEBEE);
  static const _kStudentMsgBorderError = Color(0xFFE57373);
  static const _kStudentMsgTextError = Color(0xFFB71C1C);

  static const _kOutcomeAcceptedBg = Color(0xFFE8F5E9);
  static const _kOutcomeAcceptedBorder = Color(0xFF43A047);
  static const _kOutcomeAcceptedText = Color(0xFF1B5E20);

  static const _kOutcomeRejectedBg = Color(0xFFFFEBEE);
  static const _kOutcomeRejectedBorder = Color(0xFFE53935);
  static const _kOutcomeRejectedText = Color(0xFFB71C1C);

  static const _kOutcomeDuplicateBg = Color(0xFFFFF8E1);
  static const _kOutcomeDuplicateBorder = Color(0xFFFFA000);
  static const _kOutcomeDuplicateText = Color(0xFF5D4037);

  static const _kSnackSuccess = Color(0xFF2E7D32);
  static const _kSnackError = Color(0xFFC62828);
  static const _kSnackWarning = Color(0xFFF57C00);

  static const _kTealLight = Color(0xFF27A2A9);

  @override
  void initState() {
    super.initState();
    _scanMode = _GateReaderMode.nfc;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _checkNfc();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _qrScanSub?.cancel();
    super.dispose();
  }

  void _setScanMode(_GateReaderMode mode) {
    if (mode == _scanMode) return;
    setState(() {
      _scanMode = mode;
      _statusMessage = null;
      _statusError = false;
      _lastReadId = null;
      _gateDecisionDialogPending = false;
      _isScanning = false;
      _isQrProcessing = false;
      _outcomeBanner = _GateOutcomeBanner.none;
    });
    if (mode == _GateReaderMode.qr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_qrController?.resumeCamera());
      });
    } else {
      unawaited(_qrController?.pauseCamera());
    }
  }

  void _onQrViewCreated(QRViewController controller) {
    _qrController = controller;
    _qrScanSub?.cancel();
    _qrScanSub = controller.scannedDataStream.listen(
      (scan) {
        final code = scan.code;
        if (code != null && code.isNotEmpty) {
          unawaited(_handleQrScan(code));
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _statusError = true;
          _outcomeBanner = _GateOutcomeBanner.none;
          _statusMessage = SecurityLocalization.nfcReadFailed;
        });
      },
    );
  }

  void _onQrPermissionSet(QRViewController controller, bool granted) {
    if (!mounted) return;
    if (granted) {
      setState(() => _qrPermissionDenied = false);
      return;
    }
    setState(() {
      _qrPermissionDenied = true;
      _statusError = true;
      _outcomeBanner = _GateOutcomeBanner.none;
      _statusMessage = SecurityLocalization.qrCameraPermissionDenied;
    });
  }

  Future<void> _handleQrScan(String raw) async {
    if (_scanMode != _GateReaderMode.qr ||
        _isQrProcessing ||
        _gateDecisionDialogPending) {
      return;
    }
    setState(() {
      _isQrProcessing = true;
      _statusError = false;
      _statusMessage = null;
      _lastReadId = null;
      _gateDecisionDialogPending = false;
      _outcomeBanner = _GateOutcomeBanner.none;
    });
    await _qrController?.pauseCamera();

    final rawTrimmed = raw.trim();
    final parsed = StudentGatePayload.parseGatePayload(rawTrimmed);
    final lookupKey =
        parsed?.lookupKey ??
        StudentGatePayload.parseStudentLookupKey(rawTrimmed);
    if (lookupKey == null || lookupKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isQrProcessing = false;
        _statusError = true;
        _outcomeBanner = _GateOutcomeBanner.none;
        _statusMessage = SecurityLocalization.qrInvalidGatePayload;
        _lastReadId = raw.length > 48 ? '${raw.substring(0, 48)}…' : raw.trim();
      });
      return;
    }

    final geoAudit = await _verifyGateLocation();
    if (geoAudit == null) {
      return;
    }

    await _resolveProfile(
      lookupKey,
      gateClientRev: parsed?.gateCardRev,
      gateRotatingSlot: parsed?.rotatingSlot,
      geoAudit: geoAudit,
    );
  }

  Future<SecurityGateGeoAudit?> _verifyGateLocation() async {
    if (kDebugMode) {
      debugPrint('SECURITY_GEOFENCE_CHECK_START');
    }

    setState(() {
      _isGeoChecking = true;
      _statusError = false;
      _statusMessage = SecurityLocalization.qrProcessing;
      _outcomeBanner = _GateOutcomeBanner.none;
    });

    if (kIsWeb) {
      final audit = SecurityGateGeoAudit(
        locationVerified: false,
        geoFenceStatus: 'unavailable',
        geoCheckedAt: DateTime.now(),
      );
      _blockForGeoFence(
        message: SecurityLocalization.gateLocationUnsupported,
        reason: audit.geoFenceStatus,
      );
      return null;
    }

    final blocked = await StudentCampusGeoGuard.blockingOutcome(
      mode: CampusGeoCheckMode.girlsSecurityGate,
    );
    if (!mounted) return null;

    if (blocked == null) {
      final audit = SecurityGateGeoAudit(
        locationVerified: true,
        geoFenceStatus: 'inside',
        geoCheckedAt: DateTime.now(),
      );
      if (kDebugMode) {
        debugPrint('SECURITY_GEOFENCE_CHECK_SUCCESS');
      }
      setState(() {
        _isGeoChecking = false;
        _statusError = false;
        _statusMessage = null;
        _outcomeBanner = _GateOutcomeBanner.none;
      });
      return audit;
    }

    final reason = _geoFenceStatus(blocked);
    _blockForGeoFence(message: _geoFenceMessage(blocked), reason: reason);
    return null;
  }

  void _blockForGeoFence({required String message, required String reason}) {
    if (kDebugMode) {
      debugPrint('SECURITY_GEOFENCE_CHECK_BLOCKED reason=$reason');
    }
    if (!mounted) return;
    setState(() {
      _isGeoChecking = false;
      _isScanning = false;
      _isQrProcessing = false;
      _gateDecisionDialogPending = false;
      _statusError = true;
      _statusMessage = message;
      _outcomeBanner = _GateOutcomeBanner.none;
    });
  }

  String _geoFenceStatus(GeoFenceOutcome outcome) {
    switch (outcome) {
      case GeoFenceOutcome.inside:
        return 'inside';
      case GeoFenceOutcome.outsideCampus:
        return 'outside';
      case GeoFenceOutcome.permissionDenied:
        return 'permissionDenied';
      case GeoFenceOutcome.locationServiceDisabled:
        return 'locationServiceDisabled';
      case GeoFenceOutcome.locationUnavailable:
        return 'unavailable';
    }
  }

  String _geoFenceMessage(GeoFenceOutcome outcome) {
    switch (outcome) {
      case GeoFenceOutcome.inside:
        return '';
      case GeoFenceOutcome.permissionDenied:
        return SecurityLocalization.gateLocationPermissionRequired;
      case GeoFenceOutcome.locationServiceDisabled:
        return SecurityLocalization.gateLocationServicesDisabled;
      case GeoFenceOutcome.outsideCampus:
        return SecurityLocalization.gateVerificationOutsideCampus;
      case GeoFenceOutcome.locationUnavailable:
        return SecurityLocalization.gateLocationUnsupported;
    }
  }

  Future<void> _checkNfc() async {
    if (kIsWeb) {
      setState(() {
        _checkingNfc = false;
        _nfcAvailable = false;
        _statusError = false;
        _outcomeBanner = _GateOutcomeBanner.none;
        _statusMessage = SecurityLocalization.nfcNotAvailableWeb;
      });
      return;
    }
    try {
      final available = await NfcManager.instance.isAvailable();
      if (!mounted) return;
      setState(() {
        _nfcAvailable = available;
        _checkingNfc = false;
        _outcomeBanner = _GateOutcomeBanner.none;
        if (!available) {
          _statusError = false;
          _statusMessage = SecurityLocalization.nfcNotAvailableDevice;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingNfc = false;
        _nfcAvailable = false;
        _statusError = true;
        _outcomeBanner = _GateOutcomeBanner.none;
        _statusMessage = SecurityLocalization.nfcReadFailed;
      });
    }
  }

  String _formatScanTime() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(n.hour)}:${two(n.minute)}:${two(n.second)}';
  }

  Future<void> _resolveProfile(
    String id, {
    int? gateClientRev,
    int? gateRotatingSlot,
    required SecurityGateGeoAudit geoAudit,
  }) async {
    if (gateRotatingSlot != null &&
        !StudentGatePayload.isRotatingSlotAccepted(gateRotatingSlot)) {
      if (!mounted) return;
      setState(() {
        _lastReadId = id;
        _isScanning = false;
        _isQrProcessing = false;
        _gateDecisionDialogPending = false;
        _outcomeBanner = _GateOutcomeBanner.none;
        _statusError = true;
        _statusMessage = SecurityLocalization.gateRotatingSlotStale;
      });
      return;
    }

    final repo = ref.read(securityRepositoryProvider);
    final bypassCache = gateClientRev != null;
    final byUid = await repo.findStudentBySecurityNfcUid(id);
    final byUni =
        byUid ??
        await repo.findStudentByUniversityId(id, bypassCache: bypassCache);
    if (!mounted) return;

    var profile = byUni;
    if (profile != null &&
        gateClientRev != null &&
        profile.gateCardRev != gateClientRev) {
      profile = null;
    }

    final p = profile;
    setState(() {
      _lastReadId = id;
      _isScanning = false;
      _isQrProcessing = false;
      if (p == null) {
        _gateDecisionDialogPending = false;
        _outcomeBanner = _GateOutcomeBanner.none;
        _statusError = true;
        _statusMessage = gateClientRev != null && byUni != null
            ? SecurityLocalization.gateCardRevStale
            : SecurityLocalization.nfcUnknownStudent;
      } else {
        _outcomeBanner = _GateOutcomeBanner.none;
        _statusError = false;
        _statusMessage = null;
        _gateDecisionDialogPending = true;
      }
    });
    if (p != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_openVerifyDialog(p, geoAudit));
      });
    }
  }

  Future<void> _openVerifyDialog(
    SecurityStudentProfile profile,
    SecurityGateGeoAudit geoAudit,
  ) async {
    try {
      final reasons = await ref
          .read(securityRepositoryProvider)
          .getActiveRejectionReasons();
      if (!mounted) return;

      final result = StudentGateScanResult(
        fullName: profile.fullName,
        universityId: profile.universityId,
        major: profile.major,
        scanTime: _formatScanTime(),
        photoUrl: profile.displayPhotoUrl,
      );

      final gate = currentSecurityGateOption;
      final scanDateKey = formatScanDateKey(DateTime.now());
      final priorHint = await FemaleSecurityGateScanService.instance
          .loadPriorRejectionVerificationHint(
            studentId: profile.studentId.toString(),
            gateId: gate.gateId,
            scanDateKey: scanDateKey,
          );
      if (!mounted) return;

      if (priorHint != null) {
        final proceed = await SecurityPriorRejectionDialog.show(
          context,
          priorHint,
        );
        if (!mounted) return;
        if (proceed != true) {
          return;
        }
      }

      final decision = await SecurityVerifyStudentDialog.show(
        context,
        result: result,
        rejectionReasons: reasons,
      );
      if (!mounted) return;
      if (decision == null) {
        return;
      }

      try {
        await FemaleSecurityGateScanService.instance.recordGateScanDecision(
          student: profile,
          gate: gate,
          decision: decision.isApproved
              ? const SecurityVerificationDecision.approved()
              : SecurityVerificationDecision.rejected(
                  decision.rejectionReason!,
                ),
          geoAudit: geoAudit,
        );
        if (!mounted) return;
        setState(() {
          _lastReadId = null;
          _outcomeBanner = decision.isApproved
              ? _GateOutcomeBanner.accepted
              : _GateOutcomeBanner.rejected;
          _statusMessage = decision.isApproved
              ? '${SecurityLocalization.acceptedStatus}\n${SecurityLocalization.nfcScanAgain}'
              : '${SecurityLocalization.rejectedStatus}\n${SecurityLocalization.nfcScanAgain}';
          _statusError = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: decision.isApproved
                ? _kSnackSuccess
                : _kSnackError,
            content: Text(
              decision.isApproved
                  ? SecurityLocalization.acceptedStatus
                  : SecurityLocalization.rejectedStatus,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      } on DuplicateAcceptedGateScanException {
        if (!mounted) return;
        setState(() {
          _lastReadId = null;
          _outcomeBanner = _GateOutcomeBanner.duplicate;
          _statusMessage =
              '${SecurityLocalization.thisStudentAlreadyAcceptedToday}\n${SecurityLocalization.nfcScanAgain}';
          _statusError = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _kSnackWarning,
            content: Text(
              SecurityLocalization.thisStudentAlreadyAcceptedToday,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _outcomeBanner = _GateOutcomeBanner.none;
          _statusError = true;
          _statusMessage = SecurityLocalization.saveEntryError(e);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _kSnackError,
            content: Text(
              SecurityLocalization.saveEntryError(e),
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _gateDecisionDialogPending = false);
      }
      if (mounted && _scanMode == _GateReaderMode.qr) {
        unawaited(_qrController?.resumeCamera());
      }
    }
  }

  Future<void> _startScan() async {
    if (_isScanning || !_nfcAvailable) return;
    setState(() {
      _statusError = false;
      _statusMessage = null;
      _lastReadId = null;
      _gateDecisionDialogPending = false;
      _outcomeBanner = _GateOutcomeBanner.none;
    });

    final geoAudit = await _verifyGateLocation();
    if (!mounted || geoAudit == null) return;

    setState(() {
      _isScanning = true;
      _statusError = false;
      _statusMessage = null;
      _outcomeBanner = _GateOutcomeBanner.none;
    });

    if (!mounted) return;
    await _runNfcDiscoverySession(geoAudit);
  }

  Future<void> _runNfcDiscoverySession(SecurityGateGeoAudit geoAudit) async {
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
        alertMessage: SecurityLocalization.nfcScanningHint,
        onDiscovered: (NfcTag tag) async {
          if (handled) return;
          handled = true;

          await NfcManager.instance.stopSession();
          if (!mounted) return;

          final gateRaw = NfcTagIdentifier.extractStudentGateCardNdefRaw(tag);
          if (gateRaw.isNotEmpty) {
            final parsed = StudentGatePayload.parseGatePayload(gateRaw);
            if (parsed == null || parsed.lookupKey.isEmpty) {
              if (!mounted) return;
              setState(() {
                _isScanning = false;
                _statusError = true;
                _outcomeBanner = _GateOutcomeBanner.none;
                _statusMessage = SecurityLocalization.nfcReadFailed;
              });
              if (!sessionDone.isCompleted) sessionDone.complete();
              return;
            }
            await _resolveProfile(
              parsed.lookupKey,
              gateClientRev: parsed.gateCardRev,
              gateRotatingSlot: parsed.rotatingSlot,
              geoAudit: geoAudit,
            );
          } else {
            final id = NfcTagIdentifier.extractNormalizedId(tag);
            if (id.isEmpty) {
              if (!mounted) return;
              setState(() {
                _isScanning = false;
                _statusError = true;
                _outcomeBanner = _GateOutcomeBanner.none;
                _statusMessage = SecurityLocalization.nfcReadFailed;
              });
              if (!sessionDone.isCompleted) sessionDone.complete();
              return;
            }
            await _resolveProfile(id, geoAudit: geoAudit);
          }
          if (!sessionDone.isCompleted) sessionDone.complete();
        },
        onError: (error) async {
          if (handled) return;
          handled = true;
          if (mounted) {
            setState(() {
              _isScanning = false;
              _statusError = error.type != NfcErrorType.userCanceled;
              _outcomeBanner = _GateOutcomeBanner.none;
              _statusMessage = error.type == NfcErrorType.userCanceled
                  ? null
                  : SecurityLocalization.nfcReadFailed;
            });
          }
          if (!sessionDone.isCompleted) sessionDone.complete();
        },
      );

      await sessionDone.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () async {
          if (handled) return;
          handled = true;
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          if (mounted) {
            setState(() {
              _isScanning = false;
              _statusError = true;
              _outcomeBanner = _GateOutcomeBanner.none;
              _statusMessage = SecurityLocalization.nfcReadFailed;
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _statusError = true;
        _outcomeBanner = _GateOutcomeBanner.none;
        _statusMessage = SecurityLocalization.nfcReadFailed;
      });
    } finally {
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
      if (mounted && _isScanning && !handled) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SecurityLocalization.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return Directionality(
          textDirection: SecurityLocalization.direction,
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              foregroundColor: colorScheme.onSurface,
              title: Text(
                SecurityLocalization.nfcGateVerificationTitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_checkingNfc)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                            color: _kStudentTealDark,
                          ),
                        ),
                      )
                    else ...[
                      Center(child: _buildModePill()),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildScanModePanel(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModePill() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 180,
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SecurityGateModeChip(
              label: SecurityLocalization.gateReaderModeQr,
              isActive: _scanMode == _GateReaderMode.qr,
              onTap: () => _setScanMode(_GateReaderMode.qr),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SecurityGateModeChip(
              label: SecurityLocalization.gateReaderModeNfc,
              isActive: _scanMode == _GateReaderMode.nfc,
              onTap: () => _setScanMode(_GateReaderMode.nfc),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanModePanel(BuildContext context) {
    switch (_scanMode) {
      case _GateReaderMode.qr:
        return _buildQrPanel(context);
      case _GateReaderMode.nfc:
        return _buildNfcPanel();
    }
  }

  Widget _buildPulsingRings() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        const ringCount = 12;
        final t = CurvedAnimation(
          parent: _pulseController,
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
                  color: _kStudentTealRing.withValues(alpha: opacity),
                  width: 1,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _studentStatusBox() {
    if (_statusMessage == null || _gateDecisionDialogPending) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    late Color bg;
    late Color border;
    late Color fg;
    late Color secondaryFg;

    if (_outcomeBanner == _GateOutcomeBanner.accepted) {
      bg = _kOutcomeAcceptedBg;
      border = _kOutcomeAcceptedBorder;
      fg = _kOutcomeAcceptedText;
      secondaryFg = _kOutcomeAcceptedText.withValues(alpha: 0.82);
    } else if (_outcomeBanner == _GateOutcomeBanner.rejected) {
      bg = _kOutcomeRejectedBg;
      border = _kOutcomeRejectedBorder;
      fg = _kOutcomeRejectedText;
      secondaryFg = _kOutcomeRejectedText.withValues(alpha: 0.82);
    } else if (_outcomeBanner == _GateOutcomeBanner.duplicate) {
      bg = _kOutcomeDuplicateBg;
      border = _kOutcomeDuplicateBorder;
      fg = _kOutcomeDuplicateText;
      secondaryFg = _kOutcomeDuplicateText.withValues(alpha: 0.85);
    } else {
      bg = _statusError ? _kStudentMsgBgError : colorScheme.surface;
      border = _statusError ? _kStudentMsgBorderError : _kStudentMsgBorderOk;
      fg = _statusError ? _kStudentMsgTextError : colorScheme.onSurface;
      secondaryFg = _statusError
          ? _kStudentMsgTextError.withValues(alpha: 0.78)
          : colorScheme.onSurfaceVariant;
    }

    final lines = _statusMessage!.split('\n');
    final primary = lines.isNotEmpty ? lines.first : _statusMessage!;
    final secondary = lines.length > 1 ? lines.sublist(1).join('\n') : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            primary,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          ),
          if (secondary != null && secondary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              secondary,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: secondaryFg,
                fontSize: 12,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_lastReadId != null) ...[
            const SizedBox(height: 8),
            Text(
              '${SecurityLocalization.nfcUidLabel}: $_lastReadId',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: secondaryFg,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNfcPanel() {
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildPulsingRings(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isGeoChecking) ...[
                const CircularProgressIndicator(color: _kStudentTealDark),
                const SizedBox(height: 14),
                Text(
                  SecurityLocalization.qrProcessing,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ] else if (_isScanning) ...[
                const CircularProgressIndicator(color: _kStudentTealDark),
                const SizedBox(height: 14),
                Text(
                  SecurityLocalization.nfcScanningHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ] else ...[
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _nfcAvailable
                          ? _kStudentTealDark
                          : Theme.of(context).colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.phone_iphone,
                    size: 52,
                    color: _nfcAvailable
                        ? _kStudentTealDark
                        : Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 26),
                _studentStatusBox(),
                const SizedBox(height: 16),
                SizedBox(
                  width: 210,
                  height: 44,
                  child: FilledButton(
                    onPressed:
                        (_nfcAvailable && !_isScanning && !_isGeoChecking)
                        ? _startScan
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kStudentTealDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      SecurityLocalization.nfcStartScan,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrPanel(BuildContext context) {
    final showStatusStrip =
        _statusMessage != null &&
        !_gateDecisionDialogPending &&
        (_statusError ||
            _lastReadId != null ||
            _outcomeBanner != _GateOutcomeBanner.none);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        children: [
          if (showStatusStrip) ...[
            _studentStatusBox(),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  _statusMessage = null;
                  _statusError = false;
                  _lastReadId = null;
                  _outcomeBanner = _GateOutcomeBanner.none;
                });
                unawaited(_qrController?.resumeCamera());
              },
              child: Text(
                SecurityLocalization.qrResumeScanning,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _kStudentTealDark, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildQrScannerArea(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrScannerArea(BuildContext context) {
    if (kIsWeb) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            SecurityLocalization.qrNotOnWeb,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.35,
            ),
          ),
        ),
      );
    }
    if (_qrPermissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            SecurityLocalization.qrCameraPermissionDenied,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    final cutOut = (MediaQuery.sizeOf(context).width - 48).clamp(200.0, 280.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        QRView(
          key: _qrViewKey,
          onQRViewCreated: _onQrViewCreated,
          onPermissionSet: _onQrPermissionSet,
          overlay: QrScannerOverlayShape(
            borderColor: _kTealLight,
            borderRadius: 10,
            borderLength: 28,
            borderWidth: 4,
            cutOutSize: cutOut,
            overlayColor: Colors.black54,
          ),
        ),
        if (_isQrProcessing || _isGeoChecking)
          ColoredBox(
            color: Colors.black38,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 14),
                  Text(
                    SecurityLocalization.qrProcessing,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Matches student [NfcAttendanceScreen] `_ModeChip` styling.
class _SecurityGateModeChip extends StatelessWidget {
  static const _kTeal = Color(0xFF006571);

  const _SecurityGateModeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? _kTeal : colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: isActive
              ? null
              : Border.all(color: colorScheme.primary.withValues(alpha: 0.28)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: isActive ? Colors.white : colorScheme.primary,
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
