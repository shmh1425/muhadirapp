/// Unified profile photo URL helpers (cache key + Firestore field picking).
abstract final class UserProfileImageUrl {
  static String pickRawUrl(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return '';
    String? nonEmpty(dynamic v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    return nonEmpty(data['photoUrl']) ??
        nonEmpty(data['photoURL']) ??
        nonEmpty(data['photo_url']) ??
        nonEmpty(data['imageUrl']) ??
        nonEmpty(data['image_url']) ??
        '';
  }

  static String pickPhotoVersion(Map<String, dynamic>? data) {
    if (data == null) return '';
    return (data['photoVersion'] ?? '').toString().trim();
  }

  /// Single cache key used by [CachedNetworkImage] across the app.
  static String buildCacheUrl(
    String resolvedHttpUrl, {
    String? photoVersion,
  }) {
    final url = resolvedHttpUrl.trim();
    if (url.isEmpty) return '';
    final version = (photoVersion ?? '').trim();
    if (version.isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=$version';
  }

  static bool isDirectHttpUrl(String value) {
    final v = value.trim();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  /// `gs://` or a storage object path (not yet an HTTP download URL).
  static bool needsStorageResolution(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (isDirectHttpUrl(v)) return false;
    return v.startsWith('gs://') || !v.contains('://');
  }
}
