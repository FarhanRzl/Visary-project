import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/brutal.dart';

/// Caption & Reframe sidebar panel — extracted from CaptionReframeScreen (PRD-SPRINT-18).
///
/// Stateless: menerima state via params, notifies parent via callbacks.
/// Video preview dummy NOT included — Clip Editor's VideoPlayer is the sole preview.
class CaptionReframePanel extends StatelessWidget {
  const CaptionReframePanel({
    super.key,
    required this.projectId,
    required this.aspectRatio, // 0 = 9:16, 1 = 1:1
    required this.reframeMode, // 0 = Ikuti Subjek, 1 = Blur-Pad
    required this.captionPreset, // 0 = Pop Kuning, 1 = Bold Putih, 2 = Pink Box
    required this.captionPosition, // 0 = Atas, 1 = Tengah, 2 = Bawah
    required this.activeWordIdx,
    required this.onAspectRatioChanged,
    required this.onReframeModeChanged,
    required this.onCaptionPresetChanged,
    required this.onCaptionPositionChanged,
    required this.onActiveWordChanged,
  });

  final String projectId;
  final int aspectRatio;
  final int reframeMode;
  final int captionPreset;
  final int captionPosition;
  final int activeWordIdx;
  final ValueChanged<int> onAspectRatioChanged;
  final ValueChanged<int> onReframeModeChanged;
  final ValueChanged<int> onCaptionPresetChanged;
  final ValueChanged<int> onCaptionPositionChanged;
  final ValueChanged<int> onActiveWordChanged;

  Transcript? _transcript(BuildContext context) =>
      context.read<AppState>().signalsOf(projectId)?.transcript;

  List<String> _words(BuildContext context) {
    final state = context.read<AppState>();
    final transcript = state.signalsOf(projectId)?.transcript;
    if (transcript != null && transcript.words.isNotEmpty) {
      return transcript.words
          .map((w) => w.word.trim())
          .where((w) => w.isNotEmpty)
          .toList();
    }
    final name = state.byId(projectId)?.name ?? '';
    return name.isEmpty
        ? <String>[]
        : name.split(' ').where((w) => w.isNotEmpty).toList();
  }

  /// Export transcript ke file .srt atau .txt — PRD-SPRINT-12.
  Future<void> _exportTranscript(BuildContext context, String format) async {
    final t = _transcript(context);
    if (t == null || t.isEmpty) return;

    final project = context.read<AppState>().byId(projectId);
    final rawName = project?.name ?? 'project';
    final safeName = rawName.replaceAll(RegExp(r'[^\w\-]'), '_');

    final folder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih Folder Export Transcript',
    );
    if (folder == null) return;

    final ext = format;
    final filePath = '$folder/${safeName}_transcript.$ext';

    try {
      final content = format == 'srt' ? t.toSrt() : t.toTxt();
      await File(filePath).writeAsString(content);
      if (context.mounted) {
        showBrutalSnack(context, 'Transcript tersimpan: $filePath');
      }
    } catch (e) {
      if (context.mounted) {
        showBrutalSnack(context, 'Gagal menyimpan transcript: $e',
            color: VC.pink);
      }
    }
  }

  List<Widget> _buildExportSection(BuildContext context) {
    final t = _transcript(context);
    if (t == null || t.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VC.bg,
            border: Border.all(color: VC.muted, width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: VC.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Belum ada transcript. Jalankan ASR terlebih dahulu.',
                    style: VT.body(11, color: VC.muted)),
              ),
            ],
          ),
        ),
      ];
    }

    final widgets = <Widget>[];

    // Warning: transcript tanpa timestamp → .SRT kosong.
    if (t.words.isEmpty && t.fullText.isNotEmpty) {
      widgets.add(Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: VC.yellow,
          border: Border.all(color: VC.ink, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 14, color: VC.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Transcript tanpa timestamp. .SRT kosong — gunakan .TXT.',
                  style: VT.mono(10, color: VC.ink)),
            ),
          ],
        ),
      ));
    }

    widgets.add(Row(
      children: [
        Expanded(
          child: BButton(
            label: '.SRT',
            icon: Icons.subtitles,
            kind: BtnKind.outline,
            expand: true,
            onTap: (t.words.isNotEmpty)
                ? () => _exportTranscript(context, 'srt')
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: BButton(
            label: '.TXT',
            icon: Icons.description,
            kind: BtnKind.outline,
            expand: true,
            onTap: () => _exportTranscript(context, 'txt'),
          ),
        ),
      ],
    ));

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: VC.ink, width: 3)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: withGaps([
          // Header
          Text('CAPTION & REFRAME', style: VT.mono(11, weight: FontWeight.w700)),

          const Divider(color: VC.ink, thickness: 2),

          // Export Transcript — placed above per skill rule (action buttons above growable sections)
          Text('EXPORT TRANSCRIPT', style: VT.mono(11)),
          ..._buildExportSection(context),

          const Divider(color: VC.ink, thickness: 2),

          // Aspect Ratio Toggle
          Text('ASPECT RATIO', style: VT.mono(11)),
          Row(
            children: [
              Expanded(
                child: Clickable(
                  onTap: () => onAspectRatioChanged(0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: aspectRatio == 0 ? VC.green : Colors.white,
                      border: Border.all(color: VC.ink, width: 2),
                      boxShadow: VB.shadow(2),
                    ),
                    child: Center(child: Text('9:16 (VERTIKAL)', style: VT.mono(11))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Clickable(
                  onTap: () => onAspectRatioChanged(1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: aspectRatio == 1 ? VC.blue : Colors.white,
                      border: Border.all(color: VC.ink, width: 2),
                      boxShadow: VB.shadow(2),
                    ),
                    child: Center(child: Text('1:1 (PERSEGI)', style: VT.mono(11))),
                  ),
                ),
              ),
            ],
          ),

          const Divider(color: VC.ink, thickness: 2),

          // Reframe Mode
          Text('MODE REFRAME', style: VT.mono(11)),
          Row(
            children: [
              Expanded(
                child: Clickable(
                  onTap: () => onReframeModeChanged(0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: reframeMode == 0 ? VC.yellow : Colors.white,
                      border: Border.all(color: VC.ink, width: 2),
                      boxShadow: VB.shadow(2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IKUTI SUBJEK', style: VT.mono(11, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Crop dinamis AI', style: VT.body(10, color: VC.muted)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Clickable(
                  onTap: () => onReframeModeChanged(1),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: reframeMode == 1 ? VC.yellow : Colors.white,
                      border: Border.all(color: VC.ink, width: 2),
                      boxShadow: VB.shadow(2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BLUR-PAD', style: VT.mono(11, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Latar blur statis', style: VT.body(10, color: VC.muted)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const Divider(color: VC.ink, thickness: 2),

          // Caption Preset
          Text('PRESET CAPTION', style: VT.mono(11)),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _presetChip('POP KUNING', 0, VC.yellow),
              _presetChip('BOLD PUTIH', 1, Colors.white),
              _presetChip('PINK BOX', 2, VC.pink),
            ],
          ),

          const SizedBox(height: 4),

          // Caption Position
          Text('POSISI CAPTION', style: VT.mono(11)),
          Row(
            children: [
              _posBtn('ATAS', 0),
              const SizedBox(width: 8),
              _posBtn('TENGAH', 1),
              const SizedBox(width: 8),
              _posBtn('BAWAH', 2),
            ],
          ),

          const Divider(color: VC.ink, thickness: 2),

          // Interactive Transcript Editor
          Text('KOREKSI TRANSKRIP', style: VT.mono(11)),
          Text('Klik kata untuk koreksi hasil ASR Whisper:',
              style: VT.body(11, color: VC.muted)),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VC.bg,
              border: Border.all(color: VC.ink, width: 2),
            ),
            child: _words(context).isEmpty
                ? Text(
                    'Belum ada transkrip.',
                    style: VT.body(11, color: VC.muted),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _words(context).asMap().entries.map((e) {
                      final sel = e.key == activeWordIdx;
                      return Clickable(
                        onTap: () => onActiveWordChanged(e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: sel ? VC.yellow : Colors.white,
                            border: Border.all(color: VC.ink, width: 1.5),
                            boxShadow: sel ? VB.shadow(2) : null,
                          ),
                          child: Text(e.value,
                              style: VT.body(12, weight: FontWeight.w700)),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ], 16),
      ),
    );
  }

  Widget _presetChip(String title, int idx, Color color) {
    final active = captionPreset == idx;
    return Clickable(
      onTap: () => onCaptionPresetChanged(idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          border: Border.all(color: VC.ink, width: 2),
          boxShadow: active ? VB.shadow(3) : null,
        ),
        child: Text(title, style: VT.mono(10, color: VC.ink)),
      ),
    );
  }

  Widget _posBtn(String title, int idx) {
    final active = captionPosition == idx;
    return Expanded(
      child: Clickable(
        onTap: () => onCaptionPositionChanged(idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? VC.ink : Colors.white,
            border: Border.all(color: VC.ink, width: 2),
          ),
          child: Center(
            child: Text(title,
                style: VT.mono(10, color: active ? Colors.white : VC.ink)),
          ),
        ),
      ),
    );
  }
}

/// Build caption overlay widget based on preset — used by ClipEditorScreen
/// for live preview on the video player.
Widget buildCaptionOverlay({
  required int preset,
  required String text,
}) {
  if (text.isEmpty) return const SizedBox.shrink();

  switch (preset) {
    case 0: // Pop Kuning
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: VC.yellow,
          border: Border.all(color: VC.ink, width: 2),
          boxShadow: VB.shadow(3),
        ),
        child: Text(
          text,
          style: VT.display(15, color: VC.ink),
        ),
      );
    case 1: // Bold Putih
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: VC.ink, width: 2),
          boxShadow: VB.shadow(3),
        ),
        child: Text(
          text.toUpperCase(),
          style: VT.display(15, color: VC.ink),
        ),
      );
    case 2: // Pink Box
    default:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: VC.pink,
          border: Border.all(color: VC.ink, width: 2),
          boxShadow: VB.shadow(3),
        ),
        child: Text(
          text,
          style: VT.display(15, color: Colors.white),
        ),
      );
  }
}
