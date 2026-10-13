import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../config.dart';
import 'object_storage.dart';
import 'sigv4.dart';

class StorageException implements Exception {
  StorageException(this.operation, this.status, this.body);
  final String operation;
  final int status;
  final String body;

  @override
  String toString() => 'StorageException($operation, HTTP $status): $body';
}

class S3Storage implements ObjectStorage {
  S3Storage(this._config, {http.Client? client})
      : _client = client ?? http.Client(),
        _signer = SigV4(
          endpoint: _config.s3Endpoint,
          region: _config.s3Region,
          accessKeyId: _config.s3AccessKeyId,
          secretAccessKey: _config.s3SecretAccessKey,
          pathStyle: _config.s3PathStyle,
        );

  final Config _config;
  final http.Client _client;
  final SigV4 _signer;

  String _bucketName(Bucket b) =>
      b == Bucket.originals ? _config.bucketOriginals : _config.bucketDerived;

  // Multipart uploads always target the originals bucket.
  String get _originals => _config.bucketOriginals;

  Uri _url(String method, String bucket, String key,
          {Map<String, String> query = const {}, int ttl = 120}) =>
      Uri.parse(_signer.presign(
          method: method,
          bucket: bucket,
          key: key,
          expiresSeconds: ttl,
          query: query));

  Never _fail(String op, http.Response r) =>
      throw StorageException(op, r.statusCode, r.body);

  @override
  Future<String> createMultipartUpload(String key, String contentType) async {
    // Content-Type is not part of the signature, so it can be sent as a normal header.
    final r = await _client.post(
      _url('POST', _originals, key, query: {'uploads': ''}),
      headers: {'content-type': contentType},
    );
    if (r.statusCode != 200) _fail('createMultipartUpload', r);
    final id = XmlDocument.parse(r.body)
        .findAllElements('UploadId')
        .firstOrNull
        ?.innerText;
    if (id == null || id.isEmpty)
      throw StorageException(
          'createMultipartUpload', r.statusCode, 'no UploadId');
    return id;
  }

  @override
  String presignUploadPart(String key, String uploadId, int partNumber,
          {int ttlSeconds = 3600}) =>
      _signer.presign(
        method: 'PUT',
        bucket: _originals,
        key: key,
        expiresSeconds: ttlSeconds,
        query: {'partNumber': '$partNumber', 'uploadId': uploadId},
      );

  @override
  Future<List<UploadedPart>> listParts(String key, String uploadId) async {
    final parts = <UploadedPart>[];
    var marker = '0';
    while (true) {
      final r = await _client.get(_url('GET', _originals, key, query: {
        'uploadId': uploadId,
        'part-number-marker': marker,
        'max-parts': '1000',
      }));
      if (r.statusCode != 200) _fail('listParts', r);
      final doc = XmlDocument.parse(r.body);
      for (final p in doc.findAllElements('Part')) {
        final n = int.tryParse(p.getElement('PartNumber')?.innerText ?? '');
        final etag = p.getElement('ETag')?.innerText;
        if (n != null && etag != null) parts.add(UploadedPart(n, etag));
      }
      final truncated =
          doc.findAllElements('IsTruncated').firstOrNull?.innerText == 'true';
      if (!truncated) break;
      marker =
          doc.findAllElements('NextPartNumberMarker').firstOrNull?.innerText ??
              '';
      if (marker.isEmpty) break;
    }
    return parts;
  }

  @override
  Future<void> completeMultipartUpload(
      String key, String uploadId, List<UploadedPart> parts) async {
    final sorted = [...parts]
      ..sort((a, b) => a.partNumber.compareTo(b.partNumber));
    final builder = XmlBuilder();
    builder.element('CompleteMultipartUpload', nest: () {
      for (final p in sorted) {
        builder.element('Part', nest: () {
          builder.element('PartNumber', nest: '${p.partNumber}');
          builder.element('ETag', nest: p.etag);
        });
      }
    });
    final r = await _client.post(
      _url('POST', _originals, key, query: {'uploadId': uploadId}, ttl: 600),
      headers: {'content-type': 'application/xml'},
      body: builder.buildDocument().toXmlString(),
    );
    // S3 can answer 200 with an <Error> body when completion fails part-way.
    if (r.statusCode != 200 || r.body.contains('<Error>'))
      _fail('completeMultipartUpload', r);
  }

  @override
  Future<void> abortMultipartUpload(String key, String uploadId) async {
    final r = await _client
        .delete(_url('DELETE', _originals, key, query: {'uploadId': uploadId}));
    if (r.statusCode != 204 && r.statusCode != 404)
      _fail('abortMultipartUpload', r);
  }

  @override
  Future<void> ensureBucket(Bucket bucket, {bool publicRead = false}) async {
    final name = _bucketName(bucket);
    final created = await _client.put(_url('PUT', name, ''));
    final alreadyThere = created.statusCode == 409 &&
        created.body.contains('BucketAlreadyOwnedByYou');
    if (created.statusCode != 200 && !alreadyThere)
      _fail('createBucket', created);

    if (publicRead) {
      final policy = jsonEncode({
        'Version': '2012-10-17',
        'Statement': [
          {
            'Effect': 'Allow',
            'Principal': {
              'AWS': ['*']
            },
            'Action': ['s3:GetObject'],
            'Resource': ['arn:aws:s3:::$name/*'],
          },
        ],
      });
      final r = await _client.put(
        _url('PUT', name, '', query: {'policy': ''}),
        headers: {'content-type': 'application/json'},
        body: policy,
      );
      if (r.statusCode != 200 && r.statusCode != 204)
        _fail('setBucketPolicy', r);
    }
  }

  @override
  Future<ObjectHead?> head(Bucket bucket, String key) async {
    final r = await _client.head(_url('HEAD', _bucketName(bucket), key));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) _fail('head', r);
    return ObjectHead(
      size: int.tryParse(r.headers['content-length'] ?? '') ?? 0,
      contentType: r.headers['content-type'],
    );
  }

  @override
  Future<Uint8List> getRange(
      Bucket bucket, String key, int start, int end) async {
    final r = await _client.get(
      _url('GET', _bucketName(bucket), key),
      headers: {'range': 'bytes=$start-$end'},
    );
    if (r.statusCode != 206 && r.statusCode != 200) _fail('getRange', r);
    return r.bodyBytes;
  }

  @override
  Future<void> put(
      Bucket bucket, String key, Uint8List body, String contentType,
      {String? cacheControl}) async {
    final r = await _client.put(
      _url('PUT', _bucketName(bucket), key, ttl: 600),
      headers: {
        'content-type': contentType,
        if (cacheControl != null) 'cache-control': cacheControl,
      },
      body: body,
    );
    if (r.statusCode != 200) _fail('put', r);
  }

  @override
  Future<void> delete(Bucket bucket, List<String> keys) async {
    for (final key in keys) {
      final r = await _client.delete(_url('DELETE', _bucketName(bucket), key));
      if (r.statusCode != 204 && r.statusCode != 404) _fail('delete', r);
    }
  }

  @override
  String presignGet(Bucket bucket, String key,
      {int ttlSeconds = 300, String? downloadName}) {
    return _signer.presign(
      method: 'GET',
      bucket: _bucketName(bucket),
      key: key,
      expiresSeconds: ttlSeconds,
      query: {
        if (downloadName != null)
          'response-content-disposition':
              "attachment; filename*=UTF-8''${Uri.encodeComponent(downloadName)}",
      },
    );
  }

  @override
  String derivedUrl(String key) =>
      '${_config.derivedPublicBaseUrl.replaceAll(RegExp(r'/+$'), '')}/$key';
}
