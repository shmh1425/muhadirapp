import 'package:flutter/material.dart';

import 'lecturer_nav_bar.dart';
import 'lecturer_home_screen.dart';
import 'lecturer_qr_screen.dart';
import 'lecturer_profile_screen.dart';

class LecturerNotificationsScreen extends StatefulWidget {
  const LecturerNotificationsScreen({super.key});

  @override
  State<LecturerNotificationsScreen> createState() =>
      _LecturerNotificationsScreenState();
}

class _LecturerNotificationsScreenState
    extends State<LecturerNotificationsScreen> {
  int _selectedIndex = 0; // البروفايل في اليسار
  String _selectedCategory = 'الكل';

  final List<_LecturerNotification> _allNotifications =
      List.of(_mockLecturerNotifications);

  List<_LecturerNotification> get _filteredNotifications {
    if (_selectedCategory == 'الكل') return _allNotifications;
    return _allNotifications
        .where((n) => n.categoryLabel == _selectedCategory)
        .toList();
  }

  Future<void> _onItemTapped(int index) async {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        await Future.delayed(const Duration(milliseconds: 160));
        if (!mounted) return;
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LecturerProfileScreen(
              lecturer: LecturerProfile(
                name: 'أنـاس بوقس',
                email: 'username@example.com',
                college: 'كلية الحاسبات',
                department: 'هندسة البرمجيات',
              ),
            ),
          ),
        );
        break;
      case 1:
        await Future.delayed(const Duration(milliseconds: 160));
        if (!mounted) return;
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LecturerQrScreen(lecture: null),
          ),
        );
        break;
      case 2:
        await Future.delayed(const Duration(milliseconds: 160));
        if (!mounted) return;
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LecturerHomeScreen(),
          ),
        );
        break;
    }
  }

  void _changeCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _openDetails(_LecturerNotification notification) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LecturerNotificationDetailsScreen(
          notification: notification,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF006571);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: LecturerNavBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    SizedBox(width: 28),
                    Expanded(
                      child: Text(
                        'التنبيهات',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    SizedBox(width: 28),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _CategoryTabs(
                selected: _selectedCategory,
                onChanged: _changeCategory,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filteredNotifications.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد تنبيهات حالياً',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        itemCount: _filteredNotifications.length,
                        itemBuilder: (context, index) {
                          final item = _filteredNotifications[index];
                          return GestureDetector(
                            onTap: () => _openDetails(item),
                            child: _NotificationCard(item: item),
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
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = ['الكل', 'أكاديمي', 'شخصي', 'الطلاب'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: labels.map((label) {
          final bool isActive = label == selected;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : const Color(0xFF006571),
                ),
              ),
              selected: isActive,
              onSelected: (_) => onChanged(label),
              backgroundColor: const Color(0xFFE3F2F3),
              selectedColor: const Color(0xFF006571),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color:
                      isActive ? const Color(0xFF006571) : const Color(0xFFE0E0E0),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

enum _NotificationCategory { academic, personal, students }

class _LecturerNotification {
  const _LecturerNotification({
    required this.title,
    required this.message,
    required this.date,
    required this.type,
    required this.category,
  });

  final String title;
  final String message;
  final String date;
  final _NotificationType type;
  final _NotificationCategory category;

  String get categoryLabel {
    switch (category) {
      case _NotificationCategory.academic:
        return 'أكاديمي';
      case _NotificationCategory.personal:
        return 'شخصي';
      case _NotificationCategory.students:
        return 'الطلاب';
    }
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final _LecturerNotification item;

  @override
  Widget build(BuildContext context) {
    final style = _styles[item.type]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.border, width: 1.4),
      ),
      child: Row(
        children: [
          Icon(style.icon, color: style.iconColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: style.text,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LecturerNotificationDetailsScreen extends StatelessWidget {
  const LecturerNotificationDetailsScreen({
    super.key,
    required this.notification,
  });

  final _LecturerNotification notification;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF006571);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: primaryColor),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: const Text(
            'تفاصيل الاشعار',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: primaryColor,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                notification.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                notification.message,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                notification.date,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: _GradientButton(
                        label: 'قبول',
                        colors: const [
                          Color(0xFF27A2A9),
                          Color(0xFF006571),
                        ],
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم قبول الطلب.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GradientButton(
                        label: 'رفض',
                        colors: const [
                          Color(0xFFE53935),
                          Color(0xFFC62828),
                        ],
                        onPressed: () {
                          _showRejectDialog(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        String reason = '';
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'سبب الرفض',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اكتب سبب رفضك للعذر، سيصل للطالب مع حالة الطلب.',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 3,
                  onChanged: (value) => reason = value,
                  decoration: InputDecoration(
                    hintText: 'اكتب السبب هنا...',
                    hintStyle: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF006571),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        reason.isEmpty
                            ? 'تم رفض الطلب بدون سبب محدد.'
                            : 'تم رفض الطلب مع سبب: $reason',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text(
                  'تأكيد',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFF006571),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final List<Color> colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}

const List<_LecturerNotification> _mockLecturerNotifications = [
  _LecturerNotification(
    title: 'عذر طالب لمقرر الأمن السيبراني',
    message:
        'وصل عذر جديد من أحد الطلاب لمقرر "Cybersecurity". يمكنك مراجعة التفاصيل واتخاذ الإجراء المناسب.',
    date: 'الأربعاء 14 مايو 2025 - 09:34 ص',
    type: _NotificationType.warning,
    category: _NotificationCategory.academic,
  ),
  _LecturerNotification(
    title: 'تذكير بموعد تسليم الدرجات',
    message: 'تبقّى يومان على الموعد النهائي لرفع درجات مقرر "هندسة البرمجيات".',
    date: 'الثلاثاء 13 مايو 2025 - 11:10 ص',
    type: _NotificationType.info,
    category: _NotificationCategory.academic,
  ),
  _LecturerNotification(
    title: 'تنبيه أمني على حسابك',
    message:
        'تم رصد محاولة دخول غير معتادة على حسابك من جهاز جديد. إذا لم تكن أنت، يرجى تغيير كلمة المرور فوراً.',
    date: 'الأحد 11 مايو 2025 - 04:22 م',
    type: _NotificationType.error,
    category: _NotificationCategory.personal,
  ),
  _LecturerNotification(
    title: 'تنبيه غياب طالب',
    message:
        'الطالب "محمد علي" تجاوز نسبة الغياب المسموح بها في مقرر "بحوث العمليات".',
    date: 'السبت 10 مايو 2025 - 01:15 م',
    type: _NotificationType.warning,
    category: _NotificationCategory.students,
  ),
  _LecturerNotification(
    title: 'قبول عذر طالب',
    message: 'تم قبول العذر المرفق لطالب في مقرر "الثقافة الإسلامية".',
    date: 'الخميس 8 مايو 2025 - 10:05 ص',
    type: _NotificationType.success,
    category: _NotificationCategory.students,
  ),
];

