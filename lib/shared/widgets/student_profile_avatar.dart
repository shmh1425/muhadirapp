import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth/app_session_store.dart';
import '../../services/profile_photo_session_service.dart';
import '../../services/student_auth_service.dart';
import '../../screens/student/app_settings.dart';
import '../profile/user_profile_image_url.dart';
import 'cached_user_network_image.dart';
import 'web_network_image_blur.dart';

class StudentProfileAvatar extends StatefulWidget {
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
  State<StudentProfileAvatar> createState() => _StudentProfileAvatarState();
}

class _StudentProfileAvatarState extends State<StudentProfileAvatar> {
  @override
  void initState() {
    super.initState();
    ProfilePhotoSessionService.instance.hydrateCacheKeyFromSessionSnapshot();
  }

  static Widget _fallbackAvatarStatic() {
    return const ColoredBox(
      color: Color(0xFFF1F3F4),
      child: Center(
        child: Icon(
          Icons.person,
          size: 34,
          color: Color(0xFF9AA0A6),
        ),
      ),
    );
  }

  void _schedulePersist(Map<String, dynamic> data) {
    if (UserProfileImageUrl.pickRawUrl(data).isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProfilePhotoSessionService.instance.persistFromFirestoreMap(
        data,
        role: AppSessionRole.student,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: StudentAuthService.instance.watchCurrentStudentDoc(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final map = data ?? const <String, dynamic>{};

        if (data != null && UserProfileImageUrl.pickRawUrl(data).isNotEmpty) {
          _schedulePersist(data);
        }

        final imageUrl = ProfilePhotoSessionService.instance
                .resolveStudentDisplayUrl(firestoreData: map) ??
            '';

        final gender = (map['gender'] ??
                StudentAuthService.instance.currentStudent?.gender ??
                '')
            .toString()
            .trim()
            .toLowerCase();
        final isFemale = gender == 'f' || gender == 'female';

        return ValueListenableBuilder<bool>(
          valueListenable: AppSettings.instance.blurProfileImage,
          builder: (context, isBlurred, _) {
            final double blurSigma = (isFemale && isBlurred) ? 5 : 0;

            Widget imageChild;
            if (imageUrl.isNotEmpty) {
              if (kDebugMode) {
                debugPrint('[StudentProfileAvatar] imageUrl=$imageUrl');
              }
              if (kIsWeb && blurSigma > 0) {
                imageChild = WebNetworkImageBlur(
                  url: imageUrl,
                  blurSigma: blurSigma,
                  fit: BoxFit.cover,
                  onErrorFallback: _fallbackAvatarStatic(),
                );
              } else {
                imageChild = CachedUserNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: _fallbackAvatarStatic(),
                );
              }
            } else {
              imageChild = _fallbackAvatarStatic();
            }

            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: widget.borderColor,
                  width: widget.borderWidth,
                ),
              ),
              child: ClipOval(
                child: (kIsWeb && blurSigma > 0)
                    ? imageChild
                    : ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: blurSigma,
                          sigmaY: blurSigma,
                        ),
                        child: imageChild,
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
