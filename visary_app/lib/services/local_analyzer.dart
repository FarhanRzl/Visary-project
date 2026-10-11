import 'dart:math';

import '../models/models.dart';
import 'video_service.dart';

/// Hasil scan sinyal mentah dari video (sekali jalan, di-cache per project).
class VideoSignals {
  VideoSignals({required this.shots, required this.energy, required this.duration});

  /// Timestamp pergantian shot (detik), sudah termasuk 0 dan durasi.
  final List<double> shots;

  /// RMS dBFS per detik. Kosong bila video tanpa audio.
  final List<AudioEnergyPoint> energy;
  final double duration;

  /// Hasil transkripsi ASR (PRD-SPRINT-11). null bila BYOK off / ASR gagal.
  /// Di-set setelah scan oleh AppState (cloud transcribe).
  Transcript? transcript;

  double energyAt(double t) {
    if (energy.isEmpty) return -90;
    final i = t.floor().clamp(0, energy.length - 1);
    return energy[i].rmsDb;
  }

  /// Rata-rata energi di rentang [s, e).
  double meanEnergy(double s, double e) {
    final pts = energy.where((p) => p.timeSec >= s && p.timeSec < e).toList();
    if (pts.isEmpty) return -90;
    return pts.map((p) => p.rmsDb).reduce((a, b) => a + b) / pts.length;
  }

  int shotsIn(double s, double e) => shots.where((t) => t > s && t < e).length;
}

/// Analisis lokal "mode dasar" (PRD §7.5): dipakai selama backend AI belum ada.
///
/// Semua angka berasal dari sinyal nyata FFmpeg — tidak ada teks/skor karangan:
/// - shot boundary: filter `scdet`
/// - energi audio: filter `astats` RMS per 1 detik
class LocalAnalyzer {
  static const minClip = 30.0; // PRD §3: clip final ≥ 30 detik
  static const hookMin = 2.0, hookMax = 5.0; // PRD §4.3

  static Future<VideoSignals> scan(String path, VideoProbe probe) async {
    var shots = <double>[];
    try {
      shots = await VideoService.detectShotBoundaries(path);
    } catch (_) {}
    var energy = <AudioEnergyPoint>[];
    if (probe.hasAudio) {
      try {
        energy = await VideoService.measureAudioEnergy(path);
      } catch (_) {}
    }
    final d = probe.durationSec;
    final all = {0.0, ...shots.where((t) => t > 0.5 && t < d - 0.5), d}.toList()..sort();
    return VideoSignals(shots: all, energy: energy, duration: d);
  }

  /// Snap ke batas shot terdekat dalam toleransi [tol] detik.
  static double _snap(VideoSignals s, double t, {double tol = 2.0}) {
    double best = t, dist = tol;
    for (final b in s.shots) {
      final dd = (b - t).abs();
      if (dd < dist) {
        dist = dd;
        best = b;
      }
    }
    return best;
  }

  /// Skor publik untuk rentang arbitrer (dipakai saat user trim manual).
  static int scoreRange(VideoSignals s, double a, double b) => _score(s, a, b);

  /// Skor 0–100 dari energi relatif + kepadatan cut. Normalisasi terhadap
  /// statistik video itu sendiri, jadi relatif antar segmen.
  static int _score(VideoSignals s, double a, double b) {
    final dur = b - a;
    if (dur <= 0) return 40;

    double eNorm = 0.5;
    if (s.energy.isNotEmpty) {
      final vals = s.energy.map((p) => p.rmsDb).where((v) => v > -89).toList();
      if (vals.isNotEmpty) {
        final lo = vals.reduce(min), hi = vals.reduce(max);
        final m = s.meanEnergy(a, b);
        eNorm = (hi - lo) < 0.5 ? 0.5 : ((m - lo) / (hi - lo)).clamp(0.0, 1.0);
      }
    }

    final cutsPerMin = s.shotsIn(a, b) / (dur / 60);
    final cNorm = (cutsPerMin / 20).clamp(0.0, 1.0);

    if (s.energy.isEmpty) {
      return (40 + 60 * cNorm).round().clamp(0, 100);
    }
    return (40 + 40 * eNorm + 20 * cNorm).round().clamp(0, 100);
  }

  /// Kandidat hook 2–5 detik: puncak energi + pergantian shot (PRD §4.3).
  static List<HookCandidate> hooks(VideoSignals s, {int maxCount = 5}) {
    final d = s.duration;
    if (d < hookMin) return [];

    final candidates = <(double, double, int, List<String>)>[];

    // Puncak energi lokal
    if (s.energy.length >= 3) {
      final sorted = [...s.energy]..sort((a, b) => b.rmsDb.compareTo(a.rmsDb));
      for (final p in sorted) {
        if (p.rmsDb < -60) break;
        final st = max(0.0, p.timeSec - 1);
        final en = min(d, st + 4);
        if (en - st < hookMin) continue;
        candidates.add((st, en, _score(s, st, en), ['ENERGI']));
        if (candidates.length >= maxCount * 3) break;
      }
    }
    // Perubahan visual tajam
    for (final t in s.shots.skip(1)) {
      if (t >= d - hookMin) continue;
      final en = min(d, t + 3);
      candidates.add((t, en, _score(s, t, en), ['SHOT']));
    }
    if (candidates.isEmpty) {
      candidates.add((0, min(d, hookMax), _score(s, 0, min(d, hookMax)), ['PEMBUKA']));
    }

    candidates.sort((a, b) => b.$3.compareTo(a.$3));
    final picked = <(double, double, int, List<String>)>[];
    for (final c in candidates) {
      if (picked.any((p) => c.$1 < p.$2 && c.$2 > p.$1)) continue; // no overlap
      picked.add(c);
      if (picked.length >= maxCount) break;
    }
    return [
      for (var i = 0; i < picked.length; i++)
        HookCandidate(
          id: 'h$i',
          start: picked[i].$1,
          end: picked[i].$2,
          quote: 'Segmen ${fmtSec(picked[i].$1)}–${fmtSec(picked[i].$2)}',
          score: picked[i].$3,
          reason: picked[i].$4.contains('ENERGI')
              ? 'Puncak energi audio ${s.meanEnergy(picked[i].$1, picked[i].$2).toStringAsFixed(1)} dBFS'
              : picked[i].$4.contains('SHOT')
                  ? 'Pergantian shot terdeteksi di ${fmtSec(picked[i].$1)}'
                  : 'Pembuka video',
          signals: picked[i].$4,
        ),
    ];
  }

  /// Kandidat clip mengikuti aturan durasi PRD §3.
  /// [targetMin]/[targetMax] bisa diubah user lewat prompt durasi.
  static List<Clip> clips(
    VideoSignals s,
    List<HookCandidate> hookList, {
    double targetMin = 30,
    double targetMax = 60,
  }) {
    final d = s.duration;
    if (d <= 0) return [];

    // < 30 detik: satu versi full, ditandai di bawah minimum.
    if (d < minClip) {
      final h = hookList.isNotEmpty ? hookList.first : null;
      return [
        _mk('c0', 'Full video (di bawah minimum 30 dtk)', [ClipPart(0, d)],
            ClipPart(0, min(d, hookMax)), _score(s, 0, d),
            'Video ${d.toStringAsFixed(1)} dtk < 30 dtk — diekspor utuh.', ClipType.linear),
        if (h != null && h.start > 1)
          _mk('c1', 'Hook-first (di bawah minimum)',
              [ClipPart(h.start, h.end), ClipPart(0, h.start), if (h.end < d) ClipPart(h.end, d)],
              ClipPart(h.start, h.end), _score(s, 0, d),
              'Hook ${fmtSec(h.start)} dipindah ke depan.', ClipType.resequenced),
      ];
    }

    final maxClips = d <= 60 ? 2 : d <= 180 ? 5 : min(12, (d / 30).floor());
    final maxOverlap = d <= 60 ? 1.0 : 0.5;
    final lenTarget = ((targetMin + targetMax) / 2).clamp(minClip, d);

    // Sliding window, langkah 5 dtk; titik potong di-snap ke batas shot.
    final windows = <(double, double, int)>[];
    for (double st = 0; st + targetMin <= d + 0.01; st += 5) {
      final a = _snap(s, st);
      var b = _snap(s, min(d, a + lenTarget));
      if (b - a < max(minClip, targetMin)) b = min(d, a + max(minClip, targetMin));
      if (b - a > targetMax && targetMax >= minClip) b = a + targetMax;
      if (b - a < minClip) continue;
      windows.add((a, b, _score(s, a, b)));
    }
    windows.sort((x, y) => y.$3.compareTo(x.$3));

    final picked = <(double, double, int)>[];
    for (final w in windows) {
      final ok = picked.every((p) {
        final ov = max(0.0, min(w.$2, p.$2) - max(w.$1, p.$1));
        return ov / (w.$2 - w.$1) <= maxOverlap;
      });
      if (!ok || picked.any((p) => (p.$1 - w.$1).abs() < 1)) continue;
      picked.add(w);
      if (picked.length >= maxClips) break;
    }
    picked.sort((x, y) => x.$1.compareTo(y.$1));

    final out = <Clip>[];
    for (var i = 0; i < picked.length; i++) {
      final (a, b, sc) = picked[i];
      // Hook terbaik di luar segmen (setelahnya) → varian re-sequenced.
      final inner = hookList.where((h) => h.start >= a && h.end <= b).toList();
      final hook = inner.isNotEmpty
          ? ClipPart(inner.first.start, inner.first.end)
          : ClipPart(a, min(b, a + hookMax));
      final resequence = inner.isNotEmpty && inner.first.start - a > 3;

      // Deteksi gap visual untuk rekomendasi B-roll (PRD-SPRINT-05).
      final brollGaps = detectVisualGaps(s, a: a, b: b);

      out.add(_mk(
        'c$i',
        'Clip ${i + 1} · ${fmtSec(a)}–${fmtSec(b)}',
        resequence
            ? [ClipPart(hook.start, hook.end), ClipPart(a, hook.start), if (hook.end < b) ClipPart(hook.end, b)]
            : [ClipPart(a, b)],
        hook,
        sc,
        '${s.shotsIn(a, b)} cut, energi rata-rata ${s.meanEnergy(a, b).toStringAsFixed(1)} dBFS'
        '${resequence ? ' · hook ${fmtSec(hook.start)} dipindah ke depan' : ''}',
        resequence ? ClipType.resequenced : ClipType.linear,
        brollGaps,
      ));
    }
    return out;
  }

  /// Asset otomatis dari sinyal nyata (PRD §4.7):
  /// - hook: dari [hookList]
  /// - B-roll: shot ≥3 dtk dengan energi rendah (tidak ada ucapan/musik keras)
  /// - sound bite: jendela 3–8 dtk dengan energi tertinggi
  static List<AssetItem> assets(VideoSignals s, List<HookCandidate> hookList, String sourceName) {
    final out = <AssetItem>[];
    for (final h in hookList.take(3)) {
      out.add(AssetItem(
          id: 'a_${h.id}', type: AssetType.hook, title: 'Hook ${fmtSec(h.start)}',
          sourceFile: sourceName, start: h.start, end: h.end));
    }

    final vals = s.energy.map((p) => p.rmsDb).where((v) => v > -89).toList()..sort();
    final quiet = vals.isEmpty ? -90.0 : vals[(vals.length * 0.3).floor()];
    final loud = vals.isEmpty ? 0.0 : vals[(vals.length * 0.85).floor().clamp(0, vals.length - 1)];

    var bIdx = 0;
    for (var i = 0; i + 1 < s.shots.length && bIdx < 4; i++) {
      final a = s.shots[i], b = s.shots[i + 1];
      if (b - a < 3) continue;
      if (s.energy.isNotEmpty && s.meanEnergy(a, b) > quiet) continue;
      out.add(AssetItem(
          id: 'a_b$bIdx', type: AssetType.broll, title: 'B-roll ${fmtSec(a)}',
          sourceFile: sourceName, start: a, end: min(b, a + 10)));
      bIdx++;
    }

    if (s.energy.isNotEmpty) {
      // Adaptive threshold: jika audio sangat uniform (stddev < 1 dB),
      // persentil-85 terlalu dekat dengan mean → tidak ada run 3+ detik.
      // Gunakan mean + 0.2*stddev sebagai threshold yang lebih lunak.
      final mean = vals.reduce((a, b) => a + b) / vals.length;
      final variance =
          vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / vals.length;
      final stddev = sqrt(variance);
      final threshold = stddev < 1.0 ? mean + 0.2 * stddev : loud;

      var sIdx = 0;
      double? runStart;
      for (final p in [...s.energy, AudioEnergyPoint(s.duration, -90)]) {
        if (p.rmsDb >= threshold) {
          runStart ??= p.timeSec;
        } else if (runStart != null) {
          final a = runStart, b = min(p.timeSec, a + 8);
          runStart = null;
          if (b - a >= 3 && sIdx < 4) {
            out.add(AssetItem(
                id: 'a_s$sIdx', type: AssetType.soundBite, title: 'Sound bite ${fmtSec(a)}',
                sourceFile: sourceName, start: a, end: b));
            sIdx++;
          }
        }
      }

      // Fallback: jika tidak ada sound bite terdeteksi (audio terlalu uniform),
      // ambil 3 segmen 5-detik tersebar dengan energi tertinggi (non-overlapping).
      if (sIdx == 0 && s.energy.isNotEmpty) {
        final sorted = [...s.energy]..sort((a, b) => b.rmsDb.compareTo(a.rmsDb));
        final picked = <AudioEnergyPoint>[];
        for (final p in sorted) {
          if (picked.any((q) => (p.timeSec - q.timeSec).abs() < 5)) continue;
          picked.add(p);
          if (picked.length >= 3) break;
        }
        for (var i = 0; i < picked.length; i++) {
          final peak = picked[i];
          final a = peak.timeSec.clamp(0.0, max(0.0, s.duration - 5)).toDouble();
          final b = min(a + 5, s.duration);
          if (b - a >= 2) {
            out.add(AssetItem(
                id: 'a_s$i', type: AssetType.soundBite, title: 'Sound bite ${fmtSec(a)}',
                sourceFile: sourceName, start: a, end: b));
          }
        }
      }
    }
    return out;
  }

  // ─────────────────────── B-ROLL GAP DETECTION ─────────────────────────
  // PRD-SPRINT-05 §2.1: Deteksi Visual-Audio Mismatch.
  // Segmen dengan durasi > 4 detik, narasi kuat (energi audio tinggi),
  // tapi visual monoton (tidak ada cut ≥ 5 detik).

  /// Deteksi segmen gap visual dalam rentang [a, b] dari sinyal [s].
  /// Mengembalikan daftar [BrollRecommendation] dengan keyword heuristik
  /// (AI prompt generation dilakukan terpisah di [AiService]).
  static List<BrollRecommendation> detectVisualGaps(
    VideoSignals s, {
    required double a,
    required double b,
    double minGapSec = 5.0,
  }) {
    final gaps = <BrollRecommendation>[];
    if (s.shots.length < 2 || b <= a) return gaps;

    // Energi rata-rata seluruh video untuk threshold.
    final allEnergy = s.energy.map((p) => p.rmsDb).where((v) => v > -89).toList();
    final avgEnergy = allEnergy.isEmpty
        ? -60.0
        : allEnergy.reduce((x, y) => x + y) / allEnergy.length;

    // Iterasi shot boundaries dalam rentang [a, b].
    for (var i = 0; i + 1 < s.shots.length; i++) {
      final shotStart = s.shots[i];
      final shotEnd = s.shots[i + 1];
      if (shotEnd <= a || shotStart >= b) continue;

      final segStart = shotStart < a ? a : shotStart;
      final segEnd = shotEnd > b ? b : shotEnd;
      final segDur = segEnd - segStart;

      // Gap: segmen ≥ minGapSec tanpa cut + energi audio tinggi.
      if (segDur < minGapSec) continue;

      final segEnergy = s.meanEnergy(segStart, segEnd);
      // isHighEnergy: energi segmen ≥ rata-rata video DAN di atas threshold absolut (-50 dBFS).
      // Segmen sangat hening (< -50 dBFS) dianggap tidak ada narasi → bukan gap.
      final isHighEnergy = s.energy.isEmpty || (segEnergy >= avgEnergy && segEnergy > -50);

      if (!isHighEnergy) continue;

      // Keyword heuristik berdasarkan konteks segmen.
      final keyword = _heuristicKeyword(s, segStart, segEnd, segEnergy);

      gaps.add(BrollRecommendation(
        startSec: segStart,
        endSec: segEnd,
        keywordPrompt: keyword,
        reason: 'Visual statis ${segDur.toStringAsFixed(0)}s, '
            'energi audio ${segEnergy.toStringAsFixed(1)} dBFS '
            '(narasi aktif tanpa pergantian shot).',
      ));
    }

    return gaps;
  }

  /// Keyword heuristik fallback bila AI tidak tersedia (PRD §7.5 mode dasar).
  static String _heuristicKeyword(
      VideoSignals s, double start, double end, double energy) {
    final dur = end - start;
    if (energy > -20) {
      return 'Cinematic close-up, dynamic motion, energetic b-roll';
    } else if (dur > 10) {
      return 'Wide shot establishing, slow pan, ambient b-roll';
    } else {
      return 'Medium shot, subject interaction, contextual b-roll';
    }
  }

  static Clip _mk(String id, String title, List<ClipPart> parts, ClipPart hook, int score,
          String reason, ClipType type, [List<BrollRecommendation>? broll]) =>
      Clip(id: id, title: title, parts: parts, hook: hook, score: score, reason: reason,
          type: type, brollRecommendations: broll ?? const []);
}

String fmtSec(double s) {
  final m = s ~/ 60, sec = (s % 60).floor();
  return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}
