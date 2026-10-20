import 'dart:convert';
import 'dart:math';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/auth_service.dart';
import '../config.dart';
import '../errors.dart';
import '../json.dart';
import '../storage/object_storage.dart';

Handler albumRoutes({
  required Pool<void> pool,
  required ObjectStorage storage,
  required Config config,
}) {
  final auth = authMiddleware(AuthService(pool));
  final router = Router();

  router.get('/', auth((Request request) async {
    final rows = await pool.execute(Sql.named('''
      SELECT id::text, title, description, event_date::text, year,
             visibility::text, photo_count, video_count, total_bytes,
             created_at::text
      FROM albums
      WHERE deleted_at IS NULL AND status = 'ACTIVE'
      ORDER BY event_date DESC, created_at DESC
    '''));
    return jsonResponse({
      'data': rows
          .map((r) => {
                'id': r[0],
                'title': r[1],
                'description': r[2],
                'eventDate': r[3],
                'year': r[4],
                'visibility': r[5],
                'photoCount': r[6],
                'videoCount': r[7],
                'totalBytes': r[8],
                'createdAt': r[9],
              })
          .toList()
    });
  }));

  router.post('/', auth((Request request) async {
    final body = await _readJson(request);
    final title = body['title'];
    final eventDate = body['eventDate'];
    final description = body['description'];
    final visibility = body['visibility'] ?? 'PRIVATE';
    if (title is! String ||
        title.trim().isEmpty ||
        eventDate is! String ||
        DateTime.tryParse(eventDate) == null ||
        !['PUBLIC', 'UNLISTED', 'PRIVATE'].contains(visibility)) {
      throw AppError(ErrorCode.validation,
          message: 'Judul, tanggal kegiatan, atau visibilitas tidak valid.');
    }
    final user = request.context['authUser'] as Map<String, Object?>;
    final normalized = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final slug =
        '${normalized.isEmpty ? 'album' : normalized}-${DateTime.now().microsecondsSinceEpoch}';
    final rows = await pool.execute(Sql.named('''
      INSERT INTO albums (title, slug, description, event_date, year,
                          visibility, created_by_id)
      VALUES (@title, @slug, @description, @event_date::date,
              EXTRACT(YEAR FROM @event_date::date)::int,
              @visibility::visibility_t, @user_id::uuid)
      RETURNING id::text, title, description, event_date::text,
                year, visibility::text, created_at::text
    '''), parameters: {
      'title': title.trim(),
      'slug': slug,
      'description': description is String && description.trim().isNotEmpty
          ? description.trim()
          : null,
      'event_date': eventDate,
      'visibility': visibility,
      'user_id': user['id'],
    });
    final r = rows.first;
    return jsonResponse({
      'data': {
        'id': r[0],
        'title': r[1],
        'description': r[2],
        'eventDate': r[3],
        'year': r[4],
        'visibility': r[5],
        'createdAt': r[6],
      }
    }, status: 201);
  }));

  router.post('/uploads/initiate', auth((Request request) async {
    final body = await _readJson(request);
    final albumId = body['albumId'];
    final fileName = body['fileName'];
    final mimeType = body['mimeType'];
    final fileSize = body['fileSize'];
    final folderId = body['folderId'];
    if (albumId is! String ||
        fileName is! String ||
        fileName.trim().isEmpty ||
        mimeType is! String ||
        fileSize is! int ||
        fileSize <= 0) {
      throw AppError(ErrorCode.validation,
          message: 'Informasi file belum lengkap atau tidak valid.');
    }
    final isImage = mimeType.startsWith('image/');
    final isVideo = mimeType.startsWith('video/');
    if (!isImage && !isVideo) {
      throw AppError(ErrorCode.unsupportedFormat,
          message: 'Hanya file foto dan video yang dapat diunggah.');
    }
    final maxBytes = isImage ? config.maxImageBytes : config.maxVideoBytes;
    if (fileSize > maxBytes) {
      throw AppError(ErrorCode.fileTooLarge,
          message: 'Ukuran file melewati batas yang diizinkan.');
    }

    final album = await pool.execute(Sql.named('''
      SELECT id FROM albums
      WHERE id = @id::uuid AND deleted_at IS NULL AND status = 'ACTIVE'
      LIMIT 1
    '''), parameters: {'id': albumId});
    if (album.isEmpty)
      throw AppError(ErrorCode.notFound,
          message: 'Album tujuan tidak ditemukan.');

    if (folderId is String) {
      final folder = await pool.execute(Sql.named('''
        SELECT id FROM folders WHERE id = @folder::uuid AND album_id = @album::uuid
      '''), parameters: {'folder': folderId, 'album': albumId});
      if (folder.isEmpty)
        throw AppError(ErrorCode.validation,
            message: 'Folder tidak sesuai dengan album tujuan.');
    }

    final user = request.context['authUser'] as Map<String, Object?>;
    final fileRows = await pool.execute(Sql.named('''
      INSERT INTO files (album_id, folder_id, uploaded_by_id, file_name,
                         storage_key, mime_type, file_type, file_size, status)
      VALUES (@album::uuid, @folder::uuid, @user::uuid, @name,
              @key, @mime, @type::file_type_t, @size, 'UPLOADING')
      RETURNING id::text
    '''), parameters: {
      'album': albumId,
      'folder': folderId,
      'user': user['id'],
      'name': fileName.trim(),
      'key': 'originals/${_randomKey()}',
      'mime': mimeType,
      'type': isImage ? 'IMAGE' : 'VIDEO',
      'size': fileSize,
    });
    final fileId = fileRows.first[0] as String;
    final keyRows = await pool.execute(
        Sql.named('SELECT storage_key FROM files WHERE id = @id::uuid'),
        parameters: {'id': fileId});
    final key = keyRows.first[0] as String;
    final partSize = max(config.uploadPartBytes, 5 * 1024 * 1024).toInt();
    final totalParts = (fileSize / partSize).ceil();
    String uploadId;
    try {
      uploadId = await storage.createMultipartUpload(key, mimeType);
      await pool.execute(Sql.named('''
        INSERT INTO upload_sessions (file_id, user_id, s3_upload_id,
                                     part_size, total_parts, status, expires_at)
        VALUES (@file::uuid, @user::uuid, @upload, @part_size,
                @total_parts, 'INITIATED', now() + interval '24 hours')
      '''), parameters: {
        'file': fileId,
        'user': user['id'],
        'upload': uploadId,
        'part_size': partSize,
        'total_parts': totalParts,
      });
    } catch (_) {
      await pool.execute(
          Sql.named("UPDATE files SET status = 'FAILED' WHERE id = @id::uuid"),
          parameters: {'id': fileId});
      rethrow;
    }
    return jsonResponse({
      'data': {
        'fileId': fileId,
        'partSize': partSize,
        'totalParts': totalParts,
        'expiresInSeconds': 86400,
      }
    }, status: 201);
  }));

  router.post('/uploads/<fileId>/parts/<partNumber>',
      auth((Request request) async {
    final fileId = request.params['fileId']!;
    final partNumber = request.params['partNumber']!;
    final user = request.context['authUser'] as Map<String, Object?>;
    final part = int.tryParse(partNumber);
    if (part == null || part < 1) throw AppError(ErrorCode.validation);
    final rows = await pool.execute(Sql.named('''
      SELECT f.storage_key, s.s3_upload_id, s.total_parts
      FROM upload_sessions s JOIN files f ON f.id = s.file_id
      WHERE s.file_id = @file::uuid AND s.user_id = @user::uuid
        AND s.status IN ('INITIATED', 'UPLOADING') AND s.expires_at > now()
      LIMIT 1
    '''), parameters: {'file': fileId, 'user': user['id']});
    if (rows.isEmpty)
      throw AppError(ErrorCode.notFound,
          message: 'Sesi upload tidak ditemukan atau sudah kedaluwarsa.');
    final r = rows.first;
    final total = r[2] as int;
    if (part > total)
      throw AppError(ErrorCode.validation,
          message: 'Nomor bagian file tidak valid.');
    final url = storage.presignUploadPart(r[0] as String, r[1] as String, part);
    await pool.execute(Sql.named('''
      UPDATE upload_sessions SET status = 'UPLOADING'
      WHERE file_id = @file::uuid
    '''), parameters: {'file': fileId});
    return jsonResponse({
      'data': {'partNumber': part, 'url': url}
    });
  }));

  router.post('/uploads/<fileId>/complete', auth((Request request) async {
    final fileId = request.params['fileId']!;
    final user = request.context['authUser'] as Map<String, Object?>;
    final rows = await pool.execute(Sql.named('''
      SELECT f.storage_key, s.s3_upload_id, s.total_parts
      FROM upload_sessions s JOIN files f ON f.id = s.file_id
      WHERE s.file_id = @file::uuid AND s.user_id = @user::uuid
        AND s.status IN ('INITIATED', 'UPLOADING') AND s.expires_at > now()
      LIMIT 1
    '''), parameters: {'file': fileId, 'user': user['id']});
    if (rows.isEmpty)
      throw AppError(ErrorCode.notFound,
          message: 'Sesi upload tidak ditemukan atau sudah kedaluwarsa.');
    final r = rows.first;
    final key = r[0] as String;
    final uploadId = r[1] as String;
    final expectedParts = r[2] as int;
    final parts = await storage.listParts(key, uploadId);
    if (parts.length != expectedParts ||
        parts.asMap().entries.any((e) => e.value.partNumber != e.key + 1)) {
      throw AppError(ErrorCode.validation,
          message:
              'Upload belum lengkap. Pastikan semua bagian file sudah terkirim.');
    }
    await storage.completeMultipartUpload(key, uploadId, parts);
    final head = await storage.head(Bucket.originals, key);
    if (head == null) throw AppError(ErrorCode.uploadFailed);
    await pool.runTx((tx) async {
      await tx.execute(Sql.named('''
        UPDATE files SET status = 'READY', updated_at = now()
        WHERE id = @file::uuid
      '''), parameters: {'file': fileId});
      await tx.execute(Sql.named('''
        UPDATE upload_sessions SET status = 'COMPLETED'
        WHERE file_id = @file::uuid
      '''), parameters: {'file': fileId});
      await tx.execute(Sql.named('''
        UPDATE albums SET
          photo_count = photo_count + CASE WHEN EXISTS
            (SELECT 1 FROM files WHERE id = @file::uuid AND file_type = 'IMAGE') THEN 1 ELSE 0 END,
          video_count = video_count + CASE WHEN EXISTS
            (SELECT 1 FROM files WHERE id = @file::uuid AND file_type = 'VIDEO') THEN 1 ELSE 0 END,
          total_bytes = total_bytes + @size, updated_at = now()
        WHERE id = (SELECT album_id FROM files WHERE id = @file::uuid)
      '''), parameters: {'file': fileId, 'size': head.size});
    });
    return jsonResponse({
      'data': {
        'fileId': fileId,
        'status': 'READY',
        'fileSize': head.size,
      }
    });
  }));

  return router.call;
}

Future<Map<String, dynamic>> _readJson(Request request) async {
  try {
    final value = jsonDecode(await request.readAsString());
    if (value is Map<String, dynamic>) return value;
  } on FormatException {
    // handled below
  }
  throw AppError(ErrorCode.validation, message: 'Format JSON tidak valid.');
}

String _randomKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
