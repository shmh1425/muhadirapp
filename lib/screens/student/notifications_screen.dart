import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<_NotificationItem> _items = List.of(_notifications);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
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
                  onPressed: _items.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _items.clear();
                          });
                        },
                  child: const Text(
                    'حذف الكل',
                    style: TextStyle(color: Color(0xFFE53935)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ..._items.map(
                (item) => Dismissible(
                  key: ValueKey(item.title + item.date),
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
                  onDismissed: (_) {
                    setState(() {
                      _items.remove(item);
                    });
                  },
                  child: _NotificationCard(item: item),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    required this.title,
    required this.message,
    required this.date,
    required this.type,
  });

  final String title;
  final String message;
  final String date;
  final _NotificationType type;
}

const List<_NotificationItem> _notifications = [
  _NotificationItem(
    title: 'إشعار قبول العذر',
    message: 'تم قبول العذر المرفق لمقرر "بحوث العمليات".',
    date: 'الأربعاء 21 مايو 2025',
    type: _NotificationType.success,
  ),
  _NotificationItem(
    title: 'إشعار رفض العذر',
    message: 'تم رفض العذر المرفق لمقرر "جودة البرمجيات".',
    date: 'الأحد 18 مايو 2025',
    type: _NotificationType.error,
  ),
  _NotificationItem(
    title: 'تحذير من الحرمان',
    message:
        'تجاوزت نسبة الغياب في مقرر "بحوث العمليات" إلى 14% نرجو الحضور لتفادي الحرمان الأكاديمي.',
    date: 'السبت 17 مايو 2025',
    type: _NotificationType.warning,
  ),
  _NotificationItem(
    title: 'إلغاء محاضرة',
    message: 'تم إلغاء محاضرة "الثقافة الإسلامية" للشعبة 2.',
    date: 'الاثنين 19 مايو 2025',
    type: _NotificationType.info,
  ),
  _NotificationItem(
    title: 'محاولة دخول غير مصرح بها',
    message:
        'تم رصد محاولة دخول باستخدام بطاقتك الجامعية لكن لم يتم تطابق البصمة مع المسجل.',
    date: 'الثلاثاء 20 مايو 2025',
    type: _NotificationType.error,
  ),
  _NotificationItem(
    title: 'تأخير المحاضرة',
    message: 'تم تأخير محاضرة "الثقافة الإسلامية" للشعبة 2.',
    date: 'الاثنين 26 مايو 2025 مدة 15 دقيقة.',
    type: _NotificationType.info,
  ),
];
