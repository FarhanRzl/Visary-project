import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/video_service.dart';
import 'package:visary/state/app_state.dart';

/// Integration test: render clip ke format 9:16 dan 1:1 dari sample.mp4,
/// lalu verifikasi resolusi & durasi via ffprobe (PRD-SPRINT-08 Step 1 task 6).
void main() {
  const samplePath = 'assets/videos/sample.mp4';

  test('Render clip format 9:16 menghasilkan file 1080×1920 valid', () async {
    expect(File(samplePath).existsSync(), isTrue,
        reason: 'Sample video harus ada');

    final tempDir =
        await Directory.systemTemp.createTemp('visary_export_9x16_');
    final outPath = '${tempDir.path}/clip_9x16.mp4';

    try {
      await VideoService.renderClip(
        sourcePath: samplePath,
        parts: const [ClipPart(0, 8)],
        outputPath: outPath,
        format: AspectFormat.v9x16,
        hasAudio: true,
        blurPad: false,
      );

      final outFile = File(outPath);
      expect(outFile.existsSync(), isTrue);
      expect(await outFile.length(), greaterThan(1000));

      final probe = await VideoService.probe(outPath);
      expect(probe.width, 1080, reason: 'Lebar harus 1080');
      expect(probe.height, 1920, reason: 'Tinggi harus 1920 (9:16)');
      expect(probe.durationSec, closeTo(8.0, 0.5));
      expect(probe.hasAudio, isTrue, reason: 'Audio harus ikut terender');
    } finally {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    }
  });

  test('Render clip format 1:1 menghasilkan file 1080×1080 valid', () async {
    expect(File(samplePath).existsSync(), isTrue,
        reason: 'Sample video harus ada');

    final tempDir =
        await Directory.systemTemp.createTemp('visary_export_1x1_');
    final outPath = '${tempDir.path}/clip_1x1.mp4';

    try {
      await VideoService.renderClip(
        sourcePath: samplePath,
        parts: const [ClipPart(0, 8)],
        outputPath: outPath,
        format: AspectFormat.v1x1,
        hasAudio: true,
        blurPad: false,
      );

      final outFile = File(outPath);
      expect(outFile.existsSync(), isTrue);
      expect(await outFile.length(), greaterThan(1000));

      final probe = await VideoService.probe(outPath);
      expect(probe.width, 1080, reason: 'Lebar harus 1080');
      expect(probe.height, 1080, reason: 'Tinggi harus 1080 (1:1)');
      expect(probe.durationSec, closeTo(8.0, 0.5));
      expect(probe.hasAudio, isTrue, reason: 'Audio harus ikut terender');
    } finally {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    }
  });

  test('Export via AppState.exportClip menghasilkan 2 file untuk 2 format',
      () async {
    expect(File(samplePath).existsSync(), isTrue,
        reason: 'Sample video harus ada');

    // Perlu AppState — import minimal.
    final state = _TestableAppState();
    final id = await state.addProjectFromUpload('sample.mp4',
        filePath: samplePath);
    final project = state.byId(id)!;
    final clip = project.clips.first;

    final tempDir =
        await Directory.systemTemp.createTemp('visary_export_multi_');

    try {
      final files = await state.exportClip(
        projectId: id,
        clipId: clip.id,
        formats: [AspectFormat.v9x16, AspectFormat.v1x1],
        outputDir: tempDir.path,
      );

      expect(files.length, 2, reason: 'Harus ada 2 file output');

      for (final f in files) {
        expect(File(f).existsSync(), isTrue, reason: 'File $f harus ada');
        final probe = await VideoService.probe(f);
        expect(probe.width, 1080);
        expect(
          probe.height,
          anyOf(equals(1920), equals(1080)),
          reason: 'Tinggi harus 1920 (9:16) atau 1080 (1:1)',
        );
        expect(probe.hasAudio, isTrue);
      }
    } finally {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    }
  });
}

/// Subclass tipis untuk akses AppState di test integration.
class _TestableAppState extends AppState {}
