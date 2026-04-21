import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/student_auth_service.dart';
import '../../services/student_profile_image_service.dart';
import '../../screens/student/app_settings.dart';

class StudentProfileAvatar extends StatelessWidget {
  const StudentProfileAvatar({
    super.key,
    required this.size,
    this.borderWidth = 3,
    this.borderColor = const Color(0xFF006571),
  });

  final double size;
  final double borderWidth;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final student = StudentAuthService.instance.currentStudent;
    final studentId = student?.studentId ?? 0;
    final email = student?.email ?? '';

    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.instance.blurProfileImage,
      builder: (context, isBlurred, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: ClipOval(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: isBlurred ? 8 : 0,
                sigmaY: isBlurred ? 8 : 0,
              ),
              child: _AvatarImage(studentId: studentId, email: email),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.studentId, required this.email});

  final int studentId;
  final String email;

  @override
  Widget build(BuildContext context) {
    if (studentId <= 0) {
      return Image.asset('assets/images/avatar.png', fit: BoxFit.cover);
    }

    return FutureBuilder<String?>(
      future: StudentProfileImageService.instance.getProfileImageUrl(
        studentId: studentId,
        email: email,
      ),
      builder: (context, snapshot) {
        final url = snapshot.data?.trim() ?? '';
        if (url.isNotEmpty) {
          return Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset('assets/images/avatar.png', fit: BoxFit.cover);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/images/avatar.png', fit: BoxFit.cover),
                  const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              );
            },
          );
        }

        // While loading or if no URL exists, show fallback.
        return Image.asset('assets/images/avatar.png', fit: BoxFit.cover);
      },
    );
  }
}

