import 'package:flutter/material.dart';

class SecurityDatePickerDialog extends StatefulWidget {
  const SecurityDatePickerDialog({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<SecurityDatePickerDialog> createState() =>
      _SecurityDatePickerDialogState();
}

class _SecurityDatePickerDialogState extends State<SecurityDatePickerDialog> {
  late DateTime _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ constraints ثابتة تمنع "no size"
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'اختر التاريخ',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      splashRadius: 20,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Calendar (stable)
                CalendarDatePicker(
                  initialDate: _tempSelected,
                  firstDate: DateTime(2020, 1, 1),
                  lastDate: DateTime(2035, 12, 31),
                  onDateChanged: (d) {
                    setState(() {
                      _tempSelected = DateTime(d.year, d.month, d.day);
                    });
                  },
                ),

                const SizedBox(height: 10),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop<DateTime>(_tempSelected),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF27A2A9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'تطبيق',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
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
}
