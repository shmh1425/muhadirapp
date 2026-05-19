import 'dart:async';

import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../features/translation/translation_controller.dart';
import '../features/translation/widgets/language_toggle_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeSlide {
  const _WelcomeSlide({
    required this.imageAsset,
    required this.labelAr,
    required this.labelEn,
  });

  final String imageAsset;
  final String labelAr;
  final String labelEn;
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _controller = PageController();
  static const List<_WelcomeSlide> _slides = <_WelcomeSlide>[
    _WelcomeSlide(
      imageAsset: 'assets/images/welcome_qr.png',
      labelAr: 'رمز QR',
      labelEn: 'QR code',
    ),
    _WelcomeSlide(
      imageAsset: 'assets/images/welcome_nfc.png',
      labelAr: 'تقنية NFC',
      labelEn: 'NFC',
    ),
    _WelcomeSlide(
      imageAsset: 'assets/images/Bluetooth.jpg',
      labelAr: 'البلوتوث',
      labelEn: 'Bluetooth',
    ),
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
      final nextIndex = (_currentIndex + 1) % _slides.length;
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
    final translation = TranslationController.instance;
    return AnimatedBuilder(
      animation: translation,
      builder: (context, _) {
        final titleWelcome = translation.tr('مرحباً بكم', 'Welcome');
        final titleApp = translation.tr('في تطبيق محضر', 'To the Muhadir app');
        final description = translation.tr(
          'سجّل دخولك باستخدام حسابك الجامعي لتأكيد حضورك بسهولة عبر تقنية NFC أو مسح رمز QR أو إشارة البلوتوث الخاصة بالمحاضر، وكن جزءًا من تجربة حضور ذكية وموثوقة.',
          'Sign in with your university account to record attendance easily via NFC, QR code, or your lecturer\'s Bluetooth signal — a smart, reliable attendance experience.',
        );
        final btnLogin = translation.tr('تسجيل الدخول', 'Sign in');

        return Directionality(
          textDirection: translation.textDirection,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    const Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: LanguageToggleButton(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      titleWelcome,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF006571),
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      titleApp,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFFB08B50),
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _slides.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final slide = _slides[index];
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Image.asset(
                                  slide.imageAsset,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                translation.translateToEnglish
                                    ? slide.labelEn
                                    : slide.labelAr,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF006571),
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (index) {
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
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: Text(
                            btnLogin,
                            style: const TextStyle(
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
      },
    );
  }
}
