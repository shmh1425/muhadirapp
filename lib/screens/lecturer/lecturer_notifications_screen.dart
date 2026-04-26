import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/notifications/lecturer_notification.dart';
import '../../services/notifications/lecturer_notification_service.dart';
import '../../widgets/lecturer/excuse_attachment_preview.dart';
import '../../widgets/lecturer/excuse_rejection_reason_dialog.dart';
import 'lecturer_language.dart';
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
  String _selectedCategory = 'الكل';

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  void _changeCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
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
        builder: (_) =>
            _LecturerNotificationDetailsScreen(
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
          content: Text(
            _tr('تم حذف الإشعار.', 'Notification deleted.'),
          ),
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

  List<LecturerNotification> _filteredNotifications(
    List<LecturerNotification> all,
  ) {
    if (_selectedCategory == 'الكل') return all;
    return all.where((n) {
      switch (_selectedCategory) {
        case 'أكاديمي':
          return n.isAcademic;
        case 'شخصي':
          return n.isPersonalLectureAction;
        case 'الطلاب':
          return n.isStudentRelated;
        default:
          return true;
      }
    }).toList();
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ProfileBackButton(onTap: _goBack),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD6E6E8)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _CategoryTabs(
                        selected: _selectedCategory,
                        onChanged: _changeCategory,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                          if (snapshot.connectionState == ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF006571),
                              ),
                            );
                          }

                          final allNotifications = snapshot.data ?? const [];
                          final filtered = _filteredNotifications(allNotifications);

                          return Column(
                            children: [
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
                                    _tr(
                                      'حذف كل الإشعارات',
                                      'Delete all notifications',
                                    ),
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
                                child: filtered.isEmpty
                                    ? _StateMessage(
                                        text: _tr(
                                          'لا توجد تنبيهات حالياً',
                                          'No notifications available',
                                        ),
                                        icon: Icons.notifications_none_rounded,
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        itemCount: filtered.length,
                                        itemBuilder: (context, index) {
                                          final item = filtered[index];
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
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = ['الكل', 'أكاديمي', 'شخصي', 'الطلاب'];
    String displayLabel(String label) {
      switch (label) {
        case 'الكل':
          return LecturerLanguageController.tr('الكل', 'All');
        case 'أكاديمي':
          return LecturerLanguageController.tr('أكاديمي', 'Academic');
        case 'شخصي':
          return LecturerLanguageController.tr('شخصي', 'Personal');
        case 'الطلاب':
          return LecturerLanguageController.tr('الطلاب', 'Students');
        default:
          return label;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: labels.map((label) {
          final bool isActive = label == selected;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: GestureDetector(
              onTap: () => onChanged(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF006571)
                      : const Color(0xFFF2F6F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF006571)
                        : const Color(0xFFD9E5E7),
                  ),
                ),
                child: Text(
                  displayLabel(label),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : const Color(0xFF425C62),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
    final style = _styles[_mapType(item)]!;
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
    String localizedCategory(String label) {
      switch (label) {
        case 'أكاديمي':
          return tr('أكاديمي', 'Academic');
        case 'شخصي':
          return tr('شخصي', 'Personal');
        case 'الطلاب':
          return tr('الطلاب', 'Students');
        default:
          return label;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.isRead ? const Color(0xFFFAFCFC) : const Color(0xFFF4FBFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isRead ? const Color(0xFFDDE7EA) : const Color(0xFF8FC4CB),
        ),
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
                  LecturerLanguageController.isArabic
                      ? item.titleAr
                      : (item.titleEn.isEmpty ? item.titleAr : item.titleEn),
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
                tooltip: tr('حذف الإشعار', 'Delete notification'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _metaChip(
                localizedCategory(_categoryLabel(item)),
                const Color(0xFFEAF6F7),
                const Color(0xFF006571),
              ),
              const SizedBox(width: 6),
              _metaChip(
                item.isExcuseRequest
                    ? tr('طلب عذر', 'Excuse request')
                    : _typeLabel(_mapType(item)),
                style.soft,
                style.accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            LecturerLanguageController.isArabic
                ? item.messageAr
                : (item.messageEn.isEmpty ? item.messageAr : item.messageEn),
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
                  _formatDate(item.createdAt),
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

  String _categoryLabel(LecturerNotification notification) {
    if (notification.isAcademic) return 'أكاديمي';
    if (notification.isPersonalLectureAction) return 'شخصي';
    return 'الطلاب';
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return LecturerLanguageController.tr('تاريخ غير متوفر', 'Date unavailable');
    }
    final d = value.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $hh:$mm';
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
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
    switch (type) {
      case _NotificationType.success:
        return tr('نجاح', 'Success');
      case _NotificationType.error:
        return tr('تنبيه', 'Alert');
      case _NotificationType.warning:
        return tr('تحذير', 'Warning');
      case _NotificationType.info:
        return tr('معلومة', 'Info');
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
        return _ResolvedExcuseData.fromLive(
          notification: notification,
          liveData: data,
        );
      }
      debugPrint(
        '[LecturerNotifications] details source=fallback snapshot docId=$excuseId (live missing)',
      );
      return _ResolvedExcuseData.fromSnapshot(notification: notification);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[LecturerNotifications] details source=fallback snapshot docId=$excuseId error=$e\n$st',
      );
      return _ResolvedExcuseData.fromSnapshot(notification: notification);
    } catch (e, st) {
      debugPrint(
        '[LecturerNotifications] details source=fallback snapshot docId=$excuseId error=$e\n$st',
      );
      return _ResolvedExcuseData.fromSnapshot(notification: notification);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF006571);
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) => Directionality(
        textDirection: LecturerLanguageController.direction(),
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
              final bool canApproveOrReject = notification.isExcuseRequest &&
                  resolved != null &&
                  isPending;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                              LecturerLanguageController.isArabic
                                  ? notification.titleAr
                                  : (notification.titleEn.isEmpty
                                        ? notification.titleAr
                                        : notification.titleEn),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              LecturerLanguageController.isArabic
                                  ? notification.messageAr
                                  : (notification.messageEn.isEmpty
                                        ? notification.messageAr
                                        : notification.messageEn),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _formatDate(notification.createdAt),
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
                                  details: resolved.details,
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
      ),
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
                    debugPrint('[LecturerNotifications] detail delete failed: $e\n$st');
                  } catch (e, st) {
                    debugPrint('[LecturerNotifications] detail delete failed: $e\n$st');
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
    _applyExcuseDecision(
      context,
      approve: false,
      rejectionReason: reason,
    );
  }

  Future<void> _showDecisionDialog(BuildContext context) async {
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('قرار العذر', 'Excuse decision'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF213236),
                      ),
                    ),
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        tr('إغلاق', 'Close'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
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

  Future<bool?> _confirmDecisionChange(BuildContext context) {
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('تعديل القرار', 'Change decision'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF213236),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
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
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              tr('إلغاء', 'Cancel'),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF006571),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              tr('متابعة', 'Continue'),
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
                  ],
                ),
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
      attachmentName: details.attachmentName == '-' ? '' : details.attachmentName,
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
            LecturerLanguageController.isArabic ? result.messageAr : result.messageEn,
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

  String _formatDate(DateTime? value) {
    if (value == null) {
      return LecturerLanguageController.tr('تاريخ غير متوفر', 'Date unavailable');
    }
    final d = value.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $hh:$mm';
  }
}

class _ExcusePreviewCard extends StatelessWidget {
  const _ExcusePreviewCard({
    required this.details,
    required this.onPreviewAttachment,
  });

  final _NotificationExcuseDetails details;
  final VoidCallback onPreviewAttachment;

  @override
  Widget build(BuildContext context) {
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
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
          _previewRow(tr('اسم الطالب', 'Student name'), details.studentName),
          _previewRow(
            tr('رقمه الجامعي', 'Academic number'),
            details.academicNumber,
          ),
          _previewRow(tr('المقرر', 'Course'), details.courseName),
          _previewRow(tr('الشعبة', 'Section'), details.section),
          _previewRow(tr('تاريخ المحاضرة', 'Lecture date'), details.lectureDate),
          _previewRow(tr('وقت البداية', 'Start time'), details.lectureStartTime),
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
          _previewRow(
            tr('اسم المرفق', 'Attachment name'),
            details.attachmentName == '-'
                ? tr('غير متوفر', 'Unavailable')
                : details.attachmentName,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: details.attachmentUrl == '-' ? null : onPreviewAttachment,
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
    required this.studentName,
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
  final String studentName;
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
    String? studentName,
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
      studentName: studentName ?? this.studentName,
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
    String read(
      String key, {
      String fallback = '',
    }) {
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

    return _NotificationExcuseDetails(
      submissionDate: read('submissionDate', fallback: '-'),
      submissionTime: read('submissionTime', fallback: '-'),
      studentName: read('studentName', fallback: '-'),
      academicNumber: read('academicNumber', fallback: '-'),
      courseName: read('courseNameAr', fallback: notification.courseName.isEmpty ? '-' : notification.courseName),
      section: read('sectionId', fallback: notification.section.isEmpty ? notification.sectionId : notification.section),
      lectureDate: lectureDateText.isEmpty ? '-' : lectureDateText,
      lectureStartTime: read(
        'lectureStartTime',
        fallback: notification.lectureStartTime.isEmpty ? '-' : notification.lectureStartTime,
      ),
      lectureEndTime: read(
        'lectureEndTime',
        fallback: notification.lectureEndTime.isEmpty ? '-' : notification.lectureEndTime,
      ),
      excuseText: read('reasonText', fallback: read('excuseText', fallback: '')),
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
}

class _ResolvedExcuseData {
  const _ResolvedExcuseData({
    required this.details,
    required this.status,
    required this.rejectionReason,
    required this.reviewedBy,
    required this.reviewedAtText,
    required this.decisionHistorySummary,
  });

  final _NotificationExcuseDetails details;
  final String status;
  final String rejectionReason;
  final String reviewedBy;
  final String reviewedAtText;
  final String decisionHistorySummary;

  factory _ResolvedExcuseData.fromSnapshot({
    required LecturerNotification notification,
  }) {
    final details = _NotificationExcuseDetails.fromNotification(notification);
    final snapshot = notification.excuseRequestSnapshot;
    final reviewedAt = _readTs(snapshot['reviewedAt']);
    final history = _historySummary(snapshot['decisionHistory']);
    return _ResolvedExcuseData(
      details: details,
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
        (notification.excuseRequestSnapshot['reasonText'] ?? '').toString().trim();
    final detailsReason = (notification.excuseDetails['excuseText'] ?? '')
        .toString()
        .trim();
    final resolvedReason = liveReason.isNotEmpty
        ? liveReason
        : (snapshotReason.isNotEmpty ? snapshotReason : detailsReason);
    final details = base.copyWith(
      lectureDate: _NotificationExcuseDetails._normalizeDateText(
        readLive('lectureDate'),
      ).isEmpty
          ? base.lectureDate
          : _NotificationExcuseDetails._normalizeDateText(readLive('lectureDate')),
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
      section: readLive('sectionId').isEmpty ? base.section : readLive('sectionId'),
      courseName: readLive('courseNameAr').isEmpty ? base.courseName : readLive('courseNameAr'),
      academicNumber: readLive('studentId').isEmpty ? base.academicNumber : readLive('studentId'),
      submissionTime: readLive('submittedAt').isEmpty
          ? base.submissionTime
          : _formatReviewDate(_readTs(liveData['submittedAt'])),
    );

    return _ResolvedExcuseData(
      details: details,
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
