import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';

import 'sesion_notifier.dart';

/// Optional public model. No credentials, purchases or chat history are stored.
class CarlitosModeloLocal extends SesionNotifier {
  static const fileName = 'qwen2.5-0.5b-instruct-q4_0.gguf';
  static const byteSize = 428730208;
  static const checksum =
      '7671c0c304e6ce5a7fc577bcb12aba01e2c155cc2efd29b2213c95b18edaf6ed';
  static const url =
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/9217f5db79a29953eb74d5343926648285ec7e67/$fileName';
  bool ready = false, downloading = false, generating = false;
  int downloaded = 0;
  String? error;
  HttpClient? _client;
  bool _cancelled = false, _disposed = false;
  File? _file;

  Future<File> _location() async {
    if (_file != null) return _file!;
    final root = await getApplicationSupportDirectory();
    final dir = await Directory('${root.path}/carlitos')
        .create(recursive: true);
    return _file = File('${dir.path}/$fileName');
  }

  Future<void> prepare() async {
    try {
      final file = await _location();
      ready = await file.exists() && await file.length() == byteSize;
    } catch (_) {
      ready = false;
    }
    notifyListeners();
  }

  Future<bool> _valid(File file) async =>
      await file.length() == byteSize &&
      (await sha256.bind(file.openRead()).first).toString() == checksum;

  Future<void> download() async {
    if (downloading || generating || _disposed) return;
    downloading = true;
    error = null;
    _cancelled = false;
    notifyListeners();
    File? partial;
    IOSink? sink;
    try {
      final target = await _location();
      partial = File('${target.path}.part');
      downloaded = await partial.exists() ? await partial.length() : 0;
      if (downloaded >= byteSize) {
        if (await _valid(partial)) {
          await partial.rename(target.path);
          ready = true;
          return;
        }
        await partial.delete();
        downloaded = 0;
      }
      _client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
      final request = await _client!.getUrl(Uri.parse(url));
      if (downloaded > 0) request.headers.set('Range', 'bytes=$downloaded-');
      final response = await request.close();
      if (response.statusCode == 200) {
        downloaded = 0;
      } else if (response.statusCode != 206 ||
          response.headers
                  .value('content-range')
                  ?.startsWith('bytes $downloaded-') !=
              true) {
        throw const HttpException(
          'No se pudo descargar el modelo. Reintenta con Internet.',
        );
      }
      sink = partial.openWrite(
        mode: downloaded == 0 ? FileMode.write : FileMode.append,
      );
      var lastNotice = DateTime.now();
      await for (final chunk in response.timeout(const Duration(seconds: 45))) {
        if (_cancelled || _disposed) {
          throw const HttpException('Descarga pausada.');
        }
        downloaded += chunk.length;
        if (downloaded > byteSize) {
          throw const FormatException('Tamaño de modelo inesperado.');
        }
        sink.add(chunk);
        // Bound memory while receiving a large model on a phone.
        await sink.flush();
        if (DateTime.now().difference(lastNotice).inMilliseconds > 250) {
          lastNotice = DateTime.now();
          notifyListeners();
        }
      }
      await sink.close();
      sink = null;
      if (!await _valid(partial)) {
        await partial.delete();
        throw const FormatException(
          'La descarga está incompleta o dañada. Vuelve a descargarla.',
        );
      }
      await partial.rename(target.path);
      ready = true;
    } catch (e) {
      error = _cancelled
          ? 'Descarga pausada. Puedes reanudarla.'
          : e.toString();
    } finally {
      await sink?.close();
      _client?.close(force: true);
      _client = null;
      downloading = false;
      notifyListeners();
    }
  }

  void pause() {
    _cancelled = true;
    _client?.close(force: true);
  }

  Future<void> remove() async {
    if (downloading || generating) return;
    final file = await _location();
    if (await file.exists()) await file.delete();
    final partial = File('${file.path}.part');
    if (await partial.exists()) await partial.delete();
    ready = false;
    downloaded = 0;
    error = null;
    notifyListeners();
  }

  Future<String?> answer(String question) async {
    if (generating || downloading || _disposed) return null;
    await prepare();
    if (!ready) return null;
    generating = true;
    error = null;
    notifyListeners();
    LlamaEngine? engine;
    try {
      final file = await _location();
      if (!await _valid(file)) {
        ready = false;
        throw const FormatException(
          'Modelo dañado. Elimínalo y vuelve a descargarlo.',
        );
      }
      engine = await LlamaEngine.load(
        LlamaModel(ModelSource.path(file.path)),
        params: const ModelParams(
          contextSize: 1024,
          device: ComputeDevice.cpu,
          gpuLayers: 0,
          numberOfThreads: 2,
          numberOfThreadsBatch: 2,
        ),
      );
      if (_disposed) return null;
      final text = await engine.create([
        const LlamaChatMessage.fromText(
          role: LlamaChatRole.system,
          text:
              'Eres Carlitos, un asistente de moda. Responde en español, en dos frases sencillas. '
              'Puedes dar consejos de colores y combinaciones. No conoces productos, precios, stock, '
              'personas ni pedidos de la tienda. No inventes esos datos. No puedes realizar compras. '
              'Si preguntan por esos datos, pide consultar el catálogo guardado.',
        ),
        LlamaChatMessage.fromText(
          role: LlamaChatRole.user,
          text: question.substring(0, question.length.clamp(0, 500)),
        ),
      ], params: const GenerationParams(maxTokens: 120, temp: 0.3)).text();
      return _disposed || text.trim().isEmpty ? null : text.trim();
    } catch (_) {
      error ??= 'No se pudo ejecutar el modelo en este dispositivo. La búsqueda local sigue disponible.';
      return null;
    } finally {
      await engine?.dispose();
      generating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    pause();
    super.dispose();
  }
}
