import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:typed_data';
import 'components/notification_bell.dart';
import 'components/custom_nav_bar_icons.dart';
import 'components/student_back_chevron_icon.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import '../../services/student_auth_service.dart';
import '../../services/excuse/excuse_service.dart';
import '../../services/excuse/excuse_attendance_merge.dart';
import '../../models/excuse/excuse_request.dart';
import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';

class SubmitExcuseScreen extends StatefulWidget {
  final String? course;
  final String? dateText;
  final String? timeRange;
  final String sectionId;
  final DateTime lectureDate;
  final String sessionId;
  final String attendanceRecordId;

  const SubmitExcuseScreen({
    super.key,
    this.course,
    this.dateText,
    this.timeRange,
    required this.sectionId,
    required this.lectureDate,
    required this.sessionId,
    required this.attendanceRecordId,
  });

  @override
  State<SubmitExcuseScreen> createState() => _SubmitExcuseScreenState();
}

class _SubmitExcuseScreenState extends State<SubmitExcuseScreen> {
  final TextEditingController _textController = TextEditingController();
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  bool _isSubmitting = false;

  String _en(String ar, String eng) =>
      TranslationController.instance.translateToEnglish ? eng : ar;

  bool get _english => TranslationController.instance.translateToEnglish;

  TextAlign get _textAlignStart => _english ? TextAlign.left : TextAlign.right;

  TextDirection get _fieldTextDirection =>
      _english ? TextDirection.ltr : TextDirection.rtl;

  String _displayDateLine() {
    final raw = (widget.dateText ?? '').trim();
    if (!TranslationController.instance.translateToEnglish) {
      if (raw.isNotEmpty) return raw;
      return ExcuseAttendanceMerge.formatArabicLectureDate(widget.lectureDate);
    }
    return ExcuseAttendanceMerge.formatEnglishLectureDate(widget.lectureDate);
  }

  Future<bool> _ensureFirebaseSignedIn() async {
    try {
      if (FirebaseAuth.instance.currentUser != null) return true;
      await FirebaseAuth.instance.signInAnonymously();
      return FirebaseAuth.instance.currentUser != null;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[SubmitExcuse] FirebaseAuthException: code=${e.code} message=${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('[SubmitExcuse] Auth error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final scheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        final td = TranslationController.instance.textDirection;
        return Theme(
          data: Theme.of(sheetContext),
          child: Directionality(
            textDirection: td,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Text(
                      _en('اختر نوع المرفق', 'Choose attachment type'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        fontFamily: 'Cairo',
                      ),
                      textAlign: _textAlignStart,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(
                        Icons.image,
                        color: Color(0xFF006571),
                      ),
                      title: Text(
                        _en('صورة من المعرض', 'Photo from gallery'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      onTap: () => Navigator.of(sheetContext).pop('gallery'),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.picture_as_pdf,
                        color: Color(0xFF006571),
                      ),
                      title: Text(
                        _en('ملف PDF', 'PDF file'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      onTap: () => Navigator.of(sheetContext).pop('pdf'),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'gallery') {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (!mounted || image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedFileName = image.name;
        _selectedFileBytes = bytes;
      });
      return;
    }

    if (action == 'pdf') {
      final res = await FilePicker.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: <String>['pdf'],
      );
      if (!mounted) return;
      final file = (res != null && res.files.isNotEmpty)
          ? res.files.first
          : null;
      if (file == null) return;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;
      setState(() {
        _selectedFileName = file.name;
        _selectedFileBytes = bytes;
      });
    }
  }

  List<String> _parseTimeRange(String? raw) {
    final t = (raw ?? '').trim();
    final parts = t
        .split('-')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length == 2) return parts;
    return <String>['', ''];
  }

  void _showError(String ar, String en) {
    if (!mounted) return;
    final td = TranslationController.instance.textDirection;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_en(ar, en), textDirection: td),
        backgroundColor: const Color(0xFFB71C1C),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final student = StudentAuthService.instance.currentStudent;
    final studentId = student?.studentId ?? 0;
    if (studentId <= 0) {
      _showError(
        'سجّل دخولك أولاً لإرسال العذر.',
        'Please sign in before submitting an excuse.',
      );
      return;
    }
    if (widget.sectionId.trim().isEmpty) {
      _showError(
        'تعذر تحديد الشعبة. حاول مرة أخرى.',
        'Could not determine the section. Please try again.',
      );
      return;
    }

    final reason = _textController.text.trim();
    final times = _parseTimeRange(widget.timeRange);
    final start = times[0];
    final end = times[1];
    if (start.isEmpty || end.isEmpty) {
      _showError(
        'وقت المحاضرة غير مكتمل. حاول مرة أخرى.',
        'Lecture time is incomplete. Please try again.',
      );
      return;
    }
    if (reason.isEmpty &&
        (_selectedFileBytes == null || _selectedFileBytes!.isEmpty)) {
      _showError(
        'أضف نص أو أرفق ملف قبل الإرسال.',
        'Add text or attach a file before submitting.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final signedIn = await _ensureFirebaseSignedIn();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('[SubmitExcuse] firebaseAuth signedIn=$signedIn uid=$uid');
      if (!signedIn) {
        _showError(
          'تعذر تفعيل صلاحيات الإرسال. فعّل Anonymous Auth في Firebase ثم جرّب.',
          'Could not enable upload permissions. Enable Anonymous Auth in Firebase and try again.',
        );
        return;
      }

      String? attachmentUrl;
      String? attachmentName;

      if (_selectedFileBytes != null && _selectedFileBytes!.isNotEmpty) {
        attachmentName = (_selectedFileName ?? '').trim();
        if (attachmentName.isEmpty) attachmentName = 'attachment.bin';
        final storagePath =
            'excuses/$studentId/${DateTime.now().millisecondsSinceEpoch}_$attachmentName';
        final ref = FirebaseStorage.instance.ref(storagePath);
        debugPrint(
          '[SubmitExcuse] uploading attachment path=$storagePath bytes=${_selectedFileBytes!.length}',
        );
        try {
          await ref
              .putData(_selectedFileBytes!)
              .timeout(const Duration(seconds: 30));
          attachmentUrl = await ref.getDownloadURL().timeout(
            const Duration(seconds: 15),
          );
          debugPrint(
            '[SubmitExcuse] attachment uploaded url=${attachmentUrl.substring(0, 32)}...',
          );
        } on FirebaseException catch (e) {
          debugPrint(
            '[SubmitExcuse] Storage FirebaseException: code=${e.code} message=${e.message}',
          );
          rethrow;
        }
      }

      final sessionId = widget.sessionId.trim();
      final recordId = widget.attendanceRecordId.trim();
      final String requestId = recordId.isNotEmpty
          ? recordId
          : (sessionId.isNotEmpty
                ? '${sessionId}_$studentId'
                : FirebaseFirestore.instance
                      .collection(ExcuseService.excusesCollection)
                      .doc()
                      .id);

      final studentDisplayName = (student?.nameAr ?? '').trim().isNotEmpty
          ? (student!.nameAr).trim()
          : (student?.name ?? '').trim();

      final request = ExcuseRequest(
        id: requestId,
        studentId: studentId,
        sectionId: widget.sectionId,
        courseNameAr: (widget.course ?? '').trim(),
        courseNameEn: (widget.course ?? '').trim(),
        lectureDate: DateTime(
          widget.lectureDate.year,
          widget.lectureDate.month,
          widget.lectureDate.day,
        ),
        lectureStartTime: start,
        lectureEndTime: end,
        status: ExcuseRequestStatus.pending,
        reasonText: reason.isEmpty ? null : reason,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        sessionId: sessionId.isEmpty ? null : sessionId,
        attendanceRecordId: recordId.isEmpty ? null : recordId,
        studentName: studentDisplayName.trim().isEmpty
            ? null
            : studentDisplayName.trim(),
        submittedAt: DateTime.now(),
      );

      debugPrint(
        '[SubmitExcuse] submitting request id=$requestId sectionId=${widget.sectionId} sessionId=${widget.sessionId} recordId=${widget.attendanceRecordId}',
      );
      final storedInExcuseRequests = await ExcuseService.instance
          .submitRequestAndNotifyLecturer(
            request: request,
            studentDisplayName: studentDisplayName.isEmpty
                ? studentId.toString()
                : studentDisplayName,
          );
      if (!storedInExcuseRequests) {
        _showError(
          'تم رفع الملف، لكن لم يتم حفظ بيانات العذر في قاعدة البيانات (excuse_requests). تأكد من نشر قواعد Firestore وتفعيل Anonymous Auth ثم أعد الإرسال.',
          'The file was uploaded, but the excuse document was not saved in Firestore (excuse_requests). Deploy Firestore rules and enable Anonymous Auth, then resubmit.',
        );
        return;
      }

      if (!mounted) return;
      _showSuccessDialog();
    } on StateError catch (e) {
      if (e.message == 'rejected_resubmit_window_closed') {
        _showError(
          'لا يمكن إعادة رفع العذر حالياً.',
          'This excuse can no longer be resubmitted.',
        );
        return;
      }
      if (e.message == 'pending_edit_window_closed') {
        _showError(
          'لا يمكن تعديل العذر حالياً.',
          'This excuse can no longer be edited.',
        );
        return;
      }
      rethrow;
    } on FirebaseException catch (e) {
      final msg = (e.message ?? '').trim();
      final code = e.code.trim();
      _showError(
        msg.isNotEmpty ? 'فشل إرسال العذر: $msg' : 'فشل إرسال العذر: $code',
        msg.isNotEmpty
            ? 'Failed to submit excuse: $msg'
            : 'Failed to submit excuse: $code',
      );
      debugPrint(
        '[SubmitExcuse] FirebaseException: code=$code message=${e.message}',
      );
    } on TimeoutException {
      _showError(
        'العملية أخذت وقت طويل. تأكد من الإنترنت وحاول مرة ثانية.',
        'This is taking too long. Check your internet and try again.',
      );
    } catch (_) {
      _showError(
        'فشل إرسال العذر. حاول مرة أخرى.',
        'Failed to submit excuse. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    final td = TranslationController.instance.textDirection;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Directionality(
          textDirection: td,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Close Button
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Close submit screen too (safe on web / first route)
                        Navigator.of(this.context).maybePop();
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Success Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFB2EBF2), // Light blue-green
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFF006571), // Dark teal
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Success Message
                  const TText(
                    'تم إرسال العذر بنجاح',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006571),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TranslationController.instance,
      builder: (context, _) {
        final translation = TranslationController.instance;
        return Directionality(
          textDirection: translation.textDirection,
          child: Theme(
            data: Theme.of(context),
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              bottomNavigationBar: NavBarSettingsArabic(
                selectedIndex: 1,
                onItemTapped: (index) {
                  if (index == 0) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  } else if (index == 2) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  } else if (index == 1) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
              body: SafeArea(
                child: Column(
                  children: <Widget>[
                    _buildHeader(context),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _buildDetailsCard(),
                            const SizedBox(height: 24),
                            _buildFileUploadSection(),
                            const SizedBox(height: 24),
                            _buildTextInputSection(),
                            const SizedBox(height: 32),
                            _buildSubmitButton(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final translation = TranslationController.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: StudentBackChevronIcon(color: Color(0xFF006571), size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: TText(
              translation.translateToEnglish
                  ? 'Submit Excuse Request'
                  : 'رفع عذر',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006571),
              ),
            ),
          ),
          const NotificationBell(),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TText(
                  widget.course ?? 'جودة البرمجيات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: _textAlignStart,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _displayDateLine(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: _textAlignStart,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.timeRange ?? '08:50-08:00',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TText(
          'إضافة ملف',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          textAlign: _textAlignStart,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            height: 120,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colorScheme.outlineVariant, width: 1),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _selectedFileBytes != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.description,
                        color: Color(0xFF006571),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      TText(
                        _selectedFileName ?? 'ملف مرفق',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF006571),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.cloud_upload_outlined,
                        color: colorScheme.onSurfaceVariant,
                        size: 48,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextInputSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TText(
          'إضافة نص',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          textAlign: _textAlignStart,
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant, width: 1),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _textController,
            maxLines: null,
            cursorColor: const Color(0xFF006571),
            textAlign: _textAlignStart,
            textDirection: _fieldTextDirection,
            decoration: InputDecoration(
              border: InputBorder.none,
              alignLabelWithHint: true,
              hintText: _english
                  ? 'Type your excuse here…'
                  : 'اكتب نص العذر هنا...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'Cairo',
              ),
            ),
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF27A2A9), Color(0xFF006571)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const TText(
                'إرسال',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
