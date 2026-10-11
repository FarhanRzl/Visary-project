import 'package:flutter_test/flutter_test.dart';
import 'package:visary/data/local/database.dart';
import 'package:visary/data/local/project_repository.dart';
import 'package:visary/models/models.dart';

/// Test 2.1 — PRD-SPRINT-02 §4: Drift DB insert, relasi, cascading delete.
Project _project(String id) => Project(
      id: id,
      name: '$id.mp4',
      filePath: '/videos/$id.mp4',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      probe: const VideoProbe(
        durationSec: 120.5,
        width: 1920,
        height: 1080,
        fps: 29.97,
        codec: 'h264',
        hasAudio: true,
      ),
      stage: JobStage.done,
      progress: 1,
      thumbnailPath: '/tmp/visary/$id/thumb.jpg',
      clips: [
        Clip(
          id: '$id-c1',
          title: 'Clip satu',
          parts: const [ClipPart(10, 25), ClipPart(40, 55.5)],
          hook: const ClipPart(10, 13),
          score: 87,
          reason: 'energi tinggi',
          type: ClipType.resequenced,
          selected9x16: true,
          selected1x1: true,
        ),
        Clip(
          id: '$id-c2',
          title: 'Clip dua',
          parts: const [ClipPart(60, 95)],
          hook: const ClipPart(60, 63),
          score: 70,
          reason: 'shot rapat',
          type: ClipType.linear,
        ),
      ],
      assets: [
        AssetItem(
          id: '$id-a1',
          type: AssetType.soundBite,
          title: 'Sound bite',
          sourceFile: '$id.mp4',
          start: 5,
          end: 9.5,
        ),
      ],
    );

void main() {
  late VisaryDatabase db;
  late ProjectRepository repo;

  setUp(() {
    db = VisaryDatabase.memory();
    repo = ProjectRepository(db);
  });

  tearDown(() => db.close());

  test('insert project+clip+asset, getAllProjects mengembalikan relasi lengkap',
      () async {
    await repo.save(_project('p1'));

    final rows = await db.getAllProjects();
    expect(rows, hasLength(1));
    expect(await db.getClips('p1'), hasLength(2));
    expect(await db.getAssets('p1'), hasLength(1));

    final loaded = (await repo.loadAll()).single;
    expect(loaded.id, 'p1');
    expect(loaded.name, 'p1.mp4');
    expect(loaded.probe!.durationSec, 120.5);
    expect(loaded.probe!.width, 1920);
    expect(loaded.probe!.fps, closeTo(29.97, 1e-9));
    expect(loaded.probe!.hasAudio, isTrue);
    expect(loaded.thumbnailPath, '/tmp/visary/p1/thumb.jpg');
    expect(loaded.stage, JobStage.done);

    final c1 = loaded.clips.firstWhere((c) => c.id == 'p1-c1');
    expect(c1.parts.map((p) => [p.start, p.end]).toList(), [
      [10.0, 25.0],
      [40.0, 55.5],
    ]);
    expect(c1.hook.start, 10);
    expect(c1.hook.end, 13);
    expect(c1.type, ClipType.resequenced);
    expect(c1.selected1x1, isTrue);
    expect(c1.score, 87);

    final a1 = loaded.assets.single;
    expect(a1.type, AssetType.soundBite);
    expect(a1.end, 9.5);
  });

  test('save ulang (update) mengganti clip lama, tidak menduplikasi', () async {
    final p = _project('p1');
    await repo.save(p);
    await repo.save(p.copyWith(clips: [p.clips.first]));

    expect(await db.getAllProjects(), hasLength(1));
    expect(await db.getClips('p1'), hasLength(1));
  });

  test('cascading delete: hapus project ikut hapus clip & asset', () async {
    await repo.save(_project('p1'));
    await repo.save(_project('p2'));

    await repo.delete('p1');

    expect((await db.getAllProjects()).map((r) => r.id), ['p2']);
    expect(await db.getClips('p1'), isEmpty);
    expect(await db.getAssets('p1'), isEmpty);
    // Project lain tidak tersentuh.
    expect(await db.getClips('p2'), hasLength(2));
    expect(await db.getAssets('p2'), hasLength(1));
  });

  test('regression: dua project dengan clip/asset id sama tidak bentrok', () async {
    // Analyzer selalu memberi id clip `c0`, `c1`, ... dan asset `a_s0`, ...
    // yang unik hanya dalam satu project — bukan global.
    Project sameIds(String id) => Project(
          id: id,
          name: '$id.mp4',
          filePath: '/videos/$id.mp4',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          stage: JobStage.done,
          progress: 1,
          clips: [
            Clip(
              id: 'c0',
              title: 'Clip 1',
              parts: const [ClipPart(0, 30)],
              hook: const ClipPart(0, 4),
              score: 85,
              reason: 'x',
              type: ClipType.linear,
            ),
          ],
          assets: [
            AssetItem(
              id: 'a_s0',
              type: AssetType.soundBite,
              title: 'Sound bite',
              sourceFile: '$id.mp4',
              start: 5,
              end: 10,
            ),
          ],
        );

    await repo.save(sameIds('pa'));
    await repo.save(sameIds('pb')); // dulu: UNIQUE constraint failed

    expect(await db.getClips('pa'), hasLength(1));
    expect(await db.getClips('pb'), hasLength(1));
    expect(await db.getAssets('pa'), hasLength(1));
    expect(await db.getAssets('pb'), hasLength(1));
    expect(await db.getAllProjects(), hasLength(2));
  });

  test('regression: update parts clip (split) tidak melanggar PK komposit', () async {
    final p = _project('p1');
    await repo.save(p);
    // Simula split: clip yang sama di-save ulang dengan parts berbeda.
    final split = Clip(
      id: p.clips.first.id,
      title: p.clips.first.title,
      parts: const [ClipPart(10, 17), ClipPart(17, 25), ClipPart(40, 55.5)],
      hook: const ClipPart(10, 13),
      score: 87,
      reason: 'split',
      type: ClipType.resequenced,
    );
    await repo.save(p.copyWith(clips: [split, p.clips[1]]));

    final loaded = await db.getClips('p1');
    final c = loaded.firstWhere((r) => r.id == p.clips.first.id);
    expect(c.partsJson, contains('17'));
    expect(loaded, hasLength(2));
  });
}
