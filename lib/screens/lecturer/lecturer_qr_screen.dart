import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'lecturer_nav_bar.dart';
import 'lecturer_home_screen.dart';

class LecturerQrScreen extends StatefulWidget {
  const LecturerQrScreen({
    super.key,
    this.lecture,
  });

  final LectureItem? lecture;

  @override
  State<LecturerQrScreen> createState() => _LecturerQrScreenState();
}

class _LecturerQrScreenState extends State<LecturerQrScreen> {
  late String _qrData;
  int _selectedIndex = 1; // QR في المنتصف

  @override
  void initState() {
    super.initState();
    _qrData = _generateNewCode();
  }

  String _generateNewCode() {
    // كود عشوائي بسيط مكوّن من 8 أرقام/حروف
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final code = List.generate(
      8,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();

    // يمكنك لاحقاً ربطه مع الـ backend (إرسال الكود مع CRN مثلاً)
    final crn = widget.lecture?.crn ?? 'CRN000';
    return '$crn-$code-${DateTime.now().millisecondsSinceEpoch}';
  }

  void _onRefreshPressed() {
    setState(() {
      _qrData = _generateNewCode();
    });
  }

  Future<void> _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شاشة البروفايل - قريباً'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 1:
        // شاشة QR الحالية
        break;
      case 2:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const LecturerHomeScreen(),
          ),
          (route) => false,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF006571);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: LecturerNavBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              // العنوان في الوسط بدون زر رجوع
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: Text(
                    'قم بإظهار ال QR للطلاب',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      height: 1.4,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // معلومات المقرر والباركود بخط أكبر ومحاذاة للجهاز
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.lecture?.courseName ?? 'اسم المقرر',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'CRN${widget.lecture?.crn ?? '000'} | ${widget.lecture?.activity ?? 'نظري'}، الشعبة ${widget.lecture?.section ?? '3'}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: (widget.lecture?.timeSlots ??
                                ['18:00 18:50', '18:00 18:50', '18:00 18:50'])
                            .map((slot) {
                          return Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFB5C3C7),
                                width: 0.9,
                              ),
                            ),
                            child: Text(
                              slot,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2E33),
                                fontFamily: 'Cairo',
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.72,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF006571),
                              width: 3,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: QrImageView(
                            data: _qrData,
                            size: MediaQuery.of(context).size.width * 0.5,
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF00474F),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Column(
                          children: [
                            GestureDetector(
                              onTap: _onRefreshPressed,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.14),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.refresh,
                                  color: primaryColor,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: 210,
                              height: 48,
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
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: TextButton(
                                  onPressed: _onRefreshPressed,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                  ),
                                  child: const Text(
                                    'تحديث الكود',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

