import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lecturer_catalog_providers.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/female_security/female_security_home_screen.dart';
import '../../screens/lecturer/lecturer_main_shell.dart';
import '../../screens/lecturer/lecturer_profile_screen.dart';
import '../../screens/student/home_screen.dart';
import '../../services/lecturer/lecturer_cold_start_warmup.dart';
import '../../services/lecturer_auth_service.dart';
import '../../services/student_auth_service.dart';
import '../profile_photo_session_service.dart';
import 'app_session_store.dart';
import 'auth_session_router.dart';

/// Restores in-memory role state and builds the home screen for a persisted session.
class SessionRestoreService {
  SessionRestoreService._();
  static final SessionRestoreService instance = SessionRestoreService._();

  static const _networkRoleTimeout = Duration(seconds: 4);

  Future<Widget?> buildHomeForSignedInUser(
    User user, {
    bool preferLocalCache = true,
  }) async {
    final email = user.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return null;

    if (preferLocalCache) {
      final cached = _tryBuildFromLocalCache(email);
      if (cached != null) {
        return cached;
      }
    }

    try {
      return await _resolveRoleFromFirestore(
        email: email,
        uid: user.uid,
      ).timeout(_networkRoleTimeout);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget? _tryBuildFromLocalCache(String email) {
    final snapshot = AppSessionStore.instance.read();
    if (snapshot == null || snapshot.email != email) {
      return null;
    }
    return _widgetForSnapshot(snapshot);
  }

  Future<Widget?> _resolveRoleFromFirestore({
    required String email,
    required String uid,
  }) async {
    final result = await AuthSessionRouter.instance.routeAfterFirebaseSignIn(
      email: email,
      uid: uid,
    );
    if (!result.isSuccess || result.shouldSignOut) {
      return null;
    }
    return result.screen;
  }

  Widget? _widgetForSnapshot(AppSessionSnapshot snapshot) {
    switch (snapshot.role) {
      case AppSessionRole.admin:
        return const AdminDashboardScreen();
      case AppSessionRole.security:
        unawaited(
          ProfilePhotoSessionService.instance
              .hydrateCacheKeyFromSessionSnapshot(),
        );
        return const FemaleSecurityHomeScreen();
      case AppSessionRole.lecturer:
        final lecturer = snapshot.lecturer;
        if (lecturer == null) return null;
        LecturerAuthService.instance.restoreFromCache(lecturer);
        unawaited(
          ProfilePhotoSessionService.instance
              .hydrateCacheKeyFromSessionSnapshot(),
        );
        final fallbackName = snapshot.lecturerProfileName?.trim().isNotEmpty ==
                true
            ? snapshot.lecturerProfileName!.trim()
            : 'محاضر';
        final profile = LecturerProfile.fromLecturer(
          lecturer,
          fallbackName: fallbackName,
        );
        return LecturerMainShell(initialIndex: 2, profile: profile);
      case AppSessionRole.student:
        final student = snapshot.student;
        if (student == null) return null;
        StudentAuthService.instance.restoreFromCache(
          student,
          docId: snapshot.studentDocId,
        );
        unawaited(
          ProfilePhotoSessionService.instance
              .hydrateCacheKeyFromSessionSnapshot(),
        );
        return const HomeScreen();
    }
  }

  /// Warm lecturer caches after navigation (non-blocking).
  void scheduleLecturerWarmup(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final container = ProviderScope.containerOf(context, listen: false);
      container.invalidate(lecturerUnifiedCatalogProvider);
      unawaited(LecturerColdStartWarmup.run(container));
    });
  }
}
