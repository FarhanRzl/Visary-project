import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/project_repository.dart';
import '../data/local/workspace_storage.dart';
import '../models/models.dart';
import '../services/ai_provider_service.dart';
import '../services/ai_service.dart';
import '../services/content_matcher_service.dart';
import '../services/local_analyzer.dart';
import '../services/resequence_service.dart';
import '../services/video_service.dart' show VideoService, FfmpegMissingException, BrollOverlay;

/// State global aplikasi.
///
/// Tidak ada data contoh: project hanya lahir dari file yang benar-benar
/// diupload user, metadata datang dari ffprobe, dan kandidat clip/hook/asset
/// dihitung dari sinyal FFmpeg nyata (mode dasar, PRD §7.5).
///
/// Persistensi (PRD-SPRINT-02): bila [repo] diberikan, project yang selesai
/// dianalisis disimpan ke SQLite dan dimuat ulang saat startup. Tanpa [repo]
/// (mis. di widget test) state hanya hidup di memori.
class AppState extends ChangeNotifier {
  AppState({
    this.repo,
    WorkspaceStorage? storage,
    AiProviderService? aiService,
  })  : storage = storage ?? WorkspaceStorage(),
        aiService = aiService ?? AiProviderService() {
    aiBrollService = AiService(providerService: aiService);
  }

  final ProjectRepository? repo;
  final WorkspaceStorage storage;
  final AiProviderService aiService;
  late final AiService aiBrollService;

  final List<Project> projects = [];
  String? activeProjectId;

  /// BYOK & AI Settings (PRD-SPRINT-06)
  bool byokEnabled = false;
  AiProviderType activeAiProvider = AiProviderType.server;
  String geminiApiKey = '';
  String openAiApiKey = '';
  String groqApiKey = '';
  String customApiKey = '';
  String customBaseUrl = '';
  String customModel = 'gpt-4o-mini';

  bool get isByokActive => byokEnabled && activeAiProvider != AiProviderType.server;

  /// Null sampai login/akun tersedia (PRD §4.9 — belum ada backend).
  AppUser? user;

  static const _prefsUserId = 'session.user.id';
  static const _prefsUserName = 'session.user.name';
  static const _prefsUserEmail = 'session.user.email';
  static const _prefsUserQuotaUsed = 'session.user.quotaUsed';
  static const _prefsUserQuotaTotal = 'session.user.quotaTotal';
  static const _prefsUserPlan = 'session.user.plan';

  /// Memuat pengaktifan BYOK & API key tersimpan (PRD-SPRINT-06).
  Future<void> loadAiSettings() async {
    byokEnabled = await aiService.storage.getByokEnabled();
    activeAiProvider = await aiService.storage.getActiveProvider();
    geminiApiKey = (await aiService.storage.getGeminiKey()) ?? '';
    openAiApiKey = (await aiService.storage.getOpenAiKey()) ?? '';
    groqApiKey = (await aiService.storage.getGroqKey()) ?? '';
    customApiKey = (await aiService.storage.getCustomKey()) ?? '';
    customBaseUrl = (await aiService.storage.getCustomBaseUrl()) ?? '';
    customModel = (await aiService.storage.getCustomModel()) ?? 'gpt-4o-mini';
    notifyListeners();
  }

  /// Menyimpan konfigurasi BYOK & API key ke storage terenkripsi.
  Future<void> saveAiSettings({
    required bool enabled,
    required AiProviderType provider,
    String? geminiKey,
    String? openAiKey,
    String? groqKey,
    String? customKey,
    String? customBaseUrl,
    String? customModel,
  }) async {
    byokEnabled = enabled;
    activeAiProvider = provider;
    if (geminiKey != null) geminiApiKey = geminiKey.trim();
    if (openAiKey != null) openAiApiKey = openAiKey.trim();
    if (groqKey != null) groqApiKey = groqKey.trim();
    if (customKey != null) customApiKey = customKey.trim();
    if (customBaseUrl != null) this.customBaseUrl = customBaseUrl.trim();
    if (customModel != null) this.customModel = customModel.trim();

    await aiService.storage.setByokEnabled(enabled);
    await aiService.storage.setActiveProvider(provider);
    if (geminiKey != null) await aiService.storage.saveGeminiKey(geminiApiKey);
    if (openAiKey != null) await aiService.storage.saveOpenAiKey(openAiApiKey);
    if (groqKey != null) await aiService.storage.saveGroqKey(groqApiKey);
    if (customKey != null) await aiService.storage.saveCustomKey(customApiKey);
    if (customBaseUrl != null) {
      await aiService.storage.saveCustomBaseUrl(this.customBaseUrl);
    }
    if (customModel != null) {
      await aiService.storage.saveCustomModel(this.customModel);
    }

    notifyListeners();
  }

  /// Tes koneksi API key langsung ke provider (PRD-SPRINT-06 §3.4).
  Future<ConnectionTestResult> testAiConnection(
    AiProviderType provider,
    String apiKey, {
    String? baseUrl,
  }) =>
      aiService.testConnection(provider, apiKey, baseUrl: baseUrl);
  /// Dipanggil sekali saat app start; null jika belum pernah login.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsUserId);
    if (id == null) return;
    user = AppUser(
      id: id,
      name: prefs.getString(_prefsUserName) ?? '',
      email: prefs.getString(_prefsUserEmail) ?? '',
      quota: QuotaInfo(
        usedMinutes: prefs.getInt(_prefsUserQuotaUsed) ?? 0,
        totalMinutes: prefs.getInt(_prefsUserQuotaTotal) ?? 0,
        resetAt: DateTime.now().add(const Duration(days: 30)),
        planName: prefs.getString(_prefsUserPlan) ?? 'Free',
      ),
    );
    notifyListeners();
  }

  /// Simpan sesi user ke disk supaya login bertahan antar sesi app.
  Future<void> persistSession(AppUser u) async {
    user = u;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUserId, u.id);
    await prefs.setString(_prefsUserName, u.name);
    await prefs.setString(_prefsUserEmail, u.email);
    await prefs.setInt(_prefsUserQuotaUsed, u.quota.usedMinutes);
    await prefs.setInt(_prefsUserQuotaTotal, u.quota.totalMinutes);
    await prefs.setString(_prefsUserPlan, u.quota.planName);
  }

  /// Potong kuota menit server jika BYOK tidak aktif (PRD-SPRINT-06 §3.1).
  /// Mengembalikan true bila kuota cukup / BYOK aktif, false bila kuota habis.
  bool useQuota(int minutes) {
    if (isByokActive) return true; // Bypass potong kuota server saat BYOK
    final u = user;
    if (u == null) return true;
    final q = u.quota;
    if (q.usedMinutes + minutes > q.totalMinutes) return false;
    user = AppUser(
      id: u.id,
      name: u.name,
      email: u.email,
      quota: QuotaInfo(
        usedMinutes: q.usedMinutes + minutes,
        totalMinutes: q.totalMinutes,
        resetAt: q.resetAt,
        planName: q.planName,
      ),
    );
    persistSession(user!);
    return true;
  }

  /// Hapus sesi tersimpan (logout nyata, bukan sekadar navigasi).
  Future<void> clearSession() async {
    user = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsUserId);
    await prefs.remove(_prefsUserName);
    await prefs.remove(_prefsUserEmail);
    await prefs.remove(_prefsUserQuotaUsed);
    await prefs.remove(_prefsUserQuotaTotal);
    await prefs.remove(_prefsUserPlan);
  }

  /// Hasil scan sinyal per project, supaya re-generate clip tidak perlu
  /// analisis ulang (PRD §4.1 "hasil analisis di-cache").
  final Map<String, VideoSignals> _signals = {};

  /// Pesan global terakhir (mis. ffmpeg tidak ada) untuk ditampilkan UI.
  String? toolingError;

  /// Pesan error ASR terakhir (non-fatal — pipeline tetap jalan tanpa transcript).
  String? asrError;

  Project? get activeProject =>
      projects.where((p) => p.id == activeProjectId).firstOrNull;

  Project? byId(String? id) =>
      id == null ? null : projects.where((p) => p.id == id).firstOrNull;

  VideoSignals? signalsOf(String projectId) => _signals[projectId];

  @visibleForTesting
  void setSignalsForTest(String projectId, VideoSignals signals) {
    _signals[projectId] = signals;
  }

  Future<Directory> _workDir(String projectId) => storage.ensure(projectId);

  void _put(Project p) {
    final i = projects.indexWhere((e) => e.id == p.id);
    if (i >= 0) projects[i] = p;
    notifyListeners();
    if (p.stage == JobStage.done) _persist(p);
  }

  /// Penulisan DB terakhir — ditunggu oleh test & saat shutdown.
  Future<void> _pendingWrite = Future.value();

  /// Selesaikan semua penulisan DB yang masih antre.
  Future<void> flush() => _pendingWrite;

  /// Simpan ke SQLite secara berurutan (antre), supaya update cepat
  /// beruntun (drag trim) tidak saling balapan.
  void _persist(Project p) {
    final r = repo;
    if (r == null) return;
    _pendingWrite = _pendingWrite.then((_) => r.save(p)).catchError((Object e) {
      debugPrint('Gagal menyimpan project ${p.id}: $e');
    });
  }

  /// Muat project tersimpan dari SQLite lalu bersihkan folder temp yatim
  /// (PRD-SPRINT-02 §2.2–2.3). Dipanggil sekali saat startup.
  Future<void> loadProjects() async {
    final r = repo;
    if (r == null) return;
    final loaded = await r.loadAll();
    projects
      ..clear()
      ..addAll(loaded);
    activeProjectId ??= projects.firstOrNull?.id;

    // Restore transcript dari DB ke _signals (PRD-SPRINT-15 §2.3).
    // VideoSignals adalah in-memory only — setelah restart, _signals kosong.
    // Transcript yang sudah di-persist perlu di-restore supaya user tidak
    // perlu re-transcribe setiap restart.
    for (final p in projects) {
      final t = await r.loadTranscript(p.id);
      if (t != null && t.words.isNotEmpty) {
        // Buat minimal VideoSignals supaya transcript bisa disimpan.
        // Shot boundaries dan energy tidak di-restore (harus re-scan).
        final dur = p.probe?.durationSec ?? 0;
        _signals[p.id] ??= VideoSignals(
            shots: [0, dur], energy: const [], duration: dur);
        _signals[p.id]!.transcript = t;
      }
    }

    notifyListeners();
    await storage.cleanOrphans(projects.map((p) => p.id).toSet());
  }

  /// Upload → probe → analisis lokal. Semua tahap memakai file asli di disk.
  Future<String> addProjectFromUpload(String fileName, {String? filePath}) async {
    if (filePath == null || filePath.isEmpty || !File(filePath).existsSync()) {
      throw FileSystemException('File video tidak ditemukan', filePath ?? fileName);
    }
    if (!await VideoService.isAvailable()) {
      toolingError = 'FFmpeg/FFprobe tidak ditemukan di PATH.';
      notifyListeners();
      throw FfmpegMissingException('ffmpeg');
    }

    final id = 'p${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
    var project = Project(
      id: id,
      name: fileName,
      filePath: filePath,
      createdAt: DateTime.now(),
      stage: JobStage.probe,
    );
    projects.insert(0, project);
    activeProjectId = id;
    notifyListeners();

    try {
      // 1. Probe metadata asli.
      final probe = await VideoService.probe(filePath);
      project = project.copyWith(probe: probe, progress: 0.15, stage: JobStage.shotOcr);
      _put(project);

      // 2. Thumbnail nyata dari frame video.
      final dir = await _workDir(id);
      final thumb = await VideoService.extractThumbnail(
        sourcePath: filePath,
        atSec: min(1.0, probe.durationSec / 10),
        outPath: '${dir.path}/thumb.jpg',
      );
      if (thumb != null) {
        project = project.copyWith(thumbnailPath: thumb);
        _put(project);
      }

      // 3. Sinyal: shot boundary + energi audio.
      final signals = await LocalAnalyzer.scan(filePath, probe);
      _signals[id] = signals;

      // 3b. ASR (transkripsi audio) — cloud via provider (PRD-SPRINT-11).
      if (probe.hasAudio) {
        project = project.copyWith(stage: JobStage.asr, progress: 0.45);
        _put(project);
        try {
          final asrAudio = '${dir.path}/asr_input.m4a';
          await VideoService.extractAudio(
            sourcePath: filePath,
            start: 0,
            end: probe.durationSec,
            outputPath: asrAudio,
          );
          signals.transcript = await aiService.transcribe(audioFilePath: asrAudio);
          debugPrint(
              '[ASR] transkrip: ${signals.transcript?.words.length ?? 0} words, '
              'provider=${signals.transcript?.provider}, '
              'empty=${signals.transcript?.isEmpty}');

          // Persist transcript ke DB (PRD-SPRINT-15 §2.3).
          // Survive restart — user tidak perlu re-transcribe.
          if (repo != null && signals.transcript != null) {
            await repo!.saveTranscript(id, signals.transcript!);
          }
        } catch (e) {
          // ASR gagal — pipeline tetap jalan tanpa transcript, tapi simpan
          // pesan error supaya UI bisa tampilkan ke user (bukan silent fail).
          asrError = e.toString();
          debugPrint('ASR gagal (non-fatal, fallback tanpa transkrip): $e');
        }
      }

      project = project.copyWith(progress: 0.6, stage: JobStage.llmSelect);
      _put(project);

      // 4. Hook → clip → asset, semua turunan sinyal di atas.
      final hooks = LocalAnalyzer.hooks(signals);
      final clips = LocalAnalyzer.clips(signals, hooks);
      final assets = LocalAnalyzer.assets(signals, hooks, fileName);

      project = project.copyWith(
        hooks: hooks,
        clips: clips,
        assets: assets,
        progress: 1,
        stage: JobStage.done,
      );
      _put(project);

      // Enrich B-roll recommendations (PRD-SPRINT-05) — async, non-blocking.
      enrichBrollRecommendations(id);

      return id;
    } catch (e) {
      _put(project.copyWith(stage: JobStage.error, progress: 0, errorMessage: '$e'));
      rethrow;
    }
  }

  /// Hitung ulang kandidat clip dengan target durasi berbeda (PRD §4.5):
  /// memakai sinyal yang sudah di-cache, jadi instan tanpa analisis ulang.
  void regenerateClips(String projectId, {double targetMin = 30, double targetMax = 60}) {
    final p = byId(projectId);
    final s = _signals[projectId];
    if (p == null || s == null) return;
    _put(p.copyWith(
      clips: LocalAnalyzer.clips(s, p.hooks, targetMin: targetMin, targetMax: targetMax),
    ));
  }

  /// Jadikan hook sebagai pembuka clip terpilih (PRD §4.3) — clip jadi
  /// re-sequenced: hook di depan, sisa segmen menyusul.
  void applyHookAsOpener(String projectId, String clipId, HookCandidate hook) {
    final p = byId(projectId);
    if (p == null) return;
    final i = p.clips.indexWhere((c) => c.id == clipId);
    if (i < 0) return;
    final old = p.clips[i];
    final a = old.parts.first.start, b = old.parts.last.end;
    final parts = <ClipPart>[
      ClipPart(hook.start, hook.end),
      if (hook.start > a) ClipPart(a, hook.start),
      if (hook.end < b) ClipPart(hook.end, b),
    ];
    final clips = [...p.clips];
    clips[i] = Clip(
      id: old.id,
      title: old.title,
      parts: parts,
      hook: ClipPart(hook.start, hook.end),
      score: old.score,
      reason: 'Hook ${fmtSec(hook.start)} dipindah ke depan (re-sequenced).',
      type: ClipType.resequenced,
      selected9x16: old.selected9x16,
      selected1x1: old.selected1x1,
    );
    _put(p.copyWith(clips: clips));
  }

  /// Ubah trim clip dari editor manual (PRD §4.8), snap dilakukan di UI.
  void updateClipRange(String projectId, String clipId, double start, double end) {
    final p = byId(projectId);
    if (p == null || end <= start) return;
    final i = p.clips.indexWhere((c) => c.id == clipId);
    if (i < 0) return;
    final old = p.clips[i];
    final s = _signals[projectId];
    final clips = [...p.clips];
    clips[i] = Clip(
      id: old.id,
      title: old.title,
      parts: [ClipPart(start, end)],
      hook: ClipPart(start, min(end, start + LocalAnalyzer.hookMax)),
      score: s == null ? old.score : LocalAnalyzer.scoreRange(s, start, end),
      reason: 'Trim manual ${fmtSec(start)}–${fmtSec(end)}.',
      type: ClipType.linear,
      selected9x16: old.selected9x16,
      selected1x1: old.selected1x1,
      brollRecommendations: old.brollRecommendations,
    );
    _put(p.copyWith(clips: clips));
  }

  /// Update seluruh parts clip sekaligus (PRD-SPRINT-09 multi-part editing).
  /// Dipakai untuk split, delete segment, reorder, ripple edit.
  void updateClipParts(String projectId, String clipId, List<ClipPart> parts) {
    final p = byId(projectId);
    if (p == null || parts.isEmpty) return;
    final i = p.clips.indexWhere((c) => c.id == clipId);
    if (i < 0) return;
    final old = p.clips[i];
    final clips = [...p.clips];
    clips[i] = Clip(
      id: old.id,
      title: old.title,
      parts: parts,
      hook: old.hook,
      score: old.score,
      reason: old.reason,
      type: parts.length > 1 ? ClipType.resequenced : ClipType.linear,
      selected9x16: old.selected9x16,
      selected1x1: old.selected1x1,
      brollRecommendations: old.brollRecommendations,
    );
    _put(p.copyWith(clips: clips));
  }

  void addAsset(String projectId, AssetItem item) {
    final p = byId(projectId);
    if (p == null) return;
    if (p.assets.any((a) => a.id == item.id)) return;
    _put(p.copyWith(assets: [...p.assets, item]));
  }

  void removeAsset(String projectId, String assetId) {
    final p = byId(projectId);
    if (p == null) return;
    _put(p.copyWith(assets: p.assets.where((a) => a.id != assetId).toList()));
  }

  void setActiveProject(String id) {
    activeProjectId = id;
    notifyListeners();
  }

  // ─────────────────────── AUDIO TRACK (PRD-SPRINT-10) ──────────────────

  /// Upload file audio eksternal → AssetItem(type: audio) di project.
  /// File disalin ke workspace `<projectId>/audio/`. Mengembalikan aset.
  Future<AssetItem> uploadAudioAsset(
    String projectId, {
    required String fileName,
    String? filePath,
  }) async {
    final p = byId(projectId);
    if (p == null) throw StateError('Project tidak ditemukan');
    if (filePath == null || filePath.isEmpty) {
      throw ArgumentError('filePath audio wajib');
    }
    final dir = await _workDir(projectId);
    final audioDir = Directory('${dir.path}/audio');
    if (!await audioDir.exists()) await audioDir.create(recursive: true);
    final ext = _audioExt(fileName);
    final id = 'a_au${DateTime.now().millisecondsSinceEpoch}';
    final dest = '${audioDir.path}/$id.$ext';
    await File(filePath).copy(dest);

    final probe = await VideoService.probe(dest);
    final asset = AssetItem(
      id: id,
      type: AssetType.audio,
      title: fileName,
      sourceFile: dest,
      start: 0,
      end: probe.durationSec,
      durationSec: probe.durationSec,
      audioFormat: probe.audioCodec ?? ext,
    );
    addAsset(projectId, asset);
    return asset;
  }

  /// Ekstrak audio dari video sumber (rentang [start]–[end]) → AssetItem.
  /// Default range = seluruh durasi video sumber.
  Future<AssetItem> extractAudioAsset(
    String projectId, {
    double? start,
    double? end,
  }) async {
    final p = byId(projectId);
    if (p == null) throw StateError('Project tidak ditemukan');
    final dur = p.probe?.durationSec ?? 0;
    final s = start ?? 0;
    final e = end ?? dur;
    if (e <= s) throw ArgumentError('rentang waktu tidak valid');

    final dir = await _workDir(projectId);
    final audioDir = Directory('${dir.path}/audio');
    if (!await audioDir.exists()) await audioDir.create(recursive: true);
    final id = 'a_ex${DateTime.now().millisecondsSinceEpoch}';
    final outPath = '${audioDir.path}/$id.aac';

    final res = await VideoService.extractAudio(
      sourcePath: p.filePath,
      start: s,
      end: e,
      outputPath: outPath,
    );
    final asset = AssetItem(
      id: id,
      type: AssetType.audio,
      title: 'Audio ${s.toStringAsFixed(0)}-${e.toStringAsFixed(0)}s',
      sourceFile: res.path,
      start: s,
      end: e,
      durationSec: res.durationSec,
      audioFormat: res.format,
    );
    addAsset(projectId, asset);
    return asset;
  }

  /// Set mode audio project (original/muted/replacement).
  void setAudioMode(String projectId, AudioMode mode) {
    final p = byId(projectId);
    if (p == null) return;
    _put(p.copyWith(audioMode: mode));
  }

  /// Pilih aset audio aktif sebagai pengganti + set mode replacement.
  void setActiveAudioAsset(String projectId, String assetId) {
    final p = byId(projectId);
    if (p == null) return;
    _put(p.copyWith(
      audioMode: AudioMode.replacement,
      activeAudioAssetId: assetId,
    ));
  }

  /// Bangun file preview (video-mute + audio pengganti) untuk editor
  /// (PRD-SPRINT-10 §3.2, Approach 2). Mengembalikan path preview, atau
  /// null jika tidak ada audio pengganti aktif.
  Future<String?> buildPreviewWithAudio(String projectId) async {
    final p = byId(projectId);
    if (p == null) return null;
    final audio = p.activeAudioAsset;
    if (audio == null) return null;
    final dir = await _workDir(projectId);
    final outPath = '${dir.path}/preview_audio.mp4';
    await VideoService.muxPreviewAudio(
      videoPath: p.filePath,
      audioPath: audio.sourceFile,
      outputPath: outPath,
    );
    return outPath;
  }

  /// Ekstensi file audio dari nama file (lowercase, tanpa titik).
  String _audioExt(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return 'aac';
    return fileName.substring(dot + 1).toLowerCase();
  }

  // ─────────── AUDIO-DRIVEN RE-SEQUENCING (PRD-SPRINT-13) ──────────────

  static const _resequencer = Resequencer();

  /// Transkripsi audio pengganti → timpa transcript → re-sequence clips.
  /// PRD-SPRINT-13 §2.1.
  Future<void> transcribeReplacementAudio(String projectId) async {
    final p = byId(projectId);
    if (p == null) throw StateError('Project tidak ditemukan');
    final audio = p.activeAudioAsset;
    if (audio == null) throw StateError('Tidak ada audio pengganti aktif');

    // Signals mungkin belum ada di memori (app restart). Buat minimal
    // VideoSignals supaya transkripsi + resequence bisa jalan. Resequencer
    // akan fallback ke segmen 3s bila shots kosong.
    var signals = _signals[projectId];
    if (signals == null) {
      final dur = p.probe?.durationSec ?? 0;
      signals = VideoSignals(shots: [0, dur], energy: const [], duration: dur);
      _signals[projectId] = signals;
    }

    // Convert audio pengganti ke .m4a (AAC in MP4 container) untuk
    // kompatibilitas ASR API (Groq/OpenAI tidak support raw .aac).
    final dir = await _workDir(projectId);
    final asrAudioPath = '${dir.path}/asr_replacement.m4a';
    final audioDur = audio.durationSec ?? (p.probe?.durationSec ?? 60);
    await VideoService.extractSegment(
      sourcePath: audio.sourceFile,
      start: 0,
      end: audioDur,
      outputPath: asrAudioPath,
      audioOnly: true,
    );

    final t = await aiService.transcribe(audioFilePath: asrAudioPath);
    signals.transcript = t;
    debugPrint('[S13] transkrip audio pengganti: ${t.words.length} words, '
        'provider=${t.provider}');

    // Persist transcript replacement ke DB (PRD-SPRINT-15 §2.3).
    if (repo != null) {
      await repo!.saveTranscript(projectId, t, assetId: audio.id);
    }

    resequenceClips(projectId);
    notifyListeners();
  }

  /// Re-sequence clip parts berdasarkan word boundary dari transcript.
  /// PRD-SPRINT-13 §2.2 + PRD-SPRINT-14 (matchOrder passthrough).
  void resequenceClips(String projectId, {List<int>? matchOrder}) {
    final p = byId(projectId);
    if (p == null) return;
    final signals = _signals[projectId];
    if (signals == null) return;
    final t = signals.transcript;
    if (t == null || t.words.isEmpty) return;

    final newClips = _resequencer.resequence(
      clips: p.clips,
      signals: signals,
      videoDuration: p.probe?.durationSec ?? 0,
      matchOrder: matchOrder,
    );
    _put(p.copyWith(clips: newClips));
  }

  /// Apply matchOrder ke clip parts tanpa word-boundary resequencing.
  /// Dipakai saat content matching jalan tanpa transcript (visual-only).
  /// Video dibagi N segmen sesuai matchOrder, speed-adjust ke durasi clip.
  /// PRD-SPRINT-15 §2.5.
  void _resequenceVisualOnly(String projectId, List<int> matchOrder) {
    final p = byId(projectId);
    if (p == null || matchOrder.isEmpty) return;
    final videoDuration = p.probe?.durationSec ?? 0;
    if (videoDuration <= 0) return;

    final numSegs = matchOrder.length;
    final videoSegDur = videoDuration / numSegs;
    final newClips = p.clips.map((clip) {
      final parts = <ClipPart>[];
      for (var i = 0; i < numSegs; i++) {
        final segIdx = matchOrder[i];
        final vStart = segIdx * videoSegDur;
        final vEnd = (segIdx + 1) * videoSegDur;
        parts.add(ClipPart(vStart, vEnd, 1.0));
      }
      return clip.copyWith(parts: parts, type: ClipType.resequenced);
    }).toList();
    _put(p.copyWith(clips: newClips));
  }

  // ─────── CONTENT-AWARE MATCHING (PRD-SPRINT-14) ───────────

  /// Multi-stage content-aware re-sequencing pipeline.
  /// PRD-SPRINT-14 §2.7.
  ///
  /// 1. Extract frames per shot → VLM describe → visual descriptions.
  /// 2. Extract audio topics from transcript.
  /// 3. Match content via LLM → match order.
  /// 4. Resequence clips with matchOrder.
  ///
  /// [onProgress] menerima label tahap untuk UI multi-stage progress.
  /// Fallback: bila VLM/LLM gagal di tahap manapun → timing-based (S13).
  Future<List<int>> contentAwareResequence(
    String projectId, {
    void Function(String stage)? onProgress,
  }) async {
    final p = byId(projectId);
    if (p == null) throw StateError('Project tidak ditemukan');
    final signals = _signals[projectId];
    if (signals == null) throw StateError('Sinyal video belum dianalisis');
    final t = signals.transcript;
    // Visual-only fallback: transcript boleh null/kosong — matching jalan
    // dengan visual descriptions saja (PRD-SPRINT-15 §2.5).
    final hasTranscript = t != null && t.words.isNotEmpty;

    final videoDuration = p.probe?.durationSec ?? 0;
    final dir = await _workDir(projectId);
    final matcher = ContentMatcherService(aiService);

    // ── Cek provider: Groq/Server tidak support vision ──
    final provider = await aiService.storage.getActiveProvider();
    final byokActive = await aiService.isByokActive();
    if (byokActive &&
        (provider == AiProviderType.groq || provider == AiProviderType.server)) {
      throw UnsupportedError(
          'Vision API butuh Gemini atau OpenAI. Switch provider di Settings.');
    }

    List<int>? matchOrder;

    // ── Stage 1: Extract frames per shot ──
    onProgress?.call('Extracting frames...');
    final framePaths = <String>[];
    final framesDir = Directory('${dir.path}/frames');
    if (!await framesDir.exists()) await framesDir.create(recursive: true);

    // Shot midpoints: 1 frame per shot, timestamp = (shot[i] + shot[i+1]) / 2.
    final shots = signals.shots;
    final frameTimestamps = <double>[];
    if (shots.length > 1) {
      for (var i = 0; i < shots.length - 1; i++) {
        final mid = (shots[i] + shots[i + 1]) / 2;
        frameTimestamps.add(mid);
      }
    } else {
      // Fallback: extract frame per 3 detik.
      for (double s = 1.5; s < videoDuration; s += 3) {
        frameTimestamps.add(s);
      }
    }

    // Limit max 20 frames (PRD §6 risk mitigation).
    if (frameTimestamps.length > 20) {
      // Subsample evenly.
      final step = frameTimestamps.length / 20;
      final sampled = <double>[];
      for (var i = 0; i < 20; i++) {
        sampled.add(frameTimestamps[(i * step).floor()]);
      }
      frameTimestamps.clear();
      frameTimestamps.addAll(sampled);
    }

    for (var i = 0; i < frameTimestamps.length; i++) {
      final outPath = '${framesDir.path}/shot_$i.jpg';
      try {
        await VideoService.extractFrame(
          sourcePath: p.filePath,
          timestamp: frameTimestamps[i],
          outputPath: outPath,
        );
        framePaths.add(outPath);
      } catch (e) {
        debugPrint('[S14] frame extraction gagal untuk shot $i: $e');
      }
    }

    if (framePaths.isEmpty) {
      // Fallback: timing-based resequence.
      debugPrint('[S14] tidak ada frame → fallback timing-based');
      resequenceClips(projectId);
      notifyListeners();
      return [];
    }

    // ── Stage 2: Describe frames via VLM ──
    onProgress?.call('Analyzing visuals...');
    List<String> visualDescriptions;
    try {
      visualDescriptions = await matcher.describeFrames(framePaths: framePaths);
    } catch (e) {
      debugPrint('[S14] describeFrames gagal: $e → fallback timing-based');
      resequenceClips(projectId);
      notifyListeners();
      return [];
    }

    // ── Stage 3: Extract audio topics (skip if no transcript) ──
    List<String> audioTopics = [];
    // hasTranscript sudah cek t != null, tapi analyzer perlu konfirmasi.
    // ignore: unnecessary_null_comparison
    if (hasTranscript && t != null) {
      onProgress?.call('Extracting topics...');
      final cutPoints = _resequencer.detectCutPoints(t.words);
      try {
        audioTopics = await matcher.extractTopics(
          words: t.words,
          cutPoints: cutPoints,
        );
      } catch (e) {
        debugPrint('[S14] extractTopics gagal: $e → visual-only matching');
      }
    } else {
      onProgress?.call('Visual-only matching (no transcript)...');
      debugPrint('[S15] no transcript → visual-only matching');
    }

    // ── Stage 4: Match content via LLM ──
    onProgress?.call('Matching content...');
    try {
      matchOrder = await matcher.matchContent(
        visualDescriptions: visualDescriptions,
        audioTopics: audioTopics,
      );
    } catch (e) {
      debugPrint('[S14] matchContent gagal: $e → fallback timing-based');
      matchOrder = null;
    }

    // ── Stage 5: Resequence with matchOrder ──
    // Dengan transcript: resequence clips dengan matchOrder (content-aware).
    // Tanpa transcript: hanya apply matchOrder ke clip parts (visual-only),
    // tidak pakai word-boundary resequencing karena tidak ada word timestamps.
    onProgress?.call('Re-sequencing clips...');
    if (hasTranscript) {
      resequenceClips(projectId, matchOrder: matchOrder);
    } else if (matchOrder != null && matchOrder.isNotEmpty) {
      // Visual-only: apply matchOrder ke clip parts tanpa word-boundary.
      _resequenceVisualOnly(projectId, matchOrder);
    }
    notifyListeners();

    onProgress?.call('Done');
    return matchOrder ?? [];
  }

  // ─────────────────── B-ROLL RECOMMENDATION (PRD-SPRINT-05) ──────────────

  /// Enrich clip dengan keyword B-roll dari AI (bila BYOK aktif) atau
  /// heuristik (mode dasar). Dipanggil setelah analisis selesai.
  Future<void> enrichBrollRecommendations(String projectId) async {
    final p = byId(projectId);
    final s = _signals[projectId];
    if (p == null || s == null) return;

    final newClips = <Clip>[];
    for (final clip in p.clips) {
      if (clip.brollRecommendations.isNotEmpty) {
        newClips.add(clip);
        continue;
      }
      final start = clip.parts.first.start;
      final end = clip.parts.last.end;
      final enriched = await aiBrollService.detectAndEnrichGaps(
        signals: s,
        clipStart: start,
        clipEnd: end,
      );
      newClips.add(Clip(
        id: clip.id,
        title: clip.title,
        parts: clip.parts,
        hook: clip.hook,
        score: clip.score,
        reason: clip.reason,
        type: clip.type,
        selected9x16: clip.selected9x16,
        selected1x1: clip.selected1x1,
        brollRecommendations: enriched,
      ));
    }
    _put(p.copyWith(clips: newClips));
  }

  /// Set overlay file path untuk rekomendasi B-roll tertentu.
  /// User memilih file video eksternal → disimpan untuk dipakai saat render.
  void setBrollOverlay(String projectId, String clipId, int gapIndex, String filePath) {
    final p = byId(projectId);
    if (p == null) return;
    final clipIdx = p.clips.indexWhere((c) => c.id == clipId);
    if (clipIdx < 0) return;
    final clip = p.clips[clipIdx];
    if (gapIndex >= clip.brollRecommendations.length) return;

    final newBroll = [...clip.brollRecommendations];
    newBroll[gapIndex] = newBroll[gapIndex].copyWith(overlayFilePath: filePath);

    final newClips = [...p.clips];
    newClips[clipIdx] = Clip(
      id: clip.id,
      title: clip.title,
      parts: clip.parts,
      hook: clip.hook,
      score: clip.score,
      reason: clip.reason,
      type: clip.type,
      selected9x16: clip.selected9x16,
      selected1x1: clip.selected1x1,
      brollRecommendations: newBroll,
    );
    _put(p.copyWith(clips: newClips));
  }

  void toggleFormat(String clipId, {bool? v916, bool? v11}) {
    final p = activeProject;
    if (p == null) return;
    final clip = p.clips.where((c) => c.id == clipId).firstOrNull;
    if (clip == null) return;
    if (v916 != null) clip.selected9x16 = v916;
    if (v11 != null) clip.selected1x1 = v11;
    notifyListeners();
    if (p.stage == JobStage.done) _persist(p);
  }

  /// Render clip nyata ke [outputDir]. Satu file per format yang dipilih.
  /// Mengembalikan daftar path file hasil.
  Future<List<String>> exportClip({
    required String projectId,
    required String clipId,
    required List<AspectFormat> formats,
    required String outputDir,
    bool blurPad = true,
    void Function(String label, double progress)? onProgress,
  }) async {
    final p = byId(projectId);
    if (p == null) throw StateError('Project tidak ditemukan');
    final clip = p.clips.where((c) => c.id == clipId).firstOrNull;
    if (clip == null) throw StateError('Clip tidak ditemukan');
    if (formats.isEmpty) throw ArgumentError('Pilih minimal satu format');

    final safe = clip.title.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').trim();
    final out = <String>[];

    // Kumpulkan B-roll overlays yang punya file eksternal (PRD-SPRINT-05).
    final brollOverlays = clip.brollRecommendations
        .where((b) => b.hasOverlay)
        .map((b) => BrollOverlay(b.startSec, b.endSec, b.overlayFilePath!))
        .toList();
    final useBroll = brollOverlays.isNotEmpty;
    // Catatan: B-roll overlay + audio replacement belum digabung di Phase 1
    // (renderWithBroll belum terima audioMode). S05 (B-roll) belum aktif,
    // jadi cabang B-roll praktis tak tercapai saat ini.

    for (var i = 0; i < formats.length; i++) {
      final f = formats[i];
      final path = '$outputDir/${safe.isEmpty ? clip.id : safe}_${f.label.replaceAll(':', 'x')}.mp4';
      onProgress?.call('Render ${f.label}', 0);
      if (useBroll) {
        await VideoService.renderWithBroll(
          sourcePath: p.filePath,
          parts: clip.parts,
          outputPath: path,
          format: f,
          hasAudio: p.probe?.hasAudio ?? false,
          blurPad: blurPad,
          brollOverlays: brollOverlays,
          onProgress: (v) => onProgress?.call('Render ${f.label}', (i + v) / formats.length),
        );
      } else {
        await VideoService.renderClip(
          sourcePath: p.filePath,
          parts: clip.parts,
          outputPath: path,
          format: f,
          hasAudio: p.probe?.hasAudio ?? false,
          blurPad: blurPad,
          audioMode: p.audioMode,
          replacementAudioPath: p.activeAudioAsset?.sourceFile,
          onProgress: (v) => onProgress?.call('Render ${f.label}', (i + v) / formats.length),
        );
      }
      out.add(path);
    }
    onProgress?.call('Selesai', 1);
    return out;
  }

  /// Export satu asset (hook / b-roll / sound bite / audio) ke file terpisah.
  ///
  /// Aset audio (uploaded/extracted) disalin apa adanya — sourceFile-nya
  /// sudah berupa file audio, bukan segmen video sumber (PRD-SPRINT-10).
  Future<String> exportAsset({
    required String projectId,
    required AssetItem asset,
    required String outputDir,
  }) async {
    final p = byId(projectId);
    if (p == null) throw StateError('Project tidak ditemukan');
    final safe = asset.title.replaceAll(RegExp(r'[^A-Za-z0-9_ -]'), '').trim();
    final baseName = safe.isEmpty ? asset.id : safe;

    // Aset audio — salin file audio apa adanya ke output (bukan extract video).
    if (asset.type == AssetType.audio) {
      final ext = _audioExt(asset.sourceFile);
      final path = '$outputDir/$baseName.$ext';
      await File(asset.sourceFile).copy(path);
      return path;
    }

    // Aset segmen video (hook / b-roll / sound bite) — potong dari video sumber.
    final audioOnly = asset.type == AssetType.soundBite;
    final ext = audioOnly ? 'm4a' : 'mp4';
    final path = '$outputDir/$baseName.$ext';
    return VideoService.extractSegment(
      sourcePath: p.filePath,
      start: asset.start,
      end: asset.end,
      outputPath: path,
      audioOnly: audioOnly,
    );
  }

  /// Preview cepat satu segmen (dipakai player saat klik asset/hook).
  Future<String> previewSegment({
    required String projectId,
    required double start,
    required double end,
  }) async {
    final p = byId(projectId);
    if (p == null) throw StateError('Project tidak ditemukan');
    final dir = await _workDir(projectId);
    return VideoService.extractSegment(
      sourcePath: p.filePath,
      start: start,
      end: end,
      outputPath: '${dir.path}/preview_${start.toStringAsFixed(1)}_${end.toStringAsFixed(1)}.mp4',
    );
  }

  /// Hapus project: entri SQLite (clip & asset ikut via cascade), folder
  /// fisik di temp storage, lalu state memori (PRD-SPRINT-02 §3.2).
  Future<void> removeProject(String id) async {
    await _pendingWrite;
    final r = repo;
    if (r != null) {
      try {
        await r.delete(id);
      } catch (e) {
        debugPrint('Gagal menghapus project $id dari DB: $e');
      }
    }
    await storage.delete(id);

    projects.removeWhere((p) => p.id == id);
    _signals.remove(id);
    if (activeProjectId == id) activeProjectId = projects.firstOrNull?.id;
    notifyListeners();
  }
}

extension FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
