import 'package:flutter/material.dart';
import 'student/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _agreeToTerms = false;
  _UserRole _selectedRole = _UserRole.lecturer;
  final TextEditingController _emailController = TextEditingController();
  String? _emailError;
  bool _termsError = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    final email = _emailController.text.trim();
    final hasEmail = email.isNotEmpty;
    final hasTerms = _agreeToTerms;

    setState(() {
      _emailError = hasEmail ? null : 'اكتب ايميل';
      _termsError = !hasTerms;
    });

    if (!hasEmail || !hasTerms) {
      return;
    }

    if (_selectedRole == _UserRole.student) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  Image.asset(
                    'assets/images/gate_background.jpg',
                    width: double.infinity,
                    height: 230,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.language, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    top: 150,
                    left: 24,
                    right: 24,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _RoleChip(
                                label: 'محاضر',
                                isActive: _selectedRole == _UserRole.lecturer,
                                onTap: () {
                                  setState(() {
                                    _selectedRole = _UserRole.lecturer;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: _RoleChip(
                                label: 'طالبة/ة',
                                isActive: _selectedRole == _UserRole.student,
                                onTap: () {
                                  setState(() {
                                    _selectedRole = _UserRole.student;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: _RoleChip(
                                label: 'الأمن',
                                isActive: _selectedRole == _UserRole.security,
                                onTap: () {
                                  setState(() {
                                    _selectedRole = _UserRole.security;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'تسجيل الدخول',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006571),
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'في تطبيق محضر',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFB08B50),
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'الإيميل الجامعي :',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InputField(
                      hintText: 'info@email.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      errorText: _emailError,
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() {
                            _emailError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'الرقم السري :',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InputField(
                      hintText: '••••••••',
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text(
                          'نسيت كلمة المرور؟',
                          style: TextStyle(
                            color: Color(0xFF444444),
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreeToTerms = value ?? false;
                              if (_agreeToTerms) {
                                _termsError = false;
                              }
                            });
                          },
                          activeColor: const Color(0xFF006571),
                        ),
                        const Expanded(
                          child: Text(
                            'بدخولك إلى هذا التطبيق، فإنك توافق على شروط الاستخدام وسياسة الخصوصية.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF444444),
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_termsError) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'يجب الموافقة على شروط الاستخدام',
                        style: TextStyle(
                          color: Color(0xFFD32F2F),
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
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
                          onPressed: _onLoginPressed,
                          child: const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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

class _RoleChip extends StatelessWidget {
  const _RoleChip({
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
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF006571),
              fontWeight: FontWeight.w600,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ),
    );
  }
}

enum _UserRole {
  lecturer,
  student,
  security,
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.hintText,
    this.obscureText = false,
    this.controller,
    this.keyboardType,
    this.textDirection,
    this.textAlign = TextAlign.right,
    this.errorText,
    this.onChanged,
  });

  final String hintText;
  final bool obscureText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textDirection: textDirection,
      textAlign: textAlign,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFB0B0B0)),
        errorText: errorText,
        errorStyle: const TextStyle(
          color: Color(0xFFD32F2F),
          fontFamily: 'Cairo',
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF006571)),
        ),
      ),
    );
  }
}
