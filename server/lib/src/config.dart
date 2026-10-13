/// Validated runtime configuration, read once from environment variables.
class Config {
  Config({
    required this.port,
    required this.appOrigin,
    required this.databaseUrl,
    required this.s3Endpoint,
    required this.s3Region,
    required this.s3AccessKeyId,
    required this.s3SecretAccessKey,
    required this.s3PathStyle,
    required this.bucketOriginals,
    required this.bucketDerived,
    required this.derivedPublicBaseUrl,
    required this.maxImageBytes,
    required this.maxVideoBytes,
    required this.uploadPartBytes,
    required this.autoCreateBuckets,
  });

  final int port;
  final String appOrigin;
  final String databaseUrl;
  final Uri s3Endpoint;
  final String s3Region;
  final String s3AccessKeyId;
  final String s3SecretAccessKey;
  final bool s3PathStyle;
  final String bucketOriginals;
  final String bucketDerived;
  final String derivedPublicBaseUrl;
  final int maxImageBytes;
  final int maxVideoBytes;
  final int uploadPartBytes;

  /// Create the storage buckets on startup. Turn off in production if the storage provider
  /// (for example Cloudflare R2) is managed through its own dashboard.
  final bool autoCreateBuckets;

  /// Throws [ConfigException] listing every problem at once.
  factory Config.fromEnv(Map<String, String> env) {
    final problems = <String>[];

    String req(String key) {
      final v = env[key];
      if (v == null || v.trim().isEmpty) {
        problems.add('$key is required');
        return '';
      }
      return v.trim();
    }

    int intOr(String key, int fallback, {int min = 1}) {
      final raw = env[key];
      if (raw == null || raw.trim().isEmpty) return fallback;
      final n = int.tryParse(raw.trim());
      if (n == null || n < min) {
        problems.add('$key must be an integer >= $min');
        return fallback;
      }
      return n;
    }

    final endpoint = Uri.tryParse(req('S3_ENDPOINT'));
    if (endpoint == null || !endpoint.hasScheme || endpoint.host.isEmpty) {
      problems
          .add('S3_ENDPOINT must be a full URL such as http://localhost:9000');
    }

    final cfg = Config(
      port: intOr('PORT', 8080),
      appOrigin: env['APP_ORIGIN']?.trim() ?? '',
      databaseUrl: req('DATABASE_URL'),
      s3Endpoint: endpoint ?? Uri(),
      s3Region: env['S3_REGION']?.trim().isNotEmpty == true
          ? env['S3_REGION']!.trim()
          : 'auto',
      s3AccessKeyId: req('S3_ACCESS_KEY_ID'),
      s3SecretAccessKey: req('S3_SECRET_ACCESS_KEY'),
      s3PathStyle: (env['S3_PATH_STYLE'] ?? 'true').toLowerCase() != 'false',
      bucketOriginals: req('S3_BUCKET_ORIGINALS'),
      bucketDerived: req('S3_BUCKET_DERIVED'),
      derivedPublicBaseUrl: req('DERIVED_PUBLIC_BASE_URL'),
      maxImageBytes: intOr('MAX_IMAGE_BYTES', 25 * 1024 * 1024),
      maxVideoBytes: intOr('MAX_VIDEO_BYTES', 6 * 1024 * 1024 * 1024),
      // S3 requires every part except the last to be at least 5 MiB.
      uploadPartBytes:
          intOr('UPLOAD_PART_BYTES', 16 * 1024 * 1024, min: 5 * 1024 * 1024),
      autoCreateBuckets:
          (env['AUTO_CREATE_BUCKETS'] ?? 'true').toLowerCase() != 'false',
    );

    if (problems.isNotEmpty) throw ConfigException(problems);
    return cfg;
  }
}

class ConfigException implements Exception {
  ConfigException(this.problems);
  final List<String> problems;

  @override
  String toString() => 'Invalid configuration: ${problems.join('; ')}';
}
