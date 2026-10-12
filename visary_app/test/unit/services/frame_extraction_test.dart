import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:visary/services/video_service.dart';

/// PRD-SPRINT-14 §4 — Test 14.2: Frame Extraction (VideoService.extractFrame).
void main() {
  const samplePath = 'assets/videos/sample.mp4';

  group('extractFrame — error cases', () {
    test('throws FileSystemException when source file does not exist', () async {
      expect(
        () => VideoService.extractFrame(
          sourcePath: '/non/existent/video.mp4',
          timestamp: 1.0,
          outputPath: '/tmp/visary_test_frame.jpg',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('extractFrame — success (requires ffmpeg + sample.mp4)', () {
    setUp(() async {
      if (!File(samplePath).existsSync()) {
        throw StateError('Sample video tidak ditemukan: $samplePath');
      }
      final ffmpegOk = await VideoService.isAvailable();
      if (!ffmpegOk) {
        throw StateError('FFmpeg tidak tersedia untuk integration test');
      }
    });

    test('menghasilkan file JPG di outputPath', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('visary_frame_extract_');
      final outPath = '${tempDir.path}/frame.jpg';

      try {
        final result = await VideoService.extractFrame(
          sourcePath: samplePath,
          timestamp: 5.0,
          outputPath: outPath,
        );

        expect(result, equals(outPath));
        expect(File(outPath).existsSync(), isTrue);
        expect(await File(outPath).length(), greaterThan(500));
      } finally {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      }
    });

    test('timestamp di tengah shot menghasilkan frame valid', () async {
      // Sample video 102 detik. Tengah = ~51 detik.
      final tempDir =
          await Directory.systemTemp.createTemp('visary_frame_mid_');
      final outPath = '${tempDir.path}/frame_mid.jpg';

      try {
        final result = await VideoService.extractFrame(
          sourcePath: samplePath,
          timestamp: 51.0,
          outputPath: outPath,
        );

        expect(result, equals(outPath));
        expect(File(outPath).existsSync(), isTrue);
        expect(await File(outPath).length(), greaterThan(500));
      } finally {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      }
    });

    test('membuat output directory jika belum ada', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('visary_frame_mkdir_');
      final nestedOutPath = '${tempDir.path}/nested/deep/dir/frame.jpg';

      try {
        expect(Directory('${tempDir.path}/nested/deep/dir').existsSync(),
            isFalse);

        final result = await VideoService.extractFrame(
          sourcePath: samplePath,
          timestamp: 10.0,
          outputPath: nestedOutPath,
        );

        expect(result, equals(nestedOutPath));
        expect(File(nestedOutPath).existsSync(), isTrue);
      } finally {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      }
    });
  });
}
