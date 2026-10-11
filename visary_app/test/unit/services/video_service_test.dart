import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:visary/services/video_service.dart';

void main() {
  group('VideoService Unit Tests', () {
    test('VideoService.isAvailable() handles missing vs available binaries', () async {
      final available = await VideoService.isAvailable();
      // Should return a boolean result without throwing exception
      expect(available, isA<bool>());
    });

    test('VideoService.probe() throws FileSystemException when file does not exist', () async {
      expect(
        () => VideoService.probe('/non/existent/path/video.mp4'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('FfmpegMissingException formats string correctly', () {
      final ex = FfmpegMissingException('ffprobe');
      expect(ex.binary, equals('ffprobe'));
      expect(ex.toString(), contains('ffprobe tidak ditemukan'));
    });

    test('FfmpegFailedException formats string correctly', () {
      final ex = FfmpegFailedException('ffmpeg', 1, 'Invalid codec');
      expect(ex.stage, equals('ffmpeg'));
      expect(ex.exitCode, equals(1));
      expect(ex.toString(), contains('ffmpeg gagal (exit 1)'));
    });
  });
}
