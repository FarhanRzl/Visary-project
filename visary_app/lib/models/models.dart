/// Model domain Visary — sesuai skema timeline & kontrak LLM di PRD §7.2–7.3.
library models;

enum ClipType { linear, resequenced }

/// Format output export (PRD §4.6 — MVP hanya 9:16 dan 1:1).
enum AspectFormat {
  v9x16,
  v1x1;

  (int, int) get size => switch (this) {
        AspectFormat.v9x16 => (1080, 1920),
        AspectFormat.v1x1 => (1080, 1080),
      };

  String get label => switch (this) {
        AspectFormat.v9x16 => '9:16',
        AspectFormat.v1x1 => '1:1',
      };

  static AspectFormat fromLabel(String s) =>
      s == '1:1' ? AspectFormat.v1x1 : AspectFormat.v9x16;
}

enum JobStage {
  probe,
  asr,
  shotOcr,
  vlm,
  llmSelect,
  done,
  error,
}

class VideoProbe {
  final double durationSec;
  final int width;
  final int height;
  final double fps;
  final String codec;
  final bool hasAudio;

  const VideoProbe({
    required this.durationSec,
    required this.width,
    required this.height,
    required this.fps,
    required this.codec,
    required this.hasAudio,
  });

  String get resolution => '$width×$height';
}

class Project {
  final String id;
  final String name;
  final String filePath;
  final DateTime createdAt;
  final VideoProbe? probe;
  final JobStage stage;
  final double progress; // 0..1
  final List<Clip> clips;
  final List<HookCandidate> hooks;
  final List<AssetItem> assets;
  final String? errorMessage;
  final String? thumbnailPath;

  const Project({
    required this.id,
    required this.name,
    required this.filePath,
    required this.createdAt,
    this.probe,
    this.stage = JobStage.probe,
    this.progress = 0,
    this.clips = const [],
    this.hooks = const [],
    this.assets = const [],
    this.errorMessage,
    this.thumbnailPath,
  });

  Project copyWith({
    JobStage? stage,
    double? progress,
    VideoProbe? probe,
    List<Clip>? clips,
    List<HookCandidate>? hooks,
    List<AssetItem>? assets,
    String? errorMessage,
    String? thumbnailPath,
  }) => Project(
        id: id,
        name: name,
        filePath: filePath,
        createdAt: createdAt,
        probe: probe ?? this.probe,
        stage: stage ?? this.stage,
        progress: progress ?? this.progress,
        clips: clips ?? this.clips,
        hooks: hooks ?? this.hooks,
        assets: assets ?? this.assets,
        errorMessage: errorMessage ?? this.errorMessage,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      );
}

class ClipPart {
  final double start;
  final double end;
  const ClipPart(this.start, this.end);
  double get duration => end - start;
}

class Clip {
  final String id;
  final String title;
  final List<ClipPart> parts;
  final ClipPart hook;
  final int score;
  final String reason;
  final ClipType type;
  bool selected9x16;
  bool selected1x1;

  /// Rekomendasi B-roll untuk segmen gap visual dalam clip ini (PRD-SPRINT-05).
  final List<BrollRecommendation> brollRecommendations;

  Clip({
    required this.id,
    required this.title,
    required this.parts,
    required this.hook,
    required this.score,
    required this.reason,
    required this.type,
    this.selected9x16 = true,
    this.selected1x1 = false,
    this.brollRecommendations = const [],
  });

  double get duration => parts.fold(0.0, (a, p) => a + p.duration);
}

class HookCandidate {
  final String id;
  final double start;
  final double end;
  final String quote;
  final int score;
  final String reason;
  final List<String> signals;

  const HookCandidate({
    required this.id,
    required this.start,
    required this.end,
    required this.quote,
    required this.score,
    required this.reason,
    required this.signals,
  });
}

enum AssetType { hook, broll, soundBite, ocrText }

/// Rekomendasi B-roll untuk segmen dengan gap visual (PRD-SPRINT-05 §3.1).
/// Segmen dengan narasi kuat tapi visual monoton → kirim ke VLM/LLM untuk keyword
/// pencarian stok video.
class BrollRecommendation {
  final double startSec;
  final double endSec;
  final String keywordPrompt;
  final String reason;

  /// Path file B-roll eksternal yang dipilih user (null = masih placeholder).
  final String? overlayFilePath;

  const BrollRecommendation({
    required this.startSec,
    required this.endSec,
    required this.keywordPrompt,
    required this.reason,
    this.overlayFilePath,
  });

  BrollRecommendation copyWith({
    double? startSec,
    double? endSec,
    String? keywordPrompt,
    String? reason,
    String? overlayFilePath,
  }) =>
      BrollRecommendation(
        startSec: startSec ?? this.startSec,
        endSec: endSec ?? this.endSec,
        keywordPrompt: keywordPrompt ?? this.keywordPrompt,
        reason: reason ?? this.reason,
        overlayFilePath: overlayFilePath ?? this.overlayFilePath,
      );

  bool get hasOverlay => overlayFilePath != null && overlayFilePath!.isNotEmpty;
}

class AssetItem {
  final String id;
  final AssetType type;
  final String title;
  final String sourceFile;
  final double start;
  final double end;

  const AssetItem({
    required this.id,
    required this.type,
    required this.title,
    required this.sourceFile,
    required this.start,
    required this.end,
  });
}

/// Representasi quota akun — PRD §4.9.
class QuotaInfo {
  final int usedMinutes;
  final int totalMinutes;
  final DateTime resetAt;
  final String planName;

  const QuotaInfo({
    required this.usedMinutes,
    required this.totalMinutes,
    required this.resetAt,
    required this.planName,
  });

  double get ratio => totalMinutes == 0 ? 0 : usedMinutes / totalMinutes;
  int get remaining => totalMinutes - usedMinutes;
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final QuotaInfo quota;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.quota,
  });
}
