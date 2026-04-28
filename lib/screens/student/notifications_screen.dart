import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/notifications/student_notification.dart';
import '../../services/student_auth_service.dart';
import '../../services/student_notifications_service.dart';
import '../../shared/widgets/chat_fab.dart';
import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';
import '../../services/excuse/excuse_attendance_merge.dart';
import 'excuse_screen.dart';
import 'pending_detail_screen.dart';
import 'rejection_detail_screen.dart';
import 'schedule_screen.dart';
import 'submit_excuse_screen.dart';

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

  String _selectedCategory = 'الكل';
  final ValueNotifier<Set<String>> _optimisticHiddenIds =
      ValueNotifier<Set<String>>(<String>{});

  String _tr(TranslationController t, String ar, String en) =>
      t.translateToEnglish ? en : ar;

  @override
  void dispose() {
    _optimisticHiddenIds.dispose();
    super.dispose();
  }

  String _deleteFailureMessage(TranslationController t, Object error) {
    final en = t.translateToEnglish;
    if (error is FirebaseException) {
      final code = error.code.trim().toLowerCase();
      switch (code) {
        case 'permission-denied':
          return en
              ? 'Delete failed (permission denied). Possible causes: you are not signed in as the correct student, Firestore rules block this action, or the record belongs to another student.'
              : 'فشل الحذف (ليس لديك صلاحية). أسباب محتملة: لم تسجّل دخولك كطالب صحيح، أو قواعد Firestore تمنع العملية، أو أن السجل لا يخص هذا الطالب.';
        case 'not-found':
          return en
              ? 'Delete failed (not found). The notification may have already been deleted or the data is out of sync.'
              : 'فشل الحذف (غير موجود). ربما تم حذف الإشعار مسبقًا أو البيانات غير متزامنة.';
        case 'unavailable':
        case 'deadline-exceeded':
          return en
              ? 'Delete failed (network/service unavailable). Check your internet connection and try again.'
              : 'فشل الحذف (مشكلة شبكة/الخدمة غير متاحة). تأكد من الاتصال بالإنترنت ثم حاول مرة أخرى.';
        case 'failed-precondition':
        case 'aborted':
          return en
              ? 'Delete failed due to a temporary conflict. Try again in a moment.'
              : 'فشل الحذف بسبب تعارض مؤقت. حاول مرة أخرى بعد قليل.';
        default:
          final msg = (error.message ?? '').trim();
          return en
              ? 'Delete failed ($code). ${msg.isEmpty ? 'Please try again.' : msg}'
              : 'فشل الحذف ($code). ${msg.isEmpty ? 'حاول مرة أخرى.' : msg}';
      }
    }
    return en
        ? 'Delete failed. Please try again.'
        : 'تعذر حذف الإشعار. حاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    final translation = TranslationController.instance;
    return AnimatedBuilder(
      animation: translation,
      builder: (context, _) {
        return Directionality(
          textDirection: translation.textDirection,
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
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          translation.textDirection == TextDirection.ltr
                              ? Icons.arrow_back_ios_new
                              : Icons.arrow_forward_ios,
                          color: const Color(0xFF006571),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const TText(
                        'التنبيهات',
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006571),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_studentId > 0) _buildCategoryChips(translation),
                  Align(
                    alignment: translation.textDirection == TextDirection.ltr
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _studentId <= 0 ? null : _confirmDeleteAll,
                      child: TText(
                        _tr(translation, 'حذف الكل', 'Delete all'),
                        style: const TextStyle(color: Color(0xFFE53935)),
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
      },
    );
  }

  List<Widget> _buildNotificationContent() {
    if (_studentId <= 0) {
      return const <Widget>[
        _EmptyNotificationsMessage(message: 'سجّل دخولك كطالب لعرض التنبيهات.'),
      ];
    }

    return <Widget>[
      StreamBuilder<List<StudentNotification>>(
        stream: _notificationsService.watchCurrentStudentNotifications(_studentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const _EmptyNotificationsMessage(
              message: 'تعذر تحميل التنبيهات حالياً.',
            );
          }

          final all = snapshot.data ?? const <StudentNotification>[];
          return ValueListenableBuilder<Set<String>>(
            valueListenable: _optimisticHiddenIds,
            builder: (context, optimisticHidden, _) {
              final filtered = _filteredNotifications(all)
                  .where(
                    (n) =>
                        !optimisticHidden.contains(n.id) &&
                        !optimisticHidden.contains(n.rawId),
                  )
                  .toList();

              if (filtered.isEmpty) {
                return const _EmptyNotificationsMessage(message: 'لا يوجد تنبيهات');
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Column(
                  key: ValueKey<int>(filtered.length),
                  children: filtered
                      .map((n) => _NotificationRow(
                            notification: n,
                            onOpen: () => _openDetails(n),
                            onDelete: () => _confirmDelete(n),
                          ))
                      .toList(),
                ),
              );
            },
          );
        },
      ),
    ];
  }

  Widget _buildCategoryChips(TranslationController t) {
    // Match "إدارة الأعذار" tabs style (same background + gradient active chip).
    const tabBackground = Color(0xFFF5F5F5);

    Widget tab(String value, String ar, String en) {
      final isActive = _selectedCategory == value;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _GradientTabChip(
            label: _tr(t, ar, en),
            isActive: isActive,
            onTap: () => setState(() => _selectedCategory = value),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: tabBackground,
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Row(
              children: [
                tab('الكل', 'الكل', 'All'),
                tab('الحضور', 'الحضور', 'Attendance'),
                tab('المحاضرات', 'المحاضرات', 'Classes'),
                tab('الأعذار', 'الأعذار', 'Excuses'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<StudentNotification> _filteredNotifications(List<StudentNotification> all) {
    if (_selectedCategory == 'الكل') return all;
    return all.where((n) {
      switch (_selectedCategory) {
        case 'الحضور':
          return n.category == StudentNotificationCategory.attendance;
        case 'المحاضرات':
          return n.category == StudentNotificationCategory.lectures;
        case 'الأعذار':
          return n.category == StudentNotificationCategory.excuses;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _openDetails(StudentNotification notification) async {
    try {
      await _notificationsService.markAsRead(
        studentId: _studentId,
        notification: notification,
      );
    } on FirebaseException catch (_) {
      // keep silent like lecturer flow; UI remains responsive
    } catch (_) {}

    if (!mounted) return;
    await _navigateForNotification(notification);
  }

  String _timeRangeFor(StudentNotification n) {
    final start = n.lectureStartTime.trim();
    final end = n.lectureEndTime.trim();
    if (start.isNotEmpty && end.isNotEmpty) return '$start-$end';
    return '—';
  }

  String _dateTextFor(StudentNotification n) {
    final t = TranslationController.instance;
    final d = n.lectureDate ?? n.createdAt;
    return t.translateToEnglish
        ? ExcuseAttendanceMerge.formatEnglishLectureDate(d)
        : ExcuseAttendanceMerge.formatArabicLectureDate(d);
  }

  Future<void> _navigateForNotification(StudentNotification n) async {
    if (!mounted) return;
    final t = TranslationController.instance;

    if (n.category == StudentNotificationCategory.attendance) {
      final sectionId = n.sectionId.trim();
      final sessionId = n.sessionId.trim();
      final lectureDate = n.lectureDate;
      if (sectionId.isNotEmpty && sessionId.isNotEmpty && lectureDate != null) {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SubmitExcuseScreen(
              course: n.courseName.isEmpty ? null : n.courseName,
              dateText: _dateTextFor(n),
              timeRange: _timeRangeFor(n),
              sectionId: sectionId,
              lectureDate: lectureDate,
              sessionId: sessionId,
              attendanceRecordId: n.attendanceRecordId.isNotEmpty
                  ? n.attendanceRecordId
                  : n.rawId,
            ),
          ),
        );
      }
      return;
    }

    if (n.category == StudentNotificationCategory.lectures) {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const ScheduleScreen()),
      );
      return;
    }

    // Excuse notifications.
    final status = n.excuseStatus.trim().toLowerCase();
    if (status == 'pending') {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PendingDetailScreen(
            studentId: _studentId,
            attendanceRecordId: n.attendanceRecordId,
            course: n.courseName.isEmpty ? (t.translateToEnglish ? 'Course' : 'المقرر') : n.courseName,
            dateText: _dateTextFor(n),
            timeRange: _timeRangeFor(n),
          ),
        ),
      );
      return;
    }

    if (status == 'rejected') {
      final sectionId = n.sectionId.trim();
      final sessionId = n.sessionId.trim();
      final lectureDate = n.lectureDate;
      if (sectionId.isNotEmpty && sessionId.isNotEmpty && lectureDate != null) {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => RejectionDetailScreen(
              course: n.courseName.isEmpty ? (t.translateToEnglish ? 'Course' : 'المادة') : n.courseName,
              dateText: _dateTextFor(n),
              timeRange: _timeRangeFor(n),
              reason: n.rejectionReason.isNotEmpty
                  ? n.rejectionReason
                  : (t.translateToEnglish ? 'Your excuse was not accepted.' : 'تم رفض العذر.'),
              sectionId: sectionId,
              lectureDate: lectureDate,
              sessionId: sessionId,
              attendanceRecordId: n.attendanceRecordId,
              attachmentUrl: n.attachmentUrl,
              attachmentName: n.attachmentName,
            ),
          ),
        );
      } else {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => const ExcuseScreen()),
        );
      }
      return;
    }

    // accepted or unknown -> open excuse list.
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const ExcuseScreen()),
    );
  }

  Future<void> _deleteNotification(StudentNotification notification) async {
    final t = TranslationController.instance;
    try {
      await _notificationsService.deleteNotification(
        studentId: _studentId,
        notification: notification,
      );
      if (!mounted) return;
      // Optimistic hide: attendance rows are UI-derived, so we hide immediately
      // while prefs stream catches up.
      final next = Set<String>.of(_optimisticHiddenIds.value)
        ..add(notification.id)
        ..add(notification.rawId);
      _optimisticHiddenIds.value = next;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr(t, 'تم حذف الإشعار.', 'Notification deleted.')),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_deleteFailureMessage(t, e)),
        ),
      );
    }
  }

  void _confirmDelete(StudentNotification notification) {
    final t = TranslationController.instance;
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: t.textDirection,
        child: AlertDialog(
          title: Text(_tr(t, 'حذف الإشعار', 'Delete Notification')),
          content: Text(_tr(t, 'هل أنت متأكد من حذف هذا الإشعار؟', 'Are you sure you want to delete this notification?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(_tr(t, 'إلغاء', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteNotification(notification);
              },
              child: Text(_tr(t, 'حذف', 'Delete')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAll() {
    final t = TranslationController.instance;
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: t.textDirection,
        child: AlertDialog(
          title: Text(_tr(t, 'حذف كل الإشعارات', 'Delete all notifications')),
          content: Text(_tr(t, 'سيتم حذف جميع الإشعارات من القائمة. هل تريد المتابعة؟', 'This will remove all notifications from the list. Continue?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(_tr(t, 'إلغاء', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteAll();
              },
              child: Text(_tr(t, 'حذف الكل', 'Delete all')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAll() async {
    final t = TranslationController.instance;
    try {
      final all = await _notificationsService
          .watchCurrentStudentNotifications(_studentId)
          .first;
      final filtered = _filteredNotifications(all);
      await _notificationsService.deleteAllForStudent(
        studentId: _studentId,
        visibleNotifications: filtered,
      );
      if (!mounted) return;
      final next = Set<String>.of(_optimisticHiddenIds.value);
      for (final n in filtered) {
        next.add(n.id);
        next.add(n.rawId);
      }
      _optimisticHiddenIds.value = next;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr(t, 'تم حذف جميع الإشعارات.', 'All notifications have been deleted.')),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_deleteFailureMessage(t, e)),
        ),
      );
    }
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onOpen,
    required this.onDelete,
  });

  final StudentNotification notification;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  static const Color _appGreen = Color(0xFF006571);

  String _excuseStatusTag(TranslationController t) {
    if (notification.category != StudentNotificationCategory.excuses) return '';
    final s = notification.excuseStatus.toLowerCase().trim();
    if (s.isEmpty) return '';
    if (t.translateToEnglish) {
      switch (s) {
        case 'pending':
          return ' (Pending)';
        case 'accepted':
          return ' (Accepted)';
        case 'rejected':
          return ' (Rejected)';
        default:
          return '';
      }
    }
    switch (s) {
      case 'pending':
        return ' (معلق)';
      case 'accepted':
        return ' (مقبول)';
      case 'rejected':
        return ' (مرفوض)';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TranslationController.instance;
    final title = (t.translateToEnglish ? notification.titleEn : notification.titleAr) +
        _excuseStatusTag(t);
    final message =
        t.translateToEnglish ? notification.messageEn : notification.messageAr;

    final unread = !notification.isRead;
    final bg = unread ? Colors.white : Colors.white;
    final border = unread ? const Color(0xFF006571) : Colors.grey.shade200;
    const iconColor = _appGreen;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: unread ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(
            notification.category == StudentNotificationCategory.attendance
                ? Icons.warning_amber_rounded
                : (notification.category == StudentNotificationCategory.excuses
                    ? Icons.info_outline
                    : Icons.notifications),
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TText(
                  title,
                  style: TextStyle(
                    fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                    color: const Color(0xFF006571),
                  ),
                ),
                const SizedBox(height: 4),
                TText(
                  message,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: _appGreen,
            tooltip: t.translateToEnglish ? 'Delete' : 'حذف',
          ),
        ],
      ),
    );

    return Dismissible(
      key: ValueKey(notification.id),
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
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onOpen,
          child: card,
        ),
      ),
    );
  }
}

class _EmptyNotificationsMessage extends StatelessWidget {
  const _EmptyNotificationsMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return SizedBox(
      height: (h * 0.55).clamp(260.0, 520.0),
      child: Center(
        child: TText(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _GradientTabChip extends StatelessWidget {
  const _GradientTabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: isActive
              ? const LinearGradient(
                  colors: <Color>[
                    Color(0xFF27A2A9),
                    Color(0xFF006571),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isActive ? null : Colors.white,
        ),
        alignment: Alignment.center,
        child: label.isEmpty
            ? const SizedBox.shrink()
            : TText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : const Color(0xFF444444),
                ),
              ),
      ),
    );
  }
}
