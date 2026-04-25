import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// In-app image preview or opens PDF/other files in the system browser.
class ExcuseAttachmentPreviewScreen extends StatelessWidget {
  const ExcuseAttachmentPreviewScreen({
    super.key,
    required this.url,
    this.displayName,
  });

  final String url;
  final String? displayName;

  static bool looksLikeImage(String rawUrl, String? name) {
    bool endsImage(String s) {
      final t = s.toLowerCase().trim();
      return t.endsWith('.jpg') ||
          t.endsWith('.jpeg') ||
          t.endsWith('.png') ||
          t.endsWith('.gif') ||
          t.endsWith('.webp') ||
          t.endsWith('.bmp');
    }

    final n = (name ?? '').trim();
    if (endsImage(n)) return true;
    try {
      final uri = Uri.parse(rawUrl.trim());
      final decoded = Uri.decodeComponent(uri.path).toLowerCase();
      return endsImage(decoded);
    } catch (_) {
      return false;
    }
  }

  Future<void> _openExternal(BuildContext context) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح الملف.'),
          backgroundColor: Color(0xFFB71C1C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = url.trim();
    final asImage = looksLikeImage(u, displayName);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('معاينة المرفق'),
          backgroundColor: const Color(0xFF006571),
          foregroundColor: Colors.white,
        ),
        body: asImage
            ? ColoredBox(
                color: Colors.black,
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Image.network(
                      u,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Text(
                                'تعذر عرض الصورة هنا.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => _openExternal(context),
                                child: const Text('فتح في المتصفح'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 72,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      (displayName ?? '').trim().isNotEmpty
                          ? (displayName!.trim())
                          : 'مرفق العذر',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ملفات PDF والمستندات تُعرض عادةً في نافذة المتصفح.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () => _openExternal(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF006571),
                        ),
                        child: const Text(
                          'معاينة / فتح الملف',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
