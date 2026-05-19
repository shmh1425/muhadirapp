import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/external_student.dart';
import '../../models/notifications/lecturer_notification.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../utils/lecturer_notification_display.dart';
import '../../utils/localized_firestore_fields.dart';
import '../../repositories/lecturer_catalog_repository.dart';
import '../../services/lecturer/lecturer_course_name_index.dart';
import '../../services/lecturer_auth_service.dart';
import '../../services/notifications/lecturer_notification_service.dart';
import '../../widgets/lecturer/excuse_attachment_preview.dart';
import '../../widgets/lecturer/excuse_rejection_reason_dialog.dart';
import 'lecturer_language.dart';
import 'lecturer_strings.dart';
import 'widgets/directional_navigation_icon.dart';
import 'widgets/modern_popup_dialog.dart';
import 'widgets/profile_back_button.dart';

class LecturerNotificationsScreen extends StatefulWidget {
  const LecturerNotificationsScreen({super.key});

  @override
  State<LecturerNotificationsScreen> createState() =>
      _LecturerNotificationsScreenState();
}

class _LecturerNotificationsScreenState
    extends State<LecturerNotificationsScreen> {
  final LecturerNotificationService _notificationService =
      LecturerNotificationService.instance;

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  @override
  void initState() {
    super.initState();
    _warmCourseNameIndexFromCache();
  }

  void _warmCourseNameIndexFromCache() {
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    if (lecturerId.isEmpty) return;
    final catalog =
        LecturerCatalogRepository.instance.getCachedCatalog(lecturerId);
    if (catalog != null && !catalog.isEmpty) {
      LecturerCourseNameIndex.instance.updateFromCatalog(catalog);
    }
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  Future<void> _openDetails(LecturerNotification notification) async {
    try {
      await _notificationService.markAsRead(notification.id);
    } on FirebaseException catch (e, st) {
      debugPrint('[LecturerNotifications] markAsRead failed: $e\n$st');
    } catch (e, st) {
      debugPrint('[LecturerNotifications] markAsRead failed: $e\n$st');
    }

    if (!mounted) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _LecturerNotificationDetailsScreen(
          notification: notification,
          service: _notificationService,
        ),
      ),
    );
  }

  Future<void> _deleteNotification(LecturerNotification notification) async {
    try {
      await _notificationService.deleteNotification(notification.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('تم حذف الإشعار.', 'Notification deleted.')),
          duration: const Duration(seconds: 2),
        ),
      );
    } on FirebaseException catch (e, st) {
      debugPrint('[LecturerNotifications] deleteNotification failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تعذر حذف الإشعار. حاول مرة أخرى.',
              'Unable to delete notification. Please try again.',
            ),
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('[LecturerNotifications] deleteNotification failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تعذر حذف الإشعار. حاول مرة أخرى.',
              'Unable to delete notification. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  void _confirmDelete(LecturerNotification notification) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: ModernPopupDialog(
            title: Text(
              _tr('حذف الإشعار', 'Delete Notification'),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            accentColor: const Color(0xFFE53935),
            actions: [
              ModernPopupActionButton(
                label: _tr('إلغاء', 'Cancel'),
                onTap: () => Navigator.of(dialogContext).pop(),
                isPrimary: false,
              ),
              ModernPopupActionButton(
                label: _tr('حذف', 'Delete'),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _deleteNotification(notification);
                },
                isPrimary: true,
                primaryColor: const Color(0xFFE53935),
              ),
            ],
            child: Text(
              _tr(
                'هل أنت متأكد من حذف هذا الإشعار؟ لا يمكن التراجع بعد الحذف.',
                'Are you sure you want to delete this notification? This action cannot be undone.',
              ),
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

  void _confirmDeleteAll() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: ModernPopupDialog(
            title: Text(
              _tr('حذف كل الإشعارات', 'Delete all notifications'),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            accentColor: const Color(0xFFE53935),
            actions: [
              ModernPopupActionButton(
                label: _tr('إلغاء', 'Cancel'),
                onTap: () => Navigator.of(dialogContext).pop(),
                isPrimary: false,
              ),
              ModernPopupActionButton(
                label: _tr('حذف الكل', 'Delete all'),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _deleteAll();
                },
                isPrimary: true,
                primaryColor: const Color(0xFFE53935),
              ),
            ],
            child: Text(
              _tr(
                'سيتم حذف جميع الإشعارات نهائيًا. هل تريد المتابعة؟',
                'This will permanently delete all notifications. Continue?',
              ),
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

  Future<void> _deleteAll() async {
    try {
      await _notificationService.deleteAllForCurrentLecturer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تم حذف جميع الإشعارات.',
              'All notifications have been deleted.',
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } on FirebaseException catch (e, st) {
      debugPrint('[LecturerNotifications] deleteAll failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تعذر حذف جميع الإشعارات. حاول مرة أخرى.',
              'Unable to delete all notifications. Please try again.',
            ),
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('[LecturerNotifications] deleteAll failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تعذر حذف جميع الإشعارات. حاول مرة أخرى.',
              'Unable to delete all notifications. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  List<LecturerNotification> _sortNotifications(
    List<LecturerNotification> all,
  ) {
    final sorted = List<LecturerNotification>.from(all);
    sorted.sort((a, b) {
      if (a.isRead != b.isRead) return a.isRead ? 1 : -1;
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return sorted;
  }

  DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<_NotificationGroup> _groupNotifications(List<LecturerNotification> all) {
    final sorted = _sortNotifications(all);
    final now = DateTime.now();
    final today = _dayOnly(now);
    final weekStart = today.subtract(Duration(days: today.weekday % 7));

    final unread = <LecturerNotification>[];
    final todayItems = <LecturerNotification>[];
    final thisWeek = <LecturerNotification>[];
    final older = <LecturerNotification>[];

    for (final item in sorted) {
      final created = item.createdAt;
      if (created == null) {
        older.add(item);
        continue;
      }
      final day = _dayOnly(created.toLocal());
      if (!item.isRead) unread.add(item);
      if (_isSameDay(day, today)) {
        todayItems.add(item);
      } else if ((day.isAfter(weekStart) || _isSameDay(day, weekStart)) &&
          day.isBefore(today)) {
        thisWeek.add(item);
      } else if (day.isBefore(weekStart)) {
        older.add(item);
      }
    }

    final groups = <_NotificationGroup>[];
    if (unread.isNotEmpty) {
      groups.add(
        _NotificationGroup(
          titleAr: 'غير مقروءة',
          titleEn: 'Unread',
          items: unread,
          highlight: true,
        ),
      );
    }
    if (todayItems.isNotEmpty) {
      groups.add(
        _NotificationGroup(
          titleAr: 'اليوم',
          titleEn: 'Today',
          items: todayItems,
        ),
      );
    }
    if (thisWeek.isNotEmpty) {
      groups.add(
        _NotificationGroup(
          titleAr: 'هذا الأسبوع',
          titleEn: 'This Week',
          items: thisWeek,
        ),
      );
    }
    if (older.isNotEmpty) {
      groups.add(
        _NotificationGroup(titleAr: 'أقدم', titleEn: 'Older', items: older),
      );
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FBFB),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    _buildPageTopBar(),
                    const SizedBox(height: 12),
                    _buildNotificationsHeroCard(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<List<LecturerNotification>>(
                        stream: _notificationService
                            .watchCurrentLecturerNotifications(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            debugPrint(
                              '[LecturerNotifications] stream error: ${snapshot.error}',
                            );
                            return _StateMessage(
                              text: _tr(
                                'حدث خطأ أثناء تحميل الإشعارات.',
                                'Failed to load notifications.',
                              ),
                              icon: Icons.error_outline_rounded,
                            );
                          }
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                    color: Color(0xFF006571),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    LecturerStrings.notificationsLoading(),
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF5F747A),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final allNotifications = snapshot.data ?? const [];
                          final grouped = _groupNotifications(allNotifications);
                          final unreadCount = allNotifications
                              .where((n) => !n.isRead)
                              .length;
                          final excuseCount = allNotifications
                              .where((n) => n.isExcuseRequest)
                              .length;
                          final todayCount = allNotifications.where((n) {
                            final created = n.createdAt?.toLocal();
                            if (created == null) return false;
                            final now = DateTime.now();
                            return created.year == now.year &&
                                created.month == now.month &&
                                created.day == now.day;
                          }).length;

                          return Column(
                            children: [
                              _NotificationOverviewCard(
                                unreadCount: unreadCount,
                                excuseCount: excuseCount,
                                todayCount: todayCount,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton.icon(
                                  onPressed: allNotifications.isEmpty
                                      ? null
                                      : _confirmDeleteAll,
                                  icon: const Icon(
                                    Icons.delete_sweep_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    LecturerStrings.notificationsDeleteAll(),
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFE53935),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: allNotifications.isEmpty
                                    ? _StateMessage(
                                        text: _tr(
                                          'لا توجد تنبيهات حالياً',
                                          'No notifications available',
                                        ),
                                        icon: Icons.notifications_none_rounded,
                                      )
                                    : ListView.builder(
                                        padding: EdgeInsets.fromLTRB(
                                          0,
                                          8,
                                          0,
                                          MediaQuery.paddingOf(context)
                                                  .bottom +
                                              88,
                                        ),
                                        itemCount: grouped.length,
                                        itemBuilder: (context, index) {
                                          final section = grouped[index];
                                          return _NotificationSection(
                                            titleAr: section.titleAr,
                                            titleEn: section.titleEn,
                                            highlight: section.highlight,
                                            notifications: section.items,
                                            onTapItem: _openDetails,
                                            onDeleteItem: _confirmDelete,
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageTopBar() {
    const backSlotSize = 38.0;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ProfileBackButton(onTap: _goBack),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: backSlotSize + 8),
                child: Text(
                  LecturerStrings.notificationsTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF213236),
                    height: 1.25,
                  ),
                ),
              ),
            ),
            const Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SizedBox(width: backSlotSize, height: backSlotSize),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B8793), Color(0xFF005B66)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006571).withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _tr(
                'متابعة التنبيهات وطلبات الأعذار',
                'Track alerts and excuse requests',
              ),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationGroup {
  const _NotificationGroup({
    required this.titleAr,
    required this.titleEn,
    required this.items,
    this.highlight = false,
  });

  final String titleAr;
  final String titleEn;
  final List<LecturerNotification> items;
  final bool highlight;
}

class _NotificationOverviewCard extends StatelessWidget {
  const _NotificationOverviewCard({
    required this.unreadCount,
    required this.excuseCount,
    required this.todayCount,
  });

  final int unreadCount;
  final int excuseCount;
  final int todayCount;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, language, _) {
        return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF7F8), Color(0xFFF8FCFC)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(color: const Color(0xFFD1E5E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LecturerStrings.notificationsQuickOverview(language: language),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF0B5D67),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(
                label: LecturerStrings.notificationsUnread(language: language),
                value: unreadCount,
                bg: const Color(0xFFFFF2F2),
                fg: const Color(0xFFD32F2F),
                icon: Icons.mark_email_unread_outlined,
              ),
              _StatPill(
                label: LecturerStrings.notificationsExcuses(language: language),
                value: excuseCount,
                bg: const Color(0xFFFFF8E8),
                fg: const Color(0xFFB07A06),
                icon: Icons.rule_folder_outlined,
              ),
              _StatPill(
                label: LecturerStrings.notificationsToday(language: language),
                value: todayCount,
                bg: const Color(0xFFE8F7F2),
                fg: const Color(0xFF0B8060),
                icon: Icons.today_outlined,
              ),
            ],
          ),
        ],
      ),
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
    required this.icon,
  });

  final String label;
  final int value;
  final Color bg;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSection extends StatelessWidget {
  const _NotificationSection({
    required this.titleAr,
    required this.titleEn,
    required this.highlight,
    required this.notifications,
    required this.onTapItem,
    required this.onDeleteItem,
  });

  final String titleAr;
  final String titleEn;
  final bool highlight;
  final List<LecturerNotification> notifications;
  final ValueChanged<LecturerNotification> onTapItem;
  final ValueChanged<LecturerNotification> onDeleteItem;

  @override
  Widget build(BuildContext context) {
    final title = LecturerLanguageController.tr(titleAr, titleEn);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: highlight
                  ? const Color(0xFFEAF8F9)
                  : const Color(0xFFF2F6F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E4D55),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFD2E3E7)),
                  ),
                  child: Text(
                    '${notifications.length}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D5D65),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...notifications.map(
            (item) => GestureDetector(
              onTap: () => onTapItem(item),
              child: _NotificationCard(
                item: item,
                onDelete: () => onDeleteItem(item),
              ),
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

  final LecturerNotification item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, language, _) {
        final isArabic = language == LecturerLanguage.arabic;
        final style = _styles[_mapType(item)]!;

        return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.isRead ? const Color(0xFFFAFCFC) : const Color(0xFFF1FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isRead
              ? const Color(0xFFDDE7EA)
              : const Color(0xFF6CB2BD),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: item.isRead ? 0.04 : 0.06),
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
                  item.displayTitle(isArabic: isArabic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0E4F59),
                    fontFamily: 'Cairo',
                    fontSize: 14.5,
                  ),
                ),
              ),
              if (!item.isRead)
                Container(
                  margin: const EdgeInsetsDirectional.only(end: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006571),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    LecturerStrings.notificationsNew(language: language),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE53935),
                ),
                tooltip: LecturerLanguageController.tr(
                  'حذف الإشعار',
                  'Delete notification',
                  language: language,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _metaChip(
                _categoryLabel(item, language: language),
                const Color(0xFFEAF6F7),
                const Color(0xFF006571),
              ),
              const SizedBox(width: 6),
              _metaChip(
                item.isExcuseRequest
                    ? LecturerStrings.notificationsExcuseRequest(
                        language: language,
                      )
                    : _typeLabel(_mapType(item), language: language),
                style.soft,
                style.accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.displayMessage(isArabic: isArabic),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
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
                  '${_relativeTime(item.createdAt, language: language)} · ${_formatDate(item.createdAt, language: language)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.black54,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const LecturerDirectionalForwardIcon(size: 13),
            ],
          ),
        ],
      ),
        );
      },
    );
  }

  _NotificationType _mapType(LecturerNotification notification) {
    if (notification.actionType == 'cancel') return _NotificationType.error;
    if (notification.actionType == 'delay') return _NotificationType.success;
    if (notification.isExcuseRequest) return _NotificationType.warning;
    if (notification.messageAr.contains('غياب') ||
        notification.messageEn.toLowerCase().contains('absence')) {
      return _NotificationType.warning;
    }
    return _NotificationType.info;
  }

  String _categoryLabel(
    LecturerNotification notification, {
    required LecturerLanguage language,
  }) {
    if (notification.isAcademic) {
      return LecturerStrings.notificationsAcademic(language: language);
    }
    if (notification.isPersonalLectureAction) {
      return LecturerStrings.notificationsPersonal(language: language);
    }
    return LecturerStrings.notificationsStudents(language: language);
  }

  String _formatDate(
    DateTime? value, {
    required LecturerLanguage language,
  }) {
    if (value == null) {
      return LecturerLanguageController.tr(
        'تاريخ غير متوفر',
        'Date unavailable',
        language: language,
      );
    }
    final d = value.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $hh:$mm';
  }

  String _relativeTime(
    DateTime? value, {
    required LecturerLanguage language,
  }) {
    if (value == null) {
      return LecturerLanguageController.tr('الآن', 'Now', language: language);
    }
    final now = DateTime.now();
    final diff = now.difference(value.toLocal());
    if (diff.inMinutes < 1) {
      return LecturerLanguageController.tr('الآن', 'Now', language: language);
    }
    if (diff.inMinutes < 60) {
      return LecturerLanguageController.tr(
        'قبل ${diff.inMinutes} دقيقة',
        '${diff.inMinutes}m ago',
        language: language,
      );
    }
    if (diff.inHours < 24) {
      return LecturerLanguageController.tr(
        'قبل ${diff.inHours} ساعة',
        '${diff.inHours}h ago',
        language: language,
      );
    }
    if (diff.inDays < 7) {
      return LecturerLanguageController.tr(
        'قبل ${diff.inDays} يوم',
        '${diff.inDays}d ago',
        language: language,
      );
    }
    return LecturerStrings.notificationsOlder(language: language);
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

  String _typeLabel(
    _NotificationType type, {
    required LecturerLanguage language,
  }) {
    switch (type) {
      case _NotificationType.success:
        return LecturerStrings.notificationsSuccess(language: language);
      case _NotificationType.error:
        return LecturerStrings.notificationsAlert(language: language);
      case _NotificationType.warning:
        return LecturerStrings.notificationsWarning(language: language);
      case _NotificationType.info:
        return LecturerStrings.notificationsInfo(language: language);
    }
  }
}

class _LecturerNotificationDetailsScreen extends StatefulWidget {
  const _LecturerNotificationDetailsScreen({
    required this.notification,
    required this.service,
  });

  final LecturerNotification notification;
  final LecturerNotificationService service;

  @override
  State<_LecturerNotificationDetailsScreen> createState() =>
      _LecturerNotificationDetailsScreenState();
}

class _LecturerNotificationDetailsScreenState
    extends State<_LecturerNotificationDetailsScreen> {
  late final Future<_ResolvedExcuseData?> _resolvedExcuseFuture;

  @override
  void initState() {
    super.initState();
    _resolvedExcuseFuture = _loadResolvedExcuseData();
  }

  LecturerNotification get notification => widget.notification;
  LecturerNotificationService get service => widget.service;

  Future<_ResolvedExcuseData?> _loadResolvedExcuseData() async {
    if (!notification.isExcuseRequest || notification.excuseRequestId.isEmpty) {
      return null;
    }

    final excuseId = notification.excuseRequestId.trim();
    _ResolvedExcuseData? resolved;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('excuse_requests')
          .doc(excuseId)
          .get();

      if (snap.exists) {
        final data = snap.data() ?? <String, dynamic>{};
        debugPrint(
          '[LecturerNotifications] details source=live excuse_requests docId=$excuseId',
        );
        resolved = _ResolvedExcuseData.fromLive(
          notification: notification,
          liveData: data,
        );
      } else {
        debugPrint(
          '[LecturerNotifications] details source=fallback snapshot docId=$excuseId (live missing)',
        );
        resolved = _ResolvedExcuseData.fromSnapshot(notification: notification);
      }
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[LecturerNotifications] details source=fallback snapshot docId=$excuseId error=$e\n$st',
      );
      resolved = _ResolvedExcuseData.fromSnapshot(notification: notification);
    } catch (e, st) {
      debugPrint(
        '[LecturerNotifications] details source=fallback snapshot docId=$excuseId error=$e\n$st',
      );
      resolved = _ResolvedExcuseData.fromSnapshot(notification: notification);
    }

    final studentId = resolved.details.studentId;
    if (studentId <= 0) return resolved;

    try {
      final profiles = await ManualAttendanceService.instance
          .fetchStudentProfilesByIds({studentId});
      final profile = profiles[studentId];
      if (profile == null) return resolved;
      return resolved.copyWith(studentProfile: profile);
    } catch (e, st) {
      debugPrint(
        '[LecturerNotifications] details student profile fetch failed studentId=$studentId error=$e\n$st',
      );
      return resolved;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF006571);
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, language, __) {
        final isArabic = language == LecturerLanguage.arabic;
        return Directionality(
        textDirection: LecturerLanguageController.direction(language),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const LecturerDirectionalBackIcon(
                color: primaryColor,
                size: 22,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: Text(
              tr('تفاصيل الاشعار', 'Notification Details'),
              style: const TextStyle(
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
                tooltip: tr('حذف الإشعار', 'Delete notification'),
                onPressed: () => _showDeleteDialog(context),
              ),
            ],
          ),
          body: FutureBuilder<_ResolvedExcuseData?>(
            future: _resolvedExcuseFuture,
            builder: (context, snapshot) {
              final resolved = snapshot.data;
              final status = resolved?.status ?? '';
              final isPending = status == 'pending';
              final isRejected = status == 'rejected';
              final isAccepted = status == 'accepted';
              final bool canApproveOrReject =
                  notification.isExcuseRequest && resolved != null && isPending;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              notification.displayTitle(isArabic: isArabic),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              notification.displayMessage(isArabic: isArabic),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _formatDate(notification.createdAt, language: language),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            if (notification.isExcuseRequest) ...[
                              const SizedBox(height: 16),
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  resolved == null)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF006571),
                                    ),
                                  ),
                                ),
                              if (resolved != null) ...[
                                _ExcusePreviewCard(
                                  notification: notification,
                                  details: resolved.details,
                                  studentProfile: resolved.studentProfile,
                                  isArabic: isArabic,
                                  onPreviewAttachment: () =>
                                      _showAttachmentPreviewDialog(
                                        context,
                                        resolved.details,
                                      ),
                                ),
                                if (!canApproveOrReject)
                                  _ReviewedStatusNotice(
                                    status: resolved.status,
                                    rejectionReason: resolved.rejectionReason,
                                    reviewedBy: resolved.reviewedBy,
                                    reviewedAt: resolved.reviewedAtText,
                                    decisionHistorySummary:
                                        resolved.decisionHistorySummary,
                                  ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (canApproveOrReject)
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => _showDecisionDialog(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF006571),
                            side: const BorderSide(color: Color(0xFF006571)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            tr('اتخاذ القرار', 'Take decision'),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else if (notification.isExcuseRequest &&
                        resolved != null &&
                        isRejected)
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () async {
                            final ok = await _confirmDecisionChange(context);
                            if (ok != true || !context.mounted) return;
                            _showDecisionDialog(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF006571),
                            side: const BorderSide(color: Color(0xFF006571)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            tr('تعديل القرار', 'Change decision'),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else if (notification.isExcuseRequest &&
                        resolved != null &&
                        isAccepted)
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () async {
                            final ok = await _confirmDecisionChange(context);
                            if (ok != true || !context.mounted) return;
                            _showDecisionDialog(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF006571),
                            side: const BorderSide(color: Color(0xFF006571)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            tr('تعديل القرار', 'Change decision'),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 48,
                        child: _GradientButton(
                          label: tr('إغلاق', 'Close'),
                          colors: const [Color(0xFF27A2A9), Color(0xFF006571)],
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      },
    );
  }

  void _showDeleteDialog(BuildContext context) {
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: ModernPopupDialog(
            title: Text(
              tr('حذف الإشعار', 'Delete notification'),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            accentColor: const Color(0xFFE53935),
            actions: [
              ModernPopupActionButton(
                label: tr('إلغاء', 'Cancel'),
                onTap: () => Navigator.of(ctx).pop(),
                isPrimary: false,
              ),
              ModernPopupActionButton(
                label: tr('حذف', 'Delete'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await service.deleteNotification(notification.id);
                  } on FirebaseException catch (e, st) {
                    debugPrint(
                      '[LecturerNotifications] detail delete failed: $e\n$st',
                    );
                  } catch (e, st) {
                    debugPrint(
                      '[LecturerNotifications] detail delete failed: $e\n$st',
                    );
                  }
                  if (context.mounted) Navigator.of(context).pop(true);
                },
                isPrimary: true,
                primaryColor: const Color(0xFFE53935),
              ),
            ],
            child: Text(
              tr(
                'سيتم حذف الإشعار بشكل نهائي.',
                'This notification will be permanently deleted.',
              ),
              style: const TextStyle(
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

  void _showRejectDialog(
    BuildContext context, {
    bool requireReason = false,
  }) async {
    final reason = await showExcuseRejectionReasonDialog(
      context: context,
      tr: LecturerLanguageController.tr,
      textDirection: LecturerLanguageController.direction(),
      primaryColor: const Color(0xFF006571),
    );
    if (!context.mounted || reason == null) return;
    if (requireReason && reason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LecturerLanguageController.tr(
              'سبب الرفض مطلوب.',
              'Rejection reason is required.',
            ),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
      return;
    }
    _applyExcuseDecision(context, approve: false, rejectionReason: reason);
  }

  Future<void> _showDecisionDialog(BuildContext context) async {
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: ModernPopupDialog(
            accentColor: const Color(0xFF006571),
            title: Text(
              tr('قرار العذر', 'Excuse decision'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF213236),
              ),
            ),
            actions: [
              ModernPopupActionButton(
                label: tr('إغلاق', 'Close'),
                onTap: () => Navigator.of(ctx).pop(),
                isPrimary: false,
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _applyExcuseDecision(context, approve: true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF006571),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      tr('قبول العذر', 'Accept excuse'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showRejectDialog(context, requireReason: true);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                      side: const BorderSide(color: Color(0xFFB91C1C)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      tr('رفض العذر', 'Reject excuse'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
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

  Future<bool?> _confirmDecisionChange(BuildContext context) {
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: ModernPopupDialog(
            accentColor: const Color(0xFF006571),
            title: Text(
              tr('تعديل القرار', 'Change decision'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF213236),
              ),
            ),
            actions: [
              ModernPopupActionButton(
                label: tr('إلغاء', 'Cancel'),
                onTap: () => Navigator.of(ctx).pop(false),
                isPrimary: false,
              ),
              ModernPopupActionButton(
                label: tr('متابعة', 'Continue'),
                onTap: () => Navigator.of(ctx).pop(true),
                isPrimary: true,
              ),
            ],
            child: Text(
              tr(
                'هل أنت متأكد من تعديل قرار العذر؟',
                'Are you sure you want to change the excuse decision?',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF475569),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAttachmentPreviewDialog(
    BuildContext context,
    _NotificationExcuseDetails details,
  ) {
    ExcuseAttachmentPreview.showAttachmentPreviewDialog(
      context: context,
      attachmentName: details.attachmentName == '-'
          ? ''
          : details.attachmentName,
      attachmentUrl: details.attachmentUrl == '-' ? '' : details.attachmentUrl,
      tr: LecturerLanguageController.tr,
      textDirection: LecturerLanguageController.direction(),
      primaryColor: const Color(0xFF006571),
      logTag: '[LecturerNotifications]',
    );
  }

  Future<void> _applyExcuseDecision(
    BuildContext context, {
    required bool approve,
    String rejectionReason = '',
  }) async {
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
    try {
      final result = await service.applyExcuseDecisionFromNotification(
        notification: notification,
        approve: approve,
        rejectionReason: rejectionReason,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LecturerLanguageController.isArabic
                ? result.messageAr
                : result.messageEn,
          ),
          backgroundColor: result.success
              ? const Color(0xFF2B9E56)
              : const Color(0xFFD32F2F),
        ),
      );
      if (result.success && context.mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseException catch (e, st) {
      debugPrint('[LecturerNotifications] excuse decision failed: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('فشل تحديث طلب العذر.', 'Failed to update excuse request.'),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    } catch (e, st) {
      debugPrint('[LecturerNotifications] excuse decision failed: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('فشل تحديث طلب العذر.', 'Failed to update excuse request.'),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    }
  }

  String _formatDate(
    DateTime? value, {
    required LecturerLanguage language,
  }) {
    if (value == null) {
      return LecturerLanguageController.tr(
        'تاريخ غير متوفر',
        'Date unavailable',
        language: language,
      );
    }
    final d = value.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $hh:$mm';
  }
}

class _ExcusePreviewCard extends StatelessWidget {
  const _ExcusePreviewCard({
    required this.notification,
    required this.details,
    required this.studentProfile,
    required this.isArabic,
    required this.onPreviewAttachment,
  });

  final LecturerNotification notification;
  final _NotificationExcuseDetails details;
  final ExternalStudent? studentProfile;
  final bool isArabic;
  final VoidCallback onPreviewAttachment;

  @override
  Widget build(BuildContext context) {
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
    final courseName = LecturerNotificationDisplay.resolveCourseName(
      notification,
      isArabic: isArabic,
    );
    final studentName = details.localizedStudentName(
      isArabic: isArabic,
      profile: studentProfile,
    );
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
          _previewRow(
            tr('تاريخ الاستلام', 'Submission date'),
            details.submissionDate,
          ),
          _previewRow(tr('التوقيت', 'Time'), details.submissionTime),
          const SizedBox(height: 8),
          _previewRow(tr('اسم الطالب', 'Student name'), studentName),
          _previewRow(
            tr('رقمه الجامعي', 'Academic number'),
            details.academicNumber,
          ),
          _previewRow(tr('المقرر', 'Course'), courseName),
          _previewRow(
            tr('الشعبة', 'Section'),
            details.section,
          ),
          _previewRow(
            tr('تاريخ المحاضرة', 'Lecture date'),
            details.lectureDate,
          ),
          _previewRow(
            tr('وقت البداية', 'Start time'),
            details.lectureStartTime,
          ),
          _previewRow(tr('وقت النهاية', 'End time'), details.lectureEndTime),
          _previewRow(tr('حالة الطلب', 'Status'), details.status),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFCECECE)),
          const SizedBox(height: 4),
          Text(
            tr('تفاصيل العذر المرسل', 'Excuse details'),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _normalizedExcuseText(tr),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('المرفق', 'Attachment'),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ..._buildAttachmentSection(tr),
        ],
      ),
    );
  }

  String _normalizedExcuseText(String Function(String, String) tr) {
    final text = details.excuseText.trim();
    if (text.isEmpty || text == '-') {
      return tr('لا يوجد نص عذر مرفق', 'No excuse text provided');
    }
    return text;
  }

  String _normalizedAttachmentUrl() {
    final raw = details.attachmentUrl.trim();
    if (raw.isEmpty || raw == '-') return '';
    return raw;
  }

  String _normalizedAttachmentName() {
    final raw = details.attachmentName.trim();
    if (raw.isEmpty || raw == '-') return '';
    return raw;
  }

  bool get _hasValidAttachmentUrl =>
      ExcuseAttachmentPreview.isValidAttachmentUrl(_normalizedAttachmentUrl());

  List<Widget> _buildAttachmentSection(String Function(String, String) tr) {
    if (!_hasValidAttachmentUrl) {
      return [
        Text(
          tr('لم يتم إرفاق أي مرفق.', 'No attachment was provided.'),
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ];
    }

    final name = _normalizedAttachmentName();
    return [
      if (name.isNotEmpty)
        _previewRow(tr('اسم المرفق', 'Attachment name'), name),
      if (name.isNotEmpty) const SizedBox(height: 6),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: onPreviewAttachment,
          icon: const Icon(
            Icons.attachment_rounded,
            color: Color(0xFF006571),
          ),
          label: Text(
            tr('فتح المرفق', 'Open attachment'),
            style: const TextStyle(
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
    ];
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
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

class _NotificationExcuseDetails {
  const _NotificationExcuseDetails({
    required this.submissionDate,
    required this.submissionTime,
    required this.studentId,
    required this.studentName,
    required this.studentNameAr,
    required this.studentNameEn,
    required this.academicNumber,
    required this.courseName,
    required this.section,
    required this.lectureDate,
    required this.lectureStartTime,
    required this.lectureEndTime,
    required this.excuseText,
    required this.attachmentName,
    required this.attachmentUrl,
    required this.status,
  });

  final String submissionDate;
  final String submissionTime;
  final int studentId;
  final String studentName;
  final String studentNameAr;
  final String studentNameEn;
  final String academicNumber;
  final String courseName;
  final String section;
  final String lectureDate;
  final String lectureStartTime;
  final String lectureEndTime;
  final String excuseText;
  final String attachmentName;
  final String attachmentUrl;
  final String status;

  _NotificationExcuseDetails copyWith({
    String? submissionDate,
    String? submissionTime,
    int? studentId,
    String? studentName,
    String? studentNameAr,
    String? studentNameEn,
    String? academicNumber,
    String? courseName,
    String? section,
    String? lectureDate,
    String? lectureStartTime,
    String? lectureEndTime,
    String? excuseText,
    String? attachmentName,
    String? attachmentUrl,
    String? status,
  }) {
    return _NotificationExcuseDetails(
      submissionDate: submissionDate ?? this.submissionDate,
      submissionTime: submissionTime ?? this.submissionTime,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentNameAr: studentNameAr ?? this.studentNameAr,
      studentNameEn: studentNameEn ?? this.studentNameEn,
      academicNumber: academicNumber ?? this.academicNumber,
      courseName: courseName ?? this.courseName,
      section: section ?? this.section,
      lectureDate: lectureDate ?? this.lectureDate,
      lectureStartTime: lectureStartTime ?? this.lectureStartTime,
      lectureEndTime: lectureEndTime ?? this.lectureEndTime,
      excuseText: excuseText ?? this.excuseText,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      status: status ?? this.status,
    );
  }

  factory _NotificationExcuseDetails.fromNotification(
    LecturerNotification notification,
  ) {
    final details = notification.excuseDetails;
    final snapshot = notification.excuseRequestSnapshot;
    String read(String key, {String fallback = ''}) {
      final fromDetails = (details[key] ?? '').toString().trim();
      if (fromDetails.isNotEmpty) return fromDetails;
      final fromSnapshot = (snapshot[key] ?? '').toString().trim();
      if (fromSnapshot.isNotEmpty) return fromSnapshot;
      return fallback;
    }

    final lectureDate = notification.lectureDate;
    final rawLectureDate = read('lectureDate');
    String lectureDateText = _normalizeDateText(rawLectureDate);
    lectureDateText = _normalizeDateText(lectureDateText);
    if (lectureDateText.isEmpty) {
      lectureDateText = _dateOnly(lectureDate);
    }

    final studentNameAr = read('studentNameAr', fallback: read('nameAr'));
    final studentNameEn = read('studentNameEn', fallback: read('nameEn'));
    final studentNameSnapshot = read('studentName', fallback: '-');
    final studentId = _parseStudentId(
      snapshot: snapshot,
      details: details,
      academicNumberText: read('academicNumber'),
    );

    return _NotificationExcuseDetails(
      submissionDate: read('submissionDate', fallback: '-'),
      submissionTime: read('submissionTime', fallback: '-'),
      studentId: studentId,
      studentName: studentNameSnapshot,
      studentNameAr: studentNameAr,
      studentNameEn: studentNameEn,
      academicNumber: read('academicNumber', fallback: '-'),
      courseName: read('courseName', fallback: notification.courseName),
      section: read(
        'sectionId',
        fallback: notification.section.isEmpty
            ? notification.sectionId
            : notification.section,
      ),
      lectureDate: lectureDateText.isEmpty ? '-' : lectureDateText,
      lectureStartTime: read(
        'lectureStartTime',
        fallback: notification.lectureStartTime.isEmpty
            ? '-'
            : notification.lectureStartTime,
      ),
      lectureEndTime: read(
        'lectureEndTime',
        fallback: notification.lectureEndTime.isEmpty
            ? '-'
            : notification.lectureEndTime,
      ),
      excuseText: read(
        'reasonText',
        fallback: read('excuseText', fallback: ''),
      ),
      attachmentName: read('attachmentName', fallback: '-'),
      attachmentUrl: read('attachmentUrl', fallback: '-'),
      status: read('status', fallback: '-'),
    );
  }

  static String _normalizeDateText(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == 'null') return '';
    if (!value.contains('Timestamp(')) return value;

    final secondsMatch = RegExp(r'seconds=(\d+)').firstMatch(value);
    if (secondsMatch == null) return value;
    final seconds = int.tryParse(secondsMatch.group(1) ?? '');
    if (seconds == null) return value;
    final date = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toLocal();
    return _dateOnly(date);
  }

  static String _dateOnly(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String localizedStudentName({
    required bool isArabic,
    ExternalStudent? profile,
  }) {
    if (isArabic) {
      if (studentNameAr.isNotEmpty) return studentNameAr;
      final profileAr = profile?.nameAr.trim() ?? '';
      if (profileAr.isNotEmpty) return profileAr;
      final profileEn = profile?.name.trim() ?? '';
      if (profileEn.isNotEmpty) return profileEn;
      if (studentNameEn.isNotEmpty) return studentNameEn;
      return studentName;
    }

    if (studentNameEn.isNotEmpty) return studentNameEn;
    final profileEn = profile?.name.trim() ?? '';
    if (profileEn.isNotEmpty) return profileEn;
    if (studentName.isNotEmpty &&
        !LocalizedFirestoreFields.containsArabicScript(studentName)) {
      return studentName;
    }
    if (studentNameAr.isNotEmpty) return studentNameAr;
    return studentName;
  }

  static int _parseStudentId({
    required Map<String, dynamic> snapshot,
    required Map<String, dynamic> details,
    required String academicNumberText,
  }) {
    int parse(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString().trim()) ?? 0;
    }

    final fromSnapshot = parse(snapshot['studentId']);
    if (fromSnapshot > 0) return fromSnapshot;

    final fromDetails = parse(details['studentId']);
    if (fromDetails > 0) return fromDetails;

    final fromAcademic = parse(academicNumberText);
    if (fromAcademic > 0) return fromAcademic;

    return parse(details['academicNumber']);
  }
}

class _ResolvedExcuseData {
  const _ResolvedExcuseData({
    required this.details,
    required this.studentProfile,
    required this.status,
    required this.rejectionReason,
    required this.reviewedBy,
    required this.reviewedAtText,
    required this.decisionHistorySummary,
  });

  final _NotificationExcuseDetails details;
  final ExternalStudent? studentProfile;
  final String status;
  final String rejectionReason;
  final String reviewedBy;
  final String reviewedAtText;
  final String decisionHistorySummary;

  _ResolvedExcuseData copyWith({
    _NotificationExcuseDetails? details,
    ExternalStudent? studentProfile,
    String? status,
    String? rejectionReason,
    String? reviewedBy,
    String? reviewedAtText,
    String? decisionHistorySummary,
  }) {
    return _ResolvedExcuseData(
      details: details ?? this.details,
      studentProfile: studentProfile ?? this.studentProfile,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAtText: reviewedAtText ?? this.reviewedAtText,
      decisionHistorySummary:
          decisionHistorySummary ?? this.decisionHistorySummary,
    );
  }

  factory _ResolvedExcuseData.fromSnapshot({
    required LecturerNotification notification,
  }) {
    final details = _NotificationExcuseDetails.fromNotification(notification);
    final snapshot = notification.excuseRequestSnapshot;
    final reviewedAt = _readTs(snapshot['reviewedAt']);
    final history = _historySummary(snapshot['decisionHistory']);
    return _ResolvedExcuseData(
      details: details,
      studentProfile: null,
      status: _status(details.status),
      rejectionReason: (snapshot['rejectionReason'] ?? '').toString().trim(),
      reviewedBy: (snapshot['reviewedBy'] ?? '').toString().trim(),
      reviewedAtText: _formatReviewDate(reviewedAt),
      decisionHistorySummary: history,
    );
  }

  factory _ResolvedExcuseData.fromLive({
    required LecturerNotification notification,
    required Map<String, dynamic> liveData,
  }) {
    String readLive(String key) => (liveData[key] ?? '').toString().trim();
    final base = _NotificationExcuseDetails.fromNotification(notification);
    final liveReason = readLive('reasonText');
    final snapshotReason =
        (notification.excuseRequestSnapshot['reasonText'] ?? '')
            .toString()
            .trim();
    final detailsReason = (notification.excuseDetails['excuseText'] ?? '')
        .toString()
        .trim();
    final resolvedReason = liveReason.isNotEmpty
        ? liveReason
        : (snapshotReason.isNotEmpty ? snapshotReason : detailsReason);
    final liveStudentId = _NotificationExcuseDetails._parseStudentId(
      snapshot: liveData,
      details: notification.excuseDetails,
      academicNumberText: readLive('studentId'),
    );
    final details = base.copyWith(
      lectureDate:
          _NotificationExcuseDetails._normalizeDateText(
            readLive('lectureDate'),
          ).isEmpty
          ? base.lectureDate
          : _NotificationExcuseDetails._normalizeDateText(
              readLive('lectureDate'),
            ),
      lectureStartTime: readLive('lectureStartTime').isEmpty
          ? base.lectureStartTime
          : readLive('lectureStartTime'),
      lectureEndTime: readLive('lectureEndTime').isEmpty
          ? base.lectureEndTime
          : readLive('lectureEndTime'),
      excuseText: resolvedReason,
      attachmentName: readLive('attachmentName').isEmpty
          ? base.attachmentName
          : readLive('attachmentName'),
      attachmentUrl: readLive('attachmentUrl').isEmpty
          ? base.attachmentUrl
          : readLive('attachmentUrl'),
      status: readLive('status').isEmpty ? base.status : readLive('status'),
      section: readLive('sectionId').isEmpty
          ? base.section
          : readLive('sectionId'),
      courseName: readLive('courseName').isEmpty
          ? base.courseName
          : readLive('courseName'),
      studentId: liveStudentId > 0 ? liveStudentId : base.studentId,
      studentNameAr: readLive('studentNameAr').isEmpty
          ? readLive('nameAr')
          : readLive('studentNameAr'),
      studentNameEn: readLive('studentNameEn').isEmpty
          ? readLive('nameEn')
          : readLive('studentNameEn'),
      studentName: readLive('studentName').isEmpty
          ? base.studentName
          : readLive('studentName'),
      academicNumber: readLive('studentId').isEmpty
          ? base.academicNumber
          : readLive('studentId'),
      submissionTime: readLive('submittedAt').isEmpty
          ? base.submissionTime
          : _formatReviewDate(_readTs(liveData['submittedAt'])),
    );

    return _ResolvedExcuseData(
      details: details,
      studentProfile: null,
      status: _status((liveData['status'] ?? details.status).toString()),
      rejectionReason: (liveData['rejectionReason'] ?? '').toString().trim(),
      reviewedBy: (liveData['reviewedBy'] ?? '').toString().trim(),
      reviewedAtText: _formatReviewDate(_readTs(liveData['reviewedAt'])),
      decisionHistorySummary: _historySummary(liveData['decisionHistory']),
    );
  }

  static String _status(String value) => value.trim().toLowerCase();

  static DateTime? _readTs(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static String _formatReviewDate(DateTime? date) {
    if (date == null) return '';
    final d = date.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $hh:$mm';
  }

  static String _historySummary(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return '${value.length}';
    }
    return '';
  }
}

class _ReviewedStatusNotice extends StatelessWidget {
  const _ReviewedStatusNotice({
    required this.status,
    required this.rejectionReason,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.decisionHistorySummary,
  });

  final String status;
  final String rejectionReason;
  final String reviewedBy;
  final String reviewedAt;
  final String decisionHistorySummary;

  @override
  Widget build(BuildContext context) {
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
    final isAccepted = status == 'accepted';
    final isRejected = status == 'rejected';
    final label = isAccepted
        ? tr('تمت مراجعة الطلب: مقبول', 'Request reviewed: accepted')
        : isRejected
        ? tr('تمت مراجعة الطلب: مرفوض', 'Request reviewed: rejected')
        : tr('حالة الطلب: $status', 'Request status: $status');
    final fg = isAccepted ? const Color(0xFF0D7D3E) : const Color(0xFFB91C1C);
    final bg = isAccepted ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          if (rejectionReason.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${tr('سبب الرفض', 'Rejection reason')}: $rejectionReason',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
          if (reviewedBy.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${tr('تمت المراجعة بواسطة', 'Reviewed by')}: $reviewedBy',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                color: Colors.black87,
              ),
            ),
          ],
          if (reviewedAt.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${tr('وقت المراجعة', 'Reviewed at')}: $reviewedAt',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                color: Colors.black87,
              ),
            ),
          ],
          if (decisionHistorySummary.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${tr('عدد تغييرات الحالة', 'Status changes')}: $decisionHistorySummary',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF8AA2A6), size: 32),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
