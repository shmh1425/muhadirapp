import 'package:flutter/material.dart';

import 'cached_user_network_image.dart';

/// Stub implementation (non-web).
class WebNetworkImageBlurWebImpl extends StatelessWidget {
  const WebNetworkImageBlurWebImpl({
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
    return CachedUserNetworkImage(
      imageUrl: url,
      fit: fit,
      errorWidget: onErrorFallback ?? const SizedBox.shrink(),
    );
  }
}

