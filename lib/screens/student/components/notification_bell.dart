import 'package:flutter/material.dart';

import '../../../services/student_auth_service.dart';
import '../../../services/student_notifications_service.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.size = 42, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final studentId =
        StudentAuthService.instance.currentStudent?.studentId ?? 0;
    final service = StudentNotificationsService.instance;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF006571),
              size: 26,
            ),
          ),
          if (studentId > 0)
            StreamBuilder<int>(
              stream: service.watchTotalUnreadCount(studentId),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count <= 0) return const SizedBox.shrink();
                final text = count > 99 ? '99+' : '$count';
                final badgeSize = size * 0.42;
                return Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: badgeSize,
                      minHeight: badgeSize,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(badgeSize),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
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
