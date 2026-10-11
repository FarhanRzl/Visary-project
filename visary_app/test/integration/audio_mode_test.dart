import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/video_service.dart';

/// PRD-SPRINT-10 §4 — Test 10.2 & 10.3:
/// extractAudio, renderClip muted/replacement, muxPreviewAudio.
/// Verifikasi nyata via FFmpeg + ffprobe.
void main() {
  const samplePath = 'assets/videos/sample.mp4';

  setUpAll(() {
    expect(File(samplePath).existsSync(), isTrue,
        reason: 'Sample video harus ada');
  });

  group('extractAudio', () {
    test('ekstrak audio segment menghasilkan file AAC valid', () async {
      final tempDir = await Directory.systemTemp.createTemp('visary_audio_');
      final outPath = '${tempDir.path}/extracted.aac';
      try {
        final res = await VideoService.extractAudio(
          sourcePath: samplePath,
          start: 0,
          end: 3,
          outputPath: outPath,
        );
        expect(File(res.path).existsSync(), isTrue);
        expect(res.format, isNotEmpty);
        final probe = await VideoService.probe(outPath);
        expect(probe.hasAudio, isTrue);
        expect(probe.durationSec, closeTo(3.0, 0.6));
      } finally {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      }
    });
  });

  group('renderClip audioMode', () {
    test('muted → output tanpa stream audio', () async {
      final tempDir = await Directory.systemTemp.createTemp('visary_muted_');
      final outPath = '${tempDir.path}/muted.mp4';
      try {
        await VideoService.renderClip(
          sourcePath: samplePath,
          parts: const [ClipPart(0, 5)],
          outputPath: outPath,
          format: AspectFormat.v9x16,
          hasAudio: true,
          blurPad: false,
          audioMode: AudioMode.muted,
        );
        final probe = await VideoService.probe(outPath);
        expect(probe.hasAudio, isFalse,
            reason: 'Muted tidak boleh punya stream audio');
        expect(probe.width, 1080);
        expect(probe.height, 1920);
      } finally {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      }
    });

    test(
        'replacement audio pendek → output truncate ke durasi audio (-shortest)',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('visary_replace_');
      // 1. Siapkan audio pengganti pendek (3 detik) dari sample.
      final audioPath = '${tempDir.path}/repl.aac';
      await VideoService.extractAudio(
        sourcePath: samplePath,
        start: 0,
        end: 3,
        outputPath: audioPath,
      );
      // 2. Render clip 8 detik dengan audio pengganti 3 detik.
      final outPath = '${tempDir.path}/replaced.mp4';
      try {
        await VideoService.renderClip(
          sourcePath: samplePath,
          parts: const [ClipPart(0, 8)],
          outputPath: outPath,
          format: AspectFormat.v9x16,
          hasAudio: true,
          blurPad: false,
          audioMode: AudioMode.replacement,
          replacementAudioPath: audioPath,
        );
        final probe = await VideoService.probe(outPath);
        expect(probe.hasAudio, isTrue,
            reason: 'Replacement harus punya stream audio');
        // Truncate-to-audio-length: output ≈ 3 detik (audio), bukan 8 (video).
        expect(probe.durationSec, closeTo(3.0, 0.8),
            reason:
                'Output harus ter-truncate ke durasi audio (3s), bukan video (8s)');
        expect(probe.width, 1080);
        expect(probe.height, 1920);
      } finally {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      }
    });

    test('replacement tanpa path → ArgumentError', () {
      expect(
        () => VideoService.renderClip(
          sourcePath: samplePath,
          parts: const [ClipPart(0, 5)],
          outputPath: '/tmp/visary_should_not_exist.mp4',
          audioMode: AudioMode.replacement,
        ),
        throwsArgumentError,
      );
    });
  });

  group('muxPreviewAudio', () {
    test('mux video + audio → preview valid dengan audio', () async {
      final tempDir = await Directory.systemTemp.createTemp('visary_mux_');
      final audioPath = '${tempDir.path}/mux_audio.aac';
      await VideoService.extractAudio(
        sourcePath: samplePath,
        start: 0,
        end: 3,
        outputPath: audioPath,
      );
      final outPath = '${tempDir.path}/preview.mp4';
      try {
        await VideoService.muxPreviewAudio(
          videoPath: samplePath,
          audioPath: audioPath,
          outputPath: outPath,
        );
        final probe = await VideoService.probe(outPath);
        expect(probe.hasAudio, isTrue);
        // -shortest: output = min(video, audio) = 3 detik.
        expect(probe.durationSec, closeTo(3.0, 0.8));
      } finally {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      }
    });
  });
}
