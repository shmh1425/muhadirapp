import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:share_plus/share_plus.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../models/attendance/manual_attendance_session.dart';
import '../../repositories/lecturer_catalog_repository.dart';
import '../lecturer_auth_service.dart';
import 'manual_attendance_service.dart';

/// Phase 1: single-session CSV export from authoritative Firestore attendance data.
class AttendanceSessionExportService {
  AttendanceSessionExportService._();
  static final AttendanceSessionExportService instance =
      AttendanceSessionExportService._();

  final ManualAttendanceService _manual = ManualAttendanceService.instance;

  /// Loads [manual_attendance_sessions] + [manual_attendance_records] for [sessionId],
  /// verifies the current lecturer owns [session.sectionId], builds UTF-8 CSV with BOM,
  /// and opens the system share sheet ([XFile.fromData] — works on web without `dart:io`).
  ///
  /// iOS note: when sharing XFile.fromData, file name must be passed via
  /// fileNameOverrides (the `name` in XFile.fromData is ignored on most platforms).
  Future<void> exportSessionCsvAndShare(String sessionId) async {
    final sid = sessionId.trim();
    if (sid.isEmpty) {
      throw StateError('sessionId is empty');
    }

    final session = await _manual.getSessionById(sid);
    if (session == null) {
      throw StateError('Session not found');
    }

    final owns = await _currentLecturerOwnsSection(session.sectionId);
    if (!owns) {
      throw StateError('Not authorized to export this session');
    }

    final grouped = await _manual.getRecordsForSessionIds({sid});
    final records = List<ManualAttendanceRecord>.from(
      grouped[sid] ?? const <ManualAttendanceRecord>[],
    )..sort((a, b) => a.studentName.compareTo(b.studentName));

    final csv = _buildCsv(session: session, records: records);
    final filename = _buildFilename(session);
    final raw = utf8.encode(csv);
    final bytes = Uint8List(3 + raw.length);
    bytes[0] = 0xEF;
    bytes[1] = 0xBB;
    bytes[2] = 0xBF;
    bytes.setRange(3, bytes.length, raw);

    final xFile = XFile.fromData(bytes, mimeType: 'text/csv');

    try {
      await Share.shareXFiles(
        [xFile],
        subject: filename,
        fileNameOverrides: [filename],
      );
    } catch (e) {
      // share_plus may call path_provider for temp files; channel can be missing after
      // hot reload or until a full native rebuild. Some embedders wrap as PlatformException.
      if (kIsWeb) rethrow;
      final usePlainShare =
          e is MissingPluginException ||
          (e is PlatformException &&
              (e.code == 'channel-error' ||
                  (e.message?.contains('No implementation found') ?? false) ||
                  (e.message?.contains('getTemporaryDirectory') ?? false)));
      if (!usePlainShare) rethrow;
      await Share.share(csv, subject: filename);
    }
  }

  Future<bool> _currentLecturerOwnsSection(String sectionId) async {
    final want = sectionId.trim();
    if (want.isEmpty) return false;
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    if (lecturerId.isEmpty) return false;
    final catalog =
        await LecturerCatalogRepository.instance.getCatalogForLecturer(
      lecturerId,
    );
    return catalog.sectionIds.contains(want);
  }

  String _buildFilename(ManualAttendanceSession session) {
    final d = session.lectureDate;
    final dateKey =
        '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final startKey = session.lectureStartTime.replaceAll(RegExp(r'[^\d]'), '');
    final cc = _sanitizeFilePart(session.courseCode ?? 'course');
    final sec = _sanitizeFilePart(session.sectionLabel);
    final shortSid = session.sessionId.length > 8
        ? session.sessionId.substring(0, 8)
        : session.sessionId;
    return 'Attendance_${cc}_${sec}_${dateKey}_${startKey}_$shortSid.csv';
  }

  String _sanitizeFilePart(String raw) {
    final withoutInvalidFsChars = raw.trim().replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    final asciiSafe = withoutInvalidFsChars
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (asciiSafe.isEmpty) return 'na';
    return asciiSafe.length > 32 ? asciiSafe.substring(0, 32) : asciiSafe;
  }

  String _buildCsv({
    required ManualAttendanceSession session,
    required List<ManualAttendanceRecord> records,
  }) {
    final buf = StringBuffer();
    final now = DateTime.now().toUtc();

    void meta(String k, String v) {
      buf.writeln('${_escapeCsv(k)},${_escapeCsv(v)}');
    }

    buf.writeln('${_escapeCsv('SECTION')},${_escapeCsv('METADATA')}');
    meta('exportGeneratedAtUtc', now.toIso8601String());
    meta('sessionId', session.sessionId);
    meta('sectionId', session.sectionId);
    meta('courseName', session.courseName);
    if (session.courseCode != null && session.courseCode!.isNotEmpty) {
      meta('courseCode', session.courseCode!);
    }
    meta('sectionLabel', session.sectionLabel);
    meta(
      'lectureDate',
      '${session.lectureDate.year}-${session.lectureDate.month.toString().padLeft(2, '0')}-${session.lectureDate.day.toString().padLeft(2, '0')}',
    );
    meta('lectureStartTime', session.lectureStartTime);
    meta('lectureEndTime', session.lectureEndTime);
    meta('dayOfWeek', '${session.dayOfWeek}');
    if (session.termId != null && session.termId!.isNotEmpty) {
      meta('termId', session.termId!);
    }
    if (session.officialWeekNumber != null) {
      meta('officialWeekNumber', '${session.officialWeekNumber}');
    }
    if (session.effectiveWeekNumber != null) {
      meta('effectiveWeekNumber', '${session.effectiveWeekNumber}');
    }
    meta('countInAttendance', '${session.countInAttendance}');
    meta('attendanceFinalized', '${session.attendanceFinalized}');
    if (session.lecturerId != null && session.lecturerId!.isNotEmpty) {
      meta('sessionLecturerId', session.lecturerId!);
    }

    int pending = 0, p = 0, a = 0, e = 0, l = 0;
    for (final r in records) {
      switch (r.status) {
        case ManualAttendanceStatus.pending:
          pending++;
          break;
        case ManualAttendanceStatus.present:
          p++;
          break;
        case ManualAttendanceStatus.absent:
          a++;
          break;
        case ManualAttendanceStatus.excused:
          e++;
          break;
        case ManualAttendanceStatus.late:
          l++;
          break;
      }
    }
    final total = records.length;

    buf.writeln();
    buf.writeln('${_escapeCsv('SECTION')},${_escapeCsv('SUMMARY')}');
    meta('totalStudents', '$total');
    meta('pendingCount', '$pending');
    meta('presentCount', '$p');
    meta('absentCount', '$a');
    meta('excusedCount', '$e');
    meta('lateCount', '$l');
    if (total > 0) {
      meta('presentPct', ((p / total) * 100).toStringAsFixed(2));
      meta('absentPct', ((a / total) * 100).toStringAsFixed(2));
      meta('excusedPct', ((e / total) * 100).toStringAsFixed(2));
      meta('latePct', ((l / total) * 100).toStringAsFixed(2));
    }

    buf.writeln();
    buf.writeln('${_escapeCsv('SECTION')},${_escapeCsv('STUDENTS')}');
    buf.writeln(
      [
        'recordId',
        'studentId',
        'studentName',
        'status',
        'attendanceTime',
        'courseCode',
        'lectureStartTime',
        'lectureEndTime',
      ].map(_escapeCsv).join(','),
    );

    for (final r in records) {
      buf.writeln(
        [
          _escapeCsv(r.recordId),
          _escapeCsv('${r.studentId}'),
          _escapeCsv(r.studentName),
          _escapeCsv(ManualAttendanceRecord.statusToString(r.status)),
          _escapeCsv(r.attendanceTime),
          _escapeCsv(r.courseCode ?? ''),
          _escapeCsv(r.lectureStartTime),
          _escapeCsv(r.lectureEndTime),
        ].join(','),
      );
    }

    return buf.toString();
  }

  String _escapeCsv(String value) {
    final s = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
