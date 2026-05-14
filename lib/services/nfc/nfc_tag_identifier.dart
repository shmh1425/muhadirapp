import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';

import '../attendance/nfc_attendance_service.dart';

/// Shared NFC tag → normalized identifier string (hex UID or NDEF payload).
class NfcTagIdentifier {
  NfcTagIdentifier._();

  /// Normalized id suitable for Firestore lookup / lecturer card rules.
  static String extractNormalizedId(NfcTag tag) {
    final fromNdef = _extractCardIdFromNdef(tag);
    if (fromNdef.isNotEmpty) {
      return _normalizeFromNdefText(fromNdef);
    }

    final data = tag.data;
    final candidates = <dynamic>[
      _dig(data, ['mifare', 'identifier']),
      _dig(data, ['iso15693', 'identifier']),
      _dig(data, ['iso7816', 'identifier']),
      _dig(data, ['iso15693', 'icSerialNumber']),
      _dig(data, ['nfca', 'identifier']),
      _dig(data, ['mifareclassic', 'identifier']),
      _dig(data, ['mifareultralight', 'identifier']),
      _dig(data, ['nfcv', 'identifier']),
      _dig(data, ['nfcb', 'identifier']),
      _dig(data, ['isodep', 'identifier']),
      _dig(data, ['felica', 'currentIDm']),
      _dig(data, ['ndef', 'identifier']),
    ];

    for (final candidate in candidates) {
      final id = _bytesToHex(candidate);
      if (id.isNotEmpty) {
        return NfcAttendanceService.normalizeLecturerCardId(id);
      }
    }
    return '';
  }

  /// Raw NDEF text when the payload is `student_gate_card` JSON (includes `rev`).
  static String extractStudentGateCardNdefRaw(NfcTag tag) {
    final raw = _extractCardIdFromNdef(tag);
    if (raw.isEmpty) return '';
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is Map) {
        final type = (decoded['type'] ?? '').toString().trim().toLowerCase();
        if (type == 'student_gate_card') return raw.trim();
      }
    } catch (_) {}
    return '';
  }

  static String _normalizeFromNdefText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return '';

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final payload = Map<String, dynamic>.from(decoded);
        final type = (payload['type'] ?? '').toString().trim().toLowerCase();
        final id = (payload['id'] ?? '').toString().trim();
        if (type == 'lecturer_card' && id.isNotEmpty) {
          return NfcAttendanceService.normalizeLecturerCardId(id);
        }
        if (type == 'student_gate_card' && id.isNotEmpty) {
          return NfcAttendanceService.normalizeLecturerCardId(id);
        }
      }
    } catch (_) {
      // Plain text / legacy payloads.
    }

    return NfcAttendanceService.normalizeLecturerCardId(text);
  }

  static String _extractCardIdFromNdef(NfcTag tag) {
    final ndef = Ndef.from(tag);
    final message = ndef?.cachedMessage;
    if (message == null) return '';

    for (final record in message.records) {
      final textValue = _decodeNdefRecordAsText(record);
      if (textValue.isNotEmpty) {
        return textValue;
      }
    }

    return '';
  }

  static String _decodeNdefRecordAsText(NdefRecord record) {
    final payload = record.payload;
    if (payload.isEmpty) return '';

    final type = ascii.decode(record.type, allowInvalid: true);
    if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
        type == 'T') {
      final status = payload.first;
      final languageLength = status & 0x3F;
      if (payload.length <= languageLength + 1) return '';
      final textBytes = payload.sublist(languageLength + 1);
      return utf8.decode(textBytes, allowMalformed: true).trim();
    }

    return utf8.decode(payload, allowMalformed: true).trim();
  }

  static dynamic _dig(Map<dynamic, dynamic> map, List<String> path) {
    dynamic current = map;
    for (final key in path) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  static String _bytesToHex(dynamic value) {
    List<int> bytes = <int>[];

    if (value is Uint8List) {
      bytes = value.toList();
    } else if (value is List) {
      bytes = value.whereType<num>().map((e) => e.toInt()).toList();
    } else if (value is String) {
      final normalized = value.trim().replaceAll(' ', '');
      final isHex = RegExp(r'^[A-Fa-f0-9]+$').hasMatch(normalized);
      if (isHex) {
        return normalized.toUpperCase();
      }
    }

    if (bytes.isEmpty) return '';

    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }
}
