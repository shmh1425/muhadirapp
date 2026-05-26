import '../offline_operation.dart';

/// Contract for future feature-specific sync handlers (Phase 2B+).
abstract class OfflineOperationProcessor {
  /// Operation [type] value this processor handles.
  String get type;

  /// Applies the remote side-effect for [operation].
  /// Throws on failure; the sync engine will mark the operation failed.
  Future<void> process(OfflineOperation operation);
}
