import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_settings.dart';
import '../../services/student_auth_service.dart';
import '../../models/external_student.dart';

class StudentCardPage extends StatelessWidget {
  const StudentCardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final student = StudentAuthService.instance.currentStudent;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // ⛔ يمنع السهم الافتراضي من اليسار
        title: const Text(
          'بطاقة الطالب',
          style: TextStyle(
            color: Color(0xFF00525D),
            fontWeight: FontWeight.bold,
            fontSize: 22,
            fontFamily: 'Cairo',
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.black87),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: double.infinity, // 👈 يخلي المحتوى يتمدد لطول الشاشة
          ),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStudentCard(student),
                const SizedBox(height: 20),
                _buildElectronicWalletSection(context, student),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(ExternalStudent? student) {
    final nameAr = student?.nameAr ?? '';
    final nameEn = student?.name ?? '';
    final studentId = student?.studentId?.toString() ?? '-';
    final major = student?.major ?? 'هندسة البرمجيات';
    final majorEn = student?.major ?? 'Software Engineering';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: const Color(0x3F000000),
            blurRadius: 0,
            offset: const Offset(0, 4),
            spreadRadius: -24,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 👇 Row مع اتجاه RTL عشان الصورة يمين والمعلومات يسار
          Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: AppSettings.instance.blurProfileImage,
                  builder: (context, isBlurred, child) {
                    return Container(
                      width: 45,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF006571),
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: isBlurred ? 6 : 0,
                            sigmaY: isBlurred ? 6 : 0,
                          ),
                          child: Image.asset(
                            "assets/images/avatar.png",
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        nameAr.isNotEmpty ? nameAr : nameEn,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nameEn.isNotEmpty ? nameEn : nameAr,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'رقم الطالب : $studentId',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.82),
                          fontSize: 14,
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // المعلومات السفلية معكوسة: العربي يمين والإنجليزي يسار
          Row(
            children: [
              Expanded(
                child: Text(
                  'Faculty: College of Computers\nDepartment: $majorEn\nMajor: $majorEn',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.88),
                    fontSize: 12,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'الكلية: كلية الحاسبات\nقسم $major\nالتخصص: $major',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.88),
                    fontSize: 12,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w500,
                    height: 1.70,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Issue Date: 05/2025 - تاريخ الإصدار',
              style: TextStyle(
                color: Colors.black.withOpacity(0.88),
                fontSize: 12,
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElectronicWalletSection(BuildContext context, ExternalStudent? student) {
    final nameAr = student?.nameAr ?? '-';
    final nameEn = student?.name ?? '-';
    final studentId = student?.studentId?.toString() ?? '-';
    final email = student?.email ?? '-';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF006571),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(16),
                  topLeft: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'المحفظة الإلكترونية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildWalletRow(context, 'الاسم', nameAr),
          _buildWalletRow(context, 'الاسم بالإنجليزي', nameEn, valueLtr: true),
          _buildWalletRow(context, 'رقم الطالب', studentId, valueLtr: true),
          _buildWalletRow(context, 'البريد الإلكتروني', email, valueLtr: true),
        ],
      ),
    );
  }

  Widget _buildWalletRow(BuildContext context, String label, String value, {bool valueLtr = false}) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 4),
                  valueLtr
                      ? Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            value,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        )
                      : Text(
                          value,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Cairo',
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Directionality(
                      textDirection: TextDirection.rtl,
                      child: const Text(
                        'تم النسخ',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    backgroundColor: const Color(0xFF006571),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: const Color(0xFF006571).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.copy,
                  size: 18,
                  color: Color(0xFF006571),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
