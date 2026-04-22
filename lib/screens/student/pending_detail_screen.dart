import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'components/custom_nav_bar_icons.dart';
import 'components/notification_bell.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class PendingDetailScreen extends StatelessWidget {
  final int studentId;
  final String attendanceRecordId;
  final String course;
  final String dateText;
  final String timeRange;

  const PendingDetailScreen({
    super.key,
    required this.studentId,
    required this.attendanceRecordId,
    required this.course,
    required this.dateText,
    required this.timeRange,
  });

  Stream<Map<String, dynamic>?> _watchLatestPendingSubmission() {
    return FirebaseFirestore.instance
        .collection('student_notifications')
        .where('studentId', isEqualTo: studentId)
        .where('attendanceRecordId', isEqualTo: attendanceRecordId)
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
        if (t != null && (bestTs == null || t.isAfter(bestTs!))) {
          best = doc;
          bestTs = t;
        }
      }

      return (best ?? snap.docs.first).data();
    });
  }

  Future<void> _openAttachment(BuildContext context, String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    final uri = Uri.tryParse(u);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح الملف.', textDirection: TextDirection.rtl),
          backgroundColor: Color(0xFFB71C1C),
        ),
      );
    }
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
                child: StreamBuilder<Map<String, dynamic>?>(
                  stream: _watchLatestPendingSubmission(),
                  builder: (context, snap) {
                    // If we already have data, keep showing it even if the stream later errors
                    // (e.g., transient network / backend sync errors).
                    if (snap.hasError && snap.data == null) {
                      debugPrint('[PendingDetail] stream error: ${snap.error}');
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Text(
                          'تعذر تحميل تفاصيل العذر.',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(color: Color(0xFFB71C1C)),
                        ),
                      );
                    }

                    if (snap.hasError) {
                      debugPrint('[PendingDetail] stream error (ignored): ${snap.error}');
                    }

                    final data = (snap.data ?? const <String, dynamic>{});
                    final excuseText = ((data['excuseText'] ?? data['reasonText']) ?? '')
                        .toString()
                        .trim();
                    final attachmentName =
                        (data['attachmentName'] ?? '').toString().trim();
                    final attachmentUrl =
                        (data['attachmentUrl'] ?? '').toString().trim();

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: _buildDetailCard(
                        context,
                        excuseText: excuseText,
                        attachmentName: attachmentName,
                        attachmentUrl: attachmentUrl,
                      ),
                    );
                  },
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
            icon: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(3.14159),
              child: const Icon(
                Icons.arrow_back_ios,
                color: Color(0xFF006571),
                size: 16,
              ),
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

  Widget _buildDetailCard(
    BuildContext context, {
    required String excuseText,
    required String attachmentName,
    required String attachmentUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                color: const Color(0xFFFFE082),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'قيد الانتظار',
                style: TextStyle(
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
              course,
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
              dateText,
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
              timeRange,
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
                  color: Color(0xFFFFE082),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'النص :',
                  style: TextStyle(
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
              excuseText.isEmpty ? '—' : excuseText,
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
            child: GestureDetector(
              onTap: attachmentUrl.trim().isEmpty
                  ? null
                  : () => _openAttachment(context, attachmentUrl),
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
                    attachmentName.isNotEmpty ? attachmentName : 'عذر',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: attachmentUrl.trim().isEmpty
                          ? Colors.grey.shade400
                          : const Color(0xFF006571),
                      decoration: attachmentUrl.trim().isEmpty
                          ? TextDecoration.none
                          : TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'حالة العذر: بانتظار مراجعة الدكتور.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

