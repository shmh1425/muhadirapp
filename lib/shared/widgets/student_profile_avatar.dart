import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../services/student_auth_service.dart';
import '../../services/student_profile_image_service.dart';
import '../../screens/student/app_settings.dart';
import 'web_network_image_blur.dart';

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
    return StreamBuilder(
      stream: StudentAuthService.instance.watchCurrentStudentDoc(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};

        final gender = (data['gender'] ??
                StudentAuthService.instance.currentStudent?.gender ??
                '')
            .toString()
            .trim()
            .toLowerCase();
        final isFemale = gender == 'f' || gender == 'female';

        final photoUrl = (data['photoUrl'] ?? data['photoURL'] ?? data['photo_url'] ?? '')
            .toString()
            .trim();
        final photoVersion = (data['photoVersion'] ?? '').toString().trim();
        final imageUrl = photoUrl.isEmpty
            ? ''
            : photoVersion.isEmpty
                ? photoUrl
                : '$photoUrl${photoUrl.contains('?') ? '&' : '?'}v=$photoVersion';

        return ValueListenableBuilder<bool>(
          valueListenable: AppSettings.instance.blurProfileImage,
          builder: (context, isBlurred, _) {
            final double blurSigma = (isFemale && isBlurred) ? 5 : 0;
            final bool preferHtmlElement = blurSigma <= 0;

            Widget imageChild;
            if (imageUrl.isNotEmpty) {
              if (kDebugMode) {
                debugPrint('[StudentProfileAvatar] imageUrl=$imageUrl');
              }
              if (kIsWeb && blurSigma > 0) {
                // On web, blur via CSS on <img> to avoid CORS issues with Canvas.
                imageChild = WebNetworkImageBlur(
                  url: imageUrl,
                  blurSigma: blurSigma,
                  fit: BoxFit.cover,
                  onErrorFallback: _AvatarImage._fallbackAvatarStatic(),
                );
              } else {
                imageChild = _DirectUrlAvatarImage(
                  url: imageUrl,
                  preferHtmlElement: preferHtmlElement,
                );
              }
            } else {
              final student = StudentAuthService.instance.currentStudent;
              final studentId = student?.studentId ?? 0;
              final email = student?.email ?? '';
              imageChild = _AvatarImage(
                key: ValueKey<String>('$studentId|$email'),
                studentId: studentId,
                email: email,
              );
            }

            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: borderColor, width: borderWidth),
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

class _DirectUrlAvatarImage extends StatelessWidget {
  const _DirectUrlAvatarImage({
    required this.url,
    required this.preferHtmlElement,
  });

  final String url;
  final bool preferHtmlElement;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      // NOTE (Flutter Web): `ImageFiltered` blur doesn't apply to <img> elements.
      // So when blur is ON, we must avoid the HTML element strategy.
      webHtmlElementStrategy: preferHtmlElement
          ? WebHtmlElementStrategy.prefer
          : WebHtmlElementStrategy.never,
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          debugPrint('[StudentProfileAvatar] Image.network error: $error');
        }
        return _AvatarImage._fallbackAvatarStatic();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            _AvatarImage._fallbackAvatarStatic(),
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
}

class _AvatarImage extends StatefulWidget {
  const _AvatarImage({
    super.key,
    required this.studentId,
    required this.email,
  });

  final int studentId;
  final String email;

  static Widget _fallbackAvatarStatic() {
    return Container(
      color: Color(0xFFF1F3F4),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: 34,
        color: Color(0xFF9AA0A6),
      ),
    );
  }

  @override
  State<_AvatarImage> createState() => _AvatarImageState();
}

class _AvatarImageState extends State<_AvatarImage> {
  late Future<String?> _profileUrlFuture;

  @override
  void initState() {
    super.initState();
    _profileUrlFuture = StudentProfileImageService.instance.getProfileImageUrl(
      studentId: widget.studentId,
      email: widget.email,
    );
  }

  @override
  void didUpdateWidget(covariant _AvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId || oldWidget.email != widget.email) {
      _profileUrlFuture = StudentProfileImageService.instance.getProfileImageUrl(
        studentId: widget.studentId,
        email: widget.email,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _profileUrlFuture,
      builder: (context, snapshot) {
        final url = snapshot.data?.trim() ?? '';
        if (url.isNotEmpty) {
          return Image.network(
            url,
            fit: BoxFit.cover,
            // Web: prefer <img> to avoid CORS failures (statusCode: 0).
            webHtmlElementStrategy:
                kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
            errorBuilder: (context, error, stackTrace) {
              return _fallbackAvatar();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _fallbackAvatar(),
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
        return _fallbackAvatar();
      },
    );
  }

  Widget _fallbackAvatar() => _AvatarImage._fallbackAvatarStatic();
}

