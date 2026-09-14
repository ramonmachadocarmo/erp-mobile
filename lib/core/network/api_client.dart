import 'package:dio/dio.dart';

import '../storage/session_store.dart';
import 'api_exception.dart';
import 'unauthorized_handler.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    required SessionStore session,
    required UnauthorizedHandler unauthorized,
  }) : _session = session,
       _unauthorized = unauthorized,
       _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 15),
           headers: {'Content-Type': 'application/json'},
         ),
       ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _session.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          final path = err.requestOptions.path;
          final isPublicAuth =
              path.contains('/auth/login') || path.contains('/auth/register');
          if (err.response?.statusCode == 401 && !isPublicAuth) {
            await _session.clear();
            _unauthorized.notify();
          }
          handler.next(err);
        },
      ),
    );
  }

  final Dio _dio;
  final SessionStore _session;
  final UnauthorizedHandler _unauthorized;

  Future<Map<String, dynamic>> get(String path) async {
    final data = await _send('GET', path);
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> getList(String path) async {
    return _asList(await _send('GET', path));
  }

  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    return _asMap(await _send('POST', path, body: body));
  }

  Future<Map<String, dynamic>> put(String path, {Object? body}) async {
    return _asMap(await _send('PUT', path, body: body));
  }

  Future<void> delete(String path) async {
    await _send('DELETE', path);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    String? filePath,
    String? fileName,
    required Map<String, String> fields,
  }) async {
    try {
      final map = <String, dynamic>{...fields};
      if (filePath != null && filePath.isNotEmpty) {
        map['file'] = await MultipartFile.fromFile(filePath, filename: fileName);
      }
      final form = FormData.fromMap(map);
      final res = await _dio.post<dynamic>(
        path,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return _asMap(res.data);
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode,
        _message(e),
        isNetwork: _isNetwork(e),
      );
    }
  }

  Future<dynamic> _send(String method, String path, {Object? body}) async {
    try {
      final res = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method),
      );
      if (res.statusCode == 204) return null;
      return res.data;
    } on DioException catch (e) {
      throw ApiException(
        e.response?.statusCode,
        _message(e),
        isNetwork: _isNetwork(e),
      );
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(null, 'Resposta inválida');
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return [
        for (final e in data)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    }
    if (data is Map) {
      for (final key in ['data', 'items', 'results', 'content']) {
        if (data[key] is List) return _asList(data[key]);
      }
    }
    return [];
  }

  bool _isNetwork(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.connectionError;

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    return e.message ?? 'Erro de rede';
  }
}
