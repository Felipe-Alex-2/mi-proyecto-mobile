import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Shared catalog imagery, including images stored as data URLs by the API.
class ProductPhoto extends StatefulWidget {
  final String? url;
  final BoxFit fit;
  const ProductPhoto({super.key, this.url, this.fit = BoxFit.cover});

  @override
  State<ProductPhoto> createState() => _ProductPhotoState();
}

class _ProductPhotoState extends State<ProductPhoto> {
  Uint8List? _bytes;

  void _decodeDataUrl() {
    _bytes = null;
    if (widget.url?.startsWith('data:image') ?? false) {
      try {
        _bytes = base64Decode(widget.url!.split(',').last);
      } catch (_) {
        // Invalid catalog data uses the same fallback as failed downloads.
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _decodeDataUrl();
  }

  @override
  void didUpdateWidget(ProductPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _decodeDataUrl();
  }

  @override
  Widget build(BuildContext context) {
    Widget fallback() => const ColoredBox(
      color: AppTheme.cream,
      child: Center(
        child: Icon(
          Icons.checkroom_outlined,
          size: 48,
          color: AppTheme.terracottaLight,
        ),
      ),
    );
    final url = widget.url;
    if (url == null || url.isEmpty) return fallback();
    if (url.startsWith('data:image') && _bytes == null) return fallback();
    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                  .ceil()
                  .clamp(1, 1600)
            : 1600;
        if (_bytes != null) {
          return Image.memory(
            _bytes!,
            fit: widget.fit,
            cacheWidth: cacheWidth,
            errorBuilder: (_, _, _) => fallback(),
          );
        }
        return Image.network(
          url,
          fit: widget.fit,
          cacheWidth: cacheWidth,
          errorBuilder: (_, _, _) => fallback(),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : fallback(),
        );
      },
    );
  }
}
