import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/local_analyzer.dart';
import 'package:visary/state/app_state.dart';

/// PRD-SPRINT-13 §4 — Test 13.2: transcribeReplacementAudio + resequenceClips.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Build AppState with a project that has replacement audio + signals.
  AppState _stateWithReplacementAudio() {
    final state = AppState();
    final project = Project(
      id: 'p_test',
      name: 'test_video.mp4',
      filePath: 'assets/videos/sample.mp4',
      createdAt: DateTime.now(),
      stage: JobStage.done,
      probe: const VideoProbe(
        durationSec: 20.0, width: 1080, height: 1920, fps: 30,
        codec: 'h264', hasAudio: true,
      ),
      clips: [
        Clip(
          id: 'c1',
          title: 'Clip 1',
          parts: const [ClipPart(0, 10)],
          hook: const ClipPart(0, 3),
          score: 80,
          reason: 'test',
          type: ClipType.linear,
        ),
      ],
      assets: [
        AssetItem(
          id: 'a_audio',
          type: AssetType.audio,
          title: 'replacement.mp3',
          sourceFile: 'test_audio.mp3',
          start: 0,
          end: 15,
          durationSec: 15,
          audioFormat: 'mp3',
        ),
      ],
      audioMode: AudioMode.replacement,
      activeAudioAssetId: 'a_audio',
    );
    state.projects.add(project);
    state.activeProjectId = 'p_test';

    final signals = VideoSignals(
      shots: const [0, 5, 10, 15, 20],
      energy: const [],
      duration: 20,
    );
    state.setSignalsForTest('p_test', signals);
    return state;
  }

  test('resequenceClips: transcript ada → clip parts berubah jadi resequenced', () {
    final state = _stateWithReplacementAudio();
    final signals = state.signalsOf('p_test')!;

    // Set transcript (simulasi hasil ASR)
    signals.transcript = Transcript(
      fullText: 'hello world test',
      words: const [
        WordToken(word: 'hello', start: 0.0, end: 0.5),
        WordToken(word: 'world', start: 1.0, end: 1.5), // 500ms pause
        WordToken(word: 'test', start: 2.0, end: 2.5),
      ],
      provider: 'custom',
    );

    state.resequenceClips('p_test');

    final clip = state.byId('p_test')!.clips.first;
    expect(clip.type, ClipType.resequenced);
    expect(clip.parts.length, greaterThan(1));
  });

  test('resequenceClips: transcript null → clips tidak berubah', () {
    final state = _stateWithReplacementAudio();
    final originalType = state.byId('p_test')!.clips.first.type;
    final originalPartsLen = state.byId('p_test')!.clips.first.parts.length;

    state.resequenceClips('p_test');

    final clip = state.byId('p_test')!.clips.first;
    expect(clip.type, originalType);
    expect(clip.parts.length, originalPartsLen);
  });

  test('resequenceClips: words empty → clips tidak berubah', () {
    final state = _stateWithReplacementAudio();
    final signals = state.signalsOf('p_test')!;
    signals.transcript = const Transcript(
      fullText: 'music only',
      words: [],
      provider: 'gemini',
    );

    final originalType = state.byId('p_test')!.clips.first.type;

    state.resequenceClips('p_test');

    final clip = state.byId('p_test')!.clips.first;
    expect(clip.type, originalType); // tidak berubah
  });

  test('resequenceClips: project tidak ditemukan → noop', () {
    final state = _stateWithReplacementAudio();
    // Should not throw
    state.resequenceClips('nonexistent');
  });

  test('transcribeReplacementAudio: no active audio → StateError', () async {
    final state = _stateWithReplacementAudio();
    // Switch to original mode (no replacement audio)
    state.setAudioMode('p_test', AudioMode.original);

    expect(
      () => state.transcribeReplacementAudio('p_test'),
      throwsA(isA<StateError>()),
    );
  });

  test('transcribeReplacementAudio: project not found → StateError', () async {
    final state = _stateWithReplacementAudio();

    expect(
      () => state.transcribeReplacementAudio('nonexistent'),
      throwsA(isA<StateError>()),
    );
  });

  test('Clip.copyWith: preserves fields, updates parts + type', () {
    final clip = Clip(
      id: 'c1',
      title: 'Test',
      parts: const [ClipPart(0, 5)],
      hook: const ClipPart(0, 2),
      score: 80,
      reason: 'test',
      type: ClipType.linear,
      selected9x16: true,
      selected1x1: false,
    );

    final copy = clip.copyWith(
      parts: const [ClipPart(1, 3), ClipPart(5, 8)],
      type: ClipType.resequenced,
    );

    expect(copy.id, 'c1');
    expect(copy.title, 'Test');
    expect(copy.parts.length, 2);
    expect(copy.type, ClipType.resequenced);
    expect(copy.score, 80);
    expect(copy.hook, clip.hook);
    expect(copy.selected9x16, true);
    expect(copy.selected1x1, false);
  });
}
