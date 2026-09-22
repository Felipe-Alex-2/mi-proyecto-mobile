import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/theme.dart';

/// Procesador nativo de imágenes para eliminar fondos blancos/claros y generar
/// capas PNG transparentes fluidas sobre la persona en el vestidor virtual.
class GarmentTransparentProcessor {
  static final Map<String, ui.Image> _cache = {};
  static final Map<String, Uint8List> _networkBytesCache = {};

  /// Procesa los bytes crudos RGBA y convierte píxeles blancos o casi blancos a canal alfa 0
  static Future<ui.Image?> removeWhiteBackground(Uint8List imageBytes, String cacheKey) async {
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final ui.Image origImage = frame.image;

      final byteData = await origImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return origImage;

      final Uint8List pixels = Uint8List.fromList(byteData.buffer.asUint8List());
      final int len = pixels.length;

      for (int i = 0; i < len; i += 4) {
        final int r = pixels[i];
        final int g = pixels[i + 1];
        final int b = pixels[i + 2];

        // Blanco puro o casi blanco (fondos de catálogo típicos)
        if (r > 225 && g > 225 && b > 225) {
          pixels[i + 3] = 0; // Transparencia total
        } else if (r > 212 && g > 212 && b > 212 &&
                   (r - g).abs() < 12 &&
                   (g - b).abs() < 12 &&
                   (r - b).abs() < 12) {
          // Difuminado de bordes suaves claros
          final double factor = (r - 212) / 25.0;
          final int newAlpha = (pixels[i + 3] * (1.0 - factor)).clamp(0, 255).toInt();
          pixels[i + 3] = newAlpha;
        }
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        origImage.width,
        origImage.height,
        ui.PixelFormat.rgba8888,
        (ui.Image result) {
          _cache[cacheKey] = result;
          completer.complete(result);
        },
      );
      return await completer.future;
    } catch (e) {
      debugPrint('Error en GarmentTransparentProcessor: $e');
      return null;
    }
  }

  /// Limpia la memoria caché cuando sea necesario
  static void clearCache() {
    _cache.clear();
    _networkBytesCache.clear();
  }
}

/// Widget para renderizar prendas de stock garantizando formato PNG sin fondo
class TransparentGarmentWidget extends StatefulWidget {
  final String? imageUrl;
  final BoxFit fit;
  final bool removeWhiteBg;
  final double? width;
  final double? height;

  const TransparentGarmentWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.removeWhiteBg = true,
    this.width,
    this.height,
  });

  @override
  State<TransparentGarmentWidget> createState() => _TransparentGarmentWidgetState();
}

class _TransparentGarmentWidgetState extends State<TransparentGarmentWidget> {
  ui.Image? _processedImage;
  String? _lastLoadedUrl;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(TransparentGarmentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || oldWidget.removeWhiteBg != widget.removeWhiteBg) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty || !widget.removeWhiteBg) {
      if (mounted) setState(() => _processedImage = null);
      return;
    }

    if (_lastLoadedUrl == url && _processedImage != null) return;
    _lastLoadedUrl = url;

    try {
      Uint8List? rawBytes;
      String key = url.hashCode.toString();

      if (url.startsWith('data:')) {
        final b64 = url.split(',').last;
        rawBytes = base64Decode(b64);
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        if (GarmentTransparentProcessor._networkBytesCache.containsKey(url)) {
          rawBytes = GarmentTransparentProcessor._networkBytesCache[url];
        } else {
          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200) {
            rawBytes = res.bodyBytes;
            GarmentTransparentProcessor._networkBytesCache[url] = rawBytes;
          }
        }
      }

      if (rawBytes != null) {
        final processed = await GarmentTransparentProcessor.removeWhiteBackground(rawBytes, key);
        if (mounted) {
          setState(() {
            _processedImage = processed;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error cargando prenda transparente: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: Icon(Icons.checkroom_rounded, size: 80, color: AppTheme.terracotta),
        ),
      );
    }

    // 1. Si ya se procesó el PNG transparente nativo
    if (_processedImage != null) {
      return RawImage(
        image: _processedImage,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
      );
    }

    // 2. Si es data Base64
    if (url.startsWith('data:')) {
      try {
        final b64 = url.split(',').last;
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
        );
      } catch (_) {
        return _errorPlaceholder();
      }
    }

    // 3. Si es URL HTTP
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
      );
    }

    return _errorPlaceholder();
  }

  Widget _errorPlaceholder() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: Icon(Icons.checkroom_rounded, size: 80, color: AppTheme.terracotta),
      ),
    );
  }
}
