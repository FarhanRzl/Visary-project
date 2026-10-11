import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/clip_segment_planner.dart';

/// PRD-SPRINT-10 §4 — Test 10.5: ClipSegmentPlanner.
void main() {
  final clip = Clip(
    id: 'c1',
    title: 'Clip',
    parts: const [ClipPart(0, 5), ClipPart(10, 20)],
    hook: const ClipPart(0, 3),
    score: 80,
    reason: 'test',
    type: ClipType.linear,
  );
  final project = Project(
    id: 'p1',
    name: 'p.mp4',
    filePath: '/x.mp4',
    createdAt: DateTime(2026),
    clips: [clip],
  );

  test('LocalClipPlanner mengembalikan parts clip apa adanya (Phase 1)', () {
    final parts = const LocalClipPlanner().plan(project: project, clip: clip);
    expect(parts.length, 2);
    expect(parts.first.start, 0);
    expect(parts.first.end, 5);
    expect(parts.last.start, 10);
    expect(parts.last.end, 20);
  });

  test('AudioContextClipPlanner (stub) fallback ke LocalClipPlanner', () {
    final parts = const AudioContextClipPlanner()
        .plan(project: project, clip: clip);
    // Fallback Phase 1 — identik dengan LocalClipPlanner.
    expect(parts.length, 2);
    expect(parts.first.start, 0);
    expect(parts.last.start, 10);
  });
}
