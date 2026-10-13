import 'dart:convert';
import 'dart:typed_data';

import 'package:rusmedia_server/src/media/validate.dart';
import 'package:test/test.dart';

Uint8List bytes(List<int> b) => Uint8List.fromList(b);
Uint8List cat(List<List<int>> parts) => bytes(parts.expand((p) => p).toList());

void main() {
  group('matchDeclaredFormat', () {
    test('accepts matching name and mime', () {
      expect(matchDeclaredFormat('IMG_001.JPG', 'image/jpeg')?.kind, FileKind.image);
      expect(matchDeclaredFormat('clip.mov', 'video/quicktime')?.kind, FileKind.video);
    });
    test('rejects mismatched or unsupported files', () {
      expect(matchDeclaredFormat('a.jpg', 'video/mp4'), isNull);
      expect(matchDeclaredFormat('a.gif', 'image/gif'), isNull);
      expect(matchDeclaredFormat('noext', 'image/png'), isNull);
    });
  });

  group('sniffMime', () {
    test('detects JPEG, PNG, WEBP, MP4, MOV, WEBM', () {
      expect(sniffMime(bytes([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0, 0, 0, 0, 0])), 'image/jpeg');
      expect(sniffMime(bytes([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0])), 'image/png');
      expect(sniffMime(cat([ascii.encode('RIFF'), [0, 0, 0, 0], ascii.encode('WEBP')])), 'image/webp');
      expect(sniffMime(cat([[0, 0, 0, 0], ascii.encode('ftypisom')])), 'video/mp4');
      expect(sniffMime(cat([[0, 0, 0, 0], ascii.encode('ftypqt  ')])), 'video/quicktime');
      expect(sniffMime(bytes([0x1a, 0x45, 0xdf, 0xa3, 0, 0, 0, 0, 0, 0, 0, 0])), 'video/webm');
    });
    test('returns null for unknown content (an .exe renamed to .jpg)', () {
      expect(sniffMime(cat([ascii.encode('MZ'), List.filled(10, 0)])), isNull);
    });
    test('returns null for short input instead of throwing', () {
      expect(sniffMime(bytes([0xff])), isNull);
      expect(sniffMime(bytes([])), isNull);
    });
  });

  group('mimeCompatible', () {
    test('treats mp4 and mov containers as interchangeable only with each other', () {
      expect(mimeCompatible('video/mp4', 'video/quicktime'), isTrue);
      expect(mimeCompatible('video/mp4', 'video/webm'), isFalse);
      expect(mimeCompatible('image/png', 'image/jpeg'), isFalse);
    });
  });
}
