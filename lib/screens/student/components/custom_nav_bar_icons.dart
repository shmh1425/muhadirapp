import 'package:flutter/material.dart';

class CustomNavBarIcons extends StatelessWidget {
  const CustomNavBarIcons({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  static const _barHeight = 64.0;
  static const _circleSize = 60.0;
  static const _iconSize = 24.0;
  static const _activeColor = Color(0xFF006571);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _barHeight + (_circleSize / 2) + 12,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: _barHeight,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.tune,
                    isActive: selectedIndex == 0,
                    onTap: () => onItemTapped(0),
                  ),
                  _NavItem(
                    icon: Icons.grid_view,
                    isActive: selectedIndex == 1,
                    onTap: () => onItemTapped(1),
                  ),
                  _NavItem(
                    icon: Icons.home,
                    isActive: selectedIndex == 2,
                    onTap: () => onItemTapped(2),
                  ),
                ],
              ),
            ),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: _alignmentForIndex(selectedIndex),
            child: Container(
              width: _circleSize,
              height: _circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment(0.50, 1.00),
                  end: Alignment(0.50, 0.00),
                  colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                _iconForIndex(selectedIndex),
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Alignment _alignmentForIndex(int index) {
    switch (index) {
      case 0:
        return const Alignment(-0.8, 0.55);
      case 1:
        return const Alignment(0.0, 0.55);
      case 2:
        return const Alignment(0.8, 0.55);
      default:
        return const Alignment(0.0, 0.55);
    }
  }

  IconData _iconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.tune;
      case 1:
        return Icons.grid_view;
      case 2:
        return Icons.home;
      default:
        return Icons.grid_view;
    }
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  static const _activeColor = Color(0xFF006571);
  static const _iconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: isActive ? 0.0 : 1.0,
            child: Icon(
              icon,
              size: _iconSize,
              color: _activeColor,
            ),
          ),
        ),
      ),
    );
  }
}

class NavBarSettingsArabic extends StatelessWidget {
  const NavBarSettingsArabic({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  @override
  Widget build(BuildContext context) {
    return CustomNavBarIcons(
      selectedIndex: selectedIndex,
      onItemTapped: onItemTapped,
    );
  }
}
