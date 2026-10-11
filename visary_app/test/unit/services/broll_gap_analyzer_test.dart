import 'package:flutter_test/flutter_test.dart';
import 'package:visary/services/local_analyzer.dart';
import 'package:visary/services/video_service.dart';

/// Unit test: B-roll gap detection (PRD-SPRINT-05 §4 Test 5.1).
/// Berikan mock timeline dengan narasi 10 detik tanpa pergantian shot (visual statis).
/// Validasi algoritma menghasilkan setidaknya 1 BrollRecommendation.
void main() {
  group('BrollGapAnalyzer', () {
    test('Segmen statis ≥5s dengan energi tinggi menghasilkan BrollRecommendation', () {
      // Mock VideoSignals: 1 shot panjang (0–30s) tanpa cut, energi tinggi.
      final signals = VideoSignals(
        shots: [0.0, 30.0],
        energy: [
          for (var i = 0; i < 30; i++) AudioEnergyPoint(i.toDouble(), -15.0),
        ],
        duration: 30.0,
      );

      final gaps = LocalAnalyzer.detectVisualGaps(signals, a: 0, b: 30);

      expect(gaps, isNotEmpty, reason: 'Harus ada ≥1 gap untuk segmen statis 30s');
      expect(gaps.first.startSec, lessThanOrEqualTo(30.0));
      expect(gaps.first.endSec, greaterThan(gaps.first.startSec));
      expect(gaps.first.keywordPrompt, isNotEmpty);
      expect(gaps.first.reason, contains('Visual statis'));
    });

    test('Segmen dengan banyak cut tidak menghasilkan gap', () {
      // Mock VideoSignals: cut setiap 2 detik (kepadatan shot tinggi).
      final shots = [0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0];
      final signals = VideoSignals(
        shots: shots,
        energy: [for (var i = 0; i < 20; i++) AudioEnergyPoint(i.toDouble(), -15.0)],
        duration: 20.0,
      );

      final gaps = LocalAnalyzer.detectVisualGaps(signals, a: 0, b: 20);

      // Setiap segmen hanya 2s < minGapSec(5s) → tidak ada gap.
      expect(gaps, isEmpty, reason: 'Segmen dengan cut <5s tidak boleh jadi gap');
    });

    test('Segmen statis dengan energi rendah tidak menghasilkan gap', () {
      // Mock: 1 shot panjang, tapi energi sangat rendah (hening).
      final signals = VideoSignals(
        shots: [0.0, 20.0],
        energy: [for (var i = 0; i < 20; i++) AudioEnergyPoint(i.toDouble(), -80.0)],
        duration: 20.0,
      );

      final gaps = LocalAnalyzer.detectVisualGaps(signals, a: 0, b: 20);

      expect(gaps, isEmpty, reason: 'Energi rendah = bukan narasi, tidak perlu B-roll');
    });

    test('Video tanpa audio tetap mendeteksi gap (mode visual-only)', () {
      // Mock: shot panjang tanpa audio (energy kosong).
      final signals = VideoSignals(
        shots: [0.0, 15.0],
        energy: [],
        duration: 15.0,
      );

      final gaps = LocalAnalyzer.detectVisualGaps(signals, a: 0, b: 15);

      // s.energy.isEmpty → isHighEnergy selalu true (fallback mode dasar).
      expect(gaps, isNotEmpty, reason: 'Mode visual-only tetap deteksi gap statis');
    });

    test('Multiple gaps terdeteksi untuk beberapa segmen statis', () {
      // Mock: 3 segmen panjang dipisahkan cut pendek.
      final signals = VideoSignals(
        shots: [0.0, 8.0, 10.0, 18.0, 20.0, 28.0],
        energy: [for (var i = 0; i < 28; i++) AudioEnergyPoint(i.toDouble(), -15.0)],
        duration: 28.0,
      );

      final gaps = LocalAnalyzer.detectVisualGaps(signals, a: 0, b: 28);

      // Segmen: [0-8]=8s✓, [8-10]=2s✗, [10-18]=8s✓, [18-20]=2s✗, [20-28]=8s✓
      expect(gaps.length, 3, reason: 'Harus ada 3 gap (segmen 8s, 8s, 8s)');
    });

    test('Keyword heuristik berbeda berdasarkan level energi', () {
      // Energi tinggi (-10 dBFS) → "Cinematic"
      final signalsHigh = VideoSignals(
        shots: [0.0, 8.0, 20.0],
        energy: [for (var i = 0; i < 20; i++) AudioEnergyPoint(i.toDouble(), -10.0)],
        duration: 20.0,
      );
      final gapsHigh = LocalAnalyzer.detectVisualGaps(signalsHigh, a: 0, b: 20);
      expect(gapsHigh, isNotEmpty);
      expect(gapsHigh.first.keywordPrompt, contains('Cinematic'));

      // Energi sedang (-40 dBFS), segmen pendek 8s → "Medium shot"
      final signalsLow = VideoSignals(
        shots: [0.0, 8.0, 20.0],
        energy: [
          for (var i = 0; i < 8; i++) AudioEnergyPoint(i.toDouble(), -40.0),
          for (var i = 8; i < 20; i++) AudioEnergyPoint(i.toDouble(), -80.0),
        ],
        duration: 20.0,
      );
      final gapsLow = LocalAnalyzer.detectVisualGaps(signalsLow, a: 0, b: 20);
      expect(gapsLow, isNotEmpty);
      expect(gapsLow.first.keywordPrompt, contains('Medium shot'));
    });
  });
}
