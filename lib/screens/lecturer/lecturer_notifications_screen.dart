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

  final List<_LecturerNotification> _allNotifications = List.of(
    _mockLecturerNotifications,
  );

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
          MaterialPageRoute(builder: (_) => const LecturerHomeScreen()),
        );
        break;
    }
  }

  void _changeCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  Future<void> _openDetails(_LecturerNotification notification) async {
    final bool? deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _LecturerNotificationDetailsScreen(notification: notification),
      ),
    );

    if (deleted == true) {
      _deleteNotification(notification);
    }
  }

  void _deleteNotification(_LecturerNotification notification) {
    setState(() {
      _allNotifications.removeWhere((item) => item.id == notification.id);
    });
  }

  void _confirmDelete(_LecturerNotification notification) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: _ModernPopupDialog(
            title: const Text(
              'حذف الإشعار',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            accentColor: const Color(0xFFE53935),
            actions: [
              _DialogActionButton(
                label: 'إلغاء',
                onTap: () => Navigator.of(dialogContext).pop(),
                isPrimary: false,
              ),
              _DialogActionButton(
                label: 'حذف',
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _deleteNotification(notification);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الإشعار.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                isPrimary: true,
                primaryColor: const Color(0xFFE53935),
              ),
            ],
            child: const Text(
              'هل أنت متأكد من حذف هذا الإشعار؟ لا يمكن التراجع بعد الحذف.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        );
      },
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
                            child: _NotificationCard(
                              item: item,
                              onDelete: () => _confirmDelete(item),
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
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onChanged});

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
                  color: isActive
                      ? const Color(0xFF006571)
                      : const Color(0xFFE0E0E0),
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
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    required this.type,
    required this.category,
    this.isExcuseRequest = false,
    this.excuseDetails,
  });

  final int id;
  final String title;
  final String message;
  final String date;
  final _NotificationType type;
  final _NotificationCategory category;
  final bool isExcuseRequest;
  final _StudentExcuseDetails? excuseDetails;

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

class _StudentExcuseDetails {
  const _StudentExcuseDetails({
    required this.submissionDate,
    required this.submissionTime,
    required this.studentName,
    required this.academicNumber,
    required this.excuseText,
    required this.attachmentName,
  });

  final String submissionDate;
  final String submissionTime;
  final String studentName;
  final String academicNumber;
  final String excuseText;
  final String attachmentName;
}

enum _NotificationType { success, error, warning, info }

class _NotificationStyle {
  const _NotificationStyle({
    required this.accent,
    required this.soft,
    required this.icon,
    required this.iconColor,
  });

  final Color accent;
  final Color soft;
  final IconData icon;
  final Color iconColor;
}

const Map<_NotificationType, _NotificationStyle> _styles = {
  _NotificationType.success: _NotificationStyle(
    accent: Color(0xFF00B894),
    soft: Color(0xFFE8F8F2),
    icon: Icons.check,
    iconColor: Color(0xFF00B894),
  ),
  _NotificationType.error: _NotificationStyle(
    accent: Color(0xFFE53935),
    soft: Color(0xFFFDECEC),
    icon: Icons.close,
    iconColor: Color(0xFFE53935),
  ),
  _NotificationType.warning: _NotificationStyle(
    accent: Color(0xFFF9A825),
    soft: Color(0xFFFFF8E1),
    icon: Icons.warning_amber_rounded,
    iconColor: Color(0xFFF9A825),
  ),
  _NotificationType.info: _NotificationStyle(
    accent: Color(0xFF5C6BC0),
    soft: Color(0xFFE8EAF6),
    icon: Icons.info_outline,
    iconColor: Color(0xFF5C6BC0),
  ),
};

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onDelete});

  final _LecturerNotification item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final style = _styles[item.type]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE7EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: style.soft,
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, color: style.iconColor, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0E4F59),
                    fontFamily: 'Cairo',
                    fontSize: 14.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE53935),
                ),
                tooltip: 'حذف الإشعار',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _metaChip(
                item.categoryLabel,
                const Color(0xFFEAF6F7),
                const Color(0xFF006571),
              ),
              const SizedBox(width: 6),
              _metaChip(
                item.isExcuseRequest ? 'طلب عذر' : _typeLabel(item.type),
                style.soft,
                style.accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black87,
              fontFamily: 'Cairo',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: Color(0xFF8C8C8C),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.date,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.black54,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: Color(0xFF006571),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  String _typeLabel(_NotificationType type) {
    switch (type) {
      case _NotificationType.success:
        return 'نجاح';
      case _NotificationType.error:
        return 'تنبيه';
      case _NotificationType.warning:
        return 'تحذير';
      case _NotificationType.info:
        return 'معلومة';
    }
  }
}

class _LecturerNotificationDetailsScreen extends StatelessWidget {
  const _LecturerNotificationDetailsScreen({required this.notification});

  final _LecturerNotification notification;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF006571);
    final bool canApproveOrReject = notification.isExcuseRequest;
    final excuseDetails = notification.excuseDetails;

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
          actions: [
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFE53935),
              ),
              tooltip: 'حذف الإشعار',
              onPressed: () => _showDeleteDialog(context),
            ),
          ],
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
              if (excuseDetails != null) ...[
                const SizedBox(height: 16),
                _ExcusePreviewCard(
                  details: excuseDetails,
                  onPreviewAttachment: () =>
                      _showAttachmentPreviewDialog(context, excuseDetails),
                ),
              ],
              const Spacer(),
              if (canApproveOrReject)
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Expanded(
                        child: _GradientButton(
                          label: 'قبول',
                          colors: const [Color(0xFF27A2A9), Color(0xFF006571)],
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
                          colors: const [Color(0xFFE53935), Color(0xFFC62828)],
                          onPressed: () {
                            _showRejectDialog(context);
                          },
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 48,
                  child: _GradientButton(
                    label: 'إغلاق',
                    colors: const [Color(0xFF27A2A9), Color(0xFF006571)],
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: _ModernPopupDialog(
            title: const Text(
              'حذف الإشعار',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            accentColor: const Color(0xFFE53935),
            actions: [
              _DialogActionButton(
                label: 'إلغاء',
                onTap: () => Navigator.of(ctx).pop(),
                isPrimary: false,
              ),
              _DialogActionButton(
                label: 'حذف',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(true);
                },
                isPrimary: true,
                primaryColor: const Color(0xFFE53935),
              ),
            ],
            child: const Text(
              'سيتم حذف الإشعار بشكل نهائي.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        String reason = '';
        return Directionality(
          textDirection: TextDirection.rtl,
          child: _ModernPopupDialog(
            title: const Text(
              'سبب الرفض',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            accentColor: const Color(0xFFE53935),
            actions: [
              _DialogActionButton(
                label: 'إلغاء',
                onTap: () => Navigator.of(ctx).pop(),
                isPrimary: false,
              ),
              _DialogActionButton(
                label: 'تأكيد',
                onTap: () {
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
                isPrimary: true,
                primaryColor: const Color(0xFF006571),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اكتب سبب رفضك للعذر، سيصل للطالب مع حالة الطلب.',
                  style: TextStyle(fontSize: 13, fontFamily: 'Cairo'),
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
                      borderSide: const BorderSide(color: Color(0xFF006571)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAttachmentPreviewDialog(
    BuildContext context,
    _StudentExcuseDetails details,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: _ModernPopupDialog(
            title: const Text(
              'معاينة مرفق العذر',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            accentColor: const Color(0xFF006571),
            actions: [
              _DialogActionButton(
                label: 'إغلاق',
                onTap: () => Navigator.of(ctx).pop(),
                isPrimary: true,
                primaryColor: const Color(0xFF006571),
              ),
            ],
            child: Text(
              'اسم المرفق: ${details.attachmentName}\n\nمكان عرض ملف العذر الفعلي (PDF/صورة) يكون هنا.',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExcusePreviewCard extends StatelessWidget {
  const _ExcusePreviewCard({
    required this.details,
    required this.onPreviewAttachment,
  });

  final _StudentExcuseDetails details;
  final VoidCallback onPreviewAttachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewRow('تاريخ الاستلام', details.submissionDate),
          _previewRow('التوقيت', details.submissionTime),
          const SizedBox(height: 8),
          _previewRow('عذر الطالب', details.studentName),
          _previewRow('رقمه الجامعي', details.academicNumber),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFCECECE)),
          const SizedBox(height: 4),
          const Text(
            'تفاصيل العذر المرسل',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            details.excuseText,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onPreviewAttachment,
              icon: const Icon(
                Icons.attachment_rounded,
                color: Color(0xFF006571),
              ),
              label: const Text(
                'معاينة مرفق العذر',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFF006571),
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF006571)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ModernPopupDialog extends StatelessWidget {
  const _ModernPopupDialog({
    required this.title,
    required this.child,
    required this.actions,
    required this.accentColor,
  });

  final Widget title;
  final Widget child;
  final List<Widget> actions;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD8D8D8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            title,
            const SizedBox(height: 12),
            child,
            const SizedBox(height: 14),
            Row(
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  Expanded(child: actions[i]),
                  if (i != actions.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
    this.primaryColor = const Color(0xFF006571),
  });

  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isPrimary ? null : const Color(0xFFF2F2F2),
        gradient: isPrimary
            ? LinearGradient(
                colors: [primaryColor.withValues(alpha: 0.8), primaryColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w700,
          color: isPrimary ? Colors.white : const Color(0xFF444444),
        ),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: button,
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
    id: 1,
    title: 'عذر طالب لمقرر الأمن السيبراني',
    message:
        'وصل عذر جديد من أحد الطلاب لمقرر "Cybersecurity". يمكنك مراجعة التفاصيل واتخاذ الإجراء المناسب.',
    date: 'الأربعاء 14 مايو 2025 - 09:34 ص',
    type: _NotificationType.warning,
    category: _NotificationCategory.students,
    isExcuseRequest: true,
    excuseDetails: _StudentExcuseDetails(
      submissionDate: '14-05-2025',
      submissionTime: '12:00 ص',
      studentName: 'عبدالله محمد',
      academicNumber: '441234567',
      excuseText:
          'تعذر حضوري للمحاضرة بسبب ظرف صحي طارئ، وتم إرفاق التقرير الطبي المعتمد.',
      attachmentName: 'medical_excuse_14052025.pdf',
    ),
  ),
  _LecturerNotification(
    id: 2,
    title: 'تذكير بموعد تسليم الدرجات',
    message:
        'تبقّى يومان على الموعد النهائي لرفع درجات مقرر "هندسة البرمجيات".',
    date: 'الثلاثاء 13 مايو 2025 - 11:10 ص',
    type: _NotificationType.info,
    category: _NotificationCategory.academic,
  ),
  _LecturerNotification(
    id: 3,
    title: 'تنبيه أمني على حسابك',
    message:
        'تم رصد محاولة دخول غير معتادة على حسابك من جهاز جديد. إذا لم تكن أنت، يرجى تغيير كلمة المرور فوراً.',
    date: 'الأحد 11 مايو 2025 - 04:22 م',
    type: _NotificationType.error,
    category: _NotificationCategory.personal,
  ),
  _LecturerNotification(
    id: 4,
    title: 'تنبيه غياب طالب',
    message:
        'الطالب "محمد علي" تجاوز نسبة الغياب المسموح بها في مقرر "بحوث العمليات".',
    date: 'السبت 10 مايو 2025 - 01:15 م',
    type: _NotificationType.warning,
    category: _NotificationCategory.students,
  ),
  _LecturerNotification(
    id: 5,
    title: 'قبول عذر طالب',
    message: 'تم قبول العذر المرفق لطالب في مقرر "الثقافة الإسلامية".',
    date: 'الخميس 8 مايو 2025 - 10:05 ص',
    type: _NotificationType.success,
    category: _NotificationCategory.students,
  ),
];
