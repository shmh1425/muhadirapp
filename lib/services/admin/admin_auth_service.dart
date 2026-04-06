import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminAuthService {
  AdminAuthService._();
  static final AdminAuthService instance = AdminAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Current Firebase Auth UID (null if not signed in).
  String? get currentUserUid => _auth.currentUser?.uid;

  /// Current Firebase Auth email (null if not signed in).
  String? get currentUserEmail => _auth.currentUser?.email;

  /// Debug: Log auth state and whether admins/{uid} exists. Call before Admin saves to verify isAdmin().
  Future<void> debugLogAdminState() async {
    final uid = _auth.currentUser?.uid;
    final email = _auth.currentUser?.email;
    debugPrint('[AdminAuth] currentUser.uid: $uid');
    debugPrint('[AdminAuth] currentUser.email: $email');
    if (uid == null) {
      debugPrint('[AdminAuth] admins check: SKIP (no user)');
      return;
    }
    final adminDoc = await _firestore.collection('admins').doc(uid).get();
    debugPrint('[AdminAuth] admins/$uid exists: ${adminDoc.exists}');
    debugPrint('[AdminAuth] isAdmin() would be: ${adminDoc.exists}');
  }

  Future<bool> signInAndVerifyAdmin({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final credential = await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) return false;

    final adminDoc = await _firestore.collection('admins').doc(uid).get();
    if (!adminDoc.exists) {
      await _auth.signOut();
      return false;
    }

    return true;
  }

  Future<void> signOut() => _auth.signOut();
}
