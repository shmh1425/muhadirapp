import 'dart:convert';

/// Shared JSON payload for campus gate: HCE (Android), student-card QR, and security reader.
class StudentGatePayload {
  StudentGatePayload._();

  /// Primary type written into QR / NFC text NDEF.
  static const String typeStudentGateCard = 'student_gate_card';

  /// Increment in Firestore `external_students.gateCardRev` when the card must
  /// invalidate (e.g. withdrawal) so old QR/screenshots stop working.
  static String buildJsonString(int studentId, {int gateCardRev = 0}) {
    return jsonEncode(<String, dynamic>{
      'type': typeStudentGateCard,
      'id': studentId.toString(),
      'rev': gateCardRev,
    });
  }

  /// Result of parsing a gate QR / NDEF JSON payload.
  static ParsedStudentGatePayload? parseGatePayload(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return null;
      final m = Map<String, dynamic>.from(decoded);
      final type = (m['type'] ?? '').toString().trim().toLowerCase();
      if (type != typeStudentGateCard &&
          type != 'student_gate_qr' &&
          type != 'security_gate_student' &&
          type != 'muhadir_student_gate') {
        return null;
      }
      final id = (m['id'] ?? m['studentId'] ?? m['universityId'] ?? '')
          .toString()
          .trim();
      if (id.isEmpty) return null;

      final int? rev = m.containsKey('rev')
          ? int.tryParse(m['rev'].toString()) ?? 0
          : null;

      return ParsedStudentGatePayload(lookupKey: id, gateCardRev: rev);
    } catch (_) {
      return null;
    }
  }

  /// Parses QR/HCE text into a lookup key for [SecurityRepository.findStudentByUniversityId]
  /// / [findStudentBySecurityNfcUid].
  static String? parseStudentLookupKey(String raw) {
    final parsed = parseGatePayload(raw);
    if (parsed != null) return parsed.lookupKey;

    final compact = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'^\d{5,12}$').hasMatch(compact)) return compact;
    return null;
  }
}

/// [gateCardRev] null means the payload had no `rev` field (legacy); skip rev check.
class ParsedStudentGatePayload {
  const ParsedStudentGatePayload({
    required this.lookupKey,
    this.gateCardRev,
  });

  final String lookupKey;

  /// When non-null, security must match [SecurityStudentProfile.gateCardRev].
  final int? gateCardRev;
}
