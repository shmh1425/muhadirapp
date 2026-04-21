import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StudentProfileImageService {
  StudentProfileImageService._();

  static final StudentProfileImageService instance =
      StudentProfileImageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final Map<String, Future<String?>> _cache = <String, Future<String?>>{};

  Future<String?> getProfileImageUrl({
    required int studentId,
    String? email,
  }) {
    if (studentId <= 0) return Future.value(null);
    final normalizedEmail = (email ?? '').trim().toLowerCase();
    final key = normalizedEmail.isEmpty ? '$studentId' : '$studentId|$normalizedEmail';
    return _cache.putIfAbsent(
      key,
      () => _load(studentId: studentId, email: normalizedEmail),
    );
  }

  Future<String?> _load({
    required int studentId,
    required String email,
  }) async {
    // 1) Prefer Firestore URL if present.
    try {
      final doc = await _firestore
          .collection('external_students')
          .doc('$studentId')
          .get();
      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        final url = _pickUrlField(data);
        if (url != null) {
          debugPrint(
            '[StudentProfileImage] Firestore doc hit external_students/$studentId',
          );
          return url;
        }
      } else {
        debugPrint(
          '[StudentProfileImage] Firestore doc miss external_students/$studentId',
        );
      }
    } catch (e, st) {
      debugPrint(
        '[StudentProfileImage] Firestore read failed for studentId=$studentId: $e',
      );
      debugPrintStack(
        label: '[StudentProfileImage] Firestore stackTrace',
        stackTrace: st,
      );
    }

    // 1.b) If docId isn't the academic number, try queries.
    try {
      final qInt = await _firestore
          .collection('external_students')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
      if (qInt.docs.isNotEmpty) {
        final url = _pickUrlField(qInt.docs.first.data());
        if (url != null) {
          debugPrint(
            '[StudentProfileImage] Firestore query hit studentId(int)=$studentId docId=${qInt.docs.first.id}',
          );
          return url;
        }
      }
    } catch (_) {
      // ignore
    }

    try {
      final qString = await _firestore
          .collection('external_students')
          .where('studentId', isEqualTo: '$studentId')
          .limit(1)
          .get();
      if (qString.docs.isNotEmpty) {
        final url = _pickUrlField(qString.docs.first.data());
        if (url != null) {
          debugPrint(
            '[StudentProfileImage] Firestore query hit studentId(string)=$studentId docId=${qString.docs.first.id}',
          );
          return url;
        }
      }
    } catch (_) {
      // ignore
    }

    if (email.isNotEmpty) {
      try {
        final qEmail = await _firestore
            .collection('external_students')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (qEmail.docs.isNotEmpty) {
          final url = _pickUrlField(qEmail.docs.first.data());
          if (url != null) {
            debugPrint(
              '[StudentProfileImage] Firestore query hit email=$email docId=${qEmail.docs.first.id}',
            );
            return url;
          }
        }
      } catch (_) {
        // ignore
      }
    }

    // 2) Fallback: try Storage paths where the filename is the academic number.
    // Adjust/extend these paths if your bucket uses a different convention.
    final candidates = <String>[
      'students/$studentId.jpg',
      'students/$studentId.jpeg',
      'students/$studentId.png',
      'external_students/$studentId.jpg',
      'external_students/$studentId.jpeg',
      'external_students/$studentId.png',
      'student_images/$studentId.jpg',
      'student_images/$studentId.jpeg',
      'student_images/$studentId.png',
      '$studentId.jpg',
      '$studentId.jpeg',
      '$studentId.png',
    ];

    for (final path in candidates) {
      try {
        final ref = _storage.ref().child(path);
        final url = await ref.getDownloadURL();
        if (url.isNotEmpty) {
          debugPrint(
            '[StudentProfileImage] Found storage image for studentId=$studentId at $path',
          );
          return url;
        }
      } on FirebaseException catch (e) {
        // object-not-found is expected for most candidate paths.
        if (e.code == 'unauthorized') {
          debugPrint(
            '[StudentProfileImage] Storage unauthorized for studentId=$studentId. '
            'Skipping further storage lookups.',
          );
          break;
        }
        if (e.code != 'object-not-found') {
          debugPrint(
            '[StudentProfileImage] Storage error for studentId=$studentId path=$path '
            'code=${e.code} message=${e.message}',
          );
        }
      } catch (_) {
        // ignore and continue.
      }
    }

    debugPrint(
      '[StudentProfileImage] No profile image found for studentId=$studentId email=$email',
    );
    return null;
  }

  String? _pickUrlField(Map<String, dynamic> data) {
    String? asNonEmptyString(dynamic v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    return asNonEmptyString(data['photoUrl']) ??
        asNonEmptyString(data['photo_url']) ??
        asNonEmptyString(data['imageUrl']) ??
        asNonEmptyString(data['image_url']) ??
        asNonEmptyString(data['profileUrl']) ??
        asNonEmptyString(data['profile_url']);
  }

  void clearCache() => _cache.clear();
}

