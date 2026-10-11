import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/models.dart';
import 'database.dart';

/// Konversi model domain <-> baris Drift. Tetap terpisah dari model supaya
/// layer domain tidak bergantung pada Drift.
class ProjectMapper {
  static String _partsToJson(List<ClipPart> parts) =>
      jsonEncode(parts.map((p) => [p.start, p.end]).toList());

  static List<ClipPart> _partsFromJson(String s) {
    final raw = jsonDecode(s) as List;
    return raw
        .map((e) => ClipPart(
              (e[0] as num).toDouble(),
              (e[1] as num).toDouble(),
            ))
        .toList();
  }

  static String _partToJson(ClipPart p) => jsonEncode([p.start, p.end]);

  static ClipPart _partFromJson(String s) {
    final e = jsonDecode(s) as List;
    return ClipPart((e[0] as num).toDouble(), (e[1] as num).toDouble());
  }

  static ProjectsTableCompanion projectToRow(Project p) {
    final probe = p.probe;
    return ProjectsTableCompanion.insert(
      id: p.id,
      name: p.name,
      filePath: p.filePath,
      duration: probe?.durationSec ?? 0,
      width: probe?.width ?? 0,
      height: probe?.height ?? 0,
      fps: probe?.fps ?? 0,
      hasAudio: probe?.hasAudio ?? false,
      createdAt: p.createdAt.millisecondsSinceEpoch,
      thumbnailPath: Value(p.thumbnailPath),
    );
  }

  static ClipsTableCompanion clipToRow(String projectId, Clip c) =>
      ClipsTableCompanion.insert(
        id: c.id,
        projectId: projectId,
        title: c.title,
        score: c.score,
        reason: c.reason,
        type: c.type.name,
        partsJson: _partsToJson(c.parts),
        hookJson: _partToJson(c.hook),
        selected9x16: c.selected9x16,
        selected1x1: c.selected1x1,
      );

  static AssetsTableCompanion assetToRow(String projectId, AssetItem a) =>
      AssetsTableCompanion.insert(
        id: a.id,
        projectId: projectId,
        type: a.type.name,
        title: a.title,
        sourceFile: a.sourceFile,
        startSec: a.start,
        endSec: a.end,
      );

  static Clip clipFromRow(ClipRow r) => Clip(
        id: r.id,
        title: r.title,
        parts: _partsFromJson(r.partsJson),
        hook: _partFromJson(r.hookJson),
        score: r.score,
        reason: r.reason,
        type: ClipType.values.firstWhere(
          (t) => t.name == r.type,
          orElse: () => ClipType.linear,
        ),
        selected9x16: r.selected9x16,
        selected1x1: r.selected1x1,
      );

  static AssetItem assetFromRow(AssetRow r) => AssetItem(
        id: r.id,
        type: AssetType.values.firstWhere(
          (t) => t.name == r.type,
          orElse: () => AssetType.hook,
        ),
        title: r.title,
        sourceFile: r.sourceFile,
        start: r.startSec,
        end: r.endSec,
      );

  /// Project yang dimuat dari DB selalu berstatus `done` — hanya project
  /// yang analisisnya selesai yang disimpan (lihat AppState).
  static Project projectFromRow(
    ProjectRow r, {
    required List<Clip> clips,
    required List<AssetItem> assets,
  }) =>
      Project(
        id: r.id,
        name: r.name,
        filePath: r.filePath,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
        probe: VideoProbe(
          durationSec: r.duration,
          width: r.width,
          height: r.height,
          fps: r.fps,
          codec: '',
          hasAudio: r.hasAudio,
        ),
        stage: JobStage.done,
        progress: 1,
        clips: clips,
        assets: assets,
        thumbnailPath: r.thumbnailPath,
      );
}

/// Repository project: satu-satunya pintu AppState ke SQLite.
class ProjectRepository {
  ProjectRepository(this.db);
  final VisaryDatabase db;

  /// Muat semua project lengkap dengan clip & asset (relasi).
  Future<List<Project>> loadAll() async {
    final rows = await db.getAllProjects();
    final out = <Project>[];
    for (final r in rows) {
      final clips = (await db.getClips(r.id)).map(ProjectMapper.clipFromRow);
      final assets =
          (await db.getAssets(r.id)).map(ProjectMapper.assetFromRow);
      out.add(ProjectMapper.projectFromRow(
        r,
        clips: clips.toList(),
        assets: assets.toList(),
      ));
    }
    return out;
  }

  /// Simpan project + seluruh clip & asset-nya secara atomik.
  Future<void> save(Project p) async {
    await db.transaction(() async {
      await db.upsertProject(ProjectMapper.projectToRow(p));
      await db.replaceClips(
        p.id,
        p.clips.map((c) => ProjectMapper.clipToRow(p.id, c)).toList(),
      );
      await db.replaceAssets(
        p.id,
        p.assets.map((a) => ProjectMapper.assetToRow(p.id, a)).toList(),
      );
    });
  }

  Future<void> delete(String id) => db.deleteProject(id);

  Future<Set<String>> allIds() async =>
      (await db.getAllProjects()).map((r) => r.id).toSet();
}
