/// Lifecycle status for a queued [OfflineOperation].
enum OfflineOperationStatus {
  pending,
  syncing,
  synced,
  failed;

  static OfflineOperationStatus? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase();
    for (final value in OfflineOperationStatus.values) {
      if (value.name == normalized) return value;
    }
    return null;
  }

  String get storageValue => name;
}
