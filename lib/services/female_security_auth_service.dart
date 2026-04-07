import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FemaleSecurityAuthService {
  FemaleSecurityAuthService._();
  static final FemaleSecurityAuthService instance =
      FemaleSecurityAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get currentUserUid => _auth.currentUser?.uid;

  String? get currentUserEmail => _auth.currentUser?.email;

  Future<void> debugLogSecurityStaffState() async {
    final uid = _auth.currentUser?.uid;
    final email = _auth.currentUser?.email;
    debugPrint('[FemaleSecurityAuth] currentUser.uid: $uid');
    debugPrint('[FemaleSecurityAuth] currentUser.email: $email');
    if (uid == null) {
      debugPrint('[FemaleSecurityAuth] security_staff check: SKIP (no user)');
      return;
    }

    final staffDoc = await _firestore
        .collection('security_staff')
        .doc(uid)
        .get();
    final isActive = staffDoc.data()?['isActive'] == true;
    debugPrint(
      '[FemaleSecurityAuth] security_staff/$uid exists: ${staffDoc.exists}',
    );
    debugPrint('[FemaleSecurityAuth] security_staff/$uid isActive: $isActive');
  }

  Future<bool> signInAndVerifySecurityStaff({
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

    final staffDoc = await _firestore
        .collection('security_staff')
        .doc(uid)
        .get();
    final isActive = staffDoc.data()?['isActive'] == true;

    if (!staffDoc.exists || !isActive) {
      await _auth.signOut();
      return false;
    }

    return true;
  }

  Future<void> signOut() => _auth.signOut();
}
