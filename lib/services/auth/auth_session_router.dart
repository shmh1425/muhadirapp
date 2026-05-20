import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import '../../models/external_lecturer_model.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/female_security/female_security_home_screen.dart';
import '../../screens/lecturer/lecturer_main_shell.dart';
import '../../screens/lecturer/lecturer_profile_screen.dart';
import '../../screens/student/home_screen.dart';
import '../../services/lecturer_auth_service.dart';
import '../../services/student_auth_service.dart';
import 'app_session_store.dart';

class AuthSessionRouteResult {
  const AuthSessionRouteResult({
    this.screen,
    this.errorMessage,
    this.shouldSignOut = false,
  });

  final Widget? screen;
  final String? errorMessage;
  final bool shouldSignOut;

  bool get isSuccess => screen != null;
}

/// Resolves role after Firebase email/password sign-in and persists session locally.
class AuthSessionRouter {
  AuthSessionRouter._();
  static final AuthSessionRouter instance = AuthSessionRouter._();

  Future<AuthSessionRouteResult> routeAfterFirebaseSignIn({
    required String email,
    required String uid,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final firestore = FirebaseFirestore.instance;

    final adminDoc = await firestore.collection('admins').doc(uid).get();
    if (adminDoc.exists) {
      await AppSessionStore.instance.saveAdmin(email: normalizedEmail);
      return const AuthSessionRouteResult(
        screen: AdminDashboardScreen(),
      );
    }

    final securityDoc = await firestore
        .collection('security_staff')
        .doc(uid)
        .get();
    if (securityDoc.exists) {
      final isActive = securityDoc.data()?['isActive'] == true;
      if (!isActive) {
        return const AuthSessionRouteResult(
          shouldSignOut: true,
          errorMessage: 'حساب الأمن غير مفعل حالياً',
        );
      }
      final securityData = securityDoc.data() ?? const <String, dynamic>{};
      await AppSessionStore.instance.saveSecurity(
        email: normalizedEmail,
        photoUrl: (securityData['photoUrl'] ?? '').toString(),
        photoVersion: (securityData['photoVersion'] ?? '').toString(),
      );
      return const AuthSessionRouteResult(
        screen: FemaleSecurityHomeScreen(),
      );
    }

    final lecturer = await LecturerAuthService.instance
        .verifyEmailAndGetLecturer(normalizedEmail);
    if (lecturer != null) {
      final profile = _profileFromLecturer(lecturer);
      await AppSessionStore.instance.saveLecturer(
        email: normalizedEmail,
        lecturer: lecturer,
        profileName: profile.name,
        profileCollege: profile.college,
        profileDepartment: profile.department,
      );
      return AuthSessionRouteResult(
        screen: LecturerMainShell(initialIndex: 2, profile: profile),
      );
    }

    final student = await StudentAuthService.instance
        .verifyEmailAndGetStudent(normalizedEmail);
    if (student != null) {
      await AppSessionStore.instance.saveStudent(
        email: normalizedEmail,
        student: student,
        studentDocId: StudentAuthService.instance.currentStudentDocIdForSession,
      );
      return const AuthSessionRouteResult(screen: HomeScreen());
    }

    return const AuthSessionRouteResult(
      shouldSignOut: true,
      errorMessage: 'الحساب صحيح لكن غير مربوط بدور داخل النظام',
    );
  }

  LecturerProfile _profileFromLecturer(ExternalLecturerModel lecturer) {
    return LecturerProfile.fromLecturer(lecturer, fallbackName: 'محاضر');
  }
}
