import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/attendance/nfc_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../models/attendance/qr_attendance_session.dart';
import '../../services/attendance/nfc_attendance_service.dart';
import '../../services/attendance/qr_attendance_service.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import '../../services/lecturer/lecturer_sections_service.dart';
import '../../utils/shared/time_utils.dart';
import 'lecturer_language.dart';

class LecturerQrScreen extends StatefulWidget {
  const LecturerQrScreen({super.key, this.lecture});

  final LectureItem? lecture;

  @override
  State<LecturerQrScreen> createState() => _LecturerQrScreenState();
}

class _LecturerQrScreenState extends State<LecturerQrScreen> {
  List<LectureItem> _allLectures = [];
  final LectureRepository _calendarRepository = LectureRepository();
  final QrAttendanceService _qrAttendanceService = QrAttendanceService.instance;
  final NfcAttendanceService _nfcAttendanceService =
      NfcAttendanceService.instance;
  StreamSubscription<void>? _calendarSyncSub;
  StreamSubscription<List<NfcAttendanceSession>>? _nfcSessionsSub;
  late String _qrData;
  LectureItem? _activeLecture;
  QrAttendanceSession? _qrSession;
  List<NfcAttendanceSession> _openNfcSessions = <NfcAttendanceSession>[];
  bool _isSyncRefreshing = false;
  bool _isLoadingSession = false;
  bool _isLoadingNfcAction = false;
  bool _isNfcActiveForLecture = false;
  String? _sessionErrorMessage;
  _CheckInMethod _selectedMethod = _CheckInMethod.qr;
  _QrDisplayMode _qrDisplayMode = _QrDisplayMode.qrCode;
  Timer? _codeRefreshTimer;
  static const int _codeRefreshIntervalSeconds = 45;
  int _codeRefreshSecondsLeft = _codeRefreshIntervalSeconds;

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  @override
  void initState() {
    super.initState();
    _qrData = '';
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
    _loadLectures();
  }

  @override
  void dispose() {
    _calendarSyncSub?.cancel();
    _nfcSessionsSub?.cancel();
    _stopCodeRefreshTimer();
    super.dispose();
  }

  Future<void> _loadLectures() async {
    try {
      await _calendarRepository.refreshAcademicCalendar();
      final list = await LecturerSectionsService.instance
          .getLecturesForCurrentLecturer();
      if (!mounted) return;
      setState(() {
        _allLectures = list;
      });
      await _syncLectureAndCode();
    } catch (_) {
      if (!mounted) return;
      await _syncLectureAndCode();
    }
  }

  Future<void> _handleRealtimeCalendarChange() async {
    if (!mounted || _isSyncRefreshing) return;
    _isSyncRefreshing = true;
    try {
      await _calendarRepository.refreshAcademicCalendar();
      if (!mounted) return;
      await _syncLectureAndCode();
    } catch (_) {
      // Ignore transient realtime listener errors.
    } finally {
      _isSyncRefreshing = false;
    }
  }

  Future<void> _syncLectureAndCode() async {
    final lecture = _resolveCurrentLecture();
    if (mounted) {
      setState(() {
        _activeLecture = lecture;
        _sessionErrorMessage = null;
        _recomputeNfcActiveForCurrentLecture();
      });
    }

    if (lecture == null) {
      if (!mounted) return;
      setState(() {
        _qrSession = null;
        _qrData = '';
      });
      _stopCodeRefreshTimer();
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
  }

  LectureItem? _resolveCurrentLecture() {
    if (widget.lecture != null) return widget.lecture;

    final now = _calendarRepository.currentDateTime;
    final dayLectures = TimeUtils.sortLecturesByTime(
      _allLectures.where((l) => l.dayOfWeek == now.weekday).toList(),
      (l) => l.startTime,
    );
    for (final lecture in dayLectures) {
      if (_isCurrentLecture(lecture, now)) {
        return lecture;
      }
    }
    return null;
  }

  bool _isCurrentLecture(LectureItem lecture, DateTime now) {
    final (startH, startM) = TimeUtils.parseTimeString(lecture.startTime);
    final (endH, endM) = TimeUtils.parseTimeString(lecture.endTime);
    final start = DateTime(now.year, now.month, now.day, startH, startM);
    final end = DateTime(now.year, now.month, now.day, endH, endM);
    final isAfterStart = now.isAfter(start) || now.isAtSameMomentAs(start);
    final isBeforeEnd = now.isBefore(end) || now.isAtSameMomentAs(end);
    return isAfterStart && isBeforeEnd;
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

    final now = _calendarRepository.currentDateTime;
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
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            _tr('لا توجد محاضرة حالياً', 'No lecture is currently active'),
          ),
        ),
      );
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

  Future<void> _onEnableNfcPressed() async {
    final lecture = _activeLecture;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (lecture == null) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            _tr('لا توجد محاضرة حالياً', 'No lecture is currently active'),
          ),
        ),
      );
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
        lectureDate: _calendarRepository.currentDateTime,
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
    const primaryColor = Color(0xFF006571);
    final lecture = _activeLecture;

    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) => Directionality(
        textDirection: LecturerLanguageController.direction(),
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
                          : _tr(
                              'فعّل التحضير عبر NFC للطلاب',
                              'Enable NFC attendance for students',
                            ),
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
                                      : (_isLoadingNfcAction
                                            ? null
                                            : _onEnableNfcPressed),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                  ),
                                  icon: Icon(
                                    _selectedMethod == _CheckInMethod.qr
                                        ? Icons.refresh_rounded
                                        : Icons.nfc_rounded,
                                    size: 20,
                                  ),
                                  label: Text(
                                    _selectedMethod == _CheckInMethod.qr
                                        ? _tr('تحديث الكود', 'Refresh Code')
                                        : _tr('تفعيل NFC', 'Enable NFC'),
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

enum _CheckInMethod { qr, nfc }

enum _QrDisplayMode { qrCode, numberCode }
