import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student/home_screen.dart';
import 'lecturer/lecturer_main_shell.dart';
import 'lecturer/lecturer_profile_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'female_security/accepted_screen.dart';
import '../services/admin/admin_auth_service.dart';
import '../services/student_auth_service.dart';
import '../services/lecturer_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _agreeToTerms = false;
  _UserRole _selectedRole = _UserRole.lecturer;
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
    final needsPassword =
        _selectedRole == _UserRole.student ||
        _selectedRole == _UserRole.admin ||
        _selectedRole == _UserRole.lecturer;

    setState(() {
      _emailError = hasEmail ? null : 'اكتب ايميل';
      _termsError = !hasTerms;
    });

    if (!hasEmail || !hasTerms) {
      return;
    }

    if (needsPassword && password.isEmpty) {
      setState(() => _emailError = 'أدخل كلمة المرور');
      return;
    }

    if (_selectedRole == _UserRole.student) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (!mounted) return;
        // جلب بيانات الطالب من Firestore للعرض في الإعدادات
        final student = await StudentAuthService.instance
            .verifyEmailAndGetStudent(email);
        if (!mounted) return;

        if (student == null) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _emailError = 'الحساب ليس طالباً أو الدور غير صحيح';
          });
          return;
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
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
        debugPrint('Firestore error [${e.code}]: ${e.message}');
        final message = switch (e.code) {
          'permission-denied' =>
            'لا توجد صلاحية لقراءة البيانات (Firestore Rules).',
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
    } else if (_selectedRole == _UserRole.admin) {
      setState(() => _isLoading = true);
      try {
        final isAdmin = await AdminAuthService.instance.signInAndVerifyAdmin(
          email: email,
          password: password,
        );
        if (!mounted) return;

        if (!isAdmin) {
          setState(() {
            _isLoading = false;
            _emailError = 'هذا الحساب ليس لديه صلاحية أدمن';
          });
          return;
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        final message = switch (e.code) {
          'user-not-found' => 'لا يوجد حساب بهذا الإيميل',
          'wrong-password' => 'كلمة المرور غير صحيحة',
          'invalid-email' => 'صيغة الإيميل غير صحيحة',
          'invalid-credential' => 'الإيميل أو كلمة المرور غير صحيحة',
          'network-request-failed' =>
            'تعذر الاتصال بالإنترنت. تأكد من الشبكة وحاول مرة أخرى.',
          'keychain-error' =>
            'تعذر الوصول إلى Keychain على macOS. أعد تشغيل التطبيق واسمح بالصلاحية.',
          _ => e.message ?? 'فشل تسجيل دخول الأدمن',
        };
        setState(() {
          _isLoading = false;
          _emailError = message;
        });
      } on FirebaseException catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _emailError = 'فشل التحقق من صلاحيات الأدمن (${e.code})';
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _emailError = 'حدث خطأ غير متوقع، حاول مرة أخرى';
        });
      }
    } else if (_selectedRole == _UserRole.security) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AcceptedScreen()),
      );
    } else if (_selectedRole == _UserRole.lecturer) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (!mounted) return;
        // جلب بيانات المحاضر من Firestore والتحقق من الدور
        final lecturer = await LecturerAuthService.instance
            .verifyEmailAndGetLecturer(email);
        if (!mounted) return;

        if (lecturer == null) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _emailError = 'الحساب ليس محاضراً أو الدور غير صحيح';
          });
          return;
        }

        final displayName = lecturer.nameAr.trim().isNotEmpty
            ? lecturer.nameAr
            : lecturer.nameEn;
        final profile = LecturerProfile(
          name: displayName.isNotEmpty ? displayName : 'محاضر',
          email: lecturer.email,
          college: lecturer.college,
          department: lecturer.department,
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                LecturerMainShell(initialIndex: 2, profile: profile),
          ),
        );
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
        debugPrint('Lecturer Firestore error [${e.code}]: ${e.message}');
        final message = switch (e.code) {
          'permission-denied' =>
            'لا توجد صلاحية لقراءة البيانات (Firestore Rules).',
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
        debugPrint('Unknown lecturer login error: $e');
        setState(() {
          _isLoading = false;
          _emailError = 'حدث خطأ غير متوقع، حاول مرة أخرى';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsPassword =
        _selectedRole == _UserRole.student ||
        _selectedRole == _UserRole.admin ||
        _selectedRole == _UserRole.lecturer;

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
                          color: Colors.white.withValues(alpha: 0.9),
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
                                label: 'طالب/ـة',
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
                                label: 'الأدمن',
                                isActive: _selectedRole == _UserRole.admin,
                                onTap: () {
                                  setState(() {
                                    _selectedRole = _UserRole.admin;
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
                    if (needsPassword) ...[
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
                          child: const Text(
                            'نسيت كلمة المرور؟',
                            style: TextStyle(
                              color: Color(0xFF444444),
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ),
                    ],
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
                              : const Text(
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

enum _UserRole { lecturer, student, admin, security }

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
    return TextField(
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
