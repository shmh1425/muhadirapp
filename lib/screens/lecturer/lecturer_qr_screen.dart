import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../models/attendance/qr_attendance_session.dart';
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
  StreamSubscription<void>? _calendarSyncSub;
  late String _qrData;
  LectureItem? _activeLecture;
  QrAttendanceSession? _qrSession;
  bool _isSyncRefreshing = false;
  bool _isLoadingSession = false;
  String? _sessionErrorMessage;

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  @override
  void initState() {
    super.initState();
    _qrData = '';
    _calendarSyncSub = CalendarSyncService.instance.watchChanges().listen(
      (_) => _handleRealtimeCalendarChange(),
    );
    _loadLectures();
  }

  @override
  void dispose() {
    _calendarSyncSub?.cancel();
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
      });
    }

    if (lecture == null) {
      if (!mounted) return;
      setState(() {
        _qrSession = null;
        _qrData = '';
      });
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
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _qrSession = null;
        _qrData = '';
        if (e.code == 'permission-denied') {
          _sessionErrorMessage = 'فشل إنشاء جلسة QR: لا توجد صلاحية للوصول إلى Firestore.';
        } else {
          _sessionErrorMessage = 'فشل إنشاء/جلب جلسة QR من Firestore.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _qrSession = null;
        _qrData = '';
        _sessionErrorMessage = 'فشل إنشاء/جلب جلسة QR من Firestore.';
      });
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
      messenger?.showSnackBar(
        SnackBar(
          content: Text(_sessionErrorMessage!),
        ),
      );
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
                      _tr('قم بإظهار ال QR للطلاب', 'Show the QR to students'),
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
                          if (_isLoadingSession) ...[
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
                          ] else ...[
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
                                  onPressed: _isLoadingSession
                                      ? null
                                      : _onRefreshPressed,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 20,
                                  ),
                                  label: Text(
                                    _tr('تحديث الكود', 'Refresh Code'),
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
