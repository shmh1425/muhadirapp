import 'package:flutter/material.dart';

import '../../features/translation/translation_controller.dart';

/// Horizontal chip row: in RTL the first [children] item is aligned to the right
/// (e.g. «الكل») without relying on [ScrollView.reverse].
class RtlStartHorizontalFilter extends StatefulWidget {
  const RtlStartHorizontalFilter({super.key, required this.children});

  final List<Widget> children;

  @override
  State<RtlStartHorizontalFilter> createState() =>
      _RtlStartHorizontalFilterState();
}

class _RtlStartHorizontalFilterState extends State<RtlStartHorizontalFilter> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _alignToLogicalStart();
  }

  @override
  void didUpdateWidget(covariant RtlStartHorizontalFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _alignToLogicalStart();
    }
  }

  void _alignToLogicalStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final isRtl =
          TranslationController.instance.textDirection == TextDirection.rtl;
      final position = _scrollController.position;
      _scrollController.jumpTo(isRtl ? position.maxScrollExtent : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRtl =
        TranslationController.instance.textDirection == TextDirection.rtl;
    final rowChildren =
        isRtl ? widget.children.reversed.toList() : widget.children;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: rowChildren),
      ),
    );
  }
}
