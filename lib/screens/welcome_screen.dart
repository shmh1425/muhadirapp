import 'dart:async';

import 'package:flutter/material.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _controller = PageController();
  final List<String> _images = const [
    'assets/images/welcome_qr.png',
    'assets/images/welcome_nfc.png',
  ];
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_controller.hasClients) {
        return;
      }
      final nextIndex = (_currentIndex + 1) % _images.length;
      _controller.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.language, color: Color(0xFF006571)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'مرحباً بكم',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF006571),
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'في تطبيق محضر',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFB08B50),
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _images.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Image.asset(
                        _images[index],
                        fit: BoxFit.contain,
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_images.length, (index) {
                    final isActive = index == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 10 : 8,
                      height: isActive ? 10 : 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF006571)
                            : const Color(0xFFBFCED1),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                const Text(
                  'سجّل دخولك باستخدام حسابك الجامعي لتأكيد حضورك بسهولة عبر تقنية الـNFC أو مسح رمز QR الخاص بالمحاضـر، وكن جزءًا من تجربة حضور ذكية وموثوقة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.black,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 180,
                  height: 46,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
