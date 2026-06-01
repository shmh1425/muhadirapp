import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/student_auth_service.dart';
import '../../models/external_student.dart';
import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';
import 'components/student_back_chevron_icon.dart';
import 'widgets/student_digital_id_card.dart';
import 'widgets/student_gate_mode_panel.dart';

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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.fromLTRB(12, 4, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: StudentBackChevronIcon(
                            color: const Color(0xFF006571),
                            size: 16,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        Expanded(
                          child: TText(
                            student?.isFemale == true
                                ? 'بطاقة الطالبة'
                                : 'بطاقة الطالب',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF00525D),
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (student != null)
                            StudentDigitalIdCard(student: student)
                          else
                            _buildMissingStudentCard(),
                          if (student != null &&
                              student.studentId > 0 &&
                              student.isFemale)
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: StudentAuthService.instance
                                  .watchCurrentStudentDoc(),
                              builder: (context, snap) {
                                final rev =
                                    (snap.data?.data()?['gateCardRev'] as num?)
                                        ?.toInt() ??
                                    int.tryParse(
                                      snap.data
                                              ?.data()?['gateCardRev']
                                              ?.toString() ??
                                          '',
                                    ) ??
                                    0;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: StudentGateModePanel(
                                    studentId: student.studentId,
                                    gateCardRev: rev,
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 20),
                          _buildElectronicWalletSection(context, student),
                        ],
                      ),
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

  Widget _buildMissingStudentCard() {
    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: TText(
          'لا توجد بيانات بطاقة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildElectronicWalletSection(
    BuildContext context,
    ExternalStudent? student,
  ) {
    final nameAr = (student?.nameAr ?? '').trim();
    final nameEn = student?.name ?? '-';
    final studentId = student?.studentId.toString() ?? '-';
    final email = student?.email ?? '-';
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
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
                      color: Colors.white.withValues(alpha: 0.2),
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
          _buildWalletRow(
            context,
            student?.isFemale == true ? 'رقم الطالبة' : 'رقم الطالب',
            studentId,
            valueLtr: true,
          ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: baseDir,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
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
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
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
                            style: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                            ),
                          )
                        : TText(
                            value,
                            textAlign: valueAlign,
                            style: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onSurface,
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
                  color: const Color(0xFF006571).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.copy,
                  size: 18,
                  color: Color(0xFF006571),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
