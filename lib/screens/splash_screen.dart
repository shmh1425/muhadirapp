import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth/firebase_auth_bootstrap.dart';
import '../services/auth/session_restore_service.dart';
import 'lecturer/lecturer_main_shell.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final branding = Future<void>.delayed(const Duration(milliseconds: 600));
    await FirebaseAuthBootstrap.waitForInitialAuth();
    final user = FirebaseAuth.instance.currentUser;

    Widget? destination;
    if (FirebaseAuthBootstrap.isAppUserSession(user)) {
      destination = await SessionRestoreService.instance
          .buildHomeForSignedInUser(user!);
    }

    await branding;
    if (!mounted) return;

    if (destination != null) {
      final screen = destination;
      if (screen is LecturerMainShell) {
        SessionRestoreService.instance.scheduleLecturerWarmup(context);
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => screen),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Image(
            image: AssetImage('assets/images/logo.jpg'),
            width: 180,
            height: 180,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
