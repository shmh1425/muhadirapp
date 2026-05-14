import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lecturer/unified_lecturer_catalog.dart';
import '../repositories/lecturer_catalog_repository.dart';
import '../services/lecturer_auth_service.dart';

final lecturerCatalogRepositoryProvider = Provider<LecturerCatalogRepository>((ref) {
  return LecturerCatalogRepository.instance;
});

/// Shared cache-first catalog for the signed-in lecturer (sections + course metadata).
///
/// Does not include attendance records, NFC sessions, or notifications.
///
/// Riverpod [FutureProvider] is always-alive — cached for the app session until
/// [invalidate]. Background prefetch runs after lecturer login (non-blocking).
final lecturerUnifiedCatalogProvider =
    FutureProvider<UnifiedLecturerCatalog>((ref) async {
  final id =
      (LecturerAuthService.instance.currentLecturer?.lecturerId ?? '').trim();
  if (id.isEmpty) return UnifiedLecturerCatalog.empty();

  final repo = ref.watch(lecturerCatalogRepositoryProvider);
  try {
    return await repo.getCatalogForLecturer(id).timeout(
          const Duration(seconds: 20),
          onTimeout: () => repo.getCachedCatalog(id) ?? UnifiedLecturerCatalog.empty(),
        );
  } catch (_) {
    return repo.getCachedCatalog(id) ?? UnifiedLecturerCatalog.empty();
  }
});
