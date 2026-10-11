import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';
import 'package:visary/state/app_state.dart';

/// PRD-SPRINT-10 — bugfix: exportAsset untuk AssetType.audio harus menyalin
/// file audio apa adanya (ekstensi asli), BUKAN extract video sumber ke .mp4.
void main() {
  late AppState state;
  late Directory tempDir;

  setUp(() async {
    state = AppState();
    tempDir = await Directory.systemTemp.createTemp('visary_export_audio_');
  });
  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('exportAsset audio → salin file audio (ekstensi asli, bukan mp4)',
      () async {
    // Buat file audio dummy di temp.
    final audioSrc = '${tempDir.path}/source.mp3';
    await File(audioSrc).writeAsString('fake-audio-content');

    state.projects.add(Project(
      id: 'p1',
      name: 'test.mp4',
      filePath: '/videos/test.mp4',
      createdAt: DateTime(2026),
      probe: const VideoProbe(
        durationSec: 60,
        width: 1920,
        height: 1080,
        fps: 30,
        codec: 'h264',
        hasAudio: true,
      ),
      stage: JobStage.done,
      progress: 1,
      assets: [
        AssetItem(
          id: 'a1',
          type: AssetType.audio,
          title: 'my song',
          sourceFile: audioSrc,
          start: 0,
          end: 30,
          durationSec: 30,
          audioFormat: 'mp3',
        ),
      ],
    ));

    final outDir = '${tempDir.path}/out';
    await Directory(outDir).create(recursive: true);
    final path = await state.exportAsset(
      projectId: 'p1',
      asset: state.byId('p1')!.assets.single,
      outputDir: outDir,
    );

    expect(path.endsWith('.mp3'), isTrue,
        reason: 'Harus .mp3 (ekstensi asli), bukan .mp4');
    expect(path.endsWith('.mp4'), isFalse);
    final exported = File(path);
    expect(exported.existsSync(), isTrue);
    // Konten identik = hasil copy, bukan re-encode dari video.
    expect(await exported.readAsString(), 'fake-audio-content');
  });

  test('exportAsset audio .aac (hasil extract) → ekstensi .aac', () async {
    final audioSrc = '${tempDir.path}/extracted.aac';
    await File(audioSrc).writeAsString('aac-bytes');

    state.projects.add(Project(
      id: 'p1',
      name: 'test.mp4',
      filePath: '/videos/test.mp4',
      createdAt: DateTime(2026),
      stage: JobStage.done,
      progress: 1,
      assets: [
        AssetItem(
          id: 'a_ex1',
          type: AssetType.audio,
          title: 'Audio 0-30s',
          sourceFile: audioSrc,
          start: 0,
          end: 30,
          durationSec: 30,
          audioFormat: 'aac',
        ),
      ],
    ));

    final outDir = '${tempDir.path}/out';
    await Directory(outDir).create(recursive: true);
    final path = await state.exportAsset(
      projectId: 'p1',
      asset: state.byId('p1')!.assets.single,
      outputDir: outDir,
    );
    expect(path.endsWith('.aac'), isTrue);
    expect(path.endsWith('.mp4'), isFalse);
  });
}
