import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, {this.statusCode = 500});

  @override
  String toString() => message;
}

class ApiService {
  final StorageService _storageService;

  final http.Client _client;
  final Duration requestTimeout;
  final Duration uploadTimeout;

  ApiService(
    this._storageService, {
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 30),
    this.uploadTimeout = const Duration(minutes: 5),
  }) : _client = client ?? http.Client();

  void dispose() => _client.close();

  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _storageService.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> get(String endpoint, {bool includeAuth = true}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);

    try {
      final response = await _client
          .get(url, headers: headers)
          .timeout(requestTimeout);
      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        statusCode: 408,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);

    try {
      final response = await _client
          .post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(requestTimeout);
      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        statusCode: 408,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);

    try {
      final response = await _client
          .put(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(requestTimeout);
      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        statusCode: 408,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
  }

  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);

    try {
      final response = await _client
          .patch(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(requestTimeout);
      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        statusCode: 408,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);

    try {
      final response = await _client
          .delete(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(requestTimeout);
      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        statusCode: 408,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
  }

  /// Envía un request multipart/form-data (para subir archivos al backend).
  ///
  /// [endpoint] - path del endpoint (ej. '/virtual-fitting/idm-tryon')
  /// [fileFields] - mapa de nombre_campo -> {bytes, filename, contentType}
  /// [formFields] - mapa de nombre_campo -> valor string
  Future<dynamic> postMultipart(
    String endpoint, {
    required Map<String, Map<String, dynamic>> fileFields,
    Map<String, String>? formFields,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final request = http.MultipartRequest('POST', url);

    if (includeAuth) {
      final token = await _storageService.getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }

    // Agregar campos de archivo
    for (final entry in fileFields.entries) {
      final fieldName = entry.key;
      final fileData = entry.value;
      final bytes = fileData['bytes'] as List<int>;
      final filename = fileData['filename'] as String;
      final contentType = fileData['contentType'] as String? ?? 'image/jpeg';

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
          contentType: _mediaType(contentType),
        ),
      );
    }

    // Agregar campos de formulario
    if (formFields != null) {
      request.fields.addAll(formFields);
    }

    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(uploadTimeout);
      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        statusCode: 408,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
  }

  MediaType _mediaType(String contentType) {
    final parts = contentType.split('/');
    return MediaType(parts[0], parts.length > 1 ? parts[1] : 'octet-stream');
  }

  dynamic _processResponse(http.Response response) {
    dynamic decodedBody;
    try {
      decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decodedBody = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    String errorMessage = 'Ocurrió un error inesperado';
    if (decodedBody is Map) {
      if (decodedBody.containsKey('errors') &&
          decodedBody['errors'] is List &&
          (decodedBody['errors'] as List).isNotEmpty) {
        final errList = decodedBody['errors'] as List;
        final formatted = errList
            .map((e) {
              if (e is Map) {
                final f = e['field_label'] ?? e['field'] ?? '';
                final m = e['message'] ?? '';
                return f.toString().isNotEmpty ? '• $f: $m' : '• $m';
              }
              return '• ${e.toString()}';
            })
            .join('\n');
        errorMessage = 'Errores de validación:\n$formatted';
      } else if (decodedBody.containsKey('detail')) {
        final detail = decodedBody['detail'];
        if (detail is String) {
          errorMessage = detail;
        } else if (detail is List && detail.isNotEmpty) {
          final formatted = detail
              .map((e) {
                if (e is Map) {
                  final loc =
                      (e['loc'] as List?)
                          ?.where((l) => l != 'body')
                          .join(' -> ') ??
                      '';
                  final m = e['msg'] ?? '';
                  return loc.isNotEmpty ? '• $loc: $m' : '• $m';
                }
                return '• ${e.toString()}';
              })
              .join('\n');
          errorMessage = 'Datos inválidos:\n$formatted';
        }
      } else if (decodedBody.containsKey('message')) {
        errorMessage = decodedBody['message'];
      }
    }

    throw ApiException(errorMessage, statusCode: response.statusCode);
  }
}
