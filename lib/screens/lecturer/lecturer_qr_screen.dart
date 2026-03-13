import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/lecturer/lecture_item.dart';
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
  late String _qrData;
  LectureItem? _activeLecture;

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  @override
  void initState() {
    super.initState();
    _qrData = '';
    _loadLectures();
  }

  Future<void> _loadLectures() async {
    try {
      final list = await LecturerSectionsService.instance.getLecturesForCurrentLecturer();
      if (!mounted) return;
      setState(() {
        _allLectures = list;
        _syncLectureAndCode(generateCode: true);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _syncLectureAndCode(generateCode: true));
    }
  }

  void _syncLectureAndCode({required bool generateCode}) {
    _activeLecture = _resolveCurrentLecture();
    if (_activeLecture == null) {
      _qrData = '';
      return;
    }
    if (generateCode || _qrData.isEmpty) {
      _qrData = _generateNewCode(_activeLecture!);
    }
  }

  LectureItem? _resolveCurrentLecture() {
    if (widget.lecture != null) return widget.lecture;

    final now = DateTime.now();
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

  String _generateNewCode(LectureItem lecture) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final code = List.generate(
      8,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
    return '${lecture.crn}-$code-${DateTime.now().millisecondsSinceEpoch}';
  }

  void _onRefreshPressed() {
    setState(() {
      _syncLectureAndCode(generateCode: true);
    });

    if (_activeLecture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('لا توجد محاضرة حالياً', 'No lecture is currently active'),
          ),
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
                          if (lecture == null) ...[
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
                                  onPressed: _onRefreshPressed,
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
