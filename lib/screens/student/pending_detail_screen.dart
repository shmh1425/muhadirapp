import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'components/custom_nav_bar_icons.dart';
import 'components/notification_bell.dart';
import 'components/student_back_chevron_icon.dart';
import '../../widgets/lecturer/excuse_attachment_preview.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'submit_excuse_screen.dart';
import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';

class PendingDetailScreen extends StatefulWidget {
  final int studentId;
  final String attendanceRecordId;
  final String course;
  final String dateText;
  final String timeRange;
  final String? attachmentUrl;
  final String? attachmentName;

  const PendingDetailScreen({
    super.key,
    required this.studentId,
    required this.attendanceRecordId,
    required this.course,
    required this.dateText,
    required this.timeRange,
    this.attachmentUrl,
    this.attachmentName,
  });

  @override
  State<PendingDetailScreen> createState() => _PendingDetailScreenState();
}

class _PendingDetailScreenState extends State<PendingDetailScreen> {
  late final Future<
    ({
      String sectionId,
      String sessionId,
      DateTime lectureDate,
      String timeRange,
    })?
  >
  _attendanceMetaFuture;
  late final Future<({String url, String name})?>
  _excuseAttachmentFallbackFuture;

  @override
  void initState() {
    super.initState();
    _attendanceMetaFuture = _fetchAttendanceMeta();
    _excuseAttachmentFallbackFuture = _fetchExcuseAttachmentFromRequests();
  }

  Stream<Map<String, dynamic>?> _watchLatestPendingSubmission() {
    return FirebaseFirestore.instance
        .collection('student_notifications')
        .where('studentId', isEqualTo: widget.studentId)
        .where('attendanceRecordId', isEqualTo: widget.attendanceRecordId)
        .where('isExcuseSubmission', isEqualTo: true)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;

          DateTime? tsOf(Map<String, dynamic> d) {
            final c = d['clientCreatedAt'];
            if (c is Timestamp) return c.toDate();
            final s = d['createdAt'];
            if (s is Timestamp) return s.toDate();
            return null;
          }

          QueryDocumentSnapshot<Map<String, dynamic>>? best;
          DateTime? bestTs;

          for (final doc in snap.docs) {
            final t = tsOf(doc.data());
            if (best == null) {
              best = doc;
              bestTs = t;
              continue;
            }
            if (t == null && bestTs == null) continue;
            if (t != null && (bestTs == null || t.isAfter(bestTs))) {
              best = doc;
              bestTs = t;
            }
          }

          return (best ?? snap.docs.first).data();
        });
  }

  Future<
    ({
      String sectionId,
      String sessionId,
      DateTime lectureDate,
      String timeRange,
    })?
  >
  _fetchAttendanceMeta() async {
    final rid = widget.attendanceRecordId.trim();
    if (rid.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('manual_attendance_records')
          .doc(rid)
          .get();
      if (!snap.exists) return null;
      final data = snap.data() ?? <String, dynamic>{};
      final sectionId = (data['sectionId'] ?? '').toString().trim();
      final sessionId = (data['sessionId'] ?? '').toString().trim();

      DateTime lectureDate;
      final ts = data['lectureDate'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        lectureDate = DateTime(d.year, d.month, d.day);
      } else {
        final y = int.tryParse((data['lectureYear'] ?? '').toString()) ?? 0;
        final m = int.tryParse((data['lectureMonth'] ?? '').toString()) ?? 0;
        final d = int.tryParse((data['lectureDay'] ?? '').toString()) ?? 0;
        lectureDate = (y > 0 && m > 0 && d > 0)
            ? DateTime(y, m, d)
            : DateTime.now();
      }

      final start = (data['lectureStartTime'] ?? '').toString().trim();
      final end = (data['lectureEndTime'] ?? '').toString().trim();
      final range = (start.isNotEmpty && end.isNotEmpty)
          ? '$start-$end'
          : widget.timeRange;

      if (sectionId.isEmpty || sessionId.isEmpty) return null;
      return (
        sectionId: sectionId,
        sessionId: sessionId,
        lectureDate: lectureDate,
        timeRange: range,
      );
    } catch (_) {
      return null;
    }
  }

  Future<({String url, String name})?>
  _fetchExcuseAttachmentFromRequests() async {
    final rid = widget.attendanceRecordId.trim();
    if (rid.isEmpty || widget.studentId <= 0) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('excuse_requests')
          .where('studentId', isEqualTo: widget.studentId)
          .where('attendanceRecordId', isEqualTo: rid)
          .get();
      if (snap.docs.isEmpty) return null;

      DateTime? submittedAtOf(Map<String, dynamic> d) {
        final s = d['submittedAt'];
        if (s is Timestamp) return s.toDate();
        final c = d['createdAt'];
        if (c is Timestamp) return c.toDate();
        return null;
      }

      QueryDocumentSnapshot<Map<String, dynamic>>? best;
      DateTime? bestTs;
      for (final doc in snap.docs) {
        final url = (doc.data()['attachmentUrl'] ?? '').toString().trim();
        if (url.isEmpty) continue;
        final t = submittedAtOf(doc.data());
        if (best == null ||
            (t != null && (bestTs == null || t.isAfter(bestTs)))) {
          best = doc;
          bestTs = t;
        }
      }
      final picked = best ?? snap.docs.first;
      final data = picked.data();
      final url = (data['attachmentUrl'] ?? '').toString().trim();
      if (url.isEmpty) return null;
      final name = (data['attachmentName'] ?? '').toString().trim();
      return (url: url, name: name);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openAttachmentPreview(
    BuildContext context,
    String url,
    String? name,
  ) async {
    final u = url.trim();
    if (u.isEmpty) return;
    final t = TranslationController.instance;
    await ExcuseAttachmentPreview.showAttachmentPreviewDialog(
      context: context,
      attachmentUrl: u,
      attachmentName: (name ?? '').trim(),
      tr: (ar, en) => t.translateToEnglish ? en : ar,
      textDirection: t.textDirection,
      logTag: '[StudentExcusePreview]',
    );
  }

  String _resolveAttachmentUrl({
    required String streamUrl,
    required String? fallbackUrl,
  }) {
    if (streamUrl.trim().isNotEmpty) return streamUrl.trim();
    final initial = (widget.attachmentUrl ?? '').trim();
    if (initial.isNotEmpty) return initial;
    return (fallbackUrl ?? '').trim();
  }

  String _resolveAttachmentName({
    required String streamName,
    required String? fallbackName,
  }) {
    if (streamName.trim().isNotEmpty) return streamName.trim();
    final initial = (widget.attachmentName ?? '').trim();
    if (initial.isNotEmpty) return initial;
    return (fallbackName ?? '').trim();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TranslationController.instance,
      builder: (context, _) {
        final translation = TranslationController.instance;
        return Directionality(
          textDirection: translation.textDirection,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            bottomNavigationBar: NavBarSettingsArabic(
              selectedIndex: 1,
              onItemTapped: (index) {
                if (index == 0) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                } else if (index == 2) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                } else if (index == 1) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  _buildHeader(context),
                  Expanded(
                    child: StreamBuilder<Map<String, dynamic>?>(
                      stream: _watchLatestPendingSubmission(),
                      builder: (context, snap) {
                        if (snap.hasError && snap.data == null) {
                          debugPrint(
                            '[PendingDetail] stream error: ${snap.error}',
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: TText(
                              'تعذر تحميل تفاصيل العذر.',
                              style: const TextStyle(color: Color(0xFFB71C1C)),
                              textAlign: TextAlign.start,
                            ),
                          );
                        }

                        if (snap.hasError) {
                          debugPrint(
                            '[PendingDetail] stream error (ignored): ${snap.error}',
                          );
                        }

                        final data = (snap.data ?? const <String, dynamic>{});
                        final excuseText =
                            ((data['excuseText'] ?? data['reasonText']) ?? '')
                                .toString()
                                .trim();
                        final streamAttachmentName =
                            (data['attachmentName'] ?? '').toString().trim();
                        final streamAttachmentUrl =
                            (data['attachmentUrl'] ?? '').toString().trim();

                        return FutureBuilder<({String url, String name})?>(
                          future: _excuseAttachmentFallbackFuture,
                          builder: (context, fallbackSnap) {
                            final fallback = fallbackSnap.data;
                            final attachmentUrl = _resolveAttachmentUrl(
                              streamUrl: streamAttachmentUrl,
                              fallbackUrl: fallback?.url,
                            );
                            final attachmentName = _resolveAttachmentName(
                              streamName: streamAttachmentName,
                              fallbackName: fallback?.name,
                            );

                            return SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: _buildDetailCard(
                                context,
                                excuseText: excuseText,
                                attachmentName: attachmentName,
                                attachmentUrl: attachmentUrl,
                                translateToEnglish:
                                    translation.translateToEnglish,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: StudentBackChevronIcon(color: Color(0xFF006571), size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: TText(
              'إدارة الأعذار',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006571),
              ),
            ),
          ),
          const NotificationBell(),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required String excuseText,
    required String attachmentName,
    required String attachmentUrl,
    required bool translateToEnglish,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attachmentAvailable = attachmentUrl.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? colorScheme.outlineVariant.withValues(alpha: 0.75)
              : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.topStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE082),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                translateToEnglish ? 'Pending' : 'قيد الانتظار',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.72),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TText(
              widget.course,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TText(
              widget.dateText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              widget.timeRange,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.push_pin, color: Color(0xFFFFE082), size: 20),
                const SizedBox(width: 8),
                TText(
                  translateToEnglish ? 'Text:' : 'النص :',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: excuseText.isEmpty
                ? Text(
                    '—',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.start,
                  )
                : TText(
                    excuseText,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.start,
                  ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: !attachmentAvailable
                    ? null
                    : () => _openAttachmentPreview(
                        context,
                        attachmentUrl,
                        attachmentName.isNotEmpty ? attachmentName : null,
                      ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colorScheme.surface
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          color: attachmentAvailable
                              ? const Color(0xFF006571)
                              : colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      TText(
                        attachmentName.isNotEmpty
                            ? attachmentName
                            : (translateToEnglish
                                  ? 'Attachment'
                                  : 'مرفق العذر'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: !attachmentAvailable
                              ? colorScheme.onSurfaceVariant
                              : const Color(0xFF006571),
                          decoration: !attachmentAvailable
                              ? TextDecoration.none
                              : TextDecoration.underline,
                        ),
                      ),
                      if (attachmentAvailable) ...<Widget>[
                        const SizedBox(width: 8),
                        TText(
                          translateToEnglish ? 'Preview' : 'معاينة',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF006571),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TText(
              translateToEnglish
                  ? 'Excuse status: awaiting instructor review.'
                  : 'حالة العذر: بانتظار مراجعة الدكتور.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(height: 22),
          FutureBuilder<
            ({
              String sectionId,
              String sessionId,
              DateTime lectureDate,
              String timeRange,
            })?
          >(
            future: _attendanceMetaFuture,
            builder: (context, metaSnap) {
              final meta = metaSnap.data;
              final bool loading =
                  metaSnap.connectionState == ConnectionState.waiting;

              return SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final picked = meta ?? await _fetchAttendanceMeta();
                          if (picked == null) {
                            if (!context.mounted) return;
                            final t = TranslationController.instance;
                            final td = t.textDirection;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  translateToEnglish
                                      ? 'Could not load lecture details. Please try again.'
                                      : 'تعذر تحميل بيانات المحاضرة. حاول مرة أخرى.',
                                  textDirection: td,
                                ),
                                backgroundColor: const Color(0xFFB71C1C),
                              ),
                            );
                            return;
                          }
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => SubmitExcuseScreen(
                                course: widget.course,
                                dateText: widget.dateText,
                                timeRange: picked.timeRange,
                                sectionId: picked.sectionId,
                                lectureDate: picked.lectureDate,
                                sessionId: picked.sessionId,
                                attendanceRecordId: widget.attendanceRecordId,
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006571),
                    disabledBackgroundColor: const Color(
                      0xFF006571,
                    ).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : TText(
                          translateToEnglish
                              ? 'Update excuse'
                              : 'تعديل / إعادة رفع العذر',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
