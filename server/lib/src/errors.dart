import 'dart:convert';

import 'package:shelf/shelf.dart';

enum ErrorCode {
  unauthenticated(401, 'Silakan login terlebih dahulu.'),
  forbidden(403, 'Anda tidak memiliki akses untuk melakukan ini.'),
  notFound(404, 'Dokumentasi tidak ditemukan.'),
  validation(400, 'Data yang dikirim tidak valid.'),
  fileTooLarge(413, 'File terlalu besar.'),
  unsupportedFormat(415, 'Format file tidak didukung.'),
  uploadFailed(500, 'Upload gagal. Silakan coba lagi.'),
  rateLimited(429, 'Terlalu banyak percobaan. Coba lagi sebentar lagi.'),
  internal(500, 'Terjadi kesalahan. Silakan coba lagi.');

  const ErrorCode(this.status, this.message);
  final int status;
  final String message;
}

/// Errors that are safe to show to users: the message is Indonesian and never technical.
class AppError implements Exception {
  AppError(this.code, {String? message, this.fields})
      : message = message ?? code.message;

  final ErrorCode code;
  final String message;
  final Map<String, String>? fields;
}

Response errorResponse(AppError e) => Response(
      e.code.status,
      body: jsonEncode({
        'error': {
          'code': e.code.name,
          'message': e.message,
          if (e.fields != null) 'fields': e.fields,
        },
      }),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Turns anything thrown by a handler into a safe JSON response. Raw errors are logged, never returned.
Middleware errorMiddleware() => (Handler inner) {
      return (Request request) async {
        try {
          return await inner(request);
        } on AppError catch (e) {
          return errorResponse(e);
        } catch (e, st) {
          print(
              '[unhandled] ${request.method} ${request.requestedUri.path}: $e\n$st');
          return errorResponse(AppError(ErrorCode.internal));
        }
      };
    };
