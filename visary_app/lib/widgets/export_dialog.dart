import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/video_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'brutal.dart';

/// Modal: Export Clip — canvas `mNyq7` di design / PRD §4.6.
///
/// Menerima [projectId] + [clipId] dan memanggil `AppState.exportClip()`
/// dengan progress bar nyata dari callback FFmpeg (PRD-SPRINT-08, Step 1).
class ExportModal extends StatefulWidget {
  const ExportModal({
    super.key,
    required this.projectId,
    required this.clipId,
  });

  final String projectId;
  final String clipId;

  @override
  State<ExportModal> createState() => _ExportModalState();
}

class _ExportModalState extends State<ExportModal> {
  bool _export9x16 = true;
  bool _export1x1 = false;

  /// Opsi yang belum didukung engine — di-disable dengan label "segera".
  /// Jangan tampilkan seolah aktif (PRD-SPRINT-08 Step 1 task 5).
  // burn-in caption (ASS), .srt, hardware encoder — fase 2

  String _targetFolder = '';
  bool _isExporting = false;
  double _progress = 0.0;
  String _progressLabel = '';
  List<String>? _resultFiles;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initDefaultFolder();
  }

  Future<void> _initDefaultFolder() async {
    String folder;
    try {
      final dir = await getDownloadsDirectory();
      folder = dir?.path ?? Directory.current.path;
    } catch (_) {
      folder = Directory.current.path;
    }
    if (mounted) setState(() => _targetFolder = folder);
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih Folder Export',
    );
    if (result != null && mounted) {
      setState(() => _targetFolder = result);
    }
  }

  Future<void> _startExport() async {
    final state = context.read<AppState>();
    final formats = <AspectFormat>[
      if (_export9x16) AspectFormat.v9x16,
      if (_export1x1) AspectFormat.v1x1,
    ];

    setState(() {
      _isExporting = true;
      _progress = 0.0;
      _progressLabel = 'Memulai render...';
      _resultFiles = null;
      _error = null;
    });

    try {
      final files = await state.exportClip(
        projectId: widget.projectId,
        clipId: widget.clipId,
        formats: formats,
        outputDir: _targetFolder,
        onProgress: (label, progress) {
          if (mounted) {
            setState(() {
              _progressLabel = label;
              _progress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _resultFiles = files;
          _progress = 1.0;
          _progressLabel = 'Selesai';
        });
      }
    } on FfmpegFailedException catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _error = 'Render gagal: ${e.stage} (exit ${e.exitCode}).\n${e.stderrTail}';
        });
      }
    } on FfmpegMissingException catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _error = '$e';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  void _openResultFolder() {
    if (_targetFolder.isNotEmpty) {
      try {
        if (Platform.isLinux) {
          Process.run('xdg-open', [_targetFolder]);
        } else if (Platform.isWindows) {
          Process.run('explorer', [_targetFolder]);
        } else if (Platform.isMacOS) {
          Process.run('open', [_targetFolder]);
        }
      } catch (_) {}
    }
  }

  void _reset() {
    setState(() {
      _resultFiles = null;
      _error = null;
      _progress = 0.0;
      _progressLabel = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final project = state.byId(widget.projectId);
    final clip = project?.clips.where((c) => c.id == widget.clipId).firstOrNull;

    if (clip == null) {
      return BBox(
        color: VC.paper,
        border: VB.thick,
        shadow: 8,
        padding: const EdgeInsets.all(28),
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CLIP TIDAK DITEMUKAN', style: VT.display(18)),
            const SizedBox(height: 12),
            Text('Buka ulang dari editor setelah memilih clip.',
                style: VT.mono(11, color: VC.muted)),
            const SizedBox(height: 16),
            BButton(
              label: 'TUTUP',
              kind: BtnKind.outline,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }

    final fileCount = (_export9x16 ? 1 : 0) + (_export1x1 ? 1 : 0);

    // ── State: Exporting (progress bar real) ──
    if (_isExporting) {
      return BBox(
        color: VC.paper,
        border: VB.thick,
        shadow: 8,
        padding: const EdgeInsets.all(28),
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: withGaps([
            Text('SEDANG MERENDER...', style: VT.display(18)),
            Text(clip.title, style: VT.body(13, color: VC.muted)),
            Text(_progressLabel, style: VT.mono(12)),
            BProgress(value: _progress, color: VC.pink),
            Text('${(_progress * 100).round()}%', style: VT.mono(12)),
          ], 14),
        ),
      );
    }

    // ── State: Success (file path + buka folder) ──
    if (_resultFiles != null) {
      return BBox(
        color: VC.paper,
        border: VB.thick,
        shadow: 8,
        padding: const EdgeInsets.all(28),
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: withGaps([
            Row(
              children: [
                const Icon(Icons.check_circle, color: VC.green, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('EXPORT BERHASIL', style: VT.display(18)),
                ),
                Clickable(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: VC.paper,
                      border: Border.all(color: VC.ink, width: 2),
                    ),
                    child: const Icon(Icons.close, size: 18, color: VC.ink),
                  ),
                ),
              ],
            ),
            Text('${_resultFiles!.length} file berhasil dirender:',
                style: VT.mono(12)),
            ..._resultFiles!.map((f) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: VC.bg,
                    border: Border.all(color: VC.ink, width: 1.5),
                  ),
                  child: Text(f, style: VT.mono(10, color: VC.ink),
                      overflow: TextOverflow.ellipsis),
                )),
            Row(
              children: [
                Expanded(
                  child: BButton(
                    label: 'BUKA FOLDER',
                    icon: Icons.folder_open,
                    kind: BtnKind.primary,
                    expand: true,
                    onTap: _openResultFolder,
                  ),
                ),
                const SizedBox(width: 12),
                BButton(
                  label: 'TUTUP',
                  kind: BtnKind.outline,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ], 14),
        ),
      );
    }

    // ── State: Error ──
    if (_error != null) {
      return BBox(
        color: VC.paper,
        border: VB.thick,
        shadow: 8,
        padding: const EdgeInsets.all(28),
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: withGaps([
            Row(
              children: [
                const Icon(Icons.error, color: VC.pink, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('EXPORT GAGAL', style: VT.display(18)),
                ),
                Clickable(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: VC.paper,
                      border: Border.all(color: VC.ink, width: 2),
                    ),
                    child: const Icon(Icons.close, size: 18, color: VC.ink),
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VC.bg,
                border: Border.all(color: VC.ink, width: 2),
              ),
              child: Text(_error!, style: VT.mono(10, color: VC.ink)),
            ),
            Row(
              children: [
                Expanded(
                  child: BButton(
                    label: 'COBA LAGI',
                    icon: Icons.refresh,
                    kind: BtnKind.primary,
                    expand: true,
                    onTap: _reset,
                  ),
                ),
                const SizedBox(width: 12),
                BButton(
                  label: 'TUTUP',
                  kind: BtnKind.outline,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ], 14),
        ),
      );
    }

    // ── State: Default (format picker + options) ──
    return BBox(
      color: VC.paper,
      border: VB.thick,
      shadow: 8,
      padding: const EdgeInsets.all(28),
      width: 580,
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: withGaps([
          // Header
          Row(
            children: [
              Expanded(
                child: Text('EXPORT CLIP', style: VT.display(18)),
              ),
              Clickable(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: VC.paper,
                    border: Border.all(color: VC.ink, width: 2),
                  ),
                  child: const Icon(Icons.close, size: 18, color: VC.ink),
                ),
              ),
            ],
          ),
          Text(clip.title, style: VT.body(13, color: VC.muted)),
          Text(
            '${clip.duration.toStringAsFixed(1)} detik · skor ${clip.score}',
            style: VT.mono(11, color: VC.muted),
          ),

          const Divider(color: VC.ink, thickness: 2),

          // Format selection
          Text('PILIH FORMAT (MVP: 9:16 & 1:1)', style: VT.mono(11)),

          // 9:16 Vertical
          Clickable(
            onTap: () => setState(() => _export9x16 = !_export9x16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _export9x16 ? VC.yellow : VC.paper,
                border: Border.all(color: VC.ink, width: 2),
              ),
              child: Row(
                children: [
                  Icon(_export9x16 ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 20, color: VC.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('VERTIKAL 1080×1920 (9:16)',
                            style: VT.body(12, weight: FontWeight.w700)),
                        Text('TikTok, Reels, Shorts, RedNote',
                            style: VT.mono(10, color: VC.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 1:1 Square
          Clickable(
            onTap: () => setState(() => _export1x1 = !_export1x1),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _export1x1 ? VC.yellow : VC.paper,
                border: Border.all(color: VC.ink, width: 2),
              ),
              child: Row(
                children: [
                  Icon(_export1x1 ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 20, color: VC.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PERSEGI 1080×1080 (1:1)',
                            style: VT.body(12, weight: FontWeight.w700)),
                        Text('Feed Instagram & Facebook',
                            style: VT.mono(10, color: VC.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Disabled Phase 2 formats
          Opacity(
            opacity: 0.5,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VC.bg,
                border: Border.all(color: VC.muted, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: VC.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Portrait 4:5 (1080×1350) & Landscape 16:9 — Fase 2',
                        style: VT.mono(10, color: VC.muted)),
                  ),
                ],
              ),
            ),
          ),

          const Divider(color: VC.ink, thickness: 1),

          // Disabled options with "segera" label
          Text('OPSI RENDER', style: VT.mono(11)),
          Opacity(
            opacity: 0.5,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VC.bg,
                border: Border.all(color: VC.muted, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: VC.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Burn-in Caption (ASS) — segera',
                            style: VT.mono(10, color: VC.muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: VC.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Ekspor file .SRT transkrip — segera',
                            style: VT.mono(10, color: VC.muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: VC.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Hardware Encoder (NVENC/QSV/AMF) — segera',
                            style: VT.mono(10, color: VC.muted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Destination Folder
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: VC.bg,
              border: Border.all(color: VC.ink, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder, size: 18, color: VC.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _targetFolder.isEmpty ? 'Memuat path default...' : _targetFolder,
                    style: VT.mono(10, color: VC.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Clickable(
                  onTap: _targetFolder.isEmpty ? null : _pickFolder,
                  child: Text('UBAH', style: VT.mono(10, color: VC.blue)),
                ),
              ],
            ),
          ),

          // Export Button
          Row(
            children: [
              Expanded(
                child: BButton(
                  label: 'MULAI EXPORT ($fileCount FILE)',
                  icon: Icons.download,
                  kind: BtnKind.primary,
                  expand: true,
                  onTap: (fileCount > 0 && _targetFolder.isNotEmpty)
                      ? _startExport
                      : null,
                ),
              ),
            ],
          ),
        ], 14),
        ),
      ),
    );
  }
}
