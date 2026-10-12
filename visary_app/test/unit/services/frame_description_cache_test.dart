import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:visary/services/frame_description_cache.dart';

/// S18 P4 — Test: FrameDescriptionCache
///
/// Coverage:
/// - Cache miss → null (no cached description)
/// - Cache hit → returns descriptions
/// - Same video + same config → cache hit
/// - Different video → cache miss
/// - Different model → cache miss
/// - Different prompt version → cache miss
/// - Different frame timestamps → cache miss
/// - Video file changed (size) → cache miss
/// - Cache write → subsequent read hits
/// - Cache file persists across instances
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('visary_cache_test_');
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  group('FrameDescriptionCache', () {
    test('cache miss → returns null', () async {
      final cache = FrameDescriptionCache(workspaceDir: tmpDir);
      final result = await cache.get(
        projectId: 'p1',
        videoPath: '/path/to/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0, 3.0, 5.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
      );
      expect(result, isNull);
    });

    test('cache write → subsequent read hits', () async {
      final cache = FrameDescriptionCache(workspaceDir: tmpDir);

      // Write to cache
      await cache.put(
        projectId: 'p1',
        videoPath: '/path/to/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0, 3.0, 5.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
        descriptions: ['hot pot', 'LED screen', 'street'],
      );

      // Read from cache
      final result = await cache.get(
        projectId: 'p1',
        videoPath: '/path/to/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0, 3.0, 5.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
      );

      expect(result, isNotNull);
      expect(result!.length, 3);
      expect(result[0], 'hot pot');
      expect(result[1], 'LED screen');
      expect(result[2], 'street');
    });

    test('same video + same config → cache hit', () async {
      final cache = FrameDescriptionCache(workspaceDir: tmpDir);

      await cache.put(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 2048,
        frameTimestamps: [1.0, 3.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
        descriptions: ['A', 'B'],
      );

      // Same params → hit
      final result = await cache.get(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 2048,
        frameTimestamps: [1.0, 3.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
      );

      expect(result, isNotNull);
      expect(result!.length, 2);
    });

    test('different video path → cache miss', () async {
      final cache = FrameDescriptionCache(workspaceDir: tmpDir);

      await cache.put(
        projectId: 'p1',
        videoPath: '/video1.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
        descriptions: ['A'],
      );

      final result = await cache.get(
        projectId: 'p1',
        videoPath: '/video2.mp4',  // different path
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
      );

      expect(result, isNull);
    });

    test('different video size → cache miss', () async {
      final cache = FrameDescriptionCache(workspaceDir: tmpDir);

      await cache.put(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
        descriptions: ['A'],
      );

      final result = await cache.get(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 2048,  // different size
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
      );

      expect(result, isNull);
    });

    test('different model → cache miss', () async {
      final cache = FrameDescriptionCache(workspaceDir: tmpDir);

      await cache.put(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
        descriptions: ['A'],
      );

      final result = await cache.get(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gpt-4o',  // different model
        promptVersion: 'v1',
      );

      expect(result, isNull);
    });

    test('different prompt version → cache miss', () async {
      final cache = FrameDescriptionCache(workspaceDir: tmpDir);

      await cache.put(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
        descriptions: ['A'],
      );

      final result = await cache.get(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v2',  // different prompt version
      );

      expect(result, isNull);
    });

    test('different frame timestamps → cache miss', () async {
      final cache = FrameDescriptionCache(workspaceDir: tmpDir);

      await cache.put(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0, 3.0, 5.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
        descriptions: ['A', 'B', 'C'],
      );

      final result = await cache.get(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0, 3.0, 5.0, 7.0],  // extra frame
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
      );

      expect(result, isNull);
    });

    test('cache persists across instances', () async {
      final cache1 = FrameDescriptionCache(workspaceDir: tmpDir);

      await cache1.put(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
        descriptions: ['hot pot'],
      );

      // New instance, same workspace
      final cache2 = FrameDescriptionCache(workspaceDir: tmpDir);
      final result = await cache2.get(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
      );

      expect(result, isNotNull);
      expect(result![0], 'hot pot');
    });

    test('cache hit logged via debugPrint', () async {
      final cache = FrameDescriptionCache(workspaceDir: tmpDir);

      await cache.put(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
        descriptions: ['A'],
      );

      // Just verify it returns without error — debugPrint goes to stderr
      final result = await cache.get(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
      );

      expect(result, isNotNull);
    });

    test('different project → cache miss (isolated)', () async {
      final cache = FrameDescriptionCache(workspaceDir: tmpDir);

      await cache.put(
        projectId: 'p1',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
        descriptions: ['A'],
      );

      // Different project → cache file is in p2/frames/cache.json, not p1/
      final result = await cache.get(
        projectId: 'p2',
        videoPath: '/video.mp4',
        videoSize: 1024,
        frameTimestamps: [1.0],
        model: 'gemini-flash-latest',
        promptVersion: 'v1',
      );

      expect(result, isNull);
    });
  });
}
