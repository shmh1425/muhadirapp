import 'package:flutter/material.dart';

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
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return onErrorFallback ?? const SizedBox.shrink();
      },
    );
  }
}

