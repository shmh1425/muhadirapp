import 'package:flutter/material.dart';

class FemaleSecurityNavBar extends StatelessWidget {
  const FemaleSecurityNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  static const _barHeight = 64.0;
  static const _circleSize = 52.0;
  static const _iconSize = 24.0;
  static const _activeColor = Color(0xFF27A2A9);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _barHeight + 12,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.how_to_reg_outlined,
                  activeIcon: Icons.how_to_reg,
                  isActive: selectedIndex == 0,
                  onTap: () => onItemTapped(0),
                ),
                _NavItem(
                  icon: Icons.person_off_outlined,
                  activeIcon: Icons.person_off,
                  isActive: selectedIndex == 1,
                  onTap: () => onItemTapped(1),
                ),
                _NavItem(
                  icon: Icons.campaign_outlined,
                  activeIcon: Icons.campaign,
                  isActive: selectedIndex == 2,
                  onTap: () => onItemTapped(2),
                ),
                _NavItem(
                  icon: Icons.tune,
                  activeIcon: Icons.tune,
                  isActive: selectedIndex == 3,
                  onTap: () => onItemTapped(3),
                ),
              ],
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
  });

  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;

  static const _activeColor = Color(0xFF27A2A9);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 48 : 40,
            height: isActive ? 48 : 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? _activeColor : Colors.transparent,
            ),
            child: Center(
              child: Icon(
                isActive ? activeIcon : icon,
                size: 24,
                color: isActive ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
