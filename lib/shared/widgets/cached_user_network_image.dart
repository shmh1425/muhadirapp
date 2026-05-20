import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Default placeholder while a profile image is fetched (first load).
class UserProfileImagePlaceholder extends StatelessWidget {
  const UserProfileImagePlaceholder({
    super.key,
    this.iconSize = 34,
    this.backgroundColor = const Color(0xFFF1F3F4),
    this.iconColor = const Color(0xFF9AA0A6),
    this.progressSize = 18,
    this.progressStrokeWidth = 2,
    this.progressColor,
  });

  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;
  final double progressSize;
  final double progressStrokeWidth;
  final Color? progressColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Center(
        child: SizedBox(
          width: progressSize,
          height: progressSize,
          child: CircularProgressIndicator(
            strokeWidth: progressStrokeWidth,
            color: progressColor ?? iconColor.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

/// Shown when the URL is empty or loading failed.
class UserProfileImageFallback extends StatelessWidget {
  const UserProfileImageFallback({
    super.key,
    this.iconSize = 34,
    this.backgroundColor = const Color(0xFFF1F3F4),
    this.iconColor = const Color(0xFF9AA0A6),
    this.icon = Icons.person,
  });

  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Center(
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }
}

/// Disk-backed network image for user profile photos (Firebase Storage URLs).
///
/// Offline: reads the file from [DefaultCacheManager] first (no HTTP).
class CachedUserNetworkImage extends StatefulWidget {
  const CachedUserNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 180),
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;

  @override
  State<CachedUserNetworkImage> createState() => _CachedUserNetworkImageState();
}

class _CachedUserNetworkImageState extends State<CachedUserNetworkImage> {
  static final CacheManager _cacheManager = DefaultCacheManager();

  File? _diskFile;
  bool _diskLookupDone = false;

  @override
  void initState() {
    super.initState();
    _loadFromDisk();
  }

  @override
  void didUpdateWidget(covariant CachedUserNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _diskFile = null;
      _diskLookupDone = false;
      _loadFromDisk();
    }
  }

  Future<void> _loadFromDisk() async {
    final key = widget.imageUrl.trim();
    if (key.isEmpty) {
      if (mounted) setState(() => _diskLookupDone = true);
      return;
    }
    try {
      final info = await _cacheManager.getFileFromCache(key);
      if (!mounted) return;
      setState(() {
        _diskFile = info?.file;
        _diskLookupDone = true;
      });
    } catch (_) {
      if (mounted) setState(() => _diskLookupDone = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.imageUrl.trim();
    if (trimmed.isEmpty) {
      return widget.errorWidget ??
          UserProfileImageFallback(
            iconSize: _fallbackIconSize(context),
          );
    }

    if (!kIsWeb) {
      final disk = _diskFile;
      if (disk != null && disk.existsSync()) {
        return Image.file(
          disk,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          errorBuilder: (_, __, ___) => _networkOrFallback(trimmed),
        );
      }
    }

    if (!_diskLookupDone) {
      return widget.placeholder ??
          UserProfileImagePlaceholder(
            progressSize: _progressSize(context),
          );
    }

    return _networkOrFallback(trimmed);
  }

  Widget _networkOrFallback(String url) {
    final memSize = _memoryCacheSize(context);

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: url,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      memCacheWidth: memSize?.$1,
      memCacheHeight: memSize?.$2,
      fadeInDuration: widget.fadeInDuration,
      fadeOutDuration: Duration.zero,
      placeholder: (context, _) =>
          widget.placeholder ??
          UserProfileImagePlaceholder(
            progressSize: _progressSize(context),
          ),
      errorWidget: (context, _, error) {
        if (kDebugMode) {
          debugPrint('[CachedUserNetworkImage] failed url=$url error=$error');
        }
        return widget.errorWidget ??
            UserProfileImageFallback(
              iconSize: _fallbackIconSize(context),
            );
      },
    );
  }

  (int, int)? _memoryCacheSize(BuildContext context) {
    if (widget.width == null || widget.height == null) return null;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return (
      (widget.width! * ratio).round(),
      (widget.height! * ratio).round(),
    );
  }

  double _fallbackIconSize(BuildContext context) {
    final side = widget.width ?? widget.height;
    if (side == null) return 34;
    return (side * 0.42).clamp(22.0, 40.0);
  }

  double _progressSize(BuildContext context) {
    final side = widget.width ?? widget.height;
    if (side == null) return 18;
    return (side * 0.36).clamp(18.0, 28.0);
  }
}

/// For [CircleAvatar.foregroundImage] / [DecorationImage].
ImageProvider<Object>? cachedUserImageProvider(String? imageUrl) {
  final trimmed = imageUrl?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return CachedNetworkImageProvider(trimmed, cacheKey: trimmed);
}
