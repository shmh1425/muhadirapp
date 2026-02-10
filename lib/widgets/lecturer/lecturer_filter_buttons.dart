import 'package:flutter/material.dart';

/// Filter buttons component (اليوم، غدًا، الكل)
class LecturerFilterButtons extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const LecturerFilterButtons({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = ['اليوم', 'غدًا', 'الكل'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: filters.map((filter) {
          final isSelected = selectedFilter == filter;
          return Expanded(
            child: InkWell(
              onTap: () => onFilterChanged(filter),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF666666),
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

