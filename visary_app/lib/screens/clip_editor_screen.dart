import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/brutal.dart';
import '../widgets/export_dialog.dart';
import '../widgets/pro_timeline.dart';
import '../widgets/audio_panel.dart';

/// ClipEditorScreen — Pixel-perfect match for canvas `tMv8K` (04-clip-editor.png)
class ClipEditorScreen extends StatefulWidget {
  const ClipEditorScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<ClipEditorScreen> createState() => _ClipEditorScreenState();
}

class _ClipEditorScreenState extends State<ClipEditorScreen> {
  final _promptCtrl = TextEditingController();
  String _selectedAspectRatio = '9:16';
  int _selectedClipIndex = 0;

  double _playheadSec = 24.0;
  double _clipStartSec = 24.0;
  double _clipEndSec = 56.0;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  String? _videoError;
  bool _isAudioProcessing = false;
  AudioMode? _lastAppliedAudioMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideo();
    });
  }

  void _initializeVideo() {
    final project = context
        .read<AppState>()
        .projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final path = project?.filePath ?? '';

    // File asli hasil upload (desktop) kalau ada; selain itu pakai video sample bundel.
    final controller = (!kIsWeb && path.isNotEmpty && File(path).existsSync())
        ? VideoPlayerController.file(File(path))
        : VideoPlayerController.asset('assets/videos/sample.mp4');
    _videoController = controller;

    controller.initialize().then((_) {
      if (!mounted) return;
      controller.seekTo(Duration(milliseconds: (_playheadSec * 1000).round()));
      setState(() => _isVideoInitialized = true);
    }).catchError((e) {
      debugPrint('Video init error: $e');
      if (mounted) setState(() => _videoError = '$e');
    });

    _videoController?.addListener(_onVideoUpdate);
  }

  /// Listener playhead: sinkron _playheadSec dengan posisi controller.
  void _onVideoUpdate() {
    if (!mounted || _videoController == null) return;
    final pos = _videoController!.value.position.inMilliseconds / 1000.0;
    if ((pos - _playheadSec).abs() > 0.5) {
      setState(() {
        _playheadSec = pos;
      });
    }
  }

  void _seekTo(double seconds) {
    _videoController?.seekTo(Duration(milliseconds: (seconds * 1000).round()));
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
    setState(() {});
  }

  /// Ganti sumber VideoPlayerController ke [path] (file preview audio atau
  /// source). Dipakai sync preview Approach 2 (PRD-SPRINT-10 §3.2).
  Future<void> _switchControllerTo(String path, {double volume = 1}) async {
    final old = _videoController;
    old?.removeListener(_onVideoUpdate);
    setState(() {
      _isVideoInitialized = false;
      _videoError = null;
    });
    await old?.dispose();

    final controller = VideoPlayerController.file(File(path));
    _videoController = controller;
    controller.addListener(_onVideoUpdate);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setVolume(volume);
      controller.seekTo(Duration(milliseconds: (_playheadSec * 1000).round()));
      setState(() => _isVideoInitialized = true);
    } catch (e) {
      debugPrint('Switch controller error: $e');
      if (mounted) setState(() => _videoError = '$e');
    }
  }

  /// Terapkan mode audio saat ini: swap controller ke file preview
  /// (replacement) atau kembali ke source (original/muted).
  /// Mute = source + volume 0; original = source + volume 1.
  Future<void> _applyAudioMode() async {
    final state = context.read<AppState>();
    final project = state.byId(widget.projectId);
    if (project == null) return;
    final mode = project.audioMode;
    if (mode == _lastAppliedAudioMode && _videoController != null) return;

    setState(() => _isAudioProcessing = true);
    try {
      if (mode == AudioMode.replacement) {
        final previewPath =
            await state.buildPreviewWithAudio(widget.projectId);
        if (previewPath != null && mounted) {
          await _switchControllerTo(previewPath, volume: 1);
        }
      } else {
        if (_lastAppliedAudioMode == AudioMode.replacement) {
          // dari preview → kembali ke source file.
          await _switchControllerTo(project.filePath,
              volume: mode == AudioMode.muted ? 0 : 1);
        } else {
          // tetap di source, atur volume saja.
          await _videoController?.setVolume(mode == AudioMode.muted ? 0 : 1);
        }
      }
      _lastAppliedAudioMode = mode;
    } catch (e) {
      debugPrint('Apply audio mode error: $e');
    } finally {
      if (mounted) setState(() => _isAudioProcessing = false);
    }
  }

  /// Buka panel kontrol audio (bottom sheet).
  void _openAudioPanel(Project project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VC.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: VC.ink, width: 3),
      ),
      isScrollControlled: true,
      builder: (_) => AudioPanel(
        projectId: project.id,
        onAudioChange: _applyAudioMode,
      ),
    );
  }

  void _selectClip(int index) {
    final appState = context.read<AppState>();
    final project = appState.byId(widget.projectId) ?? appState.activeProject;
    if (project == null) return;

    setState(() {
      _selectedClipIndex = index;
      if (index < project.clips.length) {
        final clip = project.clips[index];
        final start = clip.parts.isNotEmpty ? clip.parts.first.start : 0.0;
        final end = clip.parts.isNotEmpty ? clip.parts.last.end : clip.duration;
        _clipStartSec = start;
        _clipEndSec = end;
        _playheadSec = start;
        _seekTo(start);
      }
    });
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (ctx, state, _) {
      final project = state.byId(widget.projectId);

      if (project == null) {
        return Scaffold(
          backgroundColor: VC.bg,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PROJECT TIDAK DITEMUKAN', style: VT.display(20)),
                const SizedBox(height: 12),
                Text('Silakan upload atau pilih project dari Dashboard.', style: VT.mono(13, color: VC.muted)),
                const SizedBox(height: 24),
                BButton(
                  label: 'KEMBALI KE DASHBOARD',
                  kind: BtnKind.yellow,
                  onTap: () => Navigator.of(context).pushReplacementNamed('/dashboard'),
                ),
              ],
            ),
          ),
        );
      }

      final fileName = project.name.toUpperCase();
      final duration = project.probe?.durationSec ?? 0.0;

      return Scaffold(
        backgroundColor: VC.bg,
        body: Column(
          children: [
            // 1. TOP BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: VC.bg,
                border: Border(bottom: BorderSide(color: VC.ink, width: 3)),
              ),
              child: Row(
                children: [
                  // Back button
                  Clickable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: VC.ink, width: 2),
                        boxShadow: VB.shadow(3),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back, size: 16, color: VC.ink),
                          const SizedBox(width: 8),
                          Text('BACK', style: VT.mono(12, color: VC.ink)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Filename in center
                  Text(
                    fileName,
                    style: VT.mono(13, color: VC.muted),
                  ),
                  const Spacer(),
                  // Navigasi Hook Finder & Caption Reframe
                  BButton(
                    label: 'HOOK FINDER',
                    icon: Icons.auto_awesome,
                    kind: BtnKind.outline,
                    small: true,
                    onTap: () => Navigator.of(context)
                        .pushNamed('/hooks', arguments: widget.projectId),
                  ),
                  const SizedBox(width: 8),
                  BButton(
                    label: 'CAPTION & REFRAME',
                    icon: Icons.subtitles,
                    kind: BtnKind.outline,
                    small: true,
                    onTap: () => Navigator.of(context).pushNamed(
                        '/caption-reframe',
                        arguments: project.name),
                  ),
                  const SizedBox(width: 8),
                  BButton(
                    label: 'AUDIO',
                    icon: Icons.graphic_eq,
                    kind: project.audioMode != AudioMode.original
                        ? BtnKind.yellow
                        : BtnKind.outline,
                    small: true,
                    onTap: _isAudioProcessing ? null : () => _openAudioPanel(project),
                  ),
                  const SizedBox(width: 12),
                  // Cancel & Export buttons
                  BButton(
                    label: 'CANCEL',
                    kind: BtnKind.outline,
                    small: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  BButton(
                    label: 'EXPORT',
                    icon: Icons.download,
                    kind: BtnKind.dark,
                    small: true,
                    onTap: () {
                      final clips = project.clips;
                      if (clips.isEmpty) {
                        showBrutalSnack(context, 'Belum ada clip untuk diexport.');
                        return;
                      }
                      final clipId = clips[_selectedClipIndex.clamp(0, clips.length - 1)].id;
                      showDialog(
                        context: context,
                        builder: (ctx) => Dialog(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          child: ExportModal(
                            projectId: widget.projectId,
                            clipId: clipId,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 2. MAIN BODY (2 Columns)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LEFT COLUMN: Video Preview & Aspect Ratio (380px wide)
                  Container(
                    width: 420,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: VC.ink, width: 3)),
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Video Player Card (9:16 vertical ratio)
                        Container(
                          width: 290,
                          height: 480,
                          decoration: BoxDecoration(
                            color: VC.playerBg,
                            border: Border.all(color: VC.ink, width: 3),
                            boxShadow: const [
                              BoxShadow(color: VC.ink, offset: Offset(8, 8), blurRadius: 0),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Video Player Widget
                              if (_isVideoInitialized && _videoController != null)
                                SizedBox.expand(
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _videoController!.value.size.width,
                                      height: _videoController!.value.size.height,
                                      child: VideoPlayer(_videoController!),
                                    ),
                                  ),
                                )
                              else if (_videoError != null)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Video gagal dimuat:\n$_videoError',
                                    textAlign: TextAlign.center,
                                    style: VT.mono(10, color: Colors.white70),
                                  ),
                                )
                              else
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: VC.yellow,
                                  ),
                                ),
                              // Play/Pause Button in Center
                              Clickable(
                                onTap: _togglePlayPause,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.6),
                                    border: Border.all(color: VC.yellow, width: 3),
                                  ),
                                  child: Icon(
                                    _videoController?.value.isPlaying == true
                                        ? Icons.pause
                                        : Icons.play_arrow_rounded,
                                    size: 38,
                                    color: VC.yellow,
                                  ),
                                ),
                              ),
                              // Subtitle / Caption at bottom (klik untuk buka Caption & Reframe)
                              Positioned(
                                bottom: 24,
                                left: 16,
                                right: 16,
                                child: Clickable(
                                  onTap: () => Navigator.of(context).pushNamed(
                                      '/caption-reframe',
                                      arguments: project.name),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.85),
                                      border:
                                          Border.all(color: VC.ink, width: 1.5),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          (project.clips.isNotEmpty && _selectedClipIndex < project.clips.length)
                                              ? project.clips[_selectedClipIndex].title
                                              : 'Detik ${_playheadSec.toStringAsFixed(1)}s',
                                          textAlign: TextAlign.center,
                                          style:
                                              VT.mono(12, color: Colors.white),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.edit,
                                            size: 12, color: Colors.white70),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Aspect Ratio Toggles
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Clickable(
                              onTap: () => setState(() => _selectedAspectRatio = '9:16'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedAspectRatio == '9:16'
                                      ? VC.green // Teal green
                                      : Colors.white,
                                  border: Border.all(color: VC.ink, width: 2),
                                  boxShadow: VB.shadow(3),
                                ),
                                child: Text('9:16', style: VT.mono(12, color: VC.ink)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Clickable(
                              onTap: () => setState(() => _selectedAspectRatio = '1:1'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedAspectRatio == '1:1'
                                      ? VC.blue // Vibrant blue
                                      : Colors.white,
                                  border: Border.all(color: VC.ink, width: 2),
                                  boxShadow: VB.shadow(3),
                                ),
                                child: Text('1:1', style: VT.mono(12, color: VC.ink)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // RIGHT COLUMN: Controls, Clips List & Timeline
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. PROMPT BAR
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: VC.ink, width: 2.5),
                              boxShadow: VB.shadow(4),
                            ),
                            child: Row(
                              children: [
                                // Magenta Prompt Tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  height: double.infinity,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: VC.pink,
                                    border: Border(right: BorderSide(color: VC.ink, width: 2.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.auto_awesome, size: 16, color: VC.ink),
                                      const SizedBox(width: 6),
                                      Text('PROMPT', style: VT.mono(12, color: VC.ink)),
                                    ],
                                  ),
                                ),
                                // Text Input
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: TextField(
                                      controller: _promptCtrl,
                                      style: VT.body(13),
                                      decoration: InputDecoration(
                                        hintText: 'ambil momen paling lucu, durasi 30-45 detik...',
                                        hintStyle: VT.body(13, color: VC.muted),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ),
                                // Yellow Submit Button
                                Clickable(
                                  onTap: () {
                                    final text = _promptCtrl.text.toLowerCase();
                                    double min = 30;
                                    double max = 60;
                                    final match = RegExp(r'(\d+)\s*(?:-|s/d|sampai|to)\s*(\d+)').firstMatch(text);
                                    if (match != null) {
                                      min = double.tryParse(match.group(1)!) ?? 30;
                                      max = double.tryParse(match.group(2)!) ?? 60;
                                    }
                                    state.regenerateClips(project.id, targetMin: min, targetMax: max);
                                    showBrutalSnack(context, 'Memfilter klip: ${min.toInt()}-${max.toInt()} detik');
                                  },
                                  child: Container(
                                    width: 48,
                                    height: double.infinity,
                                    decoration: const BoxDecoration(
                                      color: VC.yellow,
                                      border: Border(left: BorderSide(color: VC.ink, width: 2.5)),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.arrow_forward, color: VC.ink, size: 20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 2. CLIPS LIST HEADER
                          Row(
                            children: [
                              Text(
                                '${project.clips.length} CLIPS FOUND',
                                style: VT.display(18),
                              ),
                              const Spacer(),
                              Text('PROJECT: ${project.name}', style: VT.mono(11, color: VC.muted)),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // 3. CLIPS CARDS
                          Expanded(
                            child: project.clips.isEmpty
                                ? Center(
                                    child: Text('Tidak ada klip untuk proyek ini.', style: VT.body(12, color: VC.muted)),
                                  )
                                : ListView.builder(
                                    itemCount: project.clips.length,
                                    itemBuilder: (context, index) {
                                      final clip = project.clips[index];
                                      final start = clip.parts.isNotEmpty ? clip.parts.first.start : 0.0;
                                      final end = clip.parts.isNotEmpty ? clip.parts.last.end : clip.duration;
                                      final timeStr = '${fmtTime(start)} → ${fmtTime(end)}';
                                      final tagStr = clip.type == ClipType.resequenced ? 'RESEQUENCED' : 'LINEAR';
                                      
                                      Color mainBg = Colors.white;
                                      Color scoreBg = VC.green;
                                      if (clip.score >= 90) {
                                        mainBg = VC.yellow; // Yellow
                                        scoreBg = VC.pink; // Coral Pink
                                      } else if (clip.score >= 80) {
                                        scoreBg = VC.yellow;
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _buildClipCard(
                                          index: index,
                                          duration: '${clip.duration.round()}s',
                                          title: clip.title,
                                          timecode: timeStr,
                                          tag: tagStr,
                                          score: '${clip.score}',
                                          mainBg: mainBg,
                                          scoreBg: scoreBg,
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          const SizedBox(height: 18),

                          // 4. INTERACTIVE TIMELINE SECTION
                          Container(
                            height: 200,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: VC.ink, width: 2.5),
                              boxShadow: VB.shadow(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                        'TIMELINE · SOURCE ${fmtTime(duration)}',
                                        style: VT.mono(11, color: VC.ink)),
                                    const Spacer(),
                                    Flexible(
                                      child: Text(
                                        'PLAYHEAD: ${fmtTime(_playheadSec)}  |  TRIM: ${fmtTime(_clipStartSec)} → ${fmtTime(_clipEndSec)} (${(_clipEndSec - _clipStartSec).toStringAsFixed(1)}s)',
                                        style: VT.mono(11, color: VC.muted),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ProTimeline(
                                    durationSec: duration,
                                    playhead: _playheadSec,
                                    clip: project.clips.isNotEmpty
                                        ? project.clips[_selectedClipIndex.clamp(0, project.clips.length - 1)]
                                        : Clip(id: 'empty', title: '', parts: const [ClipPart(0, 1)],
                                            hook: const ClipPart(0, 1), score: 0, reason: '',
                                            type: ClipType.linear),
                                    signals: state.signalsOf(widget.projectId),
                                    projectId: widget.projectId,
                                    sourcePath: project.filePath,
                                    brollRecommendations: project.clips.isNotEmpty
                                        ? project.clips[_selectedClipIndex.clamp(0, project.clips.length - 1)]
                                            .brollRecommendations
                                        : const [],
                                    onPlayheadChanged: (sec) {
                                      _seekTo(sec);
                                      setState(() => _playheadSec = sec);
                                    },
                                    onPartsChanged: (parts) {
                                      if (project.clips.isNotEmpty) {
                                        final clip = project.clips[_selectedClipIndex.clamp(0, project.clips.length - 1)];
                                        state.updateClipParts(widget.projectId, clip.id, parts);
                                        setState(() {
                                          _clipStartSec = parts.first.start;
                                          _clipEndSec = parts.last.end;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3RD COLUMN: EXTRACTED ASSETS SIDEBAR (190px wide)
                  Container(
                    width: 190,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(left: BorderSide(color: VC.ink, width: 3)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('ASSET', style: VT.mono(11, weight: FontWeight.w700)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: VC.yellow,
                                border: Border.all(color: VC.ink, width: 1.5),
                              ),
                              child: Text('${project.assets.length}', style: VT.mono(9, weight: FontWeight.w900)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Klik untuk preview waktu', style: VT.mono(9, color: VC.muted)),
                        const SizedBox(height: 12),
                        
                        // Extracted Assets List
                        Expanded(
                          child: ListView.builder(
                            itemCount: project.assets.length,
                            itemBuilder: (ctx, i) {
                              final a = project.assets[i];
                              return _buildExtractedAssetTile(a);
                            },
                          ),
                        ),

                        const SizedBox(height: 10),
                        // Button to full Asset Library
                        SizedBox(
                          width: double.infinity,
                          child: BButton(
                            label: 'ASSET LIBRARY',
                            icon: Icons.perm_media,
                            kind: BtnKind.outline,
                            small: true,
                            onTap: () => Navigator.of(context).pushNamed('/assets'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildExtractedAssetTile(dynamic a) {
    IconData icon = Icons.movie;
    Color color = VC.blue;

    if (a.type.toString().contains('hook')) {
      icon = Icons.anchor;
      color = VC.pink; // Pink
    } else if (a.type.toString().contains('broll')) {
      icon = Icons.image;
      color = VC.blue; // Blue
    } else if (a.type.toString().contains('soundBite')) {
      icon = Icons.volume_up;
      color = VC.green; // Green/Teal
    } else if (a.type.toString().contains('ocrText')) {
      icon = Icons.title;
      color = VC.yellow; // Yellow
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Clickable(
        onTap: () {
          setState(() {
            _playheadSec = a.start.toDouble();
            _clipStartSec = a.start.toDouble();
            _clipEndSec = a.end.toDouble();
          });
          showBrutalSnack(context, 'Seek ke ${a.title} [${fmtTime(a.start)} → ${fmtTime(a.end)}]');
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: VC.ink, width: 1.5),
            boxShadow: VB.shadow(2),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: VC.ink, width: 1.5),
                ),
                child: Icon(icon, size: 16, color: VC.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: VT.body(10, weight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${fmtTime(a.start)} – ${fmtTime(a.end)}',
                      style: VT.mono(8, color: VC.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClipCard({
    required int index,
    required String duration,
    required String title,
    required String timecode,
    required String tag,
    required String score,
    required Color mainBg,
    required Color scoreBg,
  }) {
    final isSelected = _selectedClipIndex == index;

    return Clickable(
      onTap: () => _selectClip(index),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: VC.ink, width: 2.5),
          boxShadow: VB.shadow(isSelected ? 5 : 3),
        ),
        child: Row(
          children: [
            // Left Duration Box
            Container(
              width: 60,
              height: double.infinity,
              color: VC.playerBg,
              alignment: Alignment.center,
              child: Text(duration, style: VT.mono(13, color: Colors.white)),
            ),

            // Middle Content Box
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: mainBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: VT.body(14, weight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(timecode, style: VT.mono(11, color: VC.muted)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: VC.ink, width: 1.5),
                          ),
                          child: Text(tag, style: VT.mono(9, color: VC.ink)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Right Score Box
            Container(
              width: 74,
              height: double.infinity,
              decoration: BoxDecoration(
                color: scoreBg,
                border: const Border(left: BorderSide(color: VC.ink, width: 2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(score, style: VT.display(18)),
                  Text('SCORE', style: VT.mono(9, color: VC.ink)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
