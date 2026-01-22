import 'package:flutter/material.dart';
import 'components/custom_nav_bar_icons.dart';
import 'components/notification_bell.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';

class NfcAttendanceScreen extends StatefulWidget {
  const NfcAttendanceScreen({super.key});

  @override
  State<NfcAttendanceScreen> createState() => _NfcAttendanceScreenState();
}

class _NfcAttendanceScreenState extends State<NfcAttendanceScreen>
    with SingleTickerProviderStateMixin {
  bool _isNfc = true;
  int selectedIndex = 2;
  AnimationController? _pulseController;

  void _toggleMode(bool nfc) {
    setState(() {
      _isNfc = nfc;
    });
  }

  Future<void> _onItemTapped(int index) async {
    setState(() {
      selectedIndex = index;
    });

    switch (index) {
      case 0:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          selectedIndex = 2;
        });
        break;
      case 1:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServicesScreen()),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          selectedIndex = 2;
        });
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pulseController == null) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: NavBarSettingsArabic(
          selectedIndex: selectedIndex,
          onItemTapped: _onItemTapped,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_forward_ios,
                        color: Color(0xFF006571)),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'تسجيل الحضور',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006571),
                    ),
                  ),
                  const Spacer(),
                  NotificationBell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'سجل حضورك',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 140,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F7F7),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ModeChip(
                          label: 'QR',
                          isActive: !_isNfc,
                          onTap: () => _toggleMode(false),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ModeChip(
                          label: 'NFC',
                          isActive: _isNfc,
                          onTap: () => _toggleMode(true),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: MediaQuery.of(context).size.height * 0.65,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FBFB),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isNfc) ...[
                      AnimatedBuilder(
                        animation: _pulseController ?? const AlwaysStoppedAnimation(0),
                        builder: (context, child) {
                          const ringCount = 12;
                          final t = CurvedAnimation(
                            parent: _pulseController ?? const AlwaysStoppedAnimation(0),
                            curve: Curves.easeInOut,
                          ).value;
                          return Stack(
                            alignment: Alignment.center,
                            children: List.generate(ringCount, (index) {
                              final baseSize = 90.0 + (index * 36);
                              final phase = (t + (index * 0.12)) % 1.0;
                              final eased = Curves.easeInOut.transform(phase);
                              final size = baseSize + (eased * 28);
                              final opacity = 0.05 + ((1 - eased) * 0.18);
                              return Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF6FB2B7)
                                        .withOpacity(opacity),
                                    width: 1,
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF006571),
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.phone_iphone,
                            size: 52, color: Color(0xFF006571)),
                      ),
                    ] else ...[
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 420,
                            height: 420,
                            child: Image.asset(
                              'assets/images/QR.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 180,
                            height: 44,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF27A2A9),
                                    Color(0xFF006571),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextButton(
                                onPressed: () {},
                                child: const Text(
                                  'امسح الآن',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF006571) : const Color(0xFF4CAEB7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
