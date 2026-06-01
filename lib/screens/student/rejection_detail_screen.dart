import 'dart:async';

import 'package:flutter/material.dart';
import 'components/notification_bell.dart';
import 'components/custom_nav_bar_icons.dart';
import 'components/student_back_chevron_icon.dart';
import 'home_screen.dart';
import 'submit_excuse_screen.dart';
import 'settings_screen.dart';
import '../../features/translation/translation_controller.dart';
import '../../widgets/lecturer/excuse_attachment_preview.dart';

class RejectionDetailScreen extends StatefulWidget {
  final String course;
  final String dateText;
  final String timeRange;
  final String reason;
  final String sectionId;
  final DateTime lectureDate;
  final String sessionId;
  final String attendanceRecordId;
  final String? attachmentUrl;
  final String? attachmentName;
  final DateTime? resubmitDeadline;

  const RejectionDetailScreen({
    super.key,
    required this.course,
    required this.dateText,
    required this.timeRange,
    required this.reason,
    required this.sectionId,
    required this.lectureDate,
    required this.sessionId,
    required this.attendanceRecordId,
    this.attachmentUrl,
    this.attachmentName,
    this.resubmitDeadline,
  });

  @override
  State<RejectionDetailScreen> createState() => _RejectionDetailScreenState();
}

class _RejectionDetailScreenState extends State<RejectionDetailScreen> {
  Timer? _resubmitTimer;

  bool get _canResubmit {
    final deadline = widget.resubmitDeadline;
    if (deadline == null) return true;
    return !DateTime.now().isAfter(deadline);
  }

  @override
  void initState() {
    super.initState();
    _scheduleResubmitTimer();
  }

  void _scheduleResubmitTimer() {
    _resubmitTimer?.cancel();
    final deadline = widget.resubmitDeadline;
    if (deadline == null || !_canResubmit) return;
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return;
    _resubmitTimer = Timer(remaining + const Duration(milliseconds: 200), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _resubmitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: _buildDetailCard(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: StudentBackChevronIcon(
              color: Color(0xFF006571),
              size: 16,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
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

  Widget _buildDetailCard(BuildContext context) {
    final translateToEnglish = TranslationController.instance.translateToEnglish;
    final canResubmit = _canResubmit;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.75 : 0.15,
          ),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.09),
            blurRadius: isDark ? 10 : 12,
            offset: Offset(0, isDark ? 4 : 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE57373),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                translateToEnglish ? 'Rejected' : 'تم الرفض',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              widget.course,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              widget.dateText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              widget.timeRange,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.push_pin,
                  color: Color(0xFFE57373),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  translateToEnglish ? 'Reason:' : 'السبب :',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              widget.reason,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: (widget.attachmentUrl ?? '').trim().isEmpty
                    ? null
                    : () async {
                        final t = TranslationController.instance;
                        await ExcuseAttachmentPreview.showAttachmentPreviewDialog(
                          context: context,
                          attachmentUrl: widget.attachmentUrl!.trim(),
                          attachmentName: widget.attachmentName?.trim() ?? '',
                          tr: (ar, en) => t.translateToEnglish ? en : ar,
                          textDirection: t.textDirection,
                          logTag: '[StudentExcusePreview]',
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF616161),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.attachmentName?.trim().isNotEmpty == true
                            ? widget.attachmentName!.trim()
                            : (translateToEnglish ? 'Excuse' : 'عذر'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: (widget.attachmentUrl ?? '').trim().isEmpty
                              ? Colors.grey.shade400
                              : const Color(0xFF006571),
                          decoration: (widget.attachmentUrl ?? '').trim().isEmpty
                              ? TextDecoration.none
                              : TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (canResubmit)
            Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFF27A2A9),
                    Color(0xFF006571),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubmitExcuseScreen(
                        course: widget.course,
                        dateText: widget.dateText,
                        timeRange: widget.timeRange,
                        sectionId: widget.sectionId,
                        lectureDate: widget.lectureDate,
                        sessionId: widget.sessionId,
                        attendanceRecordId: widget.attendanceRecordId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  translateToEnglish ? 'Resubmit excuse' : 'إعادة رفع عذر',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}
