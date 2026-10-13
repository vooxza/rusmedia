
import 'package:dio/dio.dart';

import 'app_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.code, this.status});

  final String message;
  final String? code;
  final int? status;

  @override
  String toString() => message;
}

class HealthStatus {
  const HealthStatus({
    required this.ok,
    required this.database,
    required this.storage,
  });

  final bool ok;
  final bool database;
  final bool storage;
}

class ApiClient {
  ApiClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
                validateStatus: (_) => true,
              ),
            );

  final Dio _dio;

  String? _token;

  void setAuthToken(String? token) {
    _token = token;
  }

  Options get _authOptions => Options(
        headers: {
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      );

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return null;
  }

  ApiException _toException(Response<dynamic> response) {
    final data = _asMap(response.data);
    final error = _asMap(data?['error']);

    return ApiException(
      error?['message'] as String? ??
          'Terjadi kesalahan. Silakan coba lagi.',
      code: error?['code'] as String?,
      status: response.statusCode,
    );
  }

  Map<String, dynamic> _getResponseData(Response<dynamic> response) {
    final status = response.statusCode ?? 500;

    if (status < 200 || status >= 300) {
      throw _toException(response);
    }

    final body = _asMap(response.data);
    final data = _asMap(body?['data']);

    if (data == null) {
      throw ApiException('Format respons server tidak valid.');
    }

    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      return _getResponseData(response);
    } on DioException {
      throw ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
  }

  Future<Map<String, dynamic>> me() async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/auth/me',
        options: _authOptions,
      );

      final data = _getResponseData(response);
      final user = _asMap(data['user']);

      if (user == null) {
        throw ApiException('Data pengguna tidak valid.');
      }

      return user;
    } on DioException {
      throw ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
  }

  Future<void> logout() async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/auth/logout',
        options: _authOptions,
      );

      _getResponseData(response);
      _token = null;
    } on DioException {
      throw ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
  }

  Future<HealthStatus> health() async {
    try {
      final response = await _dio.get<dynamic>('/api/health');

      final body = _asMap(response.data);
      final checks = _asMap(body?['checks']);

      if (body != null && checks != null) {
        return HealthStatus(
          ok: body['ok'] == true,
          database: checks['database'] == true,
          storage: checks['storage'] == true,
        );
      }

      throw _toException(response);
    } on DioException {
      throw ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
  }
}
