import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class AdminUserImageService {
  AdminUserImageService._();

  static final AdminUserImageService instance = AdminUserImageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImageFromGallery() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
  }

  Future<String> uploadStudentImage({
    required int studentId,
    required XFile file,
  }) async {
    final ext = _normalizeExt(file.name);
    final storagePath = '$studentId.$ext';
    final ref = _storage.ref().child(storagePath);
    final bytes = await file.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
    final url = await ref.getDownloadURL();
    await _firestore.collection('external_students').doc('$studentId').set({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('[AdminUserImage] uploaded studentId=$studentId path=$storagePath');
    return url;
  }

  Future<String> uploadLecturerImage({
    required String lecturerId,
    required XFile file,
  }) async {
    final ext = _normalizeExt(file.name);
    final storagePath = 'lecturers/$lecturerId/profile.$ext';
    final ref = _storage.ref().child(storagePath);
    final bytes = await file.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
    final url = await ref.getDownloadURL();
    await _firestore.collection('external_lecturers').doc(lecturerId).set({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint(
      '[AdminUserImage] uploaded lecturerId=$lecturerId path=$storagePath',
    );
    return url;
  }

  String _normalizeExt(String name) {
    final lower = name.trim().toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot == -1 ? '' : lower.substring(dot + 1);
    switch (ext) {
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
      case 'heic':
      case 'heif':
        return ext;
      case 'jpg':
      case 'jpeg':
        return 'jpeg';
      default:
        return 'png';
    }
  }
}

