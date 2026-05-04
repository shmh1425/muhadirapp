import 'package:flutter/material.dart';
import '../../screens/lecturer/widgets/modern_popup_dialog.dart';

Future<String?> showExcuseRejectionReasonDialog({
  required BuildContext context,
  required String Function(String ar, String en) tr,
  required TextDirection textDirection,
  Color primaryColor = const Color(0xFF006571),
}) async {
  const int rejectOptionNotValid = 0;
  const int rejectOptionDateMismatch = 1;
  const int rejectOptionOther = 2;

  final reasonController = TextEditingController();
  int selectedOption = rejectOptionNotValid;

  final result = await showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (ctx) {
      return Directionality(
        textDirection: textDirection,
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Widget buildRejectOption({
              required bool selected,
              required String label,
              required VoidCallback onTap,
            }) {
              return Material(
                color: selected
                    ? primaryColor.withValues(alpha: 0.12)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? primaryColor
                            : const Color(0xFFE2E8F0),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off_outlined,
                          size: 22,
                          color: selected
                              ? primaryColor
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? const Color(0xFF213236)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ModernPopupDialog(
              accentColor: primaryColor,
              title: Text(
                tr('سبب الرفض', 'Rejection reason'),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF213236),
                ),
              ),
              actions: [
                ModernPopupActionButton(
                  label: tr('إلغاء', 'Cancel'),
                  onTap: () => Navigator.of(ctx).pop(),
                  isPrimary: false,
                ),
                ModernPopupActionButton(
                  label: tr('تأكيد الرفض', 'Confirm'),
                  onTap: () {
                    String reason;
                    if (selectedOption == rejectOptionNotValid) {
                      reason = tr(
                        'ليس عذراً صحيحاً موثوقاً',
                        'Not a valid or reliable excuse',
                      );
                    } else if (selectedOption == rejectOptionDateMismatch) {
                      reason = tr(
                        'تاريخ الغياب غير متوافق',
                        'Absence date does not match',
                      );
                    } else {
                      reason = reasonController.text.trim().isEmpty
                          ? tr('سبب آخر', 'Other reason')
                          : reasonController.text.trim();
                    }
                    Navigator.of(ctx).pop(reason);
                  },
                  isPrimary: true,
                  primaryColor: primaryColor,
                ),
              ],
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildRejectOption(
                      selected: selectedOption == rejectOptionNotValid,
                      label: tr(
                        'ليس عذراً صحيحاً موثوقاً',
                        'Not a valid or reliable excuse',
                      ),
                      onTap: () => setDialogState(
                        () => selectedOption = rejectOptionNotValid,
                      ),
                    ),
                    const SizedBox(height: 8),
                    buildRejectOption(
                      selected: selectedOption == rejectOptionDateMismatch,
                      label: tr(
                        'تاريخ الغياب غير متوافق',
                        'Absence date does not match',
                      ),
                      onTap: () => setDialogState(
                        () => selectedOption = rejectOptionDateMismatch,
                      ),
                    ),
                    const SizedBox(height: 8),
                    buildRejectOption(
                      selected: selectedOption == rejectOptionOther,
                      label: tr('سبب آخر', 'Other reason'),
                      onTap: () => setDialogState(
                        () => selectedOption = rejectOptionOther,
                      ),
                    ),
                    if (selectedOption == rejectOptionOther) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        minLines: 3,
                        maxLines: 3,
                        textAlign: TextAlign.start,
                        textDirection: textDirection,
                        cursorColor: primaryColor,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: tr(
                            'اكتب سبب الرفض',
                            'Write the rejection reason',
                          ),
                          hintStyle: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );

  reasonController.dispose();
  return result;
}
