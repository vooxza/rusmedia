import 'package:postgres/postgres.dart';

/// Builds a connection pool from a `postgresql://user:pass@host:port/db` URL.
Pool<void> createPool(String databaseUrl, {int maxConnections = 10}) {
  final uri = Uri.parse(databaseUrl);
  final userInfo = uri.userInfo.split(':');
  final endpoint = Endpoint(
    host: uri.host,
    port: uri.hasPort ? uri.port : 5432,
    database: uri.path.startsWith('/') ? uri.path.substring(1) : uri.path,
    username: userInfo.isNotEmpty && userInfo.first.isNotEmpty
        ? Uri.decodeComponent(userInfo.first)
        : null,
    password: userInfo.length > 1
        ? Uri.decodeComponent(userInfo.sublist(1).join(':'))
        : null,
  );
  final sslMode = uri.queryParameters['sslmode'] == 'require'
      ? SslMode.require
      : SslMode.disable;
  return Pool.withEndpoints(
    [endpoint],
    settings:
        PoolSettings(maxConnectionCount: maxConnections, sslMode: sslMode),
  );
}
