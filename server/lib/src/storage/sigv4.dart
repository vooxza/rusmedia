import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// AWS Signature V4 query-string presigning (UNSIGNED-PAYLOAD, `host` header only).
///
/// One primitive is used for everything: the server presigns a URL and either hands it to the
/// browser/app (uploads, downloads) or calls it itself (create/complete/list/head/delete).
/// Verified against AWS's documented presigned-GET example (see test/sigv4_test.dart).
class SigV4 {
  SigV4({
    required this.endpoint,
    required this.region,
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.pathStyle,
  });

  final Uri endpoint;
  final String region;
  final String accessKeyId;
  final String secretAccessKey;
  final bool pathStyle;

  /// RFC 3986 percent-encoding as required by SigV4 (only unreserved characters stay literal).
  static String encode(String s) {
    final out = StringBuffer();
    for (final b in utf8.encode(s)) {
      final c = b;
      final unreserved = (c >= 0x41 && c <= 0x5a) || // A-Z
          (c >= 0x61 && c <= 0x7a) || // a-z
          (c >= 0x30 && c <= 0x39) || // 0-9
          c == 0x2d ||
          c == 0x5f ||
          c == 0x2e ||
          c == 0x7e; // - _ . ~
      if (unreserved) {
        out.writeCharCode(c);
      } else {
        out.write('%${c.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return out.toString();
  }

  String _hostFor(String bucket) {
    final base =
        endpoint.hasPort ? '${endpoint.host}:${endpoint.port}' : endpoint.host;
    return pathStyle ? base : '$bucket.$base';
  }

  String _pathFor(String bucket, String key) {
    if (key.isEmpty) return pathStyle ? '/${encode(bucket)}' : '/';
    final k = key.split('/').map(encode).join('/');
    return pathStyle ? '/${encode(bucket)}/$k' : '/$k';
  }

  /// Returns a presigned URL. [query] holds extra parameters (uploadId, partNumber, uploads, ...);
  /// use an empty string for valueless parameters such as `uploads`.
  String presign({
    required String method,
    required String bucket,
    required String key,
    int expiresSeconds = 300,
    Map<String, String> query = const {},
    DateTime? now,
  }) {
    final t = (now ?? DateTime.now()).toUtc();
    final amzDate = '${_d(t.year, 4)}${_d(t.month, 2)}${_d(t.day, 2)}'
        'T${_d(t.hour, 2)}${_d(t.minute, 2)}${_d(t.second, 2)}Z';
    final date = amzDate.substring(0, 8);
    final scope = '$date/$region/s3/aws4_request';
    final host = _hostFor(bucket);
    final path = _pathFor(bucket, key);

    final params = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': '$accessKeyId/$scope',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': '$expiresSeconds',
      'X-Amz-SignedHeaders': 'host',
      ...query,
    };
    final sortedKeys = params.keys.toList()..sort();
    final canonicalQuery =
        sortedKeys.map((k) => '${encode(k)}=${encode(params[k]!)}').join('&');

    final canonicalRequest = [
      method,
      path,
      canonicalQuery,
      'host:$host\n',
      'host',
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    var k = utf8.encode('AWS4$secretAccessKey');
    for (final part in [date, region, 's3', 'aws4_request']) {
      k = Uint8List.fromList(
        Hmac(sha256, k).convert(utf8.encode(part)).bytes,
      );
    }
    final signature =
        Hmac(sha256, k).convert(utf8.encode(stringToSign)).toString();

    final scheme = endpoint.scheme;
    return '$scheme://$host$path?$canonicalQuery&X-Amz-Signature=$signature';
  }

  static String _d(int v, int width) => v.toString().padLeft(width, '0');
}
