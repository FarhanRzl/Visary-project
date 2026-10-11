import 'package:flutter_test/flutter_test.dart';
import 'package:visary/data/local/database.dart';
import 'package:visary/data/local/project_repository.dart';
import 'package:visary/models/models.dart';
import 'package:visary/state/app_state.dart';

/// PRD-SPRINT-10 §4 — Test 10.1 & 10.4 (state slice):
/// AudioMode state, activeAudioAsset getter, persistensi round-trip
/// (audioMode, activeAudioAssetId, AssetItem.durationSec/audioFormat).
void main() {
  late VisaryDatabase db;
  late ProjectRepository repo;
  late AppState state;

  const audioAsset = AssetItem(
    id: 'a_au1',
    type: AssetType.audio,
    title: 'music.mp3',
    sourceFile: '/tmp/music.mp3',
    start: 0,
    end: 30,
    durationSec: 30,
    audioFormat: 'mp3',
  );

  Project makeProject({
    AudioMode mode = AudioMode.original,
    String? activeAudio,
    List<AssetItem> assets = const [],
  }) =>
      Project(
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
        assets: assets,
        audioMode: mode,
        activeAudioAssetId: activeAudio,
      );

  setUp(() {
    db = VisaryDatabase.memory();
    repo = ProjectRepository(db);
    state = AppState(repo: repo);
    state.projects.add(makeProject(assets: const [audioAsset]));
  });
  tearDown(() => db.close());

  test('setAudioMode muted → state + persist', () async {
    state.setAudioMode('p1', AudioMode.muted);
    expect(state.byId('p1')!.audioMode, AudioMode.muted);
    await state.flush();
    final loaded = (await repo.loadAll()).single;
    expect(loaded.audioMode, AudioMode.muted);
  });

  test(
      'setActiveAudioAsset → mode replacement + activeAudioAsset terisi + persist',
      () async {
    state.setActiveAudioAsset('p1', 'a_au1');
    final p = state.byId('p1')!;
    expect(p.audioMode, AudioMode.replacement);
    expect(p.activeAudioAssetId, 'a_au1');
    expect(p.activeAudioAsset?.id, 'a_au1');
    expect(p.activeAudioAsset?.sourceFile, '/tmp/music.mp3');
    await state.flush();
    final loaded = (await repo.loadAll()).single;
    expect(loaded.audioMode, AudioMode.replacement);
    expect(loaded.activeAudioAssetId, 'a_au1');
    expect(loaded.activeAudioAsset?.sourceFile, '/tmp/music.mp3');
  });

  test('activeAudioAsset null saat mode bukan replacement', () {
    // Project awal mode original → activeAudioAsset harus null walau
    // activeAudioAssetId tidak di-set.
    expect(state.byId('p1')!.activeAudioAsset, isNull);
  });

  test('audio asset durationSec/audioFormat persist round-trip', () async {
    // Trigger persist (setAudioMode no-op original) lalu reload.
    state.setAudioMode('p1', AudioMode.original);
    await state.flush();
    final loaded = (await repo.loadAll()).single;
    final a = loaded.assets.single;
    expect(a.type, AssetType.audio);
    expect(a.durationSec, 30);
    expect(a.audioFormat, 'mp3');
    expect(a.isAudio, isTrue);
  });
}
