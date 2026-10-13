import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../json.dart';
import '../storage/object_storage.dart';

/// Liveness plus dependency check. Returns only ok/fail flags, never error details.
Handler healthHandler(
    {required Pool<void> pool, required ObjectStorage storage}) {
  return (Request request) async {
    var database = false;
    var store = false;
    try {
      await pool.execute('SELECT 1');
      database = true;
    } catch (_) {
      // reported via flag only
    }
    try {
      await storage.head(Bucket.originals, '__healthcheck__');
      store = true;
    } catch (_) {
      // reported via flag only
    }
    final ok = database && store;
    return jsonResponse({
      'ok': ok,
      'checks': {'database': database, 'storage': store},
    }, status: ok ? 200 : 503);
  };
}
