import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Ensures Firebase Auth has finished loading any persisted session before
/// the app decides whether to sign in anonymously.
class FirebaseAuthBootstrap {
  FirebaseAuthBootstrap._();

  static Future<User?> waitForInitialAuth({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final auth = FirebaseAuth.instance;
    try {
      await auth.authStateChanges().first.timeout(timeout);
    } on TimeoutException {
      debugPrint(
        '[FirebaseAuthBootstrap] authStateChanges timeout; using currentUser',
      );
    } catch (e) {
      debugPrint('[FirebaseAuthBootstrap] waitForInitialAuth: $e');
    }
    return auth.currentUser;
  }

  /// Anonymous auth is only for Firestore rules when nobody is signed in.
  /// Never replace a restored email/password session.
  static Future<void> ensureAnonymousGuestIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      return;
    }
    if (user?.isAnonymous == true) {
      return;
    }
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('[FirebaseAuthBootstrap] signInAnonymously failed: $e');
    }
  }

  static bool isAppUserSession(User? user) {
    if (user == null || user.isAnonymous) return false;
    return (user.email ?? '').trim().isNotEmpty;
  }
}
