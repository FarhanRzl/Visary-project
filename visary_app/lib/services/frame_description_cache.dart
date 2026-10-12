import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Cache for VLM frame descriptions (S18 P4).
///
/// Avoids redundant API calls when match content is re-run on the same video
/// with the same extraction configuration. Cache key includes:
/// - videoFilePath + videoSize (content identity)
/// - frameTimestamps (extraction config)
/// - model (API model used)
/// - promptVersion (prompt template version)
///
/// Storage: JSON file per project at `<workspace>/<projectId>/frames/desc_cache.json`
///
/// Invalidation:
/// - Video changed (path or size) → miss
/// - Frame timestamps changed → miss
/// - Model changed → miss
/// - Prompt version changed → miss
class FrameDescriptionCache {
  FrameDescriptionCache({Directory? workspaceDir})
      : _workspaceDir = workspaceDir ?? Directory('${Directory.systemTemp.path}/visary');

  final Directory _workspaceDir;

  /// Current prompt version. Increment when prompt template changes.
  static const promptVersion = 'v1-range-status';

  /// Get cached descriptions if cache hit, null if miss.
  Future<List<String>?> get({
    required String projectId,
    required String videoPath,
    required int videoSize,
    required List<double> frameTimestamps,
    required String model,
    required String promptVersion,
  }) async {
    final cacheFile = _cacheFile(projectId);
    if (!await cacheFile.exists()) {
      debugPrint('[FrameCache] miss: no cache file for $projectId');
      return null;
    }

    try {
      final content = await cacheFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final key = _cacheKey(videoPath, videoSize, frameTimestamps, model, promptVersion);
      final entry = data[key] as Map<String, dynamic>?;

      if (entry == null) {
        debugPrint('[FrameCache] miss: key not found for $projectId');
        return null;
      }

      // Verify all params match
      if (entry['videoPath'] != videoPath ||
          entry['videoSize'] != videoSize ||
          entry['model'] != model ||
          entry['promptVersion'] != promptVersion) {
        debugPrint('[FrameCache] miss: params mismatch for $projectId');
        return null;
      }

      final storedTimestamps = (entry['frameTimestamps'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      if (!_listEquals(storedTimestamps, frameTimestamps)) {
        debugPrint('[FrameCache] miss: timestamps mismatch for $projectId');
        return null;
      }

      final descriptions = (entry['descriptions'] as List)
          .map((e) => e.toString())
          .toList();

      debugPrint('[FrameCache] HIT: ${descriptions.length} descriptions for $projectId');
      return descriptions;
    } catch (e) {
      debugPrint('[FrameCache] read error for $projectId: $e → miss');
      return null;
    }
  }

  /// Store descriptions in cache.
  Future<void> put({
    required String projectId,
    required String videoPath,
    required int videoSize,
    required List<double> frameTimestamps,
    required String model,
    required String promptVersion,
    required List<String> descriptions,
  }) async {
    final cacheFile = _cacheFile(projectId);
    final dir = cacheFile.parent;
    if (!await dir.exists()) await dir.create(recursive: true);

    Map<String, dynamic> data = {};
    if (await cacheFile.exists()) {
      try {
        data = jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        // Corrupt cache → start fresh
        data = {};
      }
    }

    final key = _cacheKey(videoPath, videoSize, frameTimestamps, model, promptVersion);
    data[key] = {
      'videoPath': videoPath,
      'videoSize': videoSize,
      'frameTimestamps': frameTimestamps,
      'model': model,
      'promptVersion': promptVersion,
      'descriptions': descriptions,
      'cachedAt': DateTime.now().toIso8601String(),
    };

    await cacheFile.writeAsString(jsonEncode(data));
    debugPrint('[FrameCache] stored: ${descriptions.length} descriptions for $projectId');
  }

  /// Clear cache for a specific project.
  Future<void> clear(String projectId) async {
    final cacheFile = _cacheFile(projectId);
    if (await cacheFile.exists()) {
      await cacheFile.delete();
      debugPrint('[FrameCache] cleared for $projectId');
    }
  }

  File _cacheFile(String projectId) =>
      File('${_workspaceDir.path}/$projectId/frames/desc_cache.json');

  String _cacheKey(
    String videoPath,
    int videoSize,
    List<double> frameTimestamps,
    String model,
    String promptVersion,
  ) {
    // Simple hash from key components
    final input = '$videoPath|$videoSize|${frameTimestamps.join(",")}|$model|$promptVersion';
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash + input.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return 'desc_$hash';
  }

  bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.001) return false;
    }
    return true;
  }
}
