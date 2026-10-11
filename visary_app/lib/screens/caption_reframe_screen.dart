import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/brutal.dart';

/// Caption & Reframe Screen — canvas `i7Nwe` (06-caption-reframe.png)
class CaptionReframeScreen extends StatefulWidget {
  const CaptionReframeScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<CaptionReframeScreen> createState() => _CaptionReframeScreenState();
}

class _CaptionReframeScreenState extends State<CaptionReframeScreen> {
  int _aspectRatio = 0; // 0 = 9:16, 1 = 1:1
  int _reframeMode = 0; // 0 = Ikuti Subjek, 1 = Blur-Pad
  int _captionPreset = 0; // 0 = Pop Kuning, 1 = Bold Putih, 2 = Pink Box
  int _captionPosition = 1; // 0 = Atas, 1 = Tengah (karena OCR warning), 2 = Bawah

  /// Kata caption: dari transkripsi ASR nyata bila tersedia (PRD-SPRINT-11),
  /// fallback ke nama project split bila ASR belum aktif/gagal.
  List<String> get _words {
    final state = context.read<AppState>();
    final transcript = state.signalsOf(widget.projectId)?.transcript;
    if (transcript != null && transcript.words.isNotEmpty) {
      return transcript.words
          .map((w) => w.word.trim())
          .where((w) => w.isNotEmpty)
          .toList();
    }
    final name = state.byId(widget.projectId)?.name ?? '';
    return name.isEmpty
        ? <String>[]
        : name.split(' ').where((w) => w.isNotEmpty).toList();
  }
  int _activeWordIdx = 0;

  String get _captionText =>
      _words.isEmpty ? '' : _words.join(' ');

  Transcript? get _transcript =>
      context.read<AppState>().signalsOf(widget.projectId)?.transcript;

  /// Export transcript ke file .srt atau .txt — PRD-SPRINT-12.
  Future<void> _exportTranscript(String format) async {
    final t = _transcript;
    if (t == null || t.isEmpty) return;

    // Capture project name sebelum async gap (avoid context across async).
    final project = context.read<AppState>().byId(widget.projectId);
    final rawName = project?.name ?? 'project';
    final safeName = rawName.replaceAll(RegExp(r'[^\w\-]'), '_');

    final folder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih Folder Export Transcript',
    );
    if (folder == null) return; // user cancel

    final ext = format;
    final filePath = '$folder/${safeName}_transcript.$ext';

    try {
      final content = format == 'srt' ? t.toSrt() : t.toTxt();
      await File(filePath).writeAsString(content);
      if (mounted) {
        showBrutalSnack(context, 'Transcript tersimpan: $filePath');
      }
    } catch (e) {
      if (mounted) {
        showBrutalSnack(context, 'Gagal menyimpan transcript: $e',
            color: VC.pink);
      }
    }
  }

  /// Build export section widgets — PRD-SPRINT-12.
  List<Widget> _buildExportSection() {
    final t = _transcript;
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
                ? () => _exportTranscript('srt')
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
            onTap: () => _exportTranscript('txt'),
          ),
        ),
      ],
    ));

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final project = context.read<AppState>().byId(widget.projectId);
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
                Clickable(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: VC.ink, width: 2),
                      boxShadow: VB.shadow(3),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back, size: 16, color: VC.ink),
                        const SizedBox(width: 8),
                        Text('BACK', style: VT.mono(12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  'CAPTION & REFRAME · ${(project?.name ?? '').toUpperCase()}',
                  style: VT.display(15),
                ),
                const Spacer(),
                BButton(
                  label: 'SIMPAN',
                  icon: Icons.check,
                  kind: BtnKind.yellow,
                  small: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    showBrutalSnack(context, 'Pengaturan Caption & Reframe disimpan!');
                  },
                ),
              ],
            ),
          ),

          // 2. MAIN BODY
          Expanded(
            child: Row(
              children: [
                // LEFT: Video Preview with Face Tracking Box & Captions
                Expanded(
                  flex: 6,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: AspectRatio(
                        aspectRatio: _aspectRatio == 0 ? 9 / 16 : 1 / 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: VC.playerBg,
                            border: Border.all(color: VC.ink, width: 3),
                            boxShadow: const [
                              BoxShadow(color: VC.ink, offset: Offset(8, 8), blurRadius: 0),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Subject Avatar Representation
                              const Center(
                                child: Icon(Icons.person, size: 120, color: VC.muted),
                              ),

                              // Subject Tracking Box (Face tracking indicator)
                              Positioned(
                                top: 80,
                                left: 60,
                                right: 60,
                                height: 180,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: VC.green, width: 2.5),
                                  ),
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Container(
                                      color: VC.green,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Text('SUBJEK TERDETEKSI',
                                          style: VT.mono(9, color: VC.ink)),
                                    ),
                                  ),
                                ),
                              ),

                              // Caption Overlay on Video
                              Positioned(
                                left: 20,
                                right: 20,
                                top: _captionPosition == 0
                                    ? 50
                                    : (_captionPosition == 1 ? null : null),
                                bottom: _captionPosition == 2
                                    ? 50
                                    : (_captionPosition == 1 ? 160 : null),
                                child: Center(
                                  child: _buildCaptionStylePreview(),
                                ),
                              ),

                              // OCR Collision Detection Warning Tag
                              Positioned(
                                bottom: 20,
                                left: 20,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: VC.yellow,
                                    border: Border.all(color: VC.ink, width: 2),
                                    boxShadow: VB.shadow(2),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 16, color: VC.ink),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'OCR: Teks asli video terdeteksi di bawah. Posisi dipindah otomatis ke tengah.',
                                          style: VT.mono(10, color: VC.ink),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // RIGHT: Settings Panel
                Container(
                  width: 420,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(left: BorderSide(color: VC.ink, width: 3)),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(28),
                    children: withGaps([
                      // Aspect Ratio Toggle
                      Text('ASPECT RATIO', style: VT.mono(11)),
                      Row(
                        children: [
                          Expanded(
                            child: Clickable(
                              onTap: () => setState(() => _aspectRatio = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _aspectRatio == 0 ? VC.green : Colors.white,
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
                              onTap: () => setState(() => _aspectRatio = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _aspectRatio == 1 ? VC.blue : Colors.white,
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
                              onTap: () => setState(() => _reframeMode = 0),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _reframeMode == 0 ? VC.yellow : Colors.white,
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
                              onTap: () => setState(() => _reframeMode = 1),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _reframeMode == 1 ? VC.yellow : Colors.white,
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

                      // Export Transcript — PRD-SPRINT-12
                      Text('EXPORT TRANSCRIPT', style: VT.mono(11)),
                      ..._buildExportSection(),

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
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _words.asMap().entries.map((e) {
                            final sel = e.key == _activeWordIdx;
                            return Clickable(
                              onTap: () => setState(() => _activeWordIdx = e.key),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionStylePreview() {
    switch (_captionPreset) {
      case 0: // Pop Kuning
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: VC.yellow,
            border: Border.all(color: VC.ink, width: 2),
            boxShadow: VB.shadow(3),
          ),
          child: Text(
            _captionText,
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
            _captionText.toUpperCase(),
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
            _captionText,
            style: VT.display(15, color: Colors.white),
          ),
        );
    }
  }

  Widget _presetChip(String title, int idx, Color color) {
    final active = _captionPreset == idx;
    return Clickable(
      onTap: () => setState(() => _captionPreset = idx),
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
    final active = _captionPosition == idx;
    return Expanded(
      child: Clickable(
        onTap: () => setState(() => _captionPosition = idx),
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
