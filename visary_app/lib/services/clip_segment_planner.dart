import '../models/models.dart';
import 'local_analyzer.dart';

/// Strategy: menentukan segment video ([List<ClipPart>]) yang ditampilkan
/// untuk sebuah clip. Extension point untuk Phase 2 audio-context matching
/// (PRD-SPRINT-10 §2.2).
///
/// Phase 1: [LocalClipPlanner] — passthrough, visual as-is dari clip.
/// Phase 2: [AudioContextClipPlanner] — re-sequence parts berdasarkan konteks
///          audio pengganti (butuh AiProviderService, S05+S06).
abstract class ClipSegmentPlanner {
  List<ClipPart> plan({
    required Project project,
    required Clip clip,
    VideoSignals? signals,
    AssetItem? audioAsset,
  });
}

/// Phase 1: kembalikan parts clip apa adanya (visual as-is dari source).
/// Tidak ada re-sequencing — perilaku identik dengan pipeline export saat ini.
class LocalClipPlanner implements ClipSegmentPlanner {
  const LocalClipPlanner();

  @override
  List<ClipPart> plan({
    required Project project,
    required Clip clip,
    VideoSignals? signals,
    AssetItem? audioAsset,
  }) =>
      clip.parts;
}

/// Phase 2 STUB: fallback ke [LocalClipPlanner] jika AI provider belum ada.
///
/// Implementasi penuh (post-S05/S06): ASR audio pengganti → match konteks
/// audio ↔ sinyal video (OCR/shot/transcript/VLM) → re-sequence parts supaya
/// visual merepresentasikan konteks audio baru.
class AudioContextClipPlanner implements ClipSegmentPlanner {
  const AudioContextClipPlanner();

  @override
  List<ClipPart> plan({
    required Project project,
    required Clip clip,
    VideoSignals? signals,
    AssetItem? audioAsset,
  }) {
    // TODO(PRD-SPRINT-10 Phase 2): integrasi AiProviderService untuk
    // audio-context-driven re-sequencing. Sampai S05+S06 siap, fallback
    // ke perilaku Phase 1 (visual as-is).
    return const LocalClipPlanner().plan(
      project: project,
      clip: clip,
      signals: signals,
      audioAsset: audioAsset,
    );
  }
}
