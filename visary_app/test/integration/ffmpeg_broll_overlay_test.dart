import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/video_service.dart';

/// Integration test: FFmpeg B-roll overlay (PRD-SPRINT-05 §4 Test 5.3).
/// Uji penggabungan (overlay) file B-roll sekunder ke file utama menggunakan
/// FFmpeg dengan rentang waktu tertentu, tanpa menimpa audio sumber.
void main() {
  const samplePath = 'assets/videos/sample.mp4';

  test('renderWithBroll menghasilkan file MP4 valid dengan overlay B-roll', () async {
    expect(File(samplePath).existsSync(), isTrue,
        reason: 'Sample video harus ada');

    final tempDir = await Directory.systemTemp.createTemp('visary_broll_overlay_');
    final brollPath = '${tempDir.path}/broll_source.mp4';
    final outPath = '${tempDir.path}/output_with_broll.mp4';

    try {
      // Buat file B-roll pendek dari sample (4 detik pertama).
      await VideoService.extractSegment(
        sourcePath: samplePath,
        start: 0,
        end: 4,
        outputPath: brollPath,
      );
      expect(File(brollPath).existsSync(), isTrue, reason: 'B-roll source harus terbentuk');

      // Render clip utama dengan overlay B-roll di detik 2–6.
      await VideoService.renderWithBroll(
        sourcePath: samplePath,
        parts: const [ClipPart(0, 10)],
        outputPath: outPath,
        format: AspectFormat.v9x16,
        hasAudio: true,
        blurPad: false,
        brollOverlays: [
          BrollOverlay(2.0, 6.0, brollPath),
        ],
      );

      final outFile = File(outPath);
      expect(outFile.existsSync(), isTrue, reason: 'File output harus ada');
      expect(await outFile.length(), greaterThan(1000));

      // Verifikasi via ffprobe: file valid, audio intact.
      final probe = await VideoService.probe(outPath);
      expect(probe.width, 1080);
      expect(probe.height, 1920);
      expect(probe.durationSec, closeTo(10.0, 0.5));
      expect(probe.hasAudio, isTrue, reason: 'Audio sumber harus tetap ada');
    } finally {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    }
  });

  test('renderWithBroll tanpa overlay valid (fallback ke render biasa)', () async {
    expect(File(samplePath).existsSync(), isTrue);

    final tempDir = await Directory.systemTemp.createTemp('visary_broll_nobroll_');
    final outPath = '${tempDir.path}/output_no_broll.mp4';

    try {
      // BrollOverlays kosong → harus tetap jalan seperti renderClip biasa.
      await VideoService.renderWithBroll(
        sourcePath: samplePath,
        parts: const [ClipPart(0, 8)],
        outputPath: outPath,
        format: AspectFormat.v1x1,
        hasAudio: true,
        blurPad: false,
        brollOverlays: const [],
      );

      final outFile = File(outPath);
      expect(outFile.existsSync(), isTrue);
      expect(await outFile.length(), greaterThan(1000));

      final probe = await VideoService.probe(outPath);
      expect(probe.width, 1080);
      expect(probe.height, 1080);
      expect(probe.hasAudio, isTrue);
    } finally {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    }
  });
}
