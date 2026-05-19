import 'package:flutter/material.dart';

import 'security_localization.dart';

class FemaleSecurityNavBar extends StatelessWidget {
  const FemaleSecurityNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  static const _primaryTeal = Color(0xFF27A2A9);
  static const _darkTeal = Color(0xFF006571);
  static const _pillHeight = 64.0;
  static const _activeSize = 52.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: _pillHeight + 8,
            child: Container(
              height: _pillHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.list_alt_outlined,
                    activeIcon: Icons.list_alt_rounded,
                    isActive: selectedIndex == 0,
                    tooltip: SecurityLocalization.records,
                    onTap: () => onItemTapped(0),
                  ),
                  _NavItem(
                    icon: Icons.qr_code_scanner_rounded,
                    activeIcon: Icons.qr_code_scanner_rounded,
                    isActive: selectedIndex == 1,
                    tooltip: SecurityLocalization.scanVerification,
                    onTap: () => onItemTapped(1),
                  ),
                  _NavItem(
                    icon: Icons.manage_accounts_outlined,
                    activeIcon: Icons.manage_accounts,
                    isActive: selectedIndex == 2,
                    tooltip: SecurityLocalization.settings,
                    onTap: () => onItemTapped(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    const iconSize = 24.0;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: FemaleSecurityNavBar._activeSize,
            height: FemaleSecurityNavBar._activeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isActive
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FemaleSecurityNavBar._primaryTeal,
                        FemaleSecurityNavBar._darkTeal,
                      ],
                    )
                  : null,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: FemaleSecurityNavBar._primaryTeal.withValues(
                          alpha: 0.26,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Tooltip(
              message: tooltip,
              child: Center(
                child: Icon(
                  isActive ? activeIcon : icon,
                  size: iconSize,
                  color: isActive ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
