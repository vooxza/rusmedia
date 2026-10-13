import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/auth_service.dart';
import '../errors.dart';
import '../json.dart';

Handler authRoutes({required Pool<void> pool}) {
  final auth = AuthService(pool);
  final requireAuth = authMiddleware(auth);

  final router = Router()
    ..post('/login', (Request request) async {
      final Object? decoded;
      try {
        decoded = jsonDecode(await request.readAsString());
      } on FormatException {
        throw AppError(ErrorCode.validation,
            message: 'Format JSON tidak valid.');
      }

      if (decoded is! Map<String, dynamic>) {
        throw AppError(ErrorCode.validation,
            message: 'Data login tidak valid.');
      }

      final email = decoded['email'];
      final password = decoded['password'];
      if (email is! String ||
          email.trim().isEmpty ||
          password is! String ||
          password.isEmpty) {
        throw AppError(
          ErrorCode.validation,
          message: 'Email dan password wajib diisi.',
          fields: {
            if (email is! String || email.trim().isEmpty)
              'email': 'Email wajib diisi.',
            if (password is! String || password.isEmpty)
              'password': 'Password wajib diisi.',
          },
        );
      }

      final result = await auth.login(
        email: email,
        password: password,
        userAgent: request.headers['user-agent'],
      );

      if (result == null) {
        throw AppError(
          ErrorCode.unauthenticated,
          message: 'Email atau password salah, atau akun tidak aktif.',
        );
      }

      return jsonResponse({'data': result});
    })
    ..get('/me', requireAuth((Request request) async {
      final user = request.context['authUser'] as Map<String, Object?>;
      return jsonResponse({
        'data': {'user': user}
      });
    }))
    ..post('/logout', requireAuth((Request request) async {
      final token = request.context['authToken'] as String;
      await auth.logout(token);
      return jsonResponse({
        'data': {'message': 'Berhasil logout.'}
      });
    }));

  return router.call;
}
