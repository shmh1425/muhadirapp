import 'dart:collection';

/// Short-lived in-memory dedup for double tap / double scan.
class AttendanceIdempotencyCache {
  AttendanceIdempotencyCache._();
  static final AttendanceIdempotencyCache instance = AttendanceIdempotencyCache._();

  static const Duration ttl = Duration(seconds: 30);

  final LinkedHashMap<String, DateTime> _seen = LinkedHashMap<String, DateTime>();

  bool tryConsume(String requestId) {
    final key = requestId.trim();
    if (key.isEmpty) return true;
    _purgeExpired();
    if (_seen.containsKey(key)) {
      return false;
    }
    _seen[key] = DateTime.now().toUtc();
    if (_seen.length > 500) {
      _seen.remove(_seen.keys.first);
    }
    return true;
  }

  void _purgeExpired() {
    final now = DateTime.now().toUtc();
    final expired = <String>[];
    for (final entry in _seen.entries) {
      if (now.difference(entry.value) > ttl) {
        expired.add(entry.key);
      }
    }
    for (final key in expired) {
      _seen.remove(key);
    }
  }
}
