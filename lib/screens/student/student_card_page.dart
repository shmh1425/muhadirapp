import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/student_auth_service.dart';
import '../../models/external_student.dart';
import '../../shared/widgets/student_profile_avatar.dart';
import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';

class StudentCardPage extends StatelessWidget {
  const StudentCardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final student = StudentAuthService.instance.currentStudent;
    final translation = TranslationController.instance;
    return AnimatedBuilder(
      animation: translation,
      builder: (context, _) {
        return Directionality(
          textDirection: translation.textDirection,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: Directionality(
                // Keep back arrow on the left always.
                textDirection: TextDirection.ltr,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.black87),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              title: const TText(
                'بطاقة الطالب',
                style: TextStyle(
                  color: Color(0xFF00525D),
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  fontFamily: 'Cairo',
                ),
              ),
              centerTitle: true,
              actions: const [],
            ),
            body: SafeArea(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: double.infinity),
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
          ),
        );
      },
    );
  }

  Widget _buildStudentCard(ExternalStudent? student) {
    final nameAr = student?.nameAr ?? '';
    final nameEn = student?.name ?? '';
    final studentId = student?.studentId.toString() ?? '-';
    final departmentAr = (student?.departmentArSafe ?? '').trim();
    final departmentEn = (student?.departmentSafe ?? '').trim();
    final majorAr = (student?.majorArSafe ?? '').trim();
    final majorEn = (student?.major ?? '').trim();

    final departmentArDisplay =
        departmentAr.isNotEmpty ? departmentAr : (majorAr.isNotEmpty ? majorAr : 'هندسة البرمجيات');
    final departmentEnDisplay =
        departmentEn.isNotEmpty ? departmentEn : (majorEn.isNotEmpty ? majorEn : 'Software Engineering');
    final majorArDisplay =
        majorAr.isNotEmpty ? majorAr : (majorEn.isNotEmpty ? majorEn : 'هندسة البرمجيات');
    final majorEnDisplay =
        majorEn.isNotEmpty ? majorEn : (majorAr.isNotEmpty ? majorAr : 'Software Engineering');
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
            // Keep avatar + names on the right always (stable order).
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Keep Arabic name always Arabic (no translation).
                      Text(
                        nameAr.isNotEmpty ? nameAr : nameEn,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      // Keep English name as-is.
                      Text(
                        nameEn.isNotEmpty ? nameEn : nameAr,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      TText(
                        'رقم الطالب : $studentId',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.82),
                          fontSize: 14,
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const StudentProfileAvatar(size: 46),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Show Arabic + English info together (two columns).
          // Keep columns stable: English left, Arabic right (regardless of page RTL/LTR).
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      'Faculty: College of Computers\nDepartment: $departmentEnDisplay\nMajor: $majorEnDisplay',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.88),
                        fontSize: 12,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w500,
                        height: 1.70,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      'الكلية: كلية الحاسبات\nالقسم: $departmentArDisplay\nالتخصص: $majorArDisplay',
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
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Issue date in both languages (stable columns).
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      'Issue Date: 05/2025',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.88),
                        fontSize: 12,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      'تاريخ الإصدار: 05/2025',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.88),
                        fontSize: 12,
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElectronicWalletSection(BuildContext context, ExternalStudent? student) {
    final nameAr = (student?.nameAr ?? '').trim();
    final nameEn = student?.name ?? '-';
    final studentId = student?.studentId.toString() ?? '-';
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
            textDirection: TranslationController.instance.textDirection,
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
                  const TText(
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
          _buildWalletRow(
            context,
            'الاسم',
            nameAr.isNotEmpty ? nameAr : nameEn,
            valueForceRtl: true, // always show first name in Arabic direction
          ),
          _buildWalletRow(context, 'الاسم بالإنجليزي', nameEn, valueLtr: true),
          _buildWalletRow(context, 'رقم الطالب', studentId, valueLtr: true),
          _buildWalletRow(context, 'البريد الإلكتروني', email, valueLtr: true),
        ],
      ),
    );
  }

  Widget _buildWalletRow(
    BuildContext context,
    String label,
    String value, {
    bool valueLtr = false,
    bool valueForceRtl = false,
  }) {
    final translation = TranslationController.instance;
    final baseDir = translation.textDirection;
    final valueDir = valueForceRtl
        ? TextDirection.rtl
        : (valueLtr ? TextDirection.ltr : baseDir);
    final labelAlign = baseDir == TextDirection.ltr
        ? TextAlign.left
        : TextAlign.right;
    final valueAlign = valueDir == TextDirection.ltr
        ? TextAlign.left
        : TextAlign.right;

    return Directionality(
      textDirection: baseDir,
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
                  TText(
                    label,
                    textAlign: labelAlign,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Directionality(
                    textDirection: valueDir,
                    child: valueForceRtl
                        // Keep Arabic name visible as Arabic (no translation).
                        ? Text(
                            value,
                            textAlign: valueAlign,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                            ),
                          )
                        : TText(
                            value,
                            textAlign: valueAlign,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                            ),
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
                      child: const TText(
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
