import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation/translation_controller.dart';
import '../features/translation/widgets/t_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student/home_screen.dart';
import 'lecturer/lecturer_main_shell.dart';
import 'lecturer/lecturer_profile_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'female_security/female_security_home_screen.dart';
import '../providers/courses_providers.dart';
import '../providers/lecturer_catalog_providers.dart';
import '../services/student_auth_service.dart';
import '../services/lecturer_auth_service.dart';
import '../services/lecturer/lecturer_cold_start_warmup.dart';
import '../features/chatbot/providers/chatbot_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _agreeToTerms = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _emailError;
  bool _termsError = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final hasEmail = email.isNotEmpty;
    final hasTerms = _agreeToTerms;

    setState(() {
      _emailError = hasEmail ? null : 'اكتب ايميل';
      _termsError = !hasTerms;
    });

    if (!hasEmail || !hasTerms) {
      return;
    }

    if (password.isEmpty) {
      setState(() => _emailError = 'أدخل كلمة المرور');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final normalizedEmail = email.toLowerCase();
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'لم يتم العثور على مستخدم مسجل.',
        );
      }

      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .get();
      if (adminDoc.exists) {
        ChatbotProvider.instance.clearChat();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
        return;
      }

      final securityDoc = await FirebaseFirestore.instance
          .collection('security_staff')
          .doc(uid)
          .get();
      if (securityDoc.exists) {
        final isActive = securityDoc.data()?['isActive'] == true;
        if (!isActive) {
          await FirebaseAuth.instance.signOut();
          ChatbotProvider.instance.clearChat();
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _emailError = 'حساب الأمن غير مفعل حالياً';
          });
          return;
        }
        ChatbotProvider.instance.clearChat();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FemaleSecurityHomeScreen()),
        );
        return;
      }

      final lecturer = await LecturerAuthService.instance
          .verifyEmailAndGetLecturer(normalizedEmail);
      if (lecturer != null) {
        final displayName = lecturer.nameAr.trim().isNotEmpty
            ? lecturer.nameAr
            : lecturer.nameEn;
        final profile = LecturerProfile(
          name: displayName.isNotEmpty ? displayName : 'محاضر',
          email: lecturer.email,
          college: lecturer.college,
          department: lecturer.department,
        );
        ChatbotProvider.instance.clearChat();
        if (!mounted) return;
        final container = ProviderScope.containerOf(context);
        container.invalidate(lecturerUnifiedCatalogProvider);
        unawaited(LecturerColdStartWarmup.run(container));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                LecturerMainShell(initialIndex: 2, profile: profile),
          ),
        );
        return;
      }

      final student = await StudentAuthService.instance
          .verifyEmailAndGetStudent(normalizedEmail);
      if (student != null) {
        ChatbotProvider.instance.clearChat();
        if (!mounted) return;
        try {
          final container = ProviderScope.containerOf(context);
          await container
              .read(
                studentUnifiedCoursesProvider(student.studentId.toString())
                    .future,
              )
              .timeout(const Duration(seconds: 12));
        } catch (e) {
          debugPrint('[Login] prefetch studentUnifiedCoursesProvider: $e');
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return;
      }

      await FirebaseAuth.instance.signOut();
      ChatbotProvider.instance.clearChat();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _emailError = 'الحساب صحيح لكن غير مربوط بدور داخل النظام';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'user-not-found' => 'لا يوجد حساب بهذا الإيميل، سجّل أولاً',
        'wrong-password' => 'كلمة المرور غير صحيحة',
        'invalid-email' => 'صيغة الإيميل غير صحيحة',
        'invalid-credential' => 'الإيميل أو كلمة المرور غير صحيحة',
        'network-request-failed' =>
          'تعذر الاتصال بالإنترنت. تأكد من الشبكة وحاول مرة أخرى.',
        'keychain-error' =>
          'تعذر الوصول إلى Keychain على macOS. أعد تشغيل التطبيق واسمح بالصلاحية.',
        _ => e.message ?? 'فشل تسجيل الدخول',
      };
      setState(() {
        _isLoading = false;
        _emailError = message;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      debugPrint('Auto role routing error [${e.code}]: ${e.message}');
      final message = switch (e.code) {
        'permission-denied' => 'لا توجد صلاحية لقراءة بيانات الدور.',
        'unavailable' =>
          'الخدمة غير متاحة حالياً، تأكد من الاتصال وحاول مرة أخرى.',
        'failed-precondition' =>
          'Firestore يحتاج إعداد إضافي (غالباً فهرس/Index).',
        _ => 'حدث خطأ (${e.code})، حاول مرة أخرى.',
      };
      setState(() {
        _isLoading = false;
        _emailError = message;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Unknown login error: $e');
      setState(() {
        _isLoading = false;
        _emailError = 'حدث خطأ غير متوقع، حاول مرة أخرى';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final translation = TranslationController.instance;
    return AnimatedBuilder(
      animation: translation,
      builder: (context, _) {
        final titleLogin = translation.translateToEnglish ? 'Sign in' : 'تسجيل الدخول';
        final titleApp = translation.translateToEnglish ? 'In Muhadir app' : 'في تطبيق محضر';
        final labelEmail =
            translation.translateToEnglish ? 'University email:' : 'الإيميل الجامعي :';
        final labelPassword =
            translation.translateToEnglish ? 'Password:' : 'الرقم السري :';
        final forgot =
            translation.translateToEnglish ? 'Forgot password?' : 'نسيت كلمة المرور؟';
        final terms = translation.translateToEnglish
            ? 'By signing in, you agree to the Terms of Use and Privacy Policy.'
            : 'بدخولك إلى هذا التطبيق، فإنك توافق على شروط الاستخدام وسياسة الخصوصية.';
        final termsError = translation.translateToEnglish
            ? 'You must agree to the terms of use'
            : 'يجب الموافقة على شروط الاستخدام';
        final btnLogin = translation.translateToEnglish ? 'Sign in' : 'تسجيل الدخول';

        return Directionality(
          textDirection: translation.textDirection,
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
                      // Language toggle moved to Settings screen only.
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TText(
                      titleLogin,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006571),
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 6),
                    TText(
                      titleApp,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFFB08B50),
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 22),
                    TText(
                      labelEmail,
                      style: const TextStyle(
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
                    TText(
                      labelPassword,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InputField(
                      hintText: '••••••••',
                      obscureText: _obscurePassword,
                      controller: _passwordController,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF006571),
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        splashRadius: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: TText(
                          forgot,
                          style: const TextStyle(
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
                          checkColor: Colors.white,
                          side: const BorderSide(
                            color: Color(0xFF006571),
                            width: 1.4,
                          ),
                          fillColor:
                              WidgetStateProperty.resolveWith<Color>((states) {
                            if (states.contains(WidgetState.selected)) {
                              return const Color(0xFF006571);
                            }
                            // Keep unchecked box clearly visible on white backgrounds.
                            return Colors.white;
                          }),
                        ),
                        Expanded(
                          child: TText(
                            terms,
                            style: const TextStyle(
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
                      TText(
                        termsError,
                        style: const TextStyle(
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
                          onPressed: _isLoading ? null : _onLoginPressed,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : TText(
                                  btnLogin,
                                  style: const TextStyle(
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
      },
    );
  }
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
    this.suffixIcon,
  });

  final String hintText;
  final bool obscureText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;

  static const Color _borderEnabled = Color(0xFFD0D0D0);
  static const Color _borderFocused = Color(0xFF006571);
  static const Color _textColor = Color(0xFF1a1a1a);
  static const Color _hintColor = Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textDirection: textDirection,
      textAlign: textAlign,
      onChanged: onChanged,
      style: const TextStyle(
        color: _textColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        fontFamily: 'Cairo',
      ),
      cursorColor: _borderFocused,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: _hintColor,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFamily: 'Cairo',
        ),
        errorText: errorText,
        errorStyle: const TextStyle(
          color: Color(0xFFD32F2F),
          fontFamily: 'Cairo',
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderEnabled, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderFocused, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
      ),
    );
  }
}
