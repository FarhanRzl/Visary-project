import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Pasangan (startSec, endSec, filePath) untuk overlay B-roll (PRD-SPRINT-05).
class BrollOverlay {
  final double startSec;
  final double endSec;
  final String filePath;
  const BrollOverlay(this.startSec, this.endSec, this.filePath);
}

/// Layer tipis di atas FFmpeg/FFprobe (PRD §7.1 langkah 1 & 8).
///
/// Semua operasi berat dijalankan sebagai proses eksternal — tidak ada data
/// simulasi di sini. Jika binary tidak tersedia, pemanggil mendapat
/// [FfmpegMissingException] supaya UI bisa menampilkan pesan jelas.
class FfmpegMissingException implements Exception {
  FfmpegMissingException(this.binary);
  final String binary;
  @override
  String toString() =>
      '$binary tidak ditemukan di PATH. Install FFmpeg lalu buka ulang aplikasi.';
}

class FfmpegFailedException implements Exception {
  FfmpegFailedException(this.stage, this.exitCode, this.stderrTail);
  final String stage;
  final int exitCode;
  final String stderrTail;
  @override
  String toString() => '$stage gagal (exit $exitCode): $stderrTail';
}

class VideoService {
  /// Resolusi biner, bisa dioverride lewat env var (dipakai di Windows ketika
  /// FFmpeg dibundel di samping executable).
  static String get ffmpegBin =>
      Platform.environment['VISARY_FFMPEG'] ?? 'ffmpeg';
  static String get ffprobeBin =>
      Platform.environment['VISARY_FFPROBE'] ?? 'ffprobe';

  static bool? _available;

  /// Cek sekali apakah ffmpeg & ffprobe bisa dieksekusi.
  static Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    try {
      final a = await Process.run(ffprobeBin, ['-version']);
      final b = await Process.run(ffmpegBin, ['-version']);
      _available = a.exitCode == 0 && b.exitCode == 0;
    } on ProcessException {
      _available = false;
    }
    return _available!;
  }

  // ─────────────────────────────── PROBE ────────────────────────────────

  /// Baca metadata asli file video via ffprobe (PRD §4.1).
  static Future<VideoProbe> probe(String filePath) async {
    if (!File(filePath).existsSync()) {
      throw FileSystemException('File tidak ditemukan', filePath);
    }

    final ProcessResult res;
    try {
      res = await Process.run(ffprobeBin, [
        '-v', 'error',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        filePath,
      ]);
    } on ProcessException {
      throw FfmpegMissingException(ffprobeBin);
    }

    if (res.exitCode != 0) {
      throw FfmpegFailedException(
          'ffprobe', res.exitCode, _tail(res.stderr.toString()));
    }

    final map = jsonDecode(res.stdout.toString()) as Map<String, dynamic>;
    final format = (map['format'] as Map?)?.cast<String, dynamic>() ?? {};
    final streams = ((map['streams'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    final video = streams.firstWhere(
      (s) => s['codec_type'] == 'video',
      orElse: () => <String, dynamic>{},
    );
    final hasAudio = streams.any((s) => s['codec_type'] == 'audio');

    // Durasi: format lebih andal, fallback ke stream video.
    var duration =
        double.tryParse('${format['duration'] ?? ''}') ??
            double.tryParse('${video['duration'] ?? ''}') ??
            0.0;
    if (duration <= 0) duration = 0;

    return VideoProbe(
      durationSec: duration,
      width: (video['width'] as num?)?.toInt() ?? 0,
      height: (video['height'] as num?)?.toInt() ?? 0,
      fps: _parseFps(video['r_frame_rate'] ?? video['avg_frame_rate']),
      codec: (video['codec_name'] as String?) ?? 'unknown',
      hasAudio: hasAudio,
    );
  }

  static double _parseFps(dynamic raw) {
    final s = '$raw';
    if (s.contains('/')) {
      final parts = s.split('/');
      final num = double.tryParse(parts[0]) ?? 0;
      final den = double.tryParse(parts[1]) ?? 0;
      if (den > 0 && num > 0) return num / den;
    }
    return double.tryParse(s) ?? 0;
  }

  // ───────────────────────────── KEYFRAME ───────────────────────────────

  /// Ekstrak 1 frame JPEG pada detik [atSec]. Dipakai untuk thumbnail nyata
  /// pada kartu project / clip / asset (bukan placeholder ikon).
  static Future<String?> extractThumbnail({
    required String sourcePath,
    required double atSec,
    required String outPath,
    int width = 480,
  }) async {
    if (!File(sourcePath).existsSync()) return null;
    try {
      final res = await Process.run(ffmpegBin, [
        '-v', 'error',
        '-ss', atSec.toStringAsFixed(3),
        '-i', sourcePath,
        '-frames:v', '1',
        '-vf', 'scale=$width:-2',
        '-y', outPath,
      ]);
      if (res.exitCode != 0) return null;
      return File(outPath).existsSync() ? outPath : null;
    } on ProcessException {
      return null;
    }
  }

  // ───────────────────── ANALISIS DASAR (LOKAL) ─────────────────────────

  /// Deteksi batas shot nyata memakai filter `scdet` FFmpeg (PRD §4.2 visual).
  /// Mengembalikan daftar timestamp (detik) tempat terjadi pergantian shot.
  static Future<List<double>> detectShotBoundaries(
    String path, {
    double threshold = 10.0,
  }) async {
    final ProcessResult res;
    try {
      res = await Process.run(ffmpegBin, [
        '-v', 'info',
        '-i', path,
        '-an',
        // Downscale dulu: hasil scdet setara, 5-10x lebih cepat.
        '-vf', 'scale=320:-2,scdet=threshold=$threshold',
        '-f', 'null', '-',
      ]);
    } on ProcessException {
      throw FfmpegMissingException(ffmpegBin);
    }

    final out = <double>[];
    final re = RegExp(r'lavfi\.scd\.time:\s*([0-9.]+)');
    for (final m in re.allMatches(res.stderr.toString())) {
      final t = double.tryParse(m.group(1)!);
      if (t != null) out.add(t);
    }
    out.sort();
    return out;
  }

  /// Ukur energi audio per window memakai filter `astats`.
  /// Mengembalikan pasangan (detik, RMS dBFS) — dasar untuk skor heuristik
  /// pada mode tanpa server (PRD §7.5).
  static Future<List<AudioEnergyPoint>> measureAudioEnergy(
    String path, {
    double windowSec = 1.0,
  }) async {
    final ProcessResult res;
    try {
      res = await Process.run(ffmpegBin, [
        '-v', 'info',
        '-i', path,
        '-map', '0:a:0',
        '-vn',
        '-af',
        // Resample ke 8 kHz lalu kelompokkan tepat windowSec per frame,
        // sehingga satu nilai RMS = satu jendela waktu.
        'aresample=8000,asetnsamples=${(8000 * windowSec).round()},'
            'astats=metadata=1:reset=1,'
            'ametadata=print:key=lavfi.astats.Overall.RMS_level',
        '-f', 'null', '-',
      ]);
    } on ProcessException {
      throw FfmpegMissingException(ffmpegBin);
    }

    final text = res.stderr.toString();
    final points = <AudioEnergyPoint>[];
    final frameRe = RegExp(r'pts_time:([0-9.]+)');
    final rmsRe = RegExp(r'RMS_level=(-?[0-9.]+|-inf)');

    double? pendingTime;
    for (final line in text.split('\n')) {
      final f = frameRe.firstMatch(line);
      if (f != null) {
        pendingTime = double.tryParse(f.group(1)!);
        continue;
      }
      final r = rmsRe.firstMatch(line);
      if (r != null && pendingTime != null) {
        final raw = r.group(1)!;
        final db = raw == '-inf' ? -90.0 : (double.tryParse(raw) ?? -90.0);
        points.add(AudioEnergyPoint(pendingTime, db));
        pendingTime = null;
      }
    }
    return points;
  }

  // ─────────────────────────────── RENDER ───────────────────────────────

  /// Render satu clip (bisa multi-part / re-sequenced) ke file MP4 final.
  ///
  /// - Setiap part di-trim dari sumber, lalu di-concat sesuai urutan `parts`
  ///   sehingga clip re-sequenced (hook dipindah ke depan) benar-benar jadi.
  /// - Reframe: scale + pad ke 1080x1920 (9:16) atau 1080x1080 (1:1),
  ///   background blur-pad bila [blurPad] true (PRD §4.6 fallback).
  /// - Audio ikut dipotong & di-concat kalau sumber punya audio.
  /// - Progres dilaporkan 0..1 lewat [onProgress] berdasarkan `-progress pipe`.
  static Future<String> renderClip({
    required String sourcePath,
    required List<ClipPart> parts,
    required String outputPath,
    AspectFormat format = AspectFormat.v9x16,
    bool hasAudio = true,
    bool blurPad = true,
    String preset = 'veryfast',
    void Function(double progress)? onProgress,
    String? burnInSubtitlePath,
  }) async {
    if (parts.isEmpty) throw ArgumentError('parts tidak boleh kosong');
    if (!File(sourcePath).existsSync()) {
      throw FileSystemException('Sumber video tidak ditemukan', sourcePath);
    }

    final (w, h) = format.size;
    final totalDur = parts.fold<double>(0, (a, p) => a + p.duration);

    // ── Bangun filter_complex: trim tiap part → concat → reframe ──
    final fc = StringBuffer();
    final vLabels = <String>[];
    final aLabels = <String>[];

    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      final s = p.start.toStringAsFixed(3);
      final e = p.end.toStringAsFixed(3);
      fc.write('[0:v]trim=start=$s:end=$e,setpts=PTS-STARTPTS[v$i];');
      vLabels.add('[v$i]');
      if (hasAudio) {
        fc.write('[0:a]atrim=start=$s:end=$e,asetpts=PTS-STARTPTS,aresample=async=1000[a$i];');
        aLabels.add('[a$i]');
      }
    }

    // Concat (n=1 tetap valid, jadi tidak perlu cabang khusus)
    fc.write('${vLabels.join()}concat=n=${parts.length}:v=1:a=0[vcat];');
    if (hasAudio) {
      fc.write('${aLabels.join()}concat=n=${parts.length}:v=0:a=1[aout];');
    }

    // Reframe ke target aspect
    if (blurPad) {
      // Background = frame yang di-blur & di-crop penuh, foreground = fit utuh.
      fc.write(
        '[vcat]split=2[bg][fg];'
        '[bg]scale=$w:$h:force_original_aspect_ratio=increase,'
        'crop=$w:$h,gblur=sigma=28[bgb];'
        '[fg]scale=$w:$h:force_original_aspect_ratio=decrease[fgs];'
        '[bgb][fgs]overlay=(W-w)/2:(H-h)/2,setsar=1',
      );
    } else {
      fc.write(
        '[vcat]scale=$w:$h:force_original_aspect_ratio=decrease,'
        'pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1',
      );
    }

    if (burnInSubtitlePath != null && File(burnInSubtitlePath).existsSync()) {
      final esc = burnInSubtitlePath.replaceAll(r'\', '/').replaceAll(':', r'\:');
      fc.write(
        ",subtitles='$esc':force_style='FontSize=18,Outline=2,Alignment=2'",
      );
    }
    fc.write('[vout]');

    final args = <String>[
      '-hide_banner',
      '-nostdin',
      '-progress', 'pipe:1',
      '-loglevel', 'error',
      '-i', sourcePath,
      '-filter_complex', fc.toString(),
      '-map', '[vout]',
      if (hasAudio) ...['-map', '[aout]', '-c:a', 'aac', '-b:a', '160k'],
      if (!hasAudio) '-an',
      '-c:v', 'libx264',
      '-preset', preset,
      '-crf', '20',
      '-pix_fmt', 'yuv420p',
      '-movflags', '+faststart',
      '-y', outputPath,
    ];

    await Directory(File(outputPath).parent.path).create(recursive: true);

    final Process proc;
    try {
      proc = await Process.start(ffmpegBin, args);
    } on ProcessException {
      throw FfmpegMissingException(ffmpegBin);
    }

    // `-progress pipe:1` menulis `out_time_ms=...` → konversi ke 0..1.
    final progressSub = proc.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (!line.startsWith('out_time_ms=') || totalDur <= 0) return;
      final us = int.tryParse(line.split('=').last.trim());
      if (us == null) return;
      final done = (us / 1e6) / totalDur;
      onProgress?.call(done.clamp(0.0, 1.0));
    });

    final errBuf = StringBuffer();
    final errSub = proc.stderr
        .transform(utf8.decoder)
        .listen(errBuf.write);

    final code = await proc.exitCode;
    await progressSub.cancel();
    await errSub.cancel();

    if (code != 0) {
      try {
        final f = File(outputPath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
      throw FfmpegFailedException('render clip', code, _tail(errBuf.toString()));
    }

    onProgress?.call(1.0);
    debugPrint('[VideoService] clip dirender: $outputPath');
    return outputPath;
  }

  /// Potong satu segmen apa adanya (tanpa reframe) — dipakai untuk export
  /// asset library: hook / b-roll / sound bite (PRD §4.7).
  static Future<String> extractSegment({
    required String sourcePath,
    required double start,
    required double end,
    required String outputPath,
    bool audioOnly = false,
  }) async {
    if (end <= start) throw ArgumentError('rentang waktu tidak valid');
    await Directory(File(outputPath).parent.path).create(recursive: true);

    final args = <String>[
      '-hide_banner', '-loglevel', 'error',
      '-ss', start.toStringAsFixed(3),
      '-to', end.toStringAsFixed(3),
      '-i', sourcePath,
      if (audioOnly) ...['-vn', '-c:a', 'aac', '-b:a', '192k'],
      if (!audioOnly) ...[
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20',
        '-c:a', 'aac', '-b:a', '160k',
      ],
      '-y', outputPath,
    ];

    final ProcessResult res;
    try {
      res = await Process.run(ffmpegBin, args);
    } on ProcessException {
      throw FfmpegMissingException(ffmpegBin);
    }
    if (res.exitCode != 0) {
      throw FfmpegFailedException(
          'extract segment', res.exitCode, _tail(res.stderr.toString()));
    }
    return outputPath;
  }

  // ─────────────────── B-ROLL OVERLAY (PRD-SPRINT-05 §3.2.4) ─────────────

  /// Render clip dengan B-roll overlay di rentang waktu tertentu.
  /// Video B-roll menutupi video utama (overlay) tanpa menimpa audio sumber.
  ///
  /// [brollOverlays] berisi pasangan (startSec, endSec, filePath) untuk tiap
  /// segmen B-roll yang akan di-overlay di atas video utama.
  static Future<String> renderWithBroll({
    required String sourcePath,
    required List<ClipPart> parts,
    required String outputPath,
    AspectFormat format = AspectFormat.v9x16,
    bool hasAudio = true,
    bool blurPad = true,
    String preset = 'veryfast',
    void Function(double progress)? onProgress,
    required List<BrollOverlay> brollOverlays,
  }) async {
    if (parts.isEmpty) throw ArgumentError('parts tidak boleh kosong');
    if (!File(sourcePath).existsSync()) {
      throw FileSystemException('Sumber video tidak ditemukan', sourcePath);
    }

    final (w, h) = format.size;
    final totalDur = parts.fold<double>(0, (a, p) => a + p.duration);

    // Filter complex: trim + concat + reframe + overlay broll
    final fc = StringBuffer();
    final vLabels = <String>[];
    final aLabels = <String>[];

    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      final s = p.start.toStringAsFixed(3);
      final e = p.end.toStringAsFixed(3);
      fc.write('[0:v]trim=start=$s:end=$e,setpts=PTS-STARTPTS[v$i];');
      vLabels.add('[v$i]');
      if (hasAudio) {
        fc.write('[0:a]atrim=start=$s:end=$e,asetpts=PTS-STARTPTS,aresample=async=1000[a$i];');
        aLabels.add('[a$i]');
      }
    }

    fc.write('${vLabels.join()}concat=n=${parts.length}:v=1:a=0[vcat];');
    if (hasAudio) {
      fc.write('${aLabels.join()}concat=n=${parts.length}:v=0:a=1[aout];');
    }

    // Reframe
    if (blurPad) {
      fc.write(
        '[vcat]split=2[bg][fg];'
        '[bg]scale=$w:$h:force_original_aspect_ratio=increase,'
        'crop=$w:$h,gblur=sigma=28[bgb];'
        '[fg]scale=$w:$h:force_original_aspect_ratio=decrease[fgs];'
        '[bgb][fgs]overlay=(W-w)/2:(H-h)/2,setsar=1[vref];',
      );
    } else {
      fc.write(
        '[vcat]scale=$w:$h:force_original_aspect_ratio=decrease,'
        'pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1[vref];',
      );
    }

    // Overlay B-roll segments
    var current = '[vref]';
    for (var i = 0; i < brollOverlays.length; i++) {
      final bo = brollOverlays[i];
      if (!File(bo.filePath).existsSync()) continue;
      final inputIdx = i + 1; // Input 0 = main, 1..N = broll files
      final startT = bo.startSec.toStringAsFixed(3);
      final endT = bo.endSec.toStringAsFixed(3);
      // Scale broll to match, overlay centered, enable only during gap
      fc.write(
        '[$inputIdx:v]scale=$w:$h:force_original_aspect_ratio=increase,'
        'crop=$w:$h[broll$i];'
        '$current[broll$i]overlay=(W-w)/2:(H-h)/2:'
        "enable='between(t,$startT,$endT)'[vovl$i];",
      );
      current = '[vovl$i]';
    }
    // Tidak write [vout] — gunakan `current` sebagai label final.
    final videoLabel = current; // '[vref]' atau '[vovlN]'

    // Build args with all inputs
    final args = <String>[
      '-hide_banner',
      '-nostdin',
      '-progress', 'pipe:1',
      '-loglevel', 'error',
      '-i', sourcePath,
      ...brollOverlays.where((bo) => File(bo.filePath).existsSync())
          .expand((bo) => ['-i', bo.filePath]),
      '-filter_complex', fc.toString(),
      '-map', videoLabel,
      if (hasAudio) ...['-map', '[aout]', '-c:a', 'aac', '-b:a', '160k'],
      if (!hasAudio) '-an',
      '-c:v', 'libx264',
      '-preset', preset,
      '-crf', '20',
      '-pix_fmt', 'yuv420p',
      '-movflags', '+faststart',
      '-y', outputPath,
    ];

    await Directory(File(outputPath).parent.path).create(recursive: true);

    final Process proc;
    try {
      proc = await Process.start(ffmpegBin, args);
    } on ProcessException {
      throw FfmpegMissingException(ffmpegBin);
    }

    final progressSub = proc.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (!line.startsWith('out_time_ms=') || totalDur <= 0) return;
      final us = int.tryParse(line.split('=').last.trim());
      if (us == null) return;
      final done = (us / 1e6) / totalDur;
      onProgress?.call(done.clamp(0.0, 1.0));
    });

    final errBuf = StringBuffer();
    final errSub = proc.stderr.transform(utf8.decoder).listen(errBuf.write);

    final code = await proc.exitCode;
    await progressSub.cancel();
    await errSub.cancel();

    if (code != 0) {
      try {
        final f = File(outputPath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
      throw FfmpegFailedException('render with broll', code, _tail(errBuf.toString()));
    }

    onProgress?.call(1.0);
    debugPrint('[VideoService] clip+broll dirender: $outputPath');
    return outputPath;
  }

  static String _tail(String s, [int max = 400]) {
    final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length <= max ? t : '…${t.substring(t.length - max)}';
  }
}

class AudioEnergyPoint {
  const AudioEnergyPoint(this.timeSec, this.rmsDb);
  final double timeSec;
  final double rmsDb;
}
