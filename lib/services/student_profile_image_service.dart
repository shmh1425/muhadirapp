import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StudentProfileImageService {
  StudentProfileImageService._();

  static final StudentProfileImageService instance =
      StudentProfileImageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Cache to avoid spamming Firestore/Storage, but keep it short-lived so
  /// profile image updates (photoVersion) show up without restarting the app.
  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};
  static const Duration _cacheTtl = Duration(minutes: 2);

  Future<String?> getProfileImageUrl({
    int studentId = 0,
    String? email,
  }) {
    final normalizedEmail = (email ?? '').trim().toLowerCase();
    final key = normalizedEmail.isNotEmpty
        ? 'email|$normalizedEmail'
        : (studentId > 0 ? '$studentId' : 'none');
    if (key == 'none') return Future.value(null);
    final now = DateTime.now();
    final existing = _cache[key];
    if (existing != null && now.difference(existing.createdAt) < _cacheTtl) {
      return existing.future;
    }
    final future = studentId > 0
        ? _load(studentId: studentId, email: normalizedEmail)
        : _loadByEmail(normalizedEmail);
    _cache[key] = _CacheEntry(future: future, createdAt: now);
    return future;
  }

  Future<String?> _loadByEmail(String email) async {
    if (email.trim().isEmpty) return null;
    try {
      final qEmail = await _firestore
          .collection('external_students')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      if (qEmail.docs.isEmpty) return null;
      final data = qEmail.docs.first.data();
      final stored = _pickUrlField(data);
      if (stored == null) return null;
      final resolved = await _resolveStoredPhotoValue(stored);
      if (resolved == null) return null;
      return _withVersion(resolved, data['photoVersion']);
    } catch (e) {
      debugPrint('[StudentProfileImage] email lookup failed: $e');
      return null;
    }
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
        final stored = _pickUrlField(data);
        if (stored != null) {
          debugPrint(
            '[StudentProfileImage] Firestore doc hit external_students/$studentId',
          );
          final resolved = await _resolveStoredPhotoValue(stored);
          if (resolved == null) return null;
          return _withVersion(resolved, data['photoVersion']);
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
        final data = qInt.docs.first.data();
        final stored = _pickUrlField(data);
        if (stored != null) {
          debugPrint(
            '[StudentProfileImage] Firestore query hit studentId(int)=$studentId docId=${qInt.docs.first.id}',
          );
          final resolved = await _resolveStoredPhotoValue(stored);
          if (resolved == null) return null;
          return _withVersion(resolved, data['photoVersion']);
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
        final data = qString.docs.first.data();
        final stored = _pickUrlField(data);
        if (stored != null) {
          debugPrint(
            '[StudentProfileImage] Firestore query hit studentId(string)=$studentId docId=${qString.docs.first.id}',
          );
          final resolved = await _resolveStoredPhotoValue(stored);
          if (resolved == null) return null;
          return _withVersion(resolved, data['photoVersion']);
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
          final data = qEmail.docs.first.data();
          final stored = _pickUrlField(data);
          if (stored != null) {
            debugPrint(
              '[StudentProfileImage] Firestore query hit email=$email docId=${qEmail.docs.first.id}',
            );
            final resolved = await _resolveStoredPhotoValue(stored);
            if (resolved == null) return null;
            return _withVersion(resolved, data['photoVersion']);
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
        asNonEmptyString(data['photoURL']) ??
        asNonEmptyString(data['photo_url']) ??
        asNonEmptyString(data['imageUrl']) ??
        asNonEmptyString(data['image_url']) ??
        asNonEmptyString(data['profileUrl']) ??
        asNonEmptyString(data['profile_url']);
  }

  String _withVersion(String rawUrl, dynamic versionValue) {
    final url = rawUrl.trim();
    if (url.isEmpty) return url;
    final version = (versionValue ?? '').toString().trim();
    if (version.isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=$version';
  }

  /// Resolves what we store in Firestore into a HTTP download URL.
  ///
  /// We support:
  /// - https://... (already a download URL)
  /// - gs://bucket/path (storage URL)
  /// - path/in/bucket.jpg (storage object path)
  Future<String?> _resolveStoredPhotoValue(String stored) async {
    final v = stored.trim();
    if (v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) return v;

    try {
      if (v.startsWith('gs://')) {
        return await _storage.refFromURL(v).getDownloadURL();
      }
      // Treat as object path in the bucket.
      return await _storage.ref().child(v).getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint(
        '[StudentProfileImage] resolve stored photo failed: code=${e.code} message=${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('[StudentProfileImage] resolve stored photo failed: $e');
      return null;
    }
  }

  void clearCache() => _cache.clear();
}

class _CacheEntry {
  const _CacheEntry({required this.future, required this.createdAt});
  final Future<String?> future;
  final DateTime createdAt;
}

