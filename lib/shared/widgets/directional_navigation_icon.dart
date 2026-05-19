import 'package:flutter/material.dart';

class DirectionalPreviousIcon extends StatelessWidget {
  const DirectionalPreviousIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      isRtl ? Icons.chevron_right : Icons.chevron_left,
      size: size,
      color: color,
    );
  }
}

class DirectionalNextIcon extends StatelessWidget {
  const DirectionalNextIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      isRtl ? Icons.chevron_left : Icons.chevron_right,
      size: size,
      color: color,
    );
  }
}
