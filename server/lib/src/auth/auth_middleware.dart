import 'package:shelf/shelf.dart';

import '../errors.dart';
import 'auth_service.dart';

Middleware authMiddleware(AuthService auth) => (Handler inner) {
      return (Request request) async {
        final authorization = request.headers['authorization'];
        if (authorization == null || !authorization.startsWith('Bearer ')) {
          throw AppError(ErrorCode.unauthenticated);
        }

        final token = authorization.substring(7).trim();
        if (token.isEmpty) throw AppError(ErrorCode.unauthenticated);

        final user = await auth.userForToken(token);
        if (user == null) throw AppError(ErrorCode.unauthenticated);

        return inner(request.change(context: {
          ...request.context,
          'authUser': user,
          'authToken': token,
        }));
      };
    };
