import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/local_analyzer.dart';

void main() {
  test('LocalAnalyzer handling VideoSignals tanpa audio (hasAudio = false)', () {
    const probe = VideoProbe(
      durationSec: 90.0,
      width: 1920,
      height: 1080,
      fps: 30.0,
      codec: 'h264',
      hasAudio: false,
    );

    final signals = VideoSignals(
      shots: [0.0, 15.0, 30.0, 45.0, 60.0, 75.0, 90.0],
      energy: [], // kosong karena tidak ada audio
      duration: probe.durationSec,
    );

    // Verifikasi scoreRange tidak throw StateError Bad state: No element
    expect(() => LocalAnalyzer.scoreRange(signals, 0, 30), returnsNormally);
    final score = LocalAnalyzer.scoreRange(signals, 0, 30);
    expect(score, greaterThanOrEqualTo(0));
    expect(score, lessThanOrEqualTo(100));

    // Verifikasi hooks() tidak throw exception
    List<HookCandidate> hooks = [];
    expect(() => hooks = LocalAnalyzer.hooks(signals), returnsNormally);
    expect(hooks, isNotEmpty);

    // Verifikasi clips() tidak throw exception
    List<Clip> clips = [];
    expect(() => clips = LocalAnalyzer.clips(signals, hooks), returnsNormally);
    expect(clips, isNotEmpty);

    // Verifikasi assets() tidak throw exception
    List<AssetItem> assets = [];
    expect(() => assets = LocalAnalyzer.assets(signals, hooks, 'no_audio.mp4'), returnsNormally);
    expect(assets, isNotNull);
  });
}
