import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../configuracion/configuracion_api.dart';
import 'almacenamiento_service.dart';
import 'sin_conexion_service.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, {this.statusCode = 500});

  @override
  String toString() => message;
}

class ApiService {
  SinConexionService? offline;
  String? activeTenantId;
  String? activeBranchId;
  Future<dynamic> get(String endpoint, {bool includeAuth = true}) =>
      offline?.owner != null && includeAuth
      ? offline!.read(
          endpoint,
          () => sendOnline('GET', endpoint, {}, includeAuth: includeAuth),
        )
      : getOnline(endpoint, includeAuth: includeAuth);
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) => _write('POST', endpoint, body, includeAuth);
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) => _write('PUT', endpoint, body, includeAuth);
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) => _write('PATCH', endpoint, body, includeAuth);
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) => _write('DELETE', endpoint, body, includeAuth);
  Future<dynamic> _write(
    String method,
    String path,
    Map<String, dynamic>? body,
    bool includeAuth,
  ) {
    if (includeAuth &&
        offline?.owner != null &&
        method == 'POST' &&
        path == '/virtual-fitting/recommend-size') {
      return offline!.read(
        'request:$path:${jsonEncode(body)}',
        () => postOnline(path, body: body),
      );
    }
    if (includeAuth &&
        offline?.owner != null &&
        SinConexionService.supports(method, path)) {
      return offline!.mutate(method, path, body ?? {});
    }
    return sendOnline(method, path, body ?? {}, includeAuth: includeAuth);
  }

  Future<dynamic> sendOnline(
    String method,
    String path,
    Map<String, dynamic> body, {
    bool includeAuth = true,
  }) async {
    try {
      return await switch (method) {
        'GET' => getOnline(path, includeAuth: includeAuth),
        'POST' => postOnline(path, body: body, includeAuth: includeAuth),
        'PUT' => putOnline(path, body: body, includeAuth: includeAuth),
        'PATCH' => patchOnline(path, body: body, includeAuth: includeAuth),
        'DELETE' => deleteOnline(path, body: body, includeAuth: includeAuth),
        _ => throw ApiException('Método no permitido', statusCode: 422),
      };
    } on ApiException catch (e) {
      if (e.statusCode != 401 || !includeAuth) rethrow;
      final refresh = await _storageService.getRefreshToken();
      if (refresh == null) rethrow;
      final tokens = await postOnline(
        '/auth/refresh',
        body: {'refresh_token': refresh},
        includeAuth: false,
      );
      await _storageService.saveTokens(
        accessToken: tokens['access_token'],
        refreshToken: tokens['refresh_token'],
      );
      return switch (method) {
        'GET' => getOnline(path),
        'POST' => postOnline(path, body: body),
        'PUT' => putOnline(path, body: body),
        'PATCH' => patchOnline(path, body: body),
        'DELETE' => deleteOnline(path, body: body),
        _ => throw ApiException('Método no permitido', statusCode: 422),
      };
    }
  }

  final AlmacenamientoService _storageService;

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
        if (activeTenantId != null && activeBranchId != null) {
          headers['X-Vesta-Tenant'] = activeTenantId!;
          headers['X-Vesta-Branch'] = activeBranchId!;
        }
      }
    }

    return headers;
  }

  Future<Uint8List> getBytes(String endpoint) async {
    final url = Uri.parse('${ConfiguracionApi.baseUrl}$endpoint');
    final headers = await _getHeaders();
    headers['Accept'] = 'application/pdf';
    final response = await _client
        .get(url, headers: headers)
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _processResponse(response);
    }
    return response.bodyBytes;
  }

  Future<dynamic> getOnline(String endpoint, {bool includeAuth = true}) async {
    final url = Uri.parse('${ConfiguracionApi.baseUrl}$endpoint');
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
        statusCode: 0,
      );
    }
  }

  Future<dynamic> postOnline(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('${ConfiguracionApi.baseUrl}$endpoint');
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
        statusCode: 0,
      );
    }
  }

  Future<dynamic> putOnline(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('${ConfiguracionApi.baseUrl}$endpoint');
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
        statusCode: 0,
      );
    }
  }

  Future<dynamic> patchOnline(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('${ConfiguracionApi.baseUrl}$endpoint');
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
        statusCode: 0,
      );
    }
  }

  Future<dynamic> deleteOnline(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    final url = Uri.parse('${ConfiguracionApi.baseUrl}$endpoint');
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
        statusCode: 0,
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
    if (offline?.offline ?? false) {
      throw ApiException(
        'El probador con IA requiere conexión. Tus resultados anteriores siguen disponibles en caché.',
        statusCode: 0,
      );
    }
    final url = Uri.parse('${ConfiguracionApi.baseUrl}$endpoint');
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
        statusCode: 0,
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
