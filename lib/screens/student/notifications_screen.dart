import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/student_auth_service.dart';
import '../../services/student_notifications_service.dart';
import '../../shared/widgets/chat_fab.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final StudentNotificationsService _notificationsService =
      StudentNotificationsService.instance;

  int get _studentId =>
      StudentAuthService.instance.currentStudent?.studentId ?? 0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: const ChatFAB(),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_forward_ios,
                        color: Color(0xFF006571)),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'التنبيهات',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006571),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _studentId <= 0
                      ? null
                      : _hideAllNotifications,
                  child: const Text(
                    'حذف الكل',
                    style: TextStyle(color: Color(0xFFE53935)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ..._buildNotificationContent(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNotificationContent() {
    if (_studentId <= 0) {
      return const <Widget>[
        _EmptyNotificationsMessage(
          message: 'سجّل دخولك كطالب لعرض التنبيهات.',
        ),
      ];
    }

    return <Widget>[
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('manual_attendance_records')
            .where('studentId', isEqualTo: _studentId)
            .where('status', whereIn: const <String>['absent', 'excused'])
            .snapshots(),
        builder: (context, recordsSnapshot) {
          if (recordsSnapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (recordsSnapshot.hasError) {
            return const _EmptyNotificationsMessage(
              message: 'تعذر تحميل التنبيهات حالياً.',
            );
          }

          return FutureBuilder<Set<String>>(
            future: _notificationsService.getHiddenNotificationIds(_studentId),
            builder: (context, hiddenSnapshot) {
              if (hiddenSnapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final hiddenIds = hiddenSnapshot.data ?? <String>{};
              final docs = recordsSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final items = docs
                  .where((doc) => !hiddenIds.contains(doc.id))
                  .map((doc) => _NotificationItem.fromAttendanceDoc(doc))
                  .toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

              if (items.isEmpty) {
                return const _EmptyNotificationsMessage(
                  message: 'لا يوجد إشعارات',
                );
              }

              return Column(
                children: items
                    .map(
                      (item) => Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _hideSingleNotification(item.id),
                        child: _NotificationCard(item: item),
                      ),
                    )
                    .toList(),
              );
            },
          );
        },
      ),
    ];
  }

  Future<void> _hideSingleNotification(String id) async {
    await _notificationsService.hideNotification(_studentId, id);
  }

  Future<void> _hideAllNotifications() async {
    if (_studentId <= 0) return;
    final query = await FirebaseFirestore.instance
        .collection('manual_attendance_records')
        .where('studentId', isEqualTo: _studentId)
        .where('status', whereIn: const <String>['absent', 'excused'])
        .get();
    final ids = query.docs.map((doc) => doc.id).toList();
    await _notificationsService.hideNotifications(_studentId, ids);
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final style = _styles[item.type]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: style.border, width: 1.4),
      ),
      child: Row(
        children: [
          Icon(style.icon, color: style.iconColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: style.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.message,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  item.date,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _NotificationType { success, error, warning, info }

class _NotificationStyle {
  const _NotificationStyle({
    required this.border,
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final Color border;
  final Color background;
  final IconData icon;
  final Color iconColor;
  final Color text;
}

const Map<_NotificationType, _NotificationStyle> _styles = {
  _NotificationType.success: _NotificationStyle(
    border: Color(0xFF00B894),
    background: Color(0xFFE8F8F2),
    icon: Icons.check,
    iconColor: Color(0xFF00B894),
    text: Color(0xFF006571),
  ),
  _NotificationType.error: _NotificationStyle(
    border: Color(0xFFE53935),
    background: Color(0xFFFDECEC),
    icon: Icons.close,
    iconColor: Color(0xFFE53935),
    text: Color(0xFF006571),
  ),
  _NotificationType.warning: _NotificationStyle(
    border: Color(0xFFF9A825),
    background: Color(0xFFFFF8E1),
    icon: Icons.warning_amber_rounded,
    iconColor: Color(0xFFF9A825),
    text: Color(0xFF006571),
  ),
  _NotificationType.info: _NotificationStyle(
    border: Color(0xFF5C6BC0),
    background: Color(0xFFE8EAF6),
    icon: Icons.info_outline,
    iconColor: Color(0xFF5C6BC0),
    text: Color(0xFF006571),
  ),
};

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    required this.type,
    required this.timestamp,
  });

  final String id;
  final String title;
  final String message;
  final String date;
  final _NotificationType type;
  final DateTime timestamp;

  factory _NotificationItem.fromAttendanceDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawStatus = (data['status'] ?? '').toString().trim().toLowerCase();
    final courseName = (data['courseName'] ?? data['courseTitle'] ?? 'المقرر')
        .toString()
        .trim();
    final section = (data['section'] ?? '').toString().trim();
    final date = _extractDate(data);
    final statusLabel = rawStatus == 'excused' ? 'بعذر' : 'بدون عذر';
    final title = rawStatus == 'excused' ? 'إشعار غياب بعذر' : 'إشعار غياب';
    final sectionLabel = section.isEmpty ? '' : ' - الشعبة $section';

    return _NotificationItem(
      id: doc.id,
      title: title,
      message: 'تم تسجيل غيابك ($statusLabel) في "$courseName"$sectionLabel.',
      date: _formatArabicDate(date),
      type: rawStatus == 'excused'
          ? _NotificationType.info
          : _NotificationType.warning,
      timestamp: date,
    );
  }

  static DateTime _extractDate(Map<String, dynamic> data) {
    final lectureDate = data['lectureDate'];
    if (lectureDate is Timestamp) {
      return lectureDate.toDate();
    }

    final year = _safeInt(data['lectureYear']);
    final month = _safeInt(data['lectureMonth']);
    final day = _safeInt(data['lectureDay']);
    if (year > 0 && month > 0 && day > 0) {
      return DateTime(year, month, day);
    }

    final dateKey = (data['dateKey'] ?? '').toString().trim();
    if (dateKey.length == 8) {
      final y = int.tryParse(dateKey.substring(0, 4));
      final m = int.tryParse(dateKey.substring(4, 6));
      final d = int.tryParse(dateKey.substring(6, 8));
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }

    return DateTime.now();
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  static String _formatArabicDate(DateTime date) {
    const days = <String>[
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    const months = <String>[
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final dayName = days[(date.weekday - 1).clamp(0, 6)];
    final monthName = months[(date.month - 1).clamp(0, 11)];
    return '$dayName ${date.day} $monthName ${date.year}';
  }
}

class _EmptyNotificationsMessage extends StatelessWidget {
  const _EmptyNotificationsMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
