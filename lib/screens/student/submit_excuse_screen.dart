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
import 'home_screen.dart';
import 'settings_screen.dart';
import '../../services/student_auth_service.dart';
import '../../services/excuse/excuse_service.dart';
import '../../models/excuse/excuse_request.dart';

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

  Future<bool> _ensureFirebaseSignedIn() async {
    try {
      if (FirebaseAuth.instance.currentUser != null) return true;
      await FirebaseAuth.instance.signInAnonymously();
      return FirebaseAuth.instance.currentUser != null;
    } on FirebaseAuthException catch (e) {
      debugPrint('[SubmitExcuse] FirebaseAuthException: code=${e.code} message=${e.message}');
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
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const Text(
                    'اختر نوع المرفق',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.image, color: Color(0xFF006571)),
                    title: const Text('صورة من المعرض'),
                    onTap: () => Navigator.of(context).pop('gallery'),
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.picture_as_pdf, color: Color(0xFF006571)),
                    title: const Text('ملف PDF'),
                    onTap: () => Navigator.of(context).pop('pdf'),
                  ),
                  const SizedBox(height: 6),
                ],
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
      final file =
          (res != null && res.files.isNotEmpty) ? res.files.first : null;
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
    final parts = t.split('-').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length == 2) return parts;
    return <String>['', ''];
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: const Color(0xFFB71C1C),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final student = StudentAuthService.instance.currentStudent;
    final studentId = student?.studentId ?? 0;
    if (studentId <= 0) {
      _showError('سجّل دخولك أولاً لإرسال العذر.');
      return;
    }
    if (widget.sectionId.trim().isEmpty) {
      _showError('تعذر تحديد الشعبة. حاول مرة أخرى.');
      return;
    }

    final reason = _textController.text.trim();
    final times = _parseTimeRange(widget.timeRange);
    final start = times[0];
    final end = times[1];
    if (start.isEmpty || end.isEmpty) {
      _showError('وقت المحاضرة غير مكتمل. حاول مرة أخرى.');
      return;
    }
    if (reason.isEmpty && (_selectedFileBytes == null || _selectedFileBytes!.isEmpty)) {
      _showError('أضف نص أو أرفق ملف قبل الإرسال.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final signedIn = await _ensureFirebaseSignedIn();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('[SubmitExcuse] firebaseAuth signedIn=$signedIn uid=$uid');
      if (!signedIn) {
        _showError('تعذر تفعيل صلاحيات الإرسال. فعّل Anonymous Auth في Firebase ثم جرّب.');
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
        debugPrint('[SubmitExcuse] uploading attachment path=$storagePath bytes=${_selectedFileBytes!.length}');
        try {
          await ref.putData(_selectedFileBytes!).timeout(const Duration(seconds: 30));
          attachmentUrl = await ref.getDownloadURL().timeout(const Duration(seconds: 15));
          debugPrint('[SubmitExcuse] attachment uploaded url=${attachmentUrl?.substring(0, 32)}...');
        } on FirebaseException catch (e) {
          debugPrint('[SubmitExcuse] Storage FirebaseException: code=${e.code} message=${e.message}');
          rethrow;
        }
      }

      final requestId = FirebaseFirestore.instance
          .collection(ExcuseService.excusesCollection)
          .doc()
          .id;

      final studentDisplayName = (student?.nameAr ?? '').trim().isNotEmpty
          ? (student!.nameAr).trim()
          : (student?.name ?? '').trim();

      final request = ExcuseRequest(
        id: requestId,
        studentId: studentId,
        sectionId: widget.sectionId,
        courseNameAr: (widget.course ?? '').trim(),
        lectureDate: DateTime(widget.lectureDate.year, widget.lectureDate.month, widget.lectureDate.day),
        lectureStartTime: start,
        lectureEndTime: end,
        status: ExcuseRequestStatus.pending,
        reasonText: reason.isEmpty ? null : reason,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        sessionId: widget.sessionId.trim().isEmpty ? null : widget.sessionId.trim(),
        attendanceRecordId: widget.attendanceRecordId.trim().isEmpty
            ? null
            : widget.attendanceRecordId.trim(),
        studentName:
            studentDisplayName.trim().isEmpty ? null : studentDisplayName.trim(),
      );

      debugPrint('[SubmitExcuse] submitting request id=$requestId sectionId=${widget.sectionId} sessionId=${widget.sessionId} recordId=${widget.attendanceRecordId}');
      await ExcuseService.instance.submitRequestAndNotifyLecturer(
        request: request,
        studentDisplayName: studentDisplayName.isEmpty ? studentId.toString() : studentDisplayName,
      );

      if (!mounted) return;
      _showSuccessDialog();
    } on FirebaseException catch (e) {
      final msg = (e.message ?? '').trim();
      final code = e.code.trim();
      _showError(
        msg.isNotEmpty
            ? 'فشل إرسال العذر: $msg'
            : 'فشل إرسال العذر: $code',
      );
      debugPrint('[SubmitExcuse] FirebaseException: code=$code message=${e.message}');
    } on TimeoutException {
      _showError('العملية أخذت وقت طويل. تأكد من الإنترنت وحاول مرة ثانية.');
    } catch (_) {
      _showError('فشل إرسال العذر. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey.shade400,
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
                  const Text(
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(3.14159),
              child: const Icon(
                Icons.arrow_back_ios,
                color: Color(0xFF006571),
                size: 16,
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Text(
              'رفع عذر',
              textAlign: TextAlign.center,
              style: TextStyle(
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                widget.course ?? 'جودة البرمجيات',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 4),
              Text(
                widget.dateText ?? 'الأربعاء, 14 مايو',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
          Text(
            widget.timeRange ?? '08:50-08:00',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          'إضافة ملف',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            height: 120,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
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
                      Text(
                        _selectedFileName ?? 'ملف مرفق',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF006571),
                        ),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.cloud_upload_outlined,
                        color: Color(0xFF616161),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          'إضافة نص',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _textController,
            maxLines: null,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '...',
              hintStyle: TextStyle(
                color: Color(0xFF9E9E9E),
              ),
            ),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A1A1A),
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
          colors: <Color>[
            Color(0xFF27A2A9),
            Color(0xFF006571),
          ],
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
            : const Text(
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
