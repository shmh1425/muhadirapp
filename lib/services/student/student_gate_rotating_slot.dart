/// 30-second rotating window for gate QR / HCE (anti-screenshot).
class StudentGateRotatingSlot {
  StudentGateRotatingSlot._();

  static const int windowSeconds = 30;

  static int at(DateTime time) =>
      time.millisecondsSinceEpoch ~/ (windowSeconds * 1000);

  static int current([DateTime? time]) => at(time ?? DateTime.now());

  /// Accepts current window and one prior (clock skew / scan at boundary).
  static bool isAccepted(int? slot, {DateTime? now}) {
    if (slot == null) return true;
    final currentSlot = at(now ?? DateTime.now());
    return slot == currentSlot || slot == currentSlot - 1;
  }
}
