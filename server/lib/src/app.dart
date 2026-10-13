
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'errors.dart';
import 'routes/auth.dart';
import 'routes/health.dart';
import 'storage/object_storage.dart';

const _securityHeaders = {
  'x-content-type-options': 'nosniff',
  'x-frame-options': 'DENY',
  'referrer-policy': 'strict-origin-when-cross-origin',
};

Middleware _securityHeadersMiddleware() => (Handler inner) {
      return (Request request) async {
        final response = await inner(request);
        return response.change(headers: _securityHeaders);
      };
    };

/// Memeriksa apakah origin berasal dari localhost.
///
/// Port tidak dibatasi karena Flutter Web menggunakan port
/// yang dapat berubah setiap kali aplikasi dijalankan.
bool _isLocalhostOrigin(String? origin) {
  if (origin == null || origin.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(origin);

  if (uri == null) {
    return false;
  }

  return uri.scheme == 'http' &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1') &&
      uri.userInfo.isEmpty &&
      uri.path.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

/// CORS middleware untuk Flutter Web.
Middleware _corsMiddleware(String allowedOrigin) => (Handler inner) {
      return (Request request) async {
        final requestOrigin = request.headers['origin'];

        final isAllowed = requestOrigin != null &&
            (requestOrigin == allowedOrigin ||
                _isLocalhostOrigin(requestOrigin));

        final cors = <String, String>{
          if (isAllowed) ...{
            'access-control-allow-origin': requestOrigin,
            'access-control-allow-methods':
                'GET, POST, PUT, PATCH, DELETE, OPTIONS',
            'access-control-allow-headers':
                'authorization, content-type',
            'vary': 'origin',
          },
        };

        // Menangani preflight request dari browser.
        if (request.method == 'OPTIONS') {
          return Response(204, headers: cors);
        }

        final response = await inner(request);

        return response.change(headers: cors);
      };
    };

Handler buildApp({
  required Config config,
  required Pool<void> pool,
  required ObjectStorage storage,
}) {
  final router = Router()
    ..get(
      '/api/health',
      healthHandler(
        pool: pool,
        storage: storage,
      ),
    )
    ..mount(
      '/api/auth/',
      authRoutes(pool: pool),
    );

  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_securityHeadersMiddleware())
      .addMiddleware(_corsMiddleware(config.appOrigin))
      .addMiddleware(errorMiddleware())
      .addHandler(router.call);
}
