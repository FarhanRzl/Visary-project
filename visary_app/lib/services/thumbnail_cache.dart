import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/local/workspace_storage.dart';
import '../services/video_service.dart';

/// Cache thumbnail strip untuk timeline video (PRD-SPRINT-09 §3.2).
///
/// Generate 1 frame JPEG per [intervalSec] dari video sumber, simpan ke
/// workspace storage per project. Lazy load hanya thumbnail yang visible.
class ThumbnailCache {
  static final Map<String, bool> _generated = {};

  /// Generate thumbnail strip untuk project. Idempotent — hanya jalan sekali
  /// per project ID (kecuali [force]).
  static Future<void> generate({
    required String sourcePath,
    required String projectId,
    required double durationSec,
    double intervalSec = 2.0,
    bool force = false,
  }) async {
    if (!force && _generated[projectId] == true) return;
    if (!File(sourcePath).existsSync()) return;

    final dir = await WorkspaceStorage().ensure(projectId);
    final count = (durationSec / intervalSec).ceil();

    for (var i = 0; i < count; i++) {
      final t = i * intervalSec;
      final outPath = '${dir.path}/strip_${i.toString().padLeft(5, '0')}.jpg';
      if (!force && File(outPath).existsSync()) continue;
      try {
        await VideoService.extractThumbnail(
          sourcePath: sourcePath,
          atSec: t,
          outPath: outPath,
          width: 160,
        );
      } catch (e) {
        debugPrint('[ThumbnailCache] gagal thumb $i: $e');
      }
    }
    _generated[projectId] = true;
  }

  /// Ambil path thumbnail untuk detik [timeSec] pada interval [intervalSec].
  /// Return null jika file belum ada.
  static String? get(String projectId, double timeSec, double intervalSec) {
    final idx = (timeSec / intervalSec).floor();
    final path =
        '${Directory.systemTemp.path}/visary/$projectId/strip_${idx.toString().padLeft(5, '0')}.jpg';
    return File(path).existsSync() ? path : null;
  }

  /// Ambil list thumbnail untuk rentang [start, end] yang visible di viewport.
  static List<(double, String)> range({
    required String projectId,
    required double start,
    required double end,
    required double intervalSec,
  }) {
    final result = <(double, String)>[];
    final startIdx = (start / intervalSec).floor();
    final endIdx = (end / intervalSec).ceil();
    for (var i = startIdx; i <= endIdx; i++) {
      final t = i * intervalSec;
      if (t > end) break;
      final path = get(projectId, t, intervalSec);
      if (path != null) result.add((t, path));
    }
    return result;
  }
}
