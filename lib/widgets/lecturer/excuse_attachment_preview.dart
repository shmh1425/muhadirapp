import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../screens/lecturer/widgets/modern_popup_dialog.dart';

class ExcuseAttachmentPreview {
  static bool isValidAttachmentUrl(String raw) {
    final value = raw.trim();
    final uri = Uri.tryParse(value);
    return value.isNotEmpty &&
        uri != null &&
        uri.isAbsolute &&
        uri.scheme.toLowerCase() == 'https';
  }

  static bool _looksLikeImageAttachment({
    required String attachmentName,
    required String attachmentUrl,
  }) {
    final lowerName = attachmentName.toLowerCase();
    final lowerUrl = attachmentUrl.toLowerCase();
    const imageExt = <String>['.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'];
    for (final ext in imageExt) {
      if (lowerName.endsWith(ext) || lowerUrl.contains(ext)) {
        return true;
      }
    }
    return false;
  }

  static bool _looksLikePdfAttachment({
    required String attachmentName,
    required String attachmentUrl,
  }) {
    final lowerName = attachmentName.toLowerCase();
    final lowerUrl = attachmentUrl.toLowerCase();
    return lowerName.endsWith('.pdf') || lowerUrl.contains('.pdf');
  }

  static Future<void> showAttachmentPreviewDialog({
    required BuildContext context,
    required String attachmentName,
    required String attachmentUrl,
    required String Function(String ar, String en) tr,
    required TextDirection textDirection,
    Color primaryColor = const Color(0xFF006571),
    String logTag = '[ExcuseAttachmentPreview]',
  }) async {
    final validUrl = isValidAttachmentUrl(attachmentUrl);
    debugPrint(
      '$logTag preview dialog open: '
      'name="$attachmentName" url="$attachmentUrl" validUrl=$validUrl',
    );
    if (!validUrl) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('رابط المرفق غير صالح.', 'Invalid attachment link.'),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
      return;
    }

    final isImage = _looksLikeImageAttachment(
      attachmentName: attachmentName,
      attachmentUrl: attachmentUrl,
    );
    final isPdf = _looksLikePdfAttachment(
      attachmentName: attachmentName,
      attachmentUrl: attachmentUrl,
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: textDirection,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ModernPopupSheet(
              title: attachmentName.isNotEmpty
                  ? attachmentName
                  : tr('معاينة المرفق', 'Attachment preview'),
              onClose: () => Navigator.of(ctx).pop(),
              accentColor: primaryColor,
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: isImage
                          ? Container(
                              color: const Color(0xFFF8FAFC),
                              child: InteractiveViewer(
                                minScale: 1,
                                maxScale: 8,
                                child: Center(
                                  child: Image.network(
                                    attachmentUrl,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        tr(
                                          'تعذر معاينة المرفق.\nيمكنك فتحه في تبويب جديد.',
                                          'Could not preview attachment.\nYou can open it in a new tab.',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : isPdf
                          ? Container(
                              color: const Color(0xFFF8FAFC),
                              child: kIsWeb
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          tr(
                                            'معاينة PDF داخل التطبيق على الويب تتطلب إعداد CORS صحيح في Firebase Storage.\nيمكنك فتح الملف في تبويب جديد.',
                                            'In-app PDF preview on Web requires proper Firebase Storage CORS configuration.\nYou can open the file in a new tab.',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            color: Color(0xFF64748B),
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    )
                                  : SfPdfViewer.network(
                                      attachmentUrl,
                                      canShowScrollHead: true,
                                      canShowScrollStatus: true,
                                      onDocumentLoaded: (_) {
                                        debugPrint(
                                          '$logTag PDF preview loaded successfully: '
                                          'url="$attachmentUrl"',
                                        );
                                      },
                                      onDocumentLoadFailed: (details) {
                                        debugPrint(
                                          '$logTag PDF preview failed: '
                                          '${details.error} (${details.description}) '
                                          'url="$attachmentUrl"',
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              tr(
                                                'تعذر معاينة المرفق.',
                                                'Could not preview attachment.',
                                              ),
                                            ),
                                            backgroundColor: const Color(
                                              0xFFD32F2F,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  tr(
                                    'هذا النوع من الملفات لا يدعم المعاينة المدمجة حالياً.\nيمكنك فتحه في تبويب جديد.',
                                    'This file type is not supported for inline preview.\nYou can open it in a new tab.',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    color: Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => _openAttachmentUrl(
                          context: context,
                          attachmentUrl: attachmentUrl,
                          tr: tr,
                          logTag: logTag,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: const BorderSide(color: Color(0xFF006571)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tr('فتح في تبويب جديد', 'Open in new tab'),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

  static Future<void> _openAttachmentUrl({
    required BuildContext context,
    required String attachmentUrl,
    required String Function(String ar, String en) tr,
    required String logTag,
  }) async {
    final raw = attachmentUrl.trim();
    debugPrint('$logTag attachment tap: rawUrl="$raw"');
    if (raw.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('لا يوجد رابط مرفق.', 'No attachment URL.')),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
      return;
    }
    if (!raw.toLowerCase().startsWith('https://')) {
      debugPrint('$logTag invalid attachment URL (must be https): $raw');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('رابط المرفق غير صالح.', 'Attachment URL is invalid.'),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.isAbsolute || uri.scheme.toLowerCase() != 'https') {
      debugPrint(
        '$logTag invalid attachment URL parse: raw="$raw", uri="$uri"',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('رابط المرفق غير صالح.', 'Attachment URL is invalid.'),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
      return;
    }
    try {
      debugPrint('$logTag opening attachment with platformDefault: $uri');
      var ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      debugPrint('$logTag launchUrl(platformDefault) result=$ok');
      if (!ok) {
        debugPrint('$logTag platformDefault failed, retry web new tab: $uri');
        ok = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
        debugPrint('$logTag launchUrl(webOnlyWindowName=_blank) result=$ok');
      }
      if (!ok) {
        debugPrint(
          '$logTag platformDefault failed, retry externalApplication: $uri',
        );
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('$logTag launchUrl(externalApplication) result=$ok');
      }
      if (!ok && context.mounted) {
        debugPrint('$logTag failed to open attachment after retries: $uri');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('تعذر فتح المرفق.', 'Could not open attachment.')),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('$logTag exception while opening attachment: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تعذر فتح المرفق.', 'Could not open attachment.')),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    }
  }
}
