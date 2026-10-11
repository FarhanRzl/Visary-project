import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart' as models show Clip, ClipPart, BrollRecommendation;
import '../services/local_analyzer.dart' show VideoSignals;
import '../services/thumbnail_cache.dart';
import '../theme/tokens.dart';
import 'brutal.dart';

/// Edit action untuk undo/redo stack (PRD-SPRINT-09 §2.8).
class EditAction {
  final String label;
  final List<models.ClipPart> before;
  final List<models.ClipPart> after;
  const EditAction(this.label, this.before, this.after);
}

/// Pro Timeline — CapCut/Opus models.Clip parity (PRD-SPRINT-09).
///
/// Fitur: zoom 1x–50x, horizontal scroll, thumbnail strip, waveform nyata,
/// multi-segment drag dengan snap, split, delete, ripple edit, undo/redo,
/// keyboard shortcuts.
class ProTimeline extends StatefulWidget {
  final double durationSec;
  final double playhead;
  final models.Clip clip;
  final VideoSignals? signals;
  final String projectId;
  final String sourcePath;
  final List<models.BrollRecommendation> brollRecommendations;
  final ValueChanged<double> onPlayheadChanged;
  final ValueChanged<List<models.ClipPart>> onPartsChanged;

  const ProTimeline({
    super.key,
    required this.durationSec,
    required this.playhead,
    required this.clip,
    this.signals,
    required this.projectId,
    required this.sourcePath,
    this.brollRecommendations = const [],
    required this.onPlayheadChanged,
    required this.onPartsChanged,
  });

  @override
  State<ProTimeline> createState() => _ProTimelineState();
}

class _ProTimelineState extends State<ProTimeline> {
  double _zoom = 1.0; // 1.0 = full video visible
  double _scrollSec = 0.0; // detik di kiri viewport
  int _selectedSegment = -1;
  bool _thumbsGenerated = false;

  // Undo/redo
  final List<EditAction> _undoStack = [];
  final List<EditAction> _redoStack = [];
  static const _maxUndo = 50;

  // Thumbnail interval adaptif terhadap zoom
  static const _thumbInterval = 2.0; // 1 thumb per 2 detik

  double get _viewportDuration => widget.durationSec / _zoom;
  double get _viewEnd => min(_scrollSec + _viewportDuration, widget.durationSec);

  @override
  void initState() {
    super.initState();
    _generateThumbnails();
    try {
      HardwareKeyboard.instance.addHandler(_onKeyEvent);
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _generateThumbnails() async {
    try {
      await ThumbnailCache.generate(
        sourcePath: widget.sourcePath,
        projectId: widget.projectId,
        durationSec: widget.durationSec,
        intervalSec: _thumbInterval,
      );
    } catch (e) {
      debugPrint('[ProTimeline] thumbnail generation skipped: $e');
    }
    if (mounted) setState(() => _thumbsGenerated = true);
  }

  void _pushUndo(String label, List<models.ClipPart> before, List<models.ClipPart> after) {
    _undoStack.add(EditAction(label, before, after));
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();
    widget.onPartsChanged(action.before);
    _redoStack.add(action);
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final action = _redoStack.removeLast();
    widget.onPartsChanged(action.after);
    _undoStack.add(action);
    setState(() {});
  }

  // ──────────────── KEYBOARD SHORTCUTS ────────────────

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;

    if (key == LogicalKeyboardKey.space) {
      widget.onPlayheadChanged(widget.playhead);
      return true;
    } else if (key == LogicalKeyboardKey.keyJ) {
      widget.onPlayheadChanged((widget.playhead - 5).clamp(0.0, widget.durationSec));
      return true;
    } else if (key == LogicalKeyboardKey.keyL) {
      widget.onPlayheadChanged((widget.playhead + 5).clamp(0.0, widget.durationSec));
      return true;
    } else if (key == LogicalKeyboardKey.keyS) {
      _splitAtPlayhead();
      return true;
    } else if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      if (_selectedSegment >= 0) _deleteSegment(_selectedSegment);
      return true;
    } else if (ctrl && key == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _redo();
      } else {
        _undo();
      }
      return true;
    } else if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.numpadAdd) {
      _zoomIn();
      return true;
    } else if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
      _zoomOut();
      return true;
    } else if (key == LogicalKeyboardKey.digit0) {
      _zoomFit();
      return true;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      widget.onPlayheadChanged((widget.playhead - 0.033).clamp(0.0, widget.durationSec));
      return true;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      widget.onPlayheadChanged((widget.playhead + 0.033).clamp(0.0, widget.durationSec));
      return true;
    }
    return false;
  }

  // ──────────────── ZOOM & SCROLL ────────────────

  void _zoomIn() => setState(() {
        _zoom = (_zoom * 1.5).clamp(1.0, 50.0);
        _clampScroll();
      });

  void _zoomOut() => setState(() {
        _zoom = (_zoom / 1.5).clamp(1.0, 50.0);
        _clampScroll();
      });

  void _zoomFit() => setState(() {
        _zoom = 1.0;
        _scrollSec = 0.0;
      });

  void _clampScroll() {
    final maxScroll = (widget.durationSec - _viewportDuration).clamp(0.0, double.infinity);
    _scrollSec = _scrollSec.clamp(0.0, maxScroll);
  }

  void _onScroll(double delta) {
    setState(() {
      _scrollSec = (_scrollSec - delta * 0.02).clamp(0.0, double.infinity);
      _clampScroll();
    });
  }

  // ──────────────── SEGMENT OPERATIONS ────────────────

  double _snapToShot(double t, {double tol = 2.0}) {
    final shots = widget.signals?.shots ?? const [0.0];
    for (final s in shots) {
      if ((s - t).abs() < tol) return s;
    }
    return t;
  }

  void _splitAtPlayhead() {
    final parts = [...widget.clip.parts];
    final pos = widget.playhead;
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (pos > p.start + 0.5 && pos < p.end - 0.5) {
        final before = List<models.ClipPart>.from(parts);
        parts[i] = models.ClipPart(p.start, pos);
        parts.insert(i + 1, models.ClipPart(pos, p.end));
        _pushUndo('Split ${fmtTime(pos)}', before, parts);
        widget.onPartsChanged(parts);
        setState(() {});
        return;
      }
    }
  }

  void _deleteSegment(int index) {
    if (index < 0 || index >= widget.clip.parts.length) return;
    final parts = [...widget.clip.parts];
    final before = List<models.ClipPart>.from(parts);
    parts.removeAt(index);
    if (parts.isEmpty) return;
    _pushUndo('Delete segment ${index + 1}', before, parts);
    widget.onPartsChanged(parts);
    setState(() => _selectedSegment = -1);
  }

  void _trimSegment(int index, double newStart, double newEnd) {
    final parts = [...widget.clip.parts];
    if (index < 0 || index >= parts.length) return;
    newStart = _snapToShot(newStart);
    newEnd = _snapToShot(newEnd);
    if (newEnd - newStart < 0.5) return;

    // Clamp: tidak overlap part tetangga
    if (index > 0) newStart = max(newStart, parts[index - 1].end);
    if (index < parts.length - 1) newEnd = min(newEnd, parts[index + 1].start);
    if (newEnd - newStart < 0.5) return;

    final before = List<models.ClipPart>.from(parts);
    parts[index] = models.ClipPart(newStart, newEnd);
    _pushUndo('Trim segment ${index + 1}', before, parts);
    widget.onPartsChanged(parts);
  }

  // ──────────────── BUILD ────────────────

  double _secToX(double sec, double w) =>
      ((sec - _scrollSec) / _viewportDuration) * w;

  double _xToSec(double x, double w) =>
      _scrollSec + (x / w) * _viewportDuration;

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(),
          const SizedBox(height: 4),
          _buildRuler(),
          const SizedBox(height: 4),
          Expanded(child: _buildTracks()),
        ],
      ),
    );
  }

  // ──────────────── TOOLBAR ────────────────

  Widget _buildToolbar() {
    return Row(
      children: [
        Text('TIMELINE', style: VT.mono(11)),
        const Spacer(),
        // Zoom controls
        Clickable(
          onTap: _zoomOut,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: VC.paper,
              border: Border.all(color: VC.ink, width: 2),
            ),
            child: const Icon(Icons.remove, size: 14),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('${_zoom.toStringAsFixed(1)}x', style: VT.mono(10)),
        ),
        Clickable(
          onTap: _zoomIn,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: VC.paper,
              border: Border.all(color: VC.ink, width: 2),
            ),
            child: const Icon(Icons.add, size: 14),
          ),
        ),
        const SizedBox(width: 6),
        Clickable(
          onTap: _zoomFit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: VC.paper,
              border: Border.all(color: VC.ink, width: 2),
            ),
            child: Text('FIT', style: VT.mono(10)),
          ),
        ),
        const SizedBox(width: 8),
        // Split button
        Clickable(
          onTap: _splitAtPlayhead,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: VC.yellow,
              border: Border.all(color: VC.ink, width: 2),
            ),
            child: Row(children: [
              const Icon(Icons.content_cut, size: 12),
              const SizedBox(width: 4),
              Text('SPLIT', style: VT.mono(10)),
            ]),
          ),
        ),
        const SizedBox(width: 6),
        // Undo
        Clickable(
          onTap: _undoStack.isEmpty ? null : _undo,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _undoStack.isEmpty ? VC.bg : VC.paper,
              border: Border.all(color: VC.ink, width: 2),
            ),
            child: Row(children: [
              const Icon(Icons.undo, size: 12),
              Text('${_undoStack.length}', style: VT.mono(9)),
            ]),
          ),
        ),
        const SizedBox(width: 4),
        Clickable(
          onTap: _redoStack.isEmpty ? null : _redo,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _redoStack.isEmpty ? VC.bg : VC.paper,
              border: Border.all(color: VC.ink, width: 2),
            ),
            child: Row(children: [
              const Icon(Icons.redo, size: 12),
              Text('${_redoStack.length}', style: VT.mono(9)),
            ]),
          ),
        ),
      ],
    );
  }

  // ──────────────── RULER ────────────────

  Widget _buildRuler() {
    return SizedBox(
      height: 18,
      child: LayoutBuilder(builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final viewDur = _viewportDuration;
        // Marker interval adaptif: 6-12 markers
        final targetMarkers = 8;
        final rawStep = viewDur / targetMarkers;
        final niceSteps = [1, 2, 5, 10, 15, 30, 60, 120, 300];
        final matching = niceSteps.where((s) => s >= rawStep).toList();
        final step = matching.isNotEmpty ? matching.first : rawStep.ceil();
        final firstMarker = (_scrollSec / step).floor() * step;
        final markers = <Widget>[];
        for (var t = firstMarker; t <= _viewEnd + step; t += step) {
          if (t < _scrollSec - step) continue;
          final x = _secToX(t.toDouble(), w);
          if (x < -30 || x > w + 30) continue;
          markers.add(Positioned(
            left: x.clamp(0.0, w - 40),
            child: Text(fmtTime(t.toDouble()), style: VT.mono(9, color: VC.muted)),
          ));
        }
        return Stack(children: markers);
      }),
    );
  }

  // ──────────────── TRACKS ────────────────

  Widget _buildTracks() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final trackHeight = (h - 6) / 4; // 4 tracks: video, audio, clip, broll

      return Listener(
        onPointerSignal: (signal) {
          if (signal is PointerScrollEvent) {
            final ctrl = HardwareKeyboard.instance.isControlPressed;
            if (ctrl && signal.scrollDelta.dy < 0) {
              _zoomIn();
            } else if (ctrl && signal.scrollDelta.dy > 0) {
              _zoomOut();
            } else {
              _onScroll(signal.scrollDelta.dx + signal.scrollDelta.dy);
            }
          }
        },
        child: GestureDetector(
          onTapDown: (d) {
            final sec = _xToSec(d.localPosition.dx, w).clamp(0.0, widget.durationSec);
            widget.onPlayheadChanged(sec);
          },
          onHorizontalDragUpdate: (d) {
            final sec = _xToSec(d.localPosition.dx, w).clamp(0.0, widget.durationSec);
            widget.onPlayheadChanged(sec);
          },
          child: Container(
            decoration: BoxDecoration(
              color: VC.bg,
              border: Border.all(color: VC.ink, width: 2.5),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Track backgrounds + content
                Column(children: [
                  SizedBox(height: trackHeight, child: _buildVideoTrack(w, trackHeight)),
                  Container(height: 1.5, color: VC.ink),
                  SizedBox(height: trackHeight, child: _buildAudioTrack(w, trackHeight)),
                  Container(height: 1.5, color: VC.ink),
                  SizedBox(height: trackHeight, child: _buildClipTrack(w, trackHeight)),
                  Container(height: 1.5, color: VC.ink),
                  Expanded(child: _buildBrollTrack(w)),
                ]),

                // Playhead needle (full height)
                _buildPlayhead(w, h),

                // Track labels
                Positioned(left: 2, top: 2, child: Text('VIDEO', style: VT.mono(7, color: VC.muted))),
                Positioned(left: 2, top: trackHeight + 4, child: Text('AUDIO', style: VT.mono(7, color: VC.muted))),
                Positioned(left: 2, top: trackHeight * 2 + 6, child: Text('CLIP', style: VT.mono(7, color: VC.muted))),
                Positioned(left: 2, top: trackHeight * 3 + 8, child: Text('B-ROLL', style: VT.mono(7, color: VC.muted))),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ──────────────── VIDEO TRACK (Thumbnail Strip) ────────────────

  Widget _buildVideoTrack(double w, double h) {
    if (!_thumbsGenerated) {
      return Center(child: SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: VC.muted),
      ));
    }

    final thumbs = ThumbnailCache.range(
      projectId: widget.projectId,
      start: _scrollSec,
      end: _viewEnd,
      intervalSec: _thumbInterval,
    );

    if (thumbs.isEmpty) {
      return Container(color: VC.bg, child: Center(child: Text('No thumbnails', style: VT.mono(8, color: VC.muted))));
    }

    return Stack(children: thumbs.map((t) {
      final x = _secToX(t.$1, w);
      final thumbW = (_thumbInterval / _viewportDuration) * w;
      return Positioned(
        left: x,
        width: thumbW + 1, // +1 to avoid gaps
        top: 0,
        bottom: 0,
        child: Image.file(File(t.$2), fit: BoxFit.cover, gaplessPlayback: true),
      );
    }).toList());
  }

  // ──────────────── AUDIO TRACK (Waveform) ────────────────

  Widget _buildAudioTrack(double w, double h) {
    final signals = widget.signals;
    if (signals == null || signals.energy.isEmpty) {
      return Container(
        color: VC.bg,
        child: Center(child: Text('NO AUDIO', style: VT.mono(8, color: VC.muted))),
      );
    }

    final pts = signals.energy.where((p) =>
        p.timeSec >= _scrollSec && p.timeSec < _viewEnd).toList();
    if (pts.isEmpty) return Container(color: VC.bg);

    final vals = signals.energy.map((p) => p.rmsDb).where((v) => v > -89).toList();
    final maxDb = vals.reduce(max);
    final minDb = vals.reduce(min);
    final range = (maxDb - minDb).abs().clamp(0.1, double.infinity);

    final barW = (_viewportDuration > 60 ? 3.0 : 6.0);

    return Stack(children: pts.map((p) {
      final norm = ((p.rmsDb - minDb) / range).clamp(0.05, 1.0);
      final x = _secToX(p.timeSec, w);
      final isPeak = p.rmsDb > -15;
      return Positioned(
        left: x,
        width: barW,
        bottom: 2,
        height: norm * (h - 4),
        child: Container(color: isPeak ? VC.pink : VC.green),
      );
    }).toList());
  }

  // ──────────────── CLIP TRACK (Segment Blocks) ────────────────

  Widget _buildClipTrack(double w, double h) {
    final parts = widget.clip.parts;

    return Stack(children: parts.asMap().entries.map((entry) {
      final i = entry.key;
      final p = entry.value;
      final x = _secToX(p.start, w);
      final segW = ((p.end - p.start) / _viewportDuration) * w;
      final isSelected = i == _selectedSegment;

      return Positioned(
        left: x,
        width: segW.clamp(8.0, w),
        top: 2,
        bottom: 2,
        child: GestureDetector(
          onTap: () => setState(() => _selectedSegment = i),
          onHorizontalDragUpdate: (d) {
            final deltaSec = (d.delta.dx / w) * _viewportDuration;
            _trimSegment(i, p.start + deltaSec, p.end + deltaSec);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? VC.yellow : VC.yellow.withValues(alpha: 0.6),
                border: Border.all(
                  color: VC.ink,
                  width: isSelected ? 2.5 : 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${p.duration.toStringAsFixed(0)}s',
                  style: VT.mono(7, color: VC.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList());
  }

  // ──────────────── B-ROLL TRACK ────────────────

  Widget _buildBrollTrack(double w) {
    if (widget.brollRecommendations.isEmpty) {
      return Container(color: VC.bg);
    }
    return Stack(children: widget.brollRecommendations.map((b) {
      final x = _secToX(b.startSec, w);
      final bw = ((b.endSec - b.startSec) / _viewportDuration) * w;
      return Positioned(
        left: x,
        width: bw.clamp(20.0, w),
        top: 2,
        bottom: 2,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: VC.pink, width: 1.5),
            color: VC.pink.withValues(alpha: 0.15),
          ),
          child: Center(child: Text(
            b.hasOverlay ? 'B-ROLL ✓' : 'B-ROLL?',
            style: VT.mono(7, color: VC.pink),
            overflow: TextOverflow.ellipsis,
          )),
        ),
      );
    }).toList());
  }

  // ──────────────── PLAYHEAD ────────────────

  Widget _buildPlayhead(double w, double h) {
    final x = _secToX(widget.playhead, w);
    if (x < -10 || x > w + 10) return const SizedBox();

    return Positioned(
      left: x - 1,
      top: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          onHorizontalDragUpdate: (d) {
            final sec = _xToSec(d.localPosition.dx + (x - 1), w)
                .clamp(0.0, widget.durationSec);
            widget.onPlayheadChanged(sec);
          },
          child: Container(
            width: 2.5,
            color: VC.pink,
          ),
        ),
      ),
    );
  }
}
