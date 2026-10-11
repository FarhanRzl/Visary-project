import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/video_service.dart';

void main() {
  test('Render clip resequenced multi-part menghasilkan file mp4 valid', () async {
    const samplePath = 'assets/videos/sample.mp4';
    expect(File(samplePath).existsSync(), isTrue, reason: 'Sample video harus ada');

    final tempDir = await Directory.systemTemp.createTemp('visary_render_test_');
    final outPath = '${tempDir.path}/rendered_resequenced.mp4';

    try {
      // 2 parts: hook dipindah ke depan (resequenced)
      final parts = [
        const ClipPart(10.0, 14.0), // hook (4 detik)
        const ClipPart(0.0, 4.0),   // segmen berikutnya (4 detik)
      ];

      await VideoService.renderClip(
        sourcePath: samplePath,
        parts: parts,
        outputPath: outPath,
        format: AspectFormat.v9x16,
        hasAudio: true,
        blurPad: false,
      );

      final outFile = File(outPath);
      expect(outFile.existsSync(), isTrue);
      expect(await outFile.length(), greaterThan(1000));

      final probe = await VideoService.probe(outPath);
      expect(probe.durationSec, closeTo(8.0, 0.5));
      expect(probe.width, 1080);
      expect(probe.height, 1920);
      expect(probe.hasAudio, isTrue);
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}
