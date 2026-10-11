import 'package:flutter/material.dart';

import '../models/models.dart' show BrollRecommendation;
import '../theme/tokens.dart';

/// NeoBrutalTimeline
/// Komponen timeline video yang interaktif dan fungsional dengan style Neo-Brutalism.
/// Mendukung drag playhead (scrubber), trim selector, dan B-roll placeholder (PRD-SPRINT-05).
class NeoBrutalTimeline extends StatefulWidget {
  final double durationSec;
  final double playhead;
  final double clipStart;
  final double clipEnd;
  final ValueChanged<double> onPlayheadChanged;
  final Function(double start, double end) onTrimChanged;

  /// Rekomendasi B-roll untuk dirender sebagai dashed-box placeholder (PRD-SPRINT-05).
  final List<BrollRecommendation> brollRecommendations;

  const NeoBrutalTimeline({
    super.key,
    required this.durationSec,
    required this.playhead,
    required this.clipStart,
    required this.clipEnd,
    required this.onPlayheadChanged,
    required this.onTrimChanged,
    this.brollRecommendations = const [],
  });

  @override
  State<NeoBrutalTimeline> createState() => _NeoBrutalTimelineState();
}

class _NeoBrutalTimelineState extends State<NeoBrutalTimeline> {
  // Simulasi mock data block untuk track 1 (Shots) dan track 2 (Speech)
  // Berisi pasangan start/end rasio (0.0 - 1.0)
  final List<List<double>> _shotBlocks = const [
    [0.0, 0.15], [0.155, 0.28], [0.29, 0.45], [0.46, 0.65], [0.66, 0.88], [0.89, 1.0]
  ];
  final List<List<double>> _audioBlocks = const [
    [0.02, 0.14], [0.18, 0.25], [0.3, 0.44], [0.5, 0.64], [0.7, 0.82], [0.9, 0.98]
  ];

  // Drag states
  bool _draggingPlayhead = false;
  bool _draggingLeftHandle = false;
  bool _draggingRightHandle = false;

  void _handleDrag(DragUpdateDetails details, double maxWidth) {
    final dx = details.delta.dx;
    final secDelta = (dx / maxWidth) * widget.durationSec;

    if (_draggingLeftHandle) {
      double newStart = (widget.clipStart + secDelta).clamp(0.0, widget.clipEnd - 1.0);
      widget.onTrimChanged(newStart, widget.clipEnd);
      widget.onPlayheadChanged(newStart);
    } else if (_draggingRightHandle) {
      double newEnd = (widget.clipEnd + secDelta).clamp(widget.clipStart + 1.0, widget.durationSec);
      widget.onTrimChanged(widget.clipStart, newEnd);
      widget.onPlayheadChanged(newEnd);
    } else if (_draggingPlayhead) {
      double newPlayhead = (widget.playhead + secDelta).clamp(0.0, widget.durationSec);
      widget.onPlayheadChanged(newPlayhead);
    }
  }

  void _handleTap(TapDownDetails details, double maxWidth) {
    final dx = details.localPosition.dx;
    final newSec = (dx / maxWidth) * widget.durationSec;
    widget.onPlayheadChanged(newSec.clamp(0.0, widget.durationSec));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // RULER (Time Markers)
        SizedBox(
          height: 20,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              const numMarkers = 6;
              final step = widget.durationSec / numMarkers;
              
              return Stack(
                children: List.generate(numMarkers + 1, (i) {
                  final sec = i * step;
                  final left = (sec / widget.durationSec) * w;
                  return Positioned(
                    left: left == w ? w - 30 : left, // Prevent overflow at the end
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fmtTime(sec), style: VT.mono(10, color: VC.muted)),
                        Container(width: 1, height: 4, color: VC.muted),
                      ],
                    ),
                  );
                }),
              );
            }
          ),
        ),
        
        const SizedBox(height: 6),

        // TRACKS CONTAINER
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              
              final clipStartX = (widget.clipStart / widget.durationSec) * w;
              final clipEndX = (widget.clipEnd / widget.durationSec) * w;
              final clipWidth = clipEndX - clipStartX;

              final playheadX = (widget.playhead / widget.durationSec) * w;

              return GestureDetector(
                onTapDown: (d) => _handleTap(d, w),
                onHorizontalDragStart: (_) => setState(() => _draggingPlayhead = true),
                onHorizontalDragUpdate: (d) => _handleDrag(d, w),
                onHorizontalDragEnd: (_) => setState(() => _draggingPlayhead = false),
                child: Container(
                  decoration: BoxDecoration(
                    color: VC.bg,
                    border: Border.all(color: VC.ink, width: 2.5),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Background tracks
                      Column(
                        children: [
                          Expanded(child: _buildTrackRow(_shotBlocks, VC.blue)), // Blue
                          Container(height: 2.5, color: VC.ink), // Divider
                          Expanded(child: _buildTrackRow(_audioBlocks, VC.green)), // Teal
                          Container(height: 2.5, color: VC.ink), // Divider
                          Expanded(child: Container(color: Colors.white)), // Clip background area
                        ],
                      ),

                      // Trim Selector overlay
                      Positioned(
                        left: clipStartX,
                        width: clipWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: VC.yellow.withValues(alpha: 0.4),
                            border: const Border(
                              top: BorderSide(color: VC.yellow, width: 3),
                              bottom: BorderSide(color: VC.yellow, width: 3),
                            ),
                          ),
                        ),
                      ),

                      // Left Trim Handle
                      Positioned(
                        left: clipStartX - 10, // center handle on border
                        width: 20,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onHorizontalDragStart: (_) => setState(() => _draggingLeftHandle = true),
                          onHorizontalDragUpdate: (d) => _handleDrag(d, w),
                          onHorizontalDragEnd: (_) => setState(() => _draggingLeftHandle = false),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: VC.yellow,
                                border: Border.all(color: VC.ink, width: 2),
                              ),
                              child: Container(width: 2, height: 16, color: VC.ink),
                            ),
                          ),
                        ),
                      ),

                      // Right Trim Handle
                      Positioned(
                        left: clipEndX - 10,
                        width: 20,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onHorizontalDragStart: (_) => setState(() => _draggingRightHandle = true),
                          onHorizontalDragUpdate: (d) => _handleDrag(d, w),
                          onHorizontalDragEnd: (_) => setState(() => _draggingRightHandle = false),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: VC.yellow,
                                border: Border.all(color: VC.ink, width: 2),
                              ),
                              child: Container(width: 2, height: 16, color: VC.ink),
                            ),
                          ),
                        ),
                      ),

                      // B-Roll Placeholder Track (PRD-SPRINT-05 §2.3)
                      ...widget.brollRecommendations.map((b) {
                        final bx = (b.startSec / widget.durationSec) * w;
                        final bw = ((b.endSec - b.startSec) / widget.durationSec) * w;
                        return Positioned(
                          left: bx,
                          width: bw.clamp(20.0, w - bx),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: VC.pink,
                                width: 2,
                                strokeAlign: BorderSide.strokeAlignInside,
                              ),
                              color: VC.pink.withValues(alpha: 0.15),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  b.hasOverlay ? 'B-ROLL ✓' : 'B-ROLL?',
                                  style: VT.mono(8, color: VC.pink),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      // Playhead Needle
                      Positioned(
                        left: playheadX - 8,
                        top: -8,
                        bottom: 0,
                        child: GestureDetector(
                          onHorizontalDragStart: (_) => setState(() => _draggingPlayhead = true),
                          onHorizontalDragUpdate: (d) => _handleDrag(d, w),
                          onHorizontalDragEnd: (_) => setState(() => _draggingPlayhead = false),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: SizedBox(
                              width: 16,
                              child: Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  // Line
                                  Container(width: 2.5, color: VC.pink), // Pink
                                  // Triangle Head
                                  Container(
                                    width: 14,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: VC.pink,
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(4),
                                        bottomRight: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildTrackRow(List<List<double>> blocks, Color color) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: blocks.map((b) {
          final startX = b[0] * constraints.maxWidth;
          final endX = b[1] * constraints.maxWidth;
          return Positioned(
            left: startX,
            width: endX - startX,
            top: 0,
            bottom: 0,
            child: Container(color: color),
          );
        }).toList(),
      );
    });
  }
}
