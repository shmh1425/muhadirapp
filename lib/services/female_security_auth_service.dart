import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class FemaleSecurityAuthService {
  FemaleSecurityAuthService._();
  static final FemaleSecurityAuthService instance =
      FemaleSecurityAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserUid => _auth.currentUser?.uid;

  String? get currentUserEmail => _auth.currentUser?.email;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentSecurityStaff() {
    final uid = currentUserUid;
    if (uid == null) {
      return const Stream.empty();
    }

    return _firestore.collection('security_staff').doc(uid).snapshots();
  }

  Future<String> uploadCurrentUserProfileImage(XFile imageFile) async {
    final uid = currentUserUid;
    if (uid == null) {
      throw StateError('No authenticated Female Security user.');
    }

    final extension = _extractFileExtension(imageFile.name);
    final storagePath = 'security_staff/$uid/profile.$extension';
    final storageRef = _storage.ref().child(storagePath);

    debugPrint('[FemaleSecurityAuth] profile upload path: $storagePath');
    debugPrint(
      '[FemaleSecurityAuth] expected path check '
      '(security_staff_profiles/$uid.jpg): '
      '${storagePath == 'security_staff_profiles/$uid.jpg'}',
    );

    final bytes = await imageFile.readAsBytes();
    try {
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/$extension'),
      );
      final downloadUrl = await storageRef.getDownloadURL();
      final photoVersion = DateTime.now().millisecondsSinceEpoch;

      await _firestore.collection('security_staff').doc(uid).set({
        'photoUrl': downloadUrl,
        'photoVersion': photoVersion,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return downloadUrl;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[FemaleSecurityAuth] Firebase Storage upload failed '
        'code=${error.code} message=${error.message}',
      );
      debugPrint(
        '[FemaleSecurityAuth] Firebase Storage upload exception: $error',
      );
      debugPrintStack(
        label: '[FemaleSecurityAuth] Firebase Storage upload stack',
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        '[FemaleSecurityAuth] Unexpected profile upload exception: $error',
      );
      debugPrintStack(
        label: '[FemaleSecurityAuth] Unexpected profile upload stack',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

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

  String _extractFileExtension(String fileName) {
    final sanitizedName = fileName.trim().toLowerCase();
    final dotIndex = sanitizedName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == sanitizedName.length - 1) {
      return 'jpeg';
    }

    final extension = sanitizedName.substring(dotIndex + 1);
    switch (extension) {
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
      case 'heic':
      case 'heif':
      case 'jpeg':
      case 'jpg':
        return extension == 'jpg' ? 'jpeg' : extension;
      default:
        return 'jpeg';
    }
  }
}
