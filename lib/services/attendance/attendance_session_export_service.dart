import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:share_plus/share_plus.dart';

import '../../models/attendance/manual_attendance_session.dart';
import '../../screens/lecturer/lecturer_language.dart';
import 'export/attendance_session_export_csv_builder.dart';
import 'export/attendance_session_export_format.dart';
import 'export/attendance_session_export_model.dart';
import 'export/attendance_session_export_pdf_builder.dart';

/// Localized single-session attendance export (CSV + PDF) from Firestore.
class AttendanceSessionExportService {
  AttendanceSessionExportService._();
  static final AttendanceSessionExportService instance =
      AttendanceSessionExportService._();

  /// Builds export data and shares the selected [format].
  ///
  /// Language follows [isArabic] when set; otherwise [LecturerLanguageController].
  ///
  /// **Pending finalization (unchanged):** [ManualAttendanceService.getRecordsForSessionIds]
  /// may still finalize pending records to absent before read (except default-present sessions).
  Future<void> exportSessionAndShare(
    String sessionId, {
    required AttendanceSessionExportFormat format,
    bool? isArabic,
  }) async {
    final model = await AttendanceSessionExportModelBuilder.build(
      sessionId: sessionId,
      isArabic: isArabic,
    );

    switch (format) {
      case AttendanceSessionExportFormat.csv:
        await _shareCsv(model);
        break;
      case AttendanceSessionExportFormat.pdf:
        await _sharePdf(model);
        break;
    }
  }

  /// Backward-compatible CSV-only export.
  Future<void> exportSessionCsvAndShare(
    String sessionId, {
    bool? isArabic,
  }) =>
      exportSessionAndShare(
        sessionId,
        format: AttendanceSessionExportFormat.csv,
        isArabic: isArabic,
      );

  Future<void> exportSessionPdfAndShare(
    String sessionId, {
    bool? isArabic,
  }) =>
      exportSessionAndShare(
        sessionId,
        format: AttendanceSessionExportFormat.pdf,
        isArabic: isArabic,
      );

  Future<void> _shareCsv(AttendanceSessionExportModel model) async {
    final csv = AttendanceSessionExportCsvBuilder.build(model);
    final filename = _buildFilename(model.session, 'csv');
    final bytes = _utf8WithBom(csv);
    await _shareBytes(
      bytes: bytes,
      filename: filename,
      mimeType: 'text/csv',
      plainTextFallback: csv,
    );
  }

  Future<void> _sharePdf(AttendanceSessionExportModel model) async {
    final pdfBytes = await AttendanceSessionExportPdfBuilder.build(model);
    final filename = _buildFilename(model.session, 'pdf');
    await _shareBytes(
      bytes: pdfBytes,
      filename: filename,
      mimeType: 'application/pdf',
    );
  }

  Uint8List _utf8WithBom(String text) {
    final raw = utf8.encode(text);
    final bytes = Uint8List(3 + raw.length);
    bytes[0] = 0xEF;
    bytes[1] = 0xBB;
    bytes[2] = 0xBF;
    bytes.setRange(3, bytes.length, raw);
    return bytes;
  }

  Future<void> _shareBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    String? plainTextFallback,
  }) async {
    final xFile = XFile.fromData(bytes, mimeType: mimeType);

    try {
      await Share.shareXFiles(
        [xFile],
        subject: filename,
        fileNameOverrides: [filename],
      );
    } catch (e) {
      if (kIsWeb) rethrow;
      final usePlainShare =
          plainTextFallback != null &&
          (e is MissingPluginException ||
              (e is PlatformException &&
                  (e.code == 'channel-error' ||
                      (e.message?.contains('No implementation found') ?? false) ||
                      (e.message?.contains('getTemporaryDirectory') ?? false))));
      if (!usePlainShare) rethrow;
      await Share.share(plainTextFallback, subject: filename);
    }
  }

  String _buildFilename(ManualAttendanceSession session, String extension) {
    final d = session.lectureDate;
    final dateKey =
        '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final startKey = session.lectureStartTime.replaceAll(RegExp(r'[^\d]'), '');
    final cc = _sanitizeFilePart(session.courseCode ?? 'course');
    final sec = _sanitizeFilePart(session.sectionLabel);
    final shortSid = session.sessionId.length > 8
        ? session.sessionId.substring(0, 8)
        : session.sessionId;
    return 'Attendance_${cc}_${sec}_${dateKey}_${startKey}_$shortSid.$extension';
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
}
