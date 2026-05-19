import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/attendance/nfc_attendance_session.dart';
import '../../models/attendance/bluetooth_attendance_session.dart';
import '../../models/attendance/qr_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../models/lecturer/unified_lecturer_catalog.dart';
import '../../providers/lecturer_catalog_providers.dart';
import '../../services/attendance/attendance_status_policy.dart';
import '../../services/attendance/bluetooth_attendance_service.dart';
import '../../services/attendance/bluetooth_ble_service.dart';
import '../../services/attendance/nfc_attendance_service.dart';
import '../../services/attendance/qr_attendance_service.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import '../../services/lecturer/lecturer_sections_service.dart';
import '../../utils/shared/time_utils.dart';
import 'lecturer_language.dart';

class LecturerQrScreen extends ConsumerStatefulWidget {
  const LecturerQrScreen({super.key, this.lecture});

  final LectureItem? lecture;

  @override
  ConsumerState<LecturerQrScreen> createState() => _LecturerQrScreenState();
}

class _LecturerQrScreenState extends ConsumerState<LecturerQrScreen> {
  List<LectureItem> _allLectures = [];
  final LectureRepository _calendarRepository = LectureRepository();
  final QrAttendanceService _qrAttendanceService = QrAttendanceService.instance;
  final NfcAttendanceService _nfcAttendanceService =
      NfcAttendanceService.instance;
  final BluetoothAttendanceService _bluetoothAttendanceService =
      BluetoothAttendanceService.instance;
  final BluetoothBleService _bluetoothBleService = BluetoothBleService.instance;
  StreamSubscription<void>? _calendarSyncSub;
  StreamSubscription<List<NfcAttendanceSession>>? _nfcSessionsSub;
  late String _qrData;
  LectureItem? _activeLecture;
  QrAttendanceSession? _qrSession;
  BluetoothAttendanceSession? _bluetoothSession;
  List<NfcAttendanceSession> _openNfcSessions = <NfcAttendanceSession>[];
  bool _isSyncRefreshing = false;
  bool _isLoadingSession = false;
  bool _isLoadingNfcAction = false;
  bool _isLoadingBluetoothAction = false;
  bool _isClosingBluetoothSession = false;
  bool _isStartingBluetoothBroadcast = false;
  bool _isStoppingBluetoothBroadcast = false;
  BluetoothBroadcastState _bluetoothBroadcastState =
      BluetoothBroadcastState.idle;
  String? _bluetoothBroadcastMessage;
  bool _isNfcActiveForLecture = false;
  String? _sessionErrorMessage;
  _CheckInMethod _selectedMethod = _CheckInMethod.qr;
  _QrDisplayMode _qrDisplayMode = _QrDisplayMode.qrCode;
  Timer? _codeRefreshTimer;
  Timer? _bluetoothTokenTimer;
  Timer? _activeLectureSyncTimer;
  static const int _codeRefreshIntervalSeconds = 30;
  static const Duration _activeLectureSyncInterval = Duration(seconds: 20);
  int _codeRefreshSecondsLeft = _codeRefreshIntervalSeconds;
  bool _isSyncingLectureAndCode = false;
  DateTime? _lastLecturesReloadAt;
  bool _isReloadingLectures = false;

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  @override
  void initState() {
    super.initState();
    _qrData = '';
    LecturerLanguageController.notifier.addListener(_onLecturerLanguageChanged);
    _calendarSyncSub = CalendarSyncService.instance.watchChanges().listen(
      (_) => _handleRealtimeCalendarChange(),
    );
    _nfcSessionsSub = _nfcAttendanceService
        .watchOpenSessionsForCurrentLecturer()
        .listen((sessions) {
          if (!mounted) return;
          setState(() {
            _openNfcSessions = sessions;
            _recomputeNfcActiveForCurrentLecture();
          });
        });
    unawaited(_bootstrapQr());
    _startActiveLectureSyncTimer();
  }

  void _onLecturerLanguageChanged() {
    final cat = ref.read(lecturerUnifiedCatalogProvider).valueOrNull;
    if (cat == null || !mounted) return;
    setState(() {
      _allLectures = cat.toLectureItems(
        isArabic: LecturerLanguageController.isArabic,
      );
    });
    unawaited(_syncLectureAndCode());
  }

  Future<void> _bootstrapQr() async {
    final cat = ref.read(lecturerUnifiedCatalogProvider).valueOrNull;
    if (cat != null && !cat.isEmpty && mounted) {
      setState(() {
        _allLectures = cat.toLectureItems(
          isArabic: LecturerLanguageController.isArabic,
        );
      });
    }
    await _syncLectureAndCode();
    unawaited(_refreshQrCatalogAndCalendarInBackground());
  }

  Future<void> _refreshQrCatalogAndCalendarInBackground() async {
    try {
      await Future.wait<Object?>([
        _calendarRepository.refreshAcademicCalendar(),
        ref.read(lecturerUnifiedCatalogProvider.future),
      ]);
      if (!mounted) return;
      final cat = ref.read(lecturerUnifiedCatalogProvider).requireValue;
      setState(() {
        _allLectures = cat.toLectureItems(
          isArabic: LecturerLanguageController.isArabic,
        );
      });
      await _syncLectureAndCode();
    } catch (_) {
      // Keep hydrated lectures list if already shown.
    }
  }

  @override
  void dispose() {
    LecturerLanguageController.notifier.removeListener(_onLecturerLanguageChanged);
    _calendarSyncSub?.cancel();
    _nfcSessionsSub?.cancel();
    _stopCodeRefreshTimer();
    _stopBluetoothTokenTimer();
    _stopActiveLectureSyncTimer();
    _bluetoothBleService.stopAdvertisingSession();
    super.dispose();
  }

  Future<void> _handleRealtimeCalendarChange() async {
    if (!mounted || _isSyncRefreshing) return;
    _isSyncRefreshing = true;
    try {
      await _calendarRepository.refreshAcademicCalendar();
      await _reloadLecturesFromSource(force: true);
      await _syncLectureAndCode();
    } catch (_) {
      // Ignore transient realtime listener errors.
    } finally {
      _isSyncRefreshing = false;
    }
  }

  Future<void> _syncLectureAndCode() async {
    if (_isSyncingLectureAndCode) return;
    _isSyncingLectureAndCode = true;
    try {
      await _reloadLecturesFromSource();
      final lecture = _resolveCurrentLecture();
      final lectureChanged = !_isSameLecture(_activeLecture, lecture);
      if (lecture == null) {
        final now = _effectiveNowForLectureWindow();
        final weekdays = _candidateWeekdaysForLectureWindow();
        final todayCount = _allLectures
            .where((l) => weekdays.contains(l.dayOfWeek))
            .length;
        debugPrint(
          '[LecturerQrScreen] No active lecture. now=$now weekday=${now.weekday} '
          'calendarWeekday=${_calendarRepository.currentDateTime.weekday} '
          'candidateWeekdays=$weekdays '
          'allLectures=${_allLectures.length} candidateLectures=$todayCount',
        );
      }
      if (mounted && (lectureChanged || _sessionErrorMessage != null)) {
        setState(() {
          _activeLecture = lecture;
          _sessionErrorMessage = null;
          _recomputeNfcActiveForCurrentLecture();
          if (lectureChanged) {
            _bluetoothSession = null;
            _bluetoothBroadcastState = BluetoothBroadcastState.idle;
            _bluetoothBroadcastMessage = null;
          }
        });
      }

      if (lecture == null) {
        if (!mounted) return;
        setState(() {
          _qrSession = null;
          _qrData = '';
        });
        _stopCodeRefreshTimer();
        _stopBluetoothTokenTimer();
        return;
      }

      if (!lectureChanged && _qrSession != null) {
        return;
      }

      final missingFields = <String>[];
      if ((lecture.sectionId ?? '').trim().isEmpty) {
        missingFields.add('sectionId');
      }
      if (lecture.startTime.trim().isEmpty) {
        missingFields.add('startTime');
      }

      if (missingFields.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _qrSession = null;
          _qrData = '';
          _sessionErrorMessage =
              'تعذر إنشاء جلسة QR: بيانات المحاضرة ناقصة (${missingFields.join(', ')}).';
        });
        _stopCodeRefreshTimer();
        return;
      }

      if (!mounted) return;
      setState(() {
        _isLoadingSession = true;
      });

      try {
        final session = await _qrAttendanceService.createOrGetSessionForLecture(
          lecture: lecture,
          lectureDate: _effectiveNowForLectureWindow(),
        );
        if (!mounted) return;
        setState(() {
          _qrSession = session;
          _qrData = _buildQrPayload(session);
          _sessionErrorMessage = null;
        });
        _startCodeRefreshTimer();
      } on FirebaseException catch (e) {
        if (!mounted) return;
        setState(() {
          _qrSession = null;
          _qrData = '';
          if (e.code == 'permission-denied') {
            _sessionErrorMessage =
                'فشل إنشاء جلسة QR: لا توجد صلاحية للوصول إلى Firestore.';
          } else {
            _sessionErrorMessage = 'فشل إنشاء/جلب جلسة QR من Firestore.';
          }
        });
        _stopCodeRefreshTimer();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _qrSession = null;
          _qrData = '';
          _sessionErrorMessage = 'فشل إنشاء/جلب جلسة QR من Firestore.';
        });
        _stopCodeRefreshTimer();
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingSession = false;
          });
        }
      }
    } finally {
      _isSyncingLectureAndCode = false;
    }
  }

  Future<void> _reloadLecturesFromSource({bool force = false}) async {
    if (_isReloadingLectures) return;
    final now = DateTime.now();
    final shouldReload =
        force ||
        _allLectures.isEmpty ||
        _lastLecturesReloadAt == null ||
        now.difference(_lastLecturesReloadAt!) > const Duration(minutes: 2);
    if (!shouldReload) return;

    _isReloadingLectures = true;
    try {
      final list = await LecturerSectionsService.instance
          .getLecturesForCurrentLecturer();
      final fallback = LecturerSectionsService.instance.cachedLectures;
      final effectiveList = list.isEmpty && fallback.isNotEmpty
          ? fallback
          : list;
      if (!mounted) return;
      setState(() {
        _allLectures = effectiveList;
        _lastLecturesReloadAt = DateTime.now();
      });
      debugPrint(
        '[LecturerQrScreen] reload lectures fetched=${list.length} '
        'effective=${effectiveList.length} cached=${fallback.length}',
      );
    } catch (_) {
      // Keep current in-memory list on transient errors.
    } finally {
      _isReloadingLectures = false;
    }
  }

  bool _isSameLecture(LectureItem? a, LectureItem? b) {
    if (a == null || b == null) return a == b;
    final aSectionId = (a.sectionId ?? '').trim();
    final bSectionId = (b.sectionId ?? '').trim();
    return aSectionId == bSectionId &&
        a.dayOfWeek == b.dayOfWeek &&
        a.startTime.trim() == b.startTime.trim() &&
        a.endTime.trim() == b.endTime.trim() &&
        a.crn.trim() == b.crn.trim();
  }

  void _startActiveLectureSyncTimer() {
    _stopActiveLectureSyncTimer();
    _activeLectureSyncTimer = Timer.periodic(_activeLectureSyncInterval, (_) {
      if (!mounted) return;
      _syncLectureAndCode();
    });
  }

  void _stopActiveLectureSyncTimer() {
    _activeLectureSyncTimer?.cancel();
    _activeLectureSyncTimer = null;
  }

  LectureItem? _resolveCurrentLecture() {
    if (widget.lecture != null) return widget.lecture;

    final now = _effectiveNowForLectureWindow();
    final weekdays = _candidateWeekdaysForLectureWindow();
    for (final weekday in weekdays) {
      final dayLectures = TimeUtils.sortLecturesByTime(
        _allLectures.where((l) => l.dayOfWeek == weekday).toList(),
        (l) => l.startTime,
      );
      for (final lecture in dayLectures) {
        if (_isCurrentLecture(lecture, now)) {
          return lecture;
        }
      }
    }

    // Fallback: if strict detection fails due time-format mismatch, pick the
    // nearest lecture from today's schedule within a reasonable window.
    return _resolveNearestTodayLecture(now, weekdays);
  }

  LectureItem? _resolveNearestTodayLecture(DateTime now, List<int> weekdays) {
    Duration? bestDistance;
    LectureItem? bestLecture;

    final dayLectures = _allLectures.where(
      (l) => weekdays.contains(l.dayOfWeek),
    );
    for (final lecture in dayLectures) {
      final (startH, startM) = TimeUtils.parseTimeString(lecture.startTime);
      final (endH, endM) = TimeUtils.parseTimeString(lecture.endTime);
      final ranges = _buildLectureRangesForCurrentDay(
        now: now,
        startH: startH,
        startM: startM,
        endH: endH,
        endM: endM,
      );
      for (final range in ranges) {
        final start = range.$1;
        final end = range.$2;
        final openWindowStart = start.subtract(
          AttendanceStatusPolicy.attendanceEarlyWindow,
        );
        final openWindowEnd = end.add(
          AttendanceStatusPolicy.attendanceLateWindow,
        );

        // If now is within the attendance window for this lecture, prefer it
        // immediately even if strict exact range check failed.
        final inAttendanceWindow =
            (now.isAfter(openWindowStart) ||
                now.isAtSameMomentAs(openWindowStart)) &&
            (now.isBefore(openWindowEnd) ||
                now.isAtSameMomentAs(openWindowEnd));
        if (inAttendanceWindow) {
          return lecture;
        }

        final distance = _distanceToRange(now, start, end);
        if (bestDistance == null || distance < bestDistance) {
          bestDistance = distance;
          bestLecture = lecture;
        }
      }
    }

    // Guard against selecting far-away lectures when there is no nearby slot.
    if (bestDistance != null && bestDistance <= const Duration(hours: 2)) {
      return bestLecture;
    }
    return null;
  }

  Duration _distanceToRange(DateTime now, DateTime start, DateTime end) {
    if (now.isBefore(start)) return start.difference(now);
    if (now.isAfter(end)) return now.difference(end);
    return Duration.zero;
  }

  List<int> _candidateWeekdaysForLectureWindow() {
    final calendarWeekday = _calendarRepository.currentDateTime.weekday;
    final deviceWeekday = DateTime.now().weekday;
    final values = <int>[calendarWeekday];
    if (!values.contains(deviceWeekday)) {
      values.add(deviceWeekday);
    }
    return values;
  }

  DateTime _effectiveNowForLectureWindow() {
    return DateTime.now();
  }

  bool _isCurrentLecture(LectureItem lecture, DateTime now) {
    final (startH, startM) = TimeUtils.parseTimeString(lecture.startTime);
    final (endH, endM) = TimeUtils.parseTimeString(lecture.endTime);
    final ranges = _buildLectureRangesForCurrentDay(
      now: now,
      startH: startH,
      startM: startM,
      endH: endH,
      endM: endM,
    );
    for (final range in ranges) {
      final start = range.$1;
      final end = range.$2;
      final isAfterStart = now.isAfter(start) || now.isAtSameMomentAs(start);
      final isBeforeEnd = now.isBefore(end) || now.isAtSameMomentAs(end);
      if (isAfterStart && isBeforeEnd) {
        return true;
      }
    }
    return false;
  }

  List<(DateTime, DateTime)> _buildLectureRangesForCurrentDay({
    required DateTime now,
    required int startH,
    required int startM,
    required int endH,
    required int endM,
  }) {
    final ranges = <(DateTime, DateTime)>[];
    void addRange(int sH, int sM, int eH, int eM) {
      var start = DateTime(now.year, now.month, now.day, sH, sM);
      var end = DateTime(now.year, now.month, now.day, eH, eM);
      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }
      ranges.add((start, end));
    }

    addRange(startH, startM, endH, endM);

    // Some schedules are stored as 12-hour values without AM/PM (e.g. 03:00
    // meaning 3 PM). In that case, also test a PM-shifted candidate.
    final canShiftToPm = startH >= 1 && startH <= 7 && endH >= 1 && endH <= 7;
    if (canShiftToPm) {
      addRange(startH + 12, startM, endH + 12, endM);
    }

    return ranges;
  }

  String _buildQrPayload(QrAttendanceSession session) {
    return jsonEncode(<String, dynamic>{
      'sessionId': session.sessionId,
      'sectionId': session.sectionId,
      'tokenId': session.currentTokenId,
      'tokenVersion': session.tokenVersion,
      'expiresAt': session.expiresAt.toUtc().toIso8601String(),
    });
  }

  void _recomputeNfcActiveForCurrentLecture() {
    final lecture = _activeLecture;
    if (lecture == null) {
      _isNfcActiveForLecture = false;
      return;
    }

    final sectionId = (lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) {
      _isNfcActiveForLecture = false;
      return;
    }

    final now = _effectiveNowForLectureWindow();
    final today = DateTime(now.year, now.month, now.day);
    _isNfcActiveForLecture = _openNfcSessions.any((session) {
      return session.isOpen &&
          session.sectionId == sectionId &&
          session.lectureStartTime.trim() == lecture.startTime.trim() &&
          _isSameDate(session.lectureDate, today);
    });
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _onRefreshPressed() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final lecture = _activeLecture;
    if (lecture == null) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingSession = true;
      _sessionErrorMessage = null;
    });

    try {
      if (_qrSession != null) {
        final refreshed = await _qrAttendanceService.refreshSessionToken(
          _qrSession!.sessionId,
        );
        if (!mounted) return;
        setState(() {
          _qrSession = refreshed;
          _qrData = _buildQrPayload(refreshed);
        });
        _startCodeRefreshTimer();
      } else {
        await _syncLectureAndCode();
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _sessionErrorMessage = e.code == 'permission-denied'
            ? 'فشل تحديث رمز QR: لا توجد صلاحية للوصول إلى Firestore.'
            : 'فشل تحديث رمز QR من Firestore.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessionErrorMessage = 'فشل تحديث رمز QR من Firestore.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSession = false;
        });
      }
    }

    if (_sessionErrorMessage != null) {
      messenger?.showSnackBar(SnackBar(content: Text(_sessionErrorMessage!)));
    }
  }

  void _startCodeRefreshTimer() {
    _stopCodeRefreshTimer();
    _codeRefreshSecondsLeft = _codeRefreshIntervalSeconds;
    _codeRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted ||
          _selectedMethod != _CheckInMethod.qr ||
          _qrSession == null ||
          _isLoadingSession) {
        return;
      }
      if (_codeRefreshSecondsLeft > 1) {
        setState(() => _codeRefreshSecondsLeft--);
        return;
      }
      await _onRefreshPressed();
      if (mounted) {
        setState(() => _codeRefreshSecondsLeft = _codeRefreshIntervalSeconds);
      }
    });
  }

  void _stopCodeRefreshTimer() {
    _codeRefreshTimer?.cancel();
    _codeRefreshTimer = null;
  }

  Future<void> _onBluetoothSelected() async {
    setState(() {
      _selectedMethod = _CheckInMethod.bluetooth;
      _sessionErrorMessage = null;
    });
    _stopCodeRefreshTimer();
    await _openOrConfirmBluetoothForCurrentLecture();
  }

  Future<void> _openOrConfirmBluetoothForCurrentLecture() async {
    final lecture = _activeLecture;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (lecture == null) {
      return;
    }

    setState(() => _isLoadingBluetoothAction = true);
    try {
      final session = await _bluetoothAttendanceService
          .createOrGetSessionForLecture(
            lecture: lecture,
            lectureDate: _effectiveNowForLectureWindow(),
          );
      if (!mounted) return;
      setState(() {
        _bluetoothSession = session;
        _sessionErrorMessage = null;
        _bluetoothBroadcastState = BluetoothBroadcastState.idle;
        _bluetoothBroadcastMessage ??= _tr(
          'اضغط على «بدء البث» لإرسال إشارة البلوتوث.',
          'Tap Start Broadcasting to send the Bluetooth signal.',
        );
      });
      _startBluetoothTokenTimer();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'جلسة البلوتوث نشطة لهذه المحاضرة.',
              'Bluetooth session active for this lecture.',
            ),
          ),
          backgroundColor: const Color(0xFF2B9E56),
        ),
      );
    } on BluetoothAttendanceException catch (e) {
      if (!mounted) return;
      setState(() => _sessionErrorMessage = _mapBluetoothError(e));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _sessionErrorMessage = e.code == 'permission-denied'
            ? _tr(
                'تعذر فتح جلسة البلوتوث: لا توجد صلاحية للوصول إلى Firestore.',
                'Failed to start Bluetooth session: Firestore permission denied.',
              )
            : _tr(
                'تعذر فتح جلسة البلوتوث لهذه المحاضرة.',
                'Failed to start Bluetooth session for this lecture.',
              );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessionErrorMessage = _tr(
          'طريقة التحضير عبر البلوتوث غير متاحة حالياً.',
          'Bluetooth attendance is currently unavailable.',
        );
      });
    } finally {
      if (mounted) setState(() => _isLoadingBluetoothAction = false);
    }
  }

  Future<void> _closeBluetoothSession() async {
    final session = _bluetoothSession;
    if (_isClosingBluetoothSession || session == null) return;

    setState(() => _isClosingBluetoothSession = true);
    try {
      await _stopBluetoothBroadcast();
      await _bluetoothAttendanceService.closeSession(session.sessionId);
      if (!mounted) return;
      _stopBluetoothTokenTimer();
      setState(() {
        _bluetoothSession = null;
        _sessionErrorMessage = null;
        _bluetoothBroadcastState = BluetoothBroadcastState.idle;
        _bluetoothBroadcastMessage = null;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            _tr('تم إغلاق جلسة البلوتوث.', 'Bluetooth session closed.'),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _sessionErrorMessage = e.code == 'permission-denied'
            ? _tr(
                'تعذر إغلاق جلسة البلوتوث: لا توجد صلاحية للوصول إلى Firestore.',
                'Failed to close Bluetooth session: Firestore permission denied.',
              )
            : _tr(
                'تعذر إغلاق جلسة البلوتوث.',
                'Failed to close Bluetooth session.',
              );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessionErrorMessage = _tr(
          'تعذر إغلاق جلسة البلوتوث.',
          'Failed to close Bluetooth session.',
        );
      });
    } finally {
      if (mounted) setState(() => _isClosingBluetoothSession = false);
    }
  }

  Future<void> _startBluetoothBroadcast({bool showSnack = true}) async {
    final session = _bluetoothSession;
    if (session == null ||
        _isStartingBluetoothBroadcast ||
        _isStoppingBluetoothBroadcast ||
        _bluetoothBroadcastState == BluetoothBroadcastState.broadcasting) {
      return;
    }

    setState(() {
      _isStartingBluetoothBroadcast = true;
      _bluetoothBroadcastState = BluetoothBroadcastState.requestingPermission;
      _bluetoothBroadcastMessage = _tr(
        'جاري التحقق من صلاحيات البلوتوث...',
        'Checking Bluetooth permissions...',
      );
    });

    try {
      final result = await _bluetoothBleService.startAdvertisingSession(
        session,
      );
      if (!mounted) return;
      setState(() {
        _isStartingBluetoothBroadcast = false;
        _bluetoothBroadcastState = result.state;
        _bluetoothBroadcastMessage = _localizedBluetoothHardwareMessage(
          result.message,
          broadcasting: true,
        );
      });
      if (showSnack && !result.isBroadcasting) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(_bluetoothBroadcastMessage ?? result.message),
            backgroundColor: const Color(0xFFD14A4A),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStartingBluetoothBroadcast = false;
        _bluetoothBroadcastState = BluetoothBroadcastState.error;
        _bluetoothBroadcastMessage = _tr(
          'تعذر بدء البث',
          'Failed to start broadcast',
        );
      });
      if (showSnack) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(_bluetoothBroadcastMessage!),
            backgroundColor: const Color(0xFFD14A4A),
          ),
        );
      }
    }
  }

  Future<void> _stopBluetoothBroadcast() async {
    if (_isStoppingBluetoothBroadcast || _isStartingBluetoothBroadcast) return;
    setState(() => _isStoppingBluetoothBroadcast = true);
    try {
      await _bluetoothBleService.stopAdvertisingSession();
      if (!mounted) return;
      setState(() {
        _bluetoothBroadcastState = BluetoothBroadcastState.idle;
        _bluetoothBroadcastMessage = _tr('تم إيقاف البث', 'Broadcast stopped');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bluetoothBroadcastMessage = _tr(
          'تعذر إيقاف البث',
          'Failed to stop broadcast',
        );
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(_bluetoothBroadcastMessage!),
          backgroundColor: const Color(0xFFD14A4A),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isStoppingBluetoothBroadcast = false);
      } else {
        _isStoppingBluetoothBroadcast = false;
      }
    }
  }

  String _bluetoothBroadcastStatusLabel() {
    if (_isStartingBluetoothBroadcast ||
        _bluetoothBroadcastState ==
            BluetoothBroadcastState.requestingPermission) {
      return _tr('جاري بدء البث...', 'Starting broadcast...');
    }
    if (_isStoppingBluetoothBroadcast) {
      return _tr('جاري إيقاف البث...', 'Stopping broadcast...');
    }
    if (_bluetoothBroadcastMessage != null &&
        _bluetoothBroadcastMessage!.trim().isNotEmpty) {
      return _bluetoothBroadcastMessage!;
    }
    if (_bluetoothBroadcastState == BluetoothBroadcastState.broadcasting) {
      return _tr(
        'يتم بث إشارة البلوتوث الآن',
        'Bluetooth signal is broadcasting now',
      );
    }
    return _tr('جلسة البلوتوث غير نشطة', 'Bluetooth session inactive');
  }

  String _localizedBluetoothHardwareMessage(
    String message, {
    required bool broadcasting,
  }) {
    final lower = message.toLowerCase();
    if (lower.contains('web')) {
      return broadcasting
          ? _tr(
              'بث البلوتوث غير مدعوم على الويب في هذه المرحلة.',
              'Bluetooth broadcasting is not supported on web in this phase.',
            )
          : _tr(
              'مسح البلوتوث يتطلب جهازًا محمولًا مدعومًا.',
              'Bluetooth scanning requires a supported mobile device.',
            );
    }
    if (lower.contains('not supported')) {
      return broadcasting
          ? _tr(
              'بث البلوتوث غير مدعوم على هذا الجهاز في هذه المرحلة.',
              'Bluetooth broadcasting is not supported on this device in this phase.',
            )
          : _tr(
              'البلوتوث غير مدعوم على هذا الجهاز.',
              'Bluetooth is not supported on this device.',
            );
    }
    if (lower.contains('permission')) {
      return _tr(
        'يحتاج التطبيق إلى صلاحية البلوتوث للمتابعة.',
        'Bluetooth permission is required to continue.',
      );
    }
    if (lower.contains('turned off')) {
      return _tr('البلوتوث غير مفعّل.', 'Bluetooth is turned off.');
    }
    if (lower.contains('still getting ready') ||
        lower.contains('unable to start bluetooth broadcast')) {
      return _tr(
        'تعذر بدء بث البلوتوث. يرجى التأكد من تشغيل البلوتوث ثم المحاولة مرة أخرى.',
        'Unable to start Bluetooth broadcast. Make sure Bluetooth is on and try again.',
      );
    }
    if (lower.contains('active')) {
      return _tr('بث البلوتوث نشط الآن.', 'Bluetooth broadcast is active.');
    }
    return message;
  }

  void _startBluetoothTokenTimer() {
    _stopBluetoothTokenTimer();
    _bluetoothTokenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted ||
          _selectedMethod != _CheckInMethod.bluetooth ||
          _bluetoothSession == null) {
        _stopBluetoothTokenTimer();
        return;
      }
      final sessionWindowLeft = _secondsUntilBluetoothSessionWindowClose();
      if (sessionWindowLeft <= 0) {
        unawaited(_closeBluetoothSession());
      }
    });
  }

  void _stopBluetoothTokenTimer() {
    _bluetoothTokenTimer?.cancel();
    _bluetoothTokenTimer = null;
  }

  int _secondsUntilBluetoothSessionWindowClose() {
    final session = _bluetoothSession;
    if (session == null) {
      return BluetoothAttendanceService.manualSessionOpenWindow.inSeconds;
    }
    final openedAt = session.openedAt ?? session.sessionOpenedAt;
    if (openedAt == null) {
      return BluetoothAttendanceService.manualSessionOpenWindow.inSeconds;
    }
    final closeAt = openedAt.add(
      BluetoothAttendanceService.manualSessionOpenWindow,
    );
    final remaining = closeAt.difference(DateTime.now()).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  String _mapBluetoothError(BluetoothAttendanceException error) {
    switch (error.code) {
      case BluetoothAttendanceErrorCode.missingLecturerSession:
        return _tr(
          'انتهت جلسة المحاضر. يرجى تسجيل الدخول من جديد.',
          'Lecturer session expired. Please log in again.',
        );
      case BluetoothAttendanceErrorCode.invalidInput:
        return _tr(
          'فشل فتح جلسة البلوتوث بسبب نقص بيانات المحاضرة.',
          'Failed to start Bluetooth because lecture data is incomplete.',
        );
      case BluetoothAttendanceErrorCode.sessionNotFound:
        return _tr(
          'تعذر العثور على جلسة البلوتوث.',
          'Bluetooth session was not found.',
        );
      case BluetoothAttendanceErrorCode.sessionClosed:
        return _tr('جلسة البلوتوث مغلقة', 'Bluetooth session is closed');
      case BluetoothAttendanceErrorCode.sessionExpired:
      case BluetoothAttendanceErrorCode.attendanceWindowClosed:
      case BluetoothAttendanceErrorCode.tokenMismatch:
        return _tr('انتهت صلاحية جلسة البلوتوث.', 'Bluetooth session expired.');
      case BluetoothAttendanceErrorCode.weakSignal:
      case BluetoothAttendanceErrorCode.studentNotEnrolled:
      case BluetoothAttendanceErrorCode.alreadyMarked:
      case BluetoothAttendanceErrorCode.unknown:
        return _tr(
          'تعذر فتح جلسة البلوتوث لهذه المحاضرة.',
          'Failed to start Bluetooth session for this lecture.',
        );
    }
  }

  Future<void> _onEnableNfcPressed() async {
    final lecture = _activeLecture;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (lecture == null) {
      return;
    }
    if (_isNfcActiveForLecture) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'التحضير عبر NFC مفعل بالفعل لهذه المحاضرة.',
              'NFC attendance is already active for this lecture.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoadingNfcAction = true);
    try {
      await _nfcAttendanceService.openSessionForLecture(
        lecture: lecture,
        lectureDate: _effectiveNowForLectureWindow(),
      );
      if (!mounted) return;
      setState(() => _isNfcActiveForLecture = true);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تم تفعيل التحضير عبر NFC لهذه المحاضرة.',
              'NFC attendance is now active for this lecture.',
            ),
          ),
          backgroundColor: const Color(0xFF2B9E56),
        ),
      );
    } on NfcAttendanceException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        NfcAttendanceErrorCode.missingLecturerCard => _tr(
          'NFC غير متاح: لا توجد بطاقة NFC مرتبطة بحسابك.',
          'NFC unavailable: no lecturer card is assigned to your account.',
        ),
        NfcAttendanceErrorCode.outsideLectureWindow => _tr(
          'لا يمكن تفعيل NFC الآن. متاح فقط أثناء نافذة وقت المحاضرة.',
          'NFC can only be enabled during the lecture attendance window.',
        ),
        NfcAttendanceErrorCode.invalidInput => _tr(
          'فشل تفعيل NFC بسبب نقص بيانات المحاضرة.',
          'Failed to enable NFC because lecture data is incomplete.',
        ),
        _ => _tr(
          'تعذر تفعيل NFC لهذه المحاضرة.',
          'Failed to enable NFC for this lecture.',
        ),
      };
      messenger?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تعذر تفعيل NFC لهذه المحاضرة.',
              'Failed to enable NFC for this lecture.',
            ),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingNfcAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UnifiedLecturerCatalog>>(
      lecturerUnifiedCatalogProvider,
      (prev, next) {
        next.whenData((cat) {
          if (!mounted) return;
          setState(() {
            _allLectures = cat.toLectureItems(
              isArabic: LecturerLanguageController.isArabic,
            );
          });
          unawaited(_syncLectureAndCode());
        });
      },
    );
    const primaryColor = Color(0xFF006571);
    final lecture = _activeLecture;

    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) => Directionality(
        textDirection: LecturerLanguageController.direction(),
        child: PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: Text(
                      _selectedMethod == _CheckInMethod.qr
                          ? _tr(
                              'قم بإظهار ال QR للطلاب',
                              'Show the QR to students',
                            )
                          : _selectedMethod == _CheckInMethod.nfc
                          ? _tr(
                              'فعّل التحضير عبر NFC للطلاب',
                              'Enable NFC attendance for students',
                            )
                          : _tr('فتح جلسة البلوتوث', 'Start Bluetooth Session'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        height: 1.4,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F5F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD9E5E8)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {
                                _selectedMethod = _CheckInMethod.qr;
                                _codeRefreshSecondsLeft =
                                    _codeRefreshIntervalSeconds;
                              });
                              _stopBluetoothTokenTimer();
                              if (_qrSession != null) {
                                _startCodeRefreshTimer();
                              }
                            },
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _selectedMethod == _CheckInMethod.qr
                                    ? const Color(0xFF006571)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'QR',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w800,
                                  color: _selectedMethod == _CheckInMethod.qr
                                      ? Colors.white
                                      : const Color(0xFF4F656B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(
                                () => _selectedMethod = _CheckInMethod.nfc,
                              );
                              _stopCodeRefreshTimer();
                              _stopBluetoothTokenTimer();
                            },
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _selectedMethod == _CheckInMethod.nfc
                                    ? const Color(0xFF006571)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'NFC',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w800,
                                  color: _selectedMethod == _CheckInMethod.nfc
                                      ? Colors.white
                                      : const Color(0xFF4F656B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _isLoadingBluetoothAction
                                ? null
                                : _onBluetoothSelected,
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    _selectedMethod == _CheckInMethod.bluetooth
                                    ? const Color(0xFF006571)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _tr('بلوتوث', 'Bluetooth'),
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color:
                                      _selectedMethod ==
                                          _CheckInMethod.bluetooth
                                      ? Colors.white
                                      : const Color(0xFF4F656B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (lecture != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          lecture.courseName,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'CRN${lecture.crn} | ${lecture.activity}، ${_tr('الشعبة', 'Section')} ${lecture.section}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        if (lecture.location != null &&
                            lecture.location!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_tr('الموقع', 'Location')}: ${lecture.location!.trim()}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ] else if (lecture.hall.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_tr('القاعة', 'Hall')}: ${lecture.hall.trim()}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: lecture.timeSlots.map((slot) {
                              return Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFB5C3C7),
                                    width: 0.9,
                                  ),
                                ),
                                child: Text(
                                  slot,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2E33),
                                    fontFamily: 'Cairo',
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.72,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedMethod == _CheckInMethod.qr &&
                              _isLoadingSession) ...[
                            const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _tr(
                                'جاري تحميل جلسة QR...',
                                'Loading QR session...',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF465A5F),
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ] else if (_selectedMethod == _CheckInMethod.nfc &&
                              _isLoadingNfcAction) ...[
                            const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: primaryColor,
                              ),
                            ),
                          ] else if (_selectedMethod ==
                                  _CheckInMethod.bluetooth &&
                              _isLoadingBluetoothAction) ...[
                            const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _tr(
                                'جاري فتح جلسة البلوتوث...',
                                'Starting Bluetooth session...',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF465A5F),
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _tr(
                                'جاري تفعيل NFC...',
                                'Activating NFC attendance...',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF465A5F),
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ] else if (lecture == null) ...[
                            const Icon(
                              Icons.event_busy_rounded,
                              size: 48,
                              color: primaryColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _tr(
                                'لا توجد محاضرة حالياً',
                                'No lecture is currently active',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF465A5F),
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ] else if (_sessionErrorMessage != null) ...[
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: primaryColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _sessionErrorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF465A5F),
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ] else if (_selectedMethod == _CheckInMethod.nfc) ...[
                            Icon(
                              _isNfcActiveForLecture
                                  ? Icons.nfc_rounded
                                  : Icons.nfc_outlined,
                              size: 64,
                              color: primaryColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isNfcActiveForLecture
                                  ? _tr(
                                      'NFC مفعل لهذه المحاضرة',
                                      'NFC is active for this lecture',
                                    )
                                  : _tr(
                                      'NFC غير مفعل بعد لهذه المحاضرة',
                                      'NFC is not active for this lecture yet',
                                    ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF465A5F),
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _tr(
                                'يمكن للطلاب التحضير بالبطاقة بعد تفعيل الجلسة.',
                                'Students can check in by card once the session is active.',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5F7A80),
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ] else if (_selectedMethod ==
                              _CheckInMethod.bluetooth) ...[
                            _buildBluetoothSessionPanel(),
                          ] else ...[
                            Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F5F6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD9E5E8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _QrDisplayChip(
                                      label: _tr('رمز QR', 'QR Code'),
                                      isActive:
                                          _qrDisplayMode ==
                                          _QrDisplayMode.qrCode,
                                      onTap: () => setState(
                                        () => _qrDisplayMode =
                                            _QrDisplayMode.qrCode,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _QrDisplayChip(
                                      label: _tr('الرمز الرقمي', 'Number Code'),
                                      isActive:
                                          _qrDisplayMode ==
                                          _QrDisplayMode.numberCode,
                                      onTap: () => setState(
                                        () => _qrDisplayMode =
                                            _QrDisplayMode.numberCode,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_qrDisplayMode == _QrDisplayMode.numberCode)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 22,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7FBFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFD9E5E8),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _tr('رمز الحضور', 'Attendance Code'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF465A5F),
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        _qrSession?.numericCode.isNotEmpty ==
                                                true
                                            ? _qrSession!.numericCode
                                            : '------',
                                        style: const TextStyle(
                                          fontSize: 42,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 8,
                                          color: Color(0xFF00474F),
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_tr('سيتم تحديث الرمز خلال', 'Code refreshes in')} ${_codeRefreshSecondsLeft}s',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF5F7A80),
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFF006571),
                                    width: 3,
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: QrImageView(
                                  data: _qrData,
                                  size: MediaQuery.of(context).size.width * 0.5,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Color(0xFF00474F),
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Color(0xFF00474F),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Text(
                              _tr('رمز الحضور: ', 'Attendance code: '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5F7A80),
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                _qrSession?.numericCode.isNotEmpty == true
                                    ? _qrSession!.numericCode
                                    : '------',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 5,
                                  color: Color(0xFF00474F),
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _tr(
                                'الجلسة متصلة بـ Firestore',
                                'Session is connected to Firestore',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5F7A80),
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                          if (lecture != null) ...[
                            const SizedBox(height: 22),
                            SizedBox(
                              width: 220,
                              height: 48,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF27A2A9),
                                      Color(0xFF006571),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: TextButton.icon(
                                  onPressed:
                                      _selectedMethod == _CheckInMethod.qr
                                      ? (_isLoadingSession
                                            ? null
                                            : _onRefreshPressed)
                                      : _selectedMethod == _CheckInMethod.nfc
                                      ? (_isLoadingNfcAction
                                            ? null
                                            : _onEnableNfcPressed)
                                      : (_isLoadingBluetoothAction
                                            ? null
                                            : _openOrConfirmBluetoothForCurrentLecture),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                  ),
                                  icon: Icon(
                                    _selectedMethod == _CheckInMethod.qr
                                        ? Icons.refresh_rounded
                                        : _selectedMethod == _CheckInMethod.nfc
                                        ? Icons.nfc_rounded
                                        : Icons.bluetooth_rounded,
                                    size: 20,
                                  ),
                                  label: Text(
                                    _selectedMethod == _CheckInMethod.qr
                                        ? _tr('تحديث الكود', 'Refresh Code')
                                        : _selectedMethod == _CheckInMethod.nfc
                                        ? _tr('تفعيل NFC', 'Enable NFC')
                                        : _tr(
                                            'فتح جلسة البلوتوث',
                                            'Start Bluetooth Session',
                                          ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildBluetoothSessionPanel() {
    final session = _bluetoothSession;
    final isBroadcasting =
        _bluetoothBroadcastState == BluetoothBroadcastState.broadcasting;
    final busy =
        _isLoadingBluetoothAction ||
        _isStartingBluetoothBroadcast ||
        _isStoppingBluetoothBroadcast ||
        _bluetoothBroadcastState ==
            BluetoothBroadcastState.requestingPermission;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isBroadcasting
              ? Icons.bluetooth_connected_rounded
              : Icons.bluetooth_rounded,
          size: 48,
          color: const Color(0xFF006571),
        ),
        const SizedBox(height: 10),
        Text(
          isBroadcasting
              ? _tr(
                  'يتم بث إشارة البلوتوث الآن',
                  'Bluetooth signal is broadcasting now',
                )
              : _tr('جلسة البلوتوث غير نشطة', 'Bluetooth session inactive'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF465A5F),
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _bluetoothBroadcastStatusLabel(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF5F7A80),
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: session == null || busy
                ? null
                : (isBroadcasting
                      ? _stopBluetoothBroadcast
                      : () => _startBluetoothBroadcast()),
            style: FilledButton.styleFrom(
              backgroundColor: isBroadcasting
                  ? const Color(0xFFD14A4A)
                  : const Color(0xFF006571),
              disabledBackgroundColor: const Color(0xFFB9C9CC),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isBroadcasting
                        ? Icons.bluetooth_disabled_rounded
                        : Icons.bluetooth_searching_rounded,
                    size: 18,
                  ),
            label: Text(
              isBroadcasting
                  ? _tr('إيقاف البث', 'Stop Broadcast')
                  : _tr('بدء البث', 'Start Broadcast'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QrDisplayChip extends StatelessWidget {
  const _QrDisplayChip({
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
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF006571) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isActive ? Colors.white : const Color(0xFF4F656B),
          ),
        ),
      ),
    );
  }
}

enum _CheckInMethod { qr, nfc, bluetooth }

enum _QrDisplayMode { qrCode, numberCode }
