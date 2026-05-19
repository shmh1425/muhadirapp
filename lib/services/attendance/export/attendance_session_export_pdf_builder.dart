import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'attendance_session_export_model.dart';

class AttendanceSessionExportPdfBuilder {
  AttendanceSessionExportPdfBuilder._();

  static Future<Uint8List> build(AttendanceSessionExportModel model) async {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontBoldData);

    final isRtl = model.locale.isArabic;
    final textDirection =
        isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final align = isRtl ? pw.TextAlign.right : pw.TextAlign.left;

    final doc = pw.Document();
    final loc = model.locale;
    final session = model.session;

    pw.Widget sectionTitle(String text) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
        child: pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.teal, width: 1),
            ),
          ),
          child: pw.Text(
            text,
            style: pw.TextStyle(font: fontBold, fontSize: 11),
            textAlign: align,
            textDirection: textDirection,
          ),
        ),
      );
    }

    pw.Widget metaLine(String label, String value) {
      final labelText = '$label:';
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: isRtl
              ? [
                  pw.Expanded(
                    child: pw.Text(
                      value,
                      style: pw.TextStyle(font: font, fontSize: 10),
                      textAlign: pw.TextAlign.left,
                      textDirection: textDirection,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    labelText,
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                    textDirection: textDirection,
                  ),
                ]
              : [
                  pw.Text(
                    labelText,
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                    textDirection: textDirection,
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Text(
                      value,
                      style: pw.TextStyle(font: font, fontSize: 10),
                      textAlign: pw.TextAlign.left,
                      textDirection: textDirection,
                    ),
                  ),
                ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: textDirection,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final blocks = <pw.Widget>[
            pw.Center(
              child: pw.Text(
                loc.reportTitle,
                style: pw.TextStyle(font: fontBold, fontSize: 18),
                textAlign: pw.TextAlign.center,
                textDirection: textDirection,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.teal, thickness: 1),
            pw.SizedBox(height: 8),
            sectionTitle(loc.sectionExportInfo),
            metaLine(loc.labelGeneratedAt, model.generatedAtDisplay),
            if (model.lecturerName.isNotEmpty)
              metaLine(loc.labelExportedBy, model.lecturerName),
            metaLine(loc.labelReportLanguage, loc.reportLanguageValue),
            sectionTitle(loc.sectionMetadata),
            metaLine(loc.labelCourseName, model.localizedCourseName),
            if (session.courseCode != null && session.courseCode!.isNotEmpty)
              metaLine(loc.labelCourseCode, session.courseCode!),
            metaLine(loc.labelSection, model.sectionDisplay),
            metaLine(loc.labelLectureDate, model.lectureDateIso),
            metaLine(loc.labelLectureTime, model.lectureTimeRange),
            metaLine(loc.labelDayOfWeek, model.dayOfWeekLabel),
            metaLine(loc.labelAttendanceMethod, model.attendanceMethodLabel),
            metaLine(loc.labelSessionId, session.sessionId),
          ];

          if (model.isDefaultPresent) {
            blocks.addAll([
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  border: pw.Border.all(color: PdfColors.amber700, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: isRtl
                      ? pw.CrossAxisAlignment.end
                      : pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      loc.labelDefaultPresentPolicy,
                      style: pw.TextStyle(font: fontBold, fontSize: 10),
                      textDirection: textDirection,
                      textAlign: align,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      loc.defaultPresentNote,
                      style: pw.TextStyle(font: font, fontSize: 9),
                      textDirection: textDirection,
                      textAlign: align,
                    ),
                  ],
                ),
              ),
            ]);
          }

          final s = model.summary;
          blocks.addAll([
            sectionTitle(loc.sectionSummary),
            metaLine(loc.labelTotalStudents, '${s.totalStudents}'),
            metaLine(loc.labelPresentCount, '${s.presentCount}'),
            metaLine(loc.labelAbsentCount, '${s.absentCount}'),
            metaLine(loc.labelExcusedCount, '${s.excusedCount}'),
            metaLine(loc.labelLateCount, '${s.lateCount}'),
            if (s.pendingCount > 0)
              metaLine(loc.labelPendingCount, '${s.pendingCount}'),
            metaLine(loc.labelSessionAttendancePct, '${s.sessionAttendancePct}%'),
            metaLine(loc.labelSessionAbsencePct, '${s.sessionAbsencePct}%'),
            metaLine(
              loc.labelDeprivedStudentsCount,
              '${s.deprivedStudentsCount}',
            ),
          ]);

          return blocks;
        },
      ),
    );

    if (model.students.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          textDirection: textDirection,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text(
              loc.sectionStudents,
              style: pw.TextStyle(font: fontBold, fontSize: 12),
              textAlign: align,
              textDirection: textDirection,
            ),
            pw.SizedBox(height: 8),
            _studentTable(model, font, fontBold, textDirection),
          ],
        ),
      );
    }

    return doc.save();
  }

  static pw.Widget _studentTable(
    AttendanceSessionExportModel model,
    pw.Font font,
    pw.Font fontBold,
    pw.TextDirection textDirection,
  ) {
    final loc = model.locale;
    final headerStyle = pw.TextStyle(font: fontBold, fontSize: 7.5);
    final cellStyle = pw.TextStyle(font: font, fontSize: 7);

    pw.Widget cell(String text, {bool header = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: pw.Text(
          text,
          style: header ? headerStyle : cellStyle,
          textDirection: textDirection,
          maxLines: 2,
        ),
      );
    }

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        cell(loc.colStudentId, header: true),
        cell(loc.colStudentName, header: true),
        cell(loc.colStatus, header: true),
        cell(loc.colAttendanceTime, header: true),
        cell(loc.colTotalAbsencePct, header: true),
        cell(loc.colUnexcusedAbsencePct, header: true),
        cell(loc.colExcusedAbsencePct, header: true),
        cell(loc.colAcademicDeprivation, header: true),
      ],
    );

    final dataRows = model.students.map(
      (row) => pw.TableRow(
        decoration: row.isAcademicallyDeprived
            ? const pw.BoxDecoration(color: PdfColors.red50)
            : null,
        children: [
          cell('${row.studentId}'),
          cell(row.studentName),
          cell(row.statusLabel),
          cell(row.attendanceTime),
          cell(row.totalAbsencePctDisplay),
          cell(row.unexcusedAbsencePctDisplay),
          cell(row.excusedAbsencePctDisplay),
          cell(row.deprivationLabel),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.25),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.1),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.1),
        4: const pw.FlexColumnWidth(1.1),
        5: const pw.FlexColumnWidth(1.2),
        6: const pw.FlexColumnWidth(1.1),
        7: const pw.FlexColumnWidth(1.4),
      },
      children: [headerRow, ...dataRows],
    );
  }
}
