import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/models.dart';
import 'database.dart';

/// Konversi Transcript ↔ DB row (PRD-SPRINT-15 §2.3).
class TranscriptMapper {
  static String _wordsToJson(List<WordToken> words) => jsonEncode(
      words.map((w) => {'word': w.word, 'start': w.start, 'end': w.end}).toList());

  static List<WordToken> _wordsFromJson(String s) {
    final raw = jsonDecode(s) as List;
    return raw
        .map((e) => WordToken(
              word: (e['word'] as String?) ?? '',
              start: ((e['start'] as num?) ?? 0).toDouble(),
              end: ((e['end'] as num?) ?? 0).toDouble(),
            ))
        .toList();
  }

  static TranscriptsTableCompanion transcriptToRow(
    String projectId,
    Transcript t, {
    String? assetId,
  }) =>
      TranscriptsTableCompanion.insert(
        projectId: projectId,
        assetId: Value(assetId),
        fullText: t.fullText,
        wordsJson: _wordsToJson(t.words),
        language: Value(t.language),
        provider: t.provider,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

  static Transcript transcriptFromRow(TranscriptRow r) => Transcript(
        fullText: r.fullText,
        words: _wordsFromJson(r.wordsJson),
        language: r.language,
        provider: r.provider,
      );
}

/// Konversi model domain <-> baris Drift. Tetap terpisah dari model supaya
/// layer domain tidak bergantung pada Drift.
class ProjectMapper {
  static String _partsToJson(List<ClipPart> parts) =>
      jsonEncode(parts.map((p) => [p.start, p.end, p.speed]).toList());

  static List<ClipPart> _partsFromJson(String s) {
    final raw = jsonDecode(s) as List;
    return raw.map((e) {
      final arr = e as List;
      // Speed is optional (index 2) for backward compat with data stored
      // before PRD-SPRINT-15. Old format: [start, end]. New: [start, end, speed].
      final speed = arr.length > 2 ? (arr[2] as num).toDouble() : 1.0;
      return ClipPart(
        (arr[0] as num).toDouble(),
        (arr[1] as num).toDouble(),
        speed,
      );
    }).toList();
  }

  static String _partToJson(ClipPart p) => jsonEncode([p.start, p.end, p.speed]);

  static ClipPart _partFromJson(String s) {
    final e = jsonDecode(s) as List;
    final speed = e.length > 2 ? (e[2] as num).toDouble() : 1.0;
    return ClipPart((e[0] as num).toDouble(), (e[1] as num).toDouble(), speed);
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
      audioMode: Value(p.audioMode.name),
      activeAudioAssetId: Value(p.activeAudioAssetId),
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
        durationSec: Value(a.durationSec),
        audioFormat: Value(a.audioFormat),
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
        durationSec: r.durationSec,
        audioFormat: r.audioFormat,
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
        audioMode: _audioModeFromName(r.audioMode),
        activeAudioAssetId: r.activeAudioAssetId,
      );

  static AudioMode _audioModeFromName(String? s) {
    if (s == null) return AudioMode.original;
    return AudioMode.values.firstWhere(
      (m) => m.name == s,
      orElse: () => AudioMode.original,
    );
  }
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

  // ── Transcript (PRD-SPRINT-15 §2.3) ──

  Future<Transcript?> loadTranscript(String projectId) async {
    final row = await db.getTranscript(projectId);
    if (row == null) return null;
    return TranscriptMapper.transcriptFromRow(row);
  }

  Future<void> saveTranscript(
    String projectId,
    Transcript t, {
    String? assetId,
  }) async {
    await db.upsertTranscript(
        TranscriptMapper.transcriptToRow(projectId, t, assetId: assetId));
  }

  Future<void> deleteTranscript(String projectId) =>
      db.deleteTranscript(projectId);
}
