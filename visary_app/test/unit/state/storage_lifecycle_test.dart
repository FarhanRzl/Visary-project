import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visary/data/local/database.dart';
import 'package:visary/data/local/project_repository.dart';
import 'package:visary/data/local/workspace_storage.dart';
import 'package:visary/models/models.dart';
import 'package:visary/state/app_state.dart';

/// Test 2.2 — PRD-SPRINT-02 §4: lifecycle folder workspace & persistensi
/// AppState lintas "restart".
Project _done(String id) => Project(
      id: id,
      name: '$id.mp4',
      filePath: '/videos/$id.mp4',
      createdAt: DateTime.now(),
      probe: const VideoProbe(
        durationSec: 60,
        width: 1080,
        height: 1920,
        fps: 30,
        codec: 'h264',
        hasAudio: false,
      ),
      stage: JobStage.done,
      progress: 1,
      clips: [
        Clip(
          id: '$id-c1',
          title: 'c1',
          parts: const [ClipPart(0, 30)],
          hook: const ClipPart(0, 3),
          score: 50,
          reason: 'r',
          type: ClipType.linear,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpRoot;
  late WorkspaceStorage storage;
  late VisaryDatabase db;
  late ProjectRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmpRoot = await Directory.systemTemp.createTemp('visary_ws_test_');
    storage = WorkspaceStorage(root: tmpRoot);
    db = VisaryDatabase.memory();
    repo = ProjectRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tmpRoot.exists()) await tmpRoot.delete(recursive: true);
  });

  test('ensure() membuat direktori workspace project', () async {
    final d = await storage.ensure('p1');
    expect(await d.exists(), isTrue);
    expect(d.path, '${tmpRoot.path}/p1');
  });

  test('removeProject menghapus folder fisik, entri DB, dan state memori',
      () async {
    final state = AppState(repo: repo, storage: storage);
    final dir = await storage.ensure('p1');
    await File('${dir.path}/thumb.jpg').writeAsBytes([1, 2, 3]);
    await File('${dir.path}/preview_0.0_5.0.mp4').writeAsBytes([4, 5]);

    state.projects.add(_done('p1'));
    await repo.save(_done('p1'));

    await state.removeProject('p1');

    expect(await dir.exists(), isFalse);
    expect(await db.getAllProjects(), isEmpty);
    expect(await db.getClips('p1'), isEmpty);
    expect(state.projects, isEmpty);
  });

  test('removeProject aman bila folder tidak ada', () async {
    final state = AppState(repo: repo, storage: storage);
    state.projects.add(_done('ghost'));
    await state.removeProject('ghost');
    expect(state.projects, isEmpty);
  });

  test('project tetap ada setelah "restart" (AppState baru, DB sama)',
      () async {
    final first = AppState(repo: repo, storage: storage);
    first.projects.add(_done('p1').copyWith(stage: JobStage.probe));
    // Update ke `done` memicu penyimpanan otomatis.
    first.updateClipRange('p1', 'p1-c1', 0, 20); // stage probe → tidak disimpan
    await first.flush();
    expect(await db.getAllProjects(), isEmpty,
        reason: 'project yang belum selesai tidak boleh disimpan');

    first.projects[0] = _done('p1');
    first.updateClipRange('p1', 'p1-c1', 5, 25);
    await first.flush();

    final second = AppState(repo: repo, storage: storage);
    await second.loadProjects();
    expect(second.projects, hasLength(1));
    final clip = second.projects.single.clips.single;
    expect(clip.parts.single.start, 5);
    expect(clip.parts.single.end, 25);
    expect(second.activeProjectId, 'p1');
  });

  test('loadProjects membersihkan folder yatim, folder project valid tetap',
      () async {
    await repo.save(_done('keep'));
    final keep = await storage.ensure('keep');
    final orphan = await storage.ensure('orphan_failed');
    await File('${orphan.path}/thumb.jpg').writeAsBytes([0]);

    final state = AppState(repo: repo, storage: storage);
    await state.loadProjects();

    expect(await keep.exists(), isTrue);
    expect(await orphan.exists(), isFalse);
  });

  test('toggleFormat ikut tersimpan', () async {
    final state = AppState(repo: repo, storage: storage);
    state.projects.add(_done('p1'));
    state.setActiveProject('p1');
    state.toggleFormat('p1-c1', v11: true);
    await state.flush();

    final loaded = (await repo.loadAll()).single;
    expect(loaded.clips.single.selected1x1, isTrue);
  });
}
