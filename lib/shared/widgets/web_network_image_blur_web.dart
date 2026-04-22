// Web-only implementation.
//
// NOTE: Flutter's analyzer marks `dart:html` as deprecated in newer SDKs.
// We intentionally use it only in a conditional import (web-only file).
// ignore_for_file: deprecated_member_use
//
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class WebNetworkImageBlurWebImpl extends StatefulWidget {
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
  State<WebNetworkImageBlurWebImpl> createState() =>
      _WebNetworkImageBlurWebImplState();
}

class _WebNetworkImageBlurWebImplState extends State<WebNetworkImageBlurWebImpl> {
  late String _viewType;
  bool _hadError = false;

  String _newViewType() =>
      'web-img-blur-${DateTime.now().microsecondsSinceEpoch}-${widget.hashCode}';

  void _registerFactoryFor(String viewType) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final img = html.ImageElement()
        ..src = widget.url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = _cssObjectFit(widget.fit)
        ..style.filter = 'blur(${widget.blurSigma}px)'
        ..style.transform = 'translateZ(0)'
        ..style.willChange = 'filter'
        ..draggable = false;

      img.onError.listen((_) {
        if (mounted) {
          setState(() => _hadError = true);
        }
      });

      return img;
    });
  }

  @override
  void initState() {
    super.initState();
    _viewType = _newViewType();
    _registerFactoryFor(_viewType);
  }

  @override
  void didUpdateWidget(covariant WebNetworkImageBlurWebImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.blurSigma != widget.blurSigma ||
        oldWidget.fit != widget.fit) {
      // HtmlElementView doesn't update the already-created DOM element when
      // widget parameters change, so we force a new viewType to refresh blur/url.
      _hadError = false;
      final next = _newViewType();
      _registerFactoryFor(next);
      setState(() => _viewType = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hadError) {
      return widget.onErrorFallback ?? const SizedBox.shrink();
    }

    // HtmlElementView will expand to parent's size.
    return HtmlElementView(viewType: _viewType);
  }
}

String _cssObjectFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'contain';
    case BoxFit.cover:
      return 'cover';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.fitHeight:
      return 'contain';
    case BoxFit.fitWidth:
      return 'contain';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
  }
}

