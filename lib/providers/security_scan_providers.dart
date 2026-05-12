import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/security_repository.dart';
import '../services/female_security/security_gate_scan_service.dart';

final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  return SecurityRepository.instance;
});

/// Uniquely identifies one gate + calendar day (local date only).
@immutable
class GateScanKey {
  const GateScanKey({required this.gateId, required this.date});

  final String gateId;
  final DateTime date;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GateScanKey) return false;
    if (other.gateId != gateId) return false;
    return formatScanDateKey(other.date) == formatScanDateKey(date);
  }

  @override
  int get hashCode => Object.hash(gateId, formatScanDateKey(date));
}

/// Realtime accepted scans for a gate/day — one shared stream per [GateScanKey].
final securityAcceptedScansStreamProvider =
    StreamProvider.family<List<SecurityGateScanRecord>, GateScanKey>(
  (ref, key) {
    return ref.watch(securityRepositoryProvider).watchAcceptedScans(
          gateId: key.gateId,
          date: key.date,
        );
  },
);

/// Realtime rejected scans for a gate/day.
final securityRejectedScansStreamProvider =
    StreamProvider.family<List<SecurityGateScanRecord>, GateScanKey>(
  (ref, key) {
    return ref.watch(securityRepositoryProvider).watchRejectedScans(
          gateId: key.gateId,
          date: key.date,
        );
  },
);
