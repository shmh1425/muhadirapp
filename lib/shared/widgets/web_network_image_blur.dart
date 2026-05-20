import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'cached_user_network_image.dart';
import 'web_network_image_blur_stub.dart'
    if (dart.library.html) 'web_network_image_blur_web.dart';

/// Cross-platform blurred network image.
///
/// - On web: uses an `<img>` element + CSS `filter: blur(...)` (works even when
///   Canvas loading is blocked by CORS).
/// - On mobile/desktop: falls back to Flutter `Image.network` (no blur here;
///   blur should be applied by parent via `ImageFiltered`).
class WebNetworkImageBlur extends StatelessWidget {
  const WebNetworkImageBlur({
    super.key,
    required this.url,
    required this.blurSigma,
    this.fit = BoxFit.cover,
    this.onErrorFallback,
  });

  final String url;
  final double blurSigma;
  final BoxFit fit;
  final Widget? onErrorFallback;

  @override
  Widget build(BuildContext context) {
    // If not web, or blur is off, just use default image.
    if (!kIsWeb || blurSigma <= 0) {
      return CachedUserNetworkImage(
        imageUrl: url,
        fit: fit,
        errorWidget: onErrorFallback ?? const SizedBox.shrink(),
      );
    }

    return WebNetworkImageBlurWebImpl(
      url: url,
      blurSigma: blurSigma,
      fit: fit,
      onErrorFallback: onErrorFallback,
    );
  }
}

