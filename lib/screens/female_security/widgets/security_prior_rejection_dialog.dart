import 'package:flutter/material.dart';

import '../../../services/female_security/security_gate_scan_service.dart';
import '../security_localization.dart';

const _kAmberIcon = Color(0xFFFFA000);
const _kAmberDark = Color(0xFFE65100);
const _kTeal = Color(0xFF27A2A9);
const _kCancelRed = Color(0xFFD32F2F);

/// Pop-up with warning triangle before [SecurityVerifyStudentDialog] when the
/// student had a rejection earlier the same day at this gate.
class SecurityPriorRejectionDialog extends StatelessWidget {
  const SecurityPriorRejectionDialog({super.key, required this.hint});

  final PriorGateRejectionHint hint;

  /// Returns `true` if the guard chose to continue to the main verify dialog.
  static Future<bool?> show(BuildContext context, PriorGateRejectionHint hint) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: SecurityLocalization.direction,
        child: SecurityPriorRejectionDialog(hint: hint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: SecurityLocalization.controller,
      builder: (context, _) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    shape: BoxShape.circle,
                    border: Border.all(color: _kAmberIcon, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 52,
                    color: _kAmberDark,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  SecurityLocalization.priorRejectionAlertTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  SecurityLocalization.priorRejectionAlertLead,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _kAmberIcon.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      hint.lastRejectionReasonText.isNotEmpty
                          ? hint.lastRejectionReasonText
                          : SecurityLocalization.noReasonRecorded,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kAmberDark,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  SecurityLocalization.priorRejectionAlertFooter,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          SecurityLocalization.priorRejectionAlertContinue,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kCancelRed,
                          side: const BorderSide(
                            color: _kCancelRed,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          SecurityLocalization.priorRejectionAlertCancel,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _kCancelRed,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 40, height: 40),
        const Expanded(child: SizedBox.shrink()),
        IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: Icon(Icons.close, color: colorScheme.onSurface, size: 22),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
            side: BorderSide(color: colorScheme.outlineVariant, width: 1),
            shape: const CircleBorder(),
            minimumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
