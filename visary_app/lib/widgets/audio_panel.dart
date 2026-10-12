import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'brutal.dart';

/// Panel kontrol audio (PRD-SPRINT-10 §3.4): mute, upload, extract, select.
/// Dibuka sebagai bottom sheet dari editor. Setiap perubahan mode/aset
/// memanggil [onAudioChange] supaya editor bisa swap controller preview.
class AudioPanel extends StatefulWidget {
  const AudioPanel({
    super.key,
    required this.projectId,
    required this.onAudioChange,
  });

  final String projectId;
  final Future<void> Function() onAudioChange;

  @override
  State<AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends State<AudioPanel> {
  bool _busy = false;
  bool _isTranscribing = false;
  bool _isMatching = false;
  String _matchStage = '';

  Future<void> _upload() async {
    final state = context.read<AppState>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    if (picked.path == null) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final asset = await state.uploadAudioAsset(
        widget.projectId,
        fileName: picked.name,
        filePath: picked.path,
      );
      state.setActiveAudioAsset(widget.projectId, asset.id);
      await widget.onAudioChange();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload audio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extract() async {
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      final asset = await state.extractAudioAsset(widget.projectId);
      state.setActiveAudioAsset(widget.projectId, asset.id);
      await widget.onAudioChange();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ekstrak audio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleMute() async {
    final state = context.read<AppState>();
    final project = state.byId(widget.projectId);
    if (project == null) return;
    state.setAudioMode(
      widget.projectId,
      project.audioMode == AudioMode.muted
          ? AudioMode.original
          : AudioMode.muted,
    );
    await widget.onAudioChange();
  }

  Future<void> _useAsset(AssetItem a) async {
    context.read<AppState>().setActiveAudioAsset(widget.projectId, a.id);
    await widget.onAudioChange();
  }

  /// Transkripsi audio pengganti → re-sequence clips. PRD-SPRINT-13.
  Future<void> _transcribeAudio() async {
    setState(() => _isTranscribing = true);
    try {
      final state = context.read<AppState>();
      await state.transcribeReplacementAudio(widget.projectId);
      if (mounted) {
        final t = state.signalsOf(widget.projectId)?.transcript;
        final wordCount = t?.words.length ?? 0;
        showBrutalSnack(context,
            'Transkrip audio pengganti: $wordCount kata. Clips di-resequence.');
      }
    } on StateError catch (e) {
      if (mounted) {
        showBrutalSnack(context, e.message, color: VC.pink);
      }
    } catch (e) {
      if (mounted) {
        showBrutalSnack(context, 'Transkripsi gagal: $e', color: VC.pink);
      }
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  /// Content-aware audio-visual matching via VLM + LLM. PRD-SPRINT-14.
  Future<void> _matchContent() async {
    setState(() {
      _isMatching = true;
      _matchStage = 'Starting...';
    });
    try {
      final state = context.read<AppState>();
      final matchOrder = await state.contentAwareResequence(
        widget.projectId,
        onProgress: (stage) {
          if (mounted) setState(() => _matchStage = stage);
        },
      );
      if (mounted) {
        showBrutalSnack(
          context,
          'Content matched: ${matchOrder.length} segments. Clips di-resequence.',
        );
      }
    } on UnsupportedError catch (e) {
      if (mounted) {
        showBrutalSnack(context, e.message ?? 'Unsupported provider', color: VC.pink);
      }
    } on StateError catch (e) {
      if (mounted) {
        showBrutalSnack(context, e.message, color: VC.pink);
      }
    } catch (e) {
      if (mounted) {
        showBrutalSnack(context, 'Match content gagal: $e', color: VC.pink);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMatching = false;
          _matchStage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (ctx, state, _) {
      final project = state.byId(widget.projectId);
      if (project == null) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Project tidak ditemukan'),
        );
      }
      final audioAssets = project.assets.where((a) => a.isAudio).toList();
      final mode = project.audioMode;

      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('AUDIO TRACK', style: VT.display(18)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: VC.ink),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _modeChip(mode),
            const SizedBox(height: 16),
            // Mute toggle
            BButton(
              label: mode == AudioMode.muted ? 'UNMUTE (AUDIO ASLI)' : 'MUTE AUDIO',
              icon: mode == AudioMode.muted
                  ? Icons.volume_up
                  : Icons.volume_off,
              kind: mode == AudioMode.muted ? BtnKind.yellow : BtnKind.outline,
              expand: true,
              onTap: _busy ? null : _toggleMute,
            ),
            const SizedBox(height: 12),
            // Upload & Extract
            Row(
              children: [
                Expanded(
                  child: BButton(
                    label: 'UPLOAD AUDIO',
                    icon: Icons.file_upload,
                    kind: BtnKind.outline,
                    small: true,
                    onTap: _busy ? null : _upload,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BButton(
                    label: 'EXTRACT AUDIO',
                    icon: Icons.graphic_eq,
                    kind: BtnKind.outline,
                    small: true,
                    onTap: _busy ? null : _extract,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('ASET AUDIO (${audioAssets.length})',
                style: VT.mono(12, color: VC.muted)),
            const SizedBox(height: 8),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child:
                    Center(child: CircularProgressIndicator(color: VC.purple)),
              )
            else if (audioAssets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Belum ada aset audio. Upload file atau ekstrak dari video sumber.',
                  style: VT.body(13, color: VC.muted),
                ),
              )
            else
              ...audioAssets.map(
                  (a) => _audioTile(a, mode, project.activeAudioAssetId)),

            // Transcribe Audio Pengganti — PRD-SPRINT-13
            if (mode == AudioMode.replacement) ...[
              const SizedBox(height: 16),
              const Divider(color: VC.ink, thickness: 2),
              const SizedBox(height: 12),
              Text('TRANSKRIPSI AUDIO PENGGANTI',
                  style: VT.mono(12, color: VC.muted)),
              const SizedBox(height: 8),
              if (_isTranscribing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                      child: CircularProgressIndicator(color: VC.purple)),
                )
              else
                BButton(
                  label: 'TRANSCRIBE AUDIO',
                  icon: Icons.mic,
                  kind: BtnKind.dark,
                  expand: true,
                  onTap: _transcribeAudio,
                ),
            ],

            // Match Content — PRD-SPRINT-14
            if (mode == AudioMode.replacement &&
                state.signalsOf(widget.projectId)?.transcript != null &&
                (state.signalsOf(widget.projectId)?.transcript?.words
                        .isNotEmpty ??
                    false)) ...[
              const SizedBox(height: 16),
              const Divider(color: VC.ink, thickness: 2),
              const SizedBox(height: 12),
              Text('CONTENT-AWARE MATCHING',
                  style: VT.mono(12, color: VC.muted)),
              const SizedBox(height: 8),
              if (_isMatching) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: VC.purple),
                      const SizedBox(height: 8),
                      Text(_matchStage, style: VT.mono(11, color: VC.muted)),
                    ],
                  ),
                ),
              ] else
                BButton(
                  label: 'MATCH CONTENT',
                  icon: Icons.compare,
                  kind: BtnKind.primary,
                  expand: true,
                  onTap: _matchContent,
                ),
            ],
          ],
          ),
        ),
      ),
      );
    });
  }

  Widget _modeChip(AudioMode mode) {
    final (label, color) = switch (mode) {
      AudioMode.original => ('AUDIO ASLI', VC.muted),
      AudioMode.muted => ('MUTED', VC.yellow),
      AudioMode.replacement => ('REPLACEMENT', VC.purple),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: VC.ink, width: 2),
      ),
      child: Text(label, style: VT.mono(11, color: VC.ink)),
    );
  }

  Widget _audioTile(AssetItem a, AudioMode mode, String? activeId) {
    final isActive = mode == AudioMode.replacement && activeId == a.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? VC.purple.withValues(alpha: 0.15) : Colors.white,
        border: Border.all(
            color: isActive ? VC.purple : VC.ink, width: 2),
      ),
      child: ListTile(
        leading: const Icon(Icons.music_note, color: VC.purple),
        title: Text(a.title, style: VT.body(13)),
        subtitle: Text(
          '${a.audioFormat ?? '?'} • ${a.durationSec?.toStringAsFixed(1) ?? '?'}s',
          style: VT.mono(10, color: VC.muted),
        ),
        trailing: isActive
            ? const Icon(Icons.check_circle, color: VC.purple)
            : BButton(
                label: 'PAKAI',
                kind: BtnKind.outline,
                small: true,
                onTap: _busy ? null : () => _useAsset(a),
              ),
      ),
    );
  }
}
