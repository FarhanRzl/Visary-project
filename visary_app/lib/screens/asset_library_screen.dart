import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/video_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/brutal.dart';

/// Asset Library — canvas `v9yYA`. PRD §4.7.
class AssetLibraryScreen extends StatefulWidget {
  const AssetLibraryScreen({super.key});

  @override
  State<AssetLibraryScreen> createState() => _AssetLibraryScreenState();
}

class _AssetLibraryScreenState extends State<AssetLibraryScreen> {
  final _searchCtrl = TextEditingController();
  AssetType? _filter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _typeColor(AssetType t) => switch (t) {
        AssetType.hook => VC.yellow,
        AssetType.broll => VC.blue,
        AssetType.soundBite => VC.green,
        AssetType.ocrText => VC.pink,
        AssetType.audio => VC.purple,
      };

  String _typeLabel(AssetType t) => switch (t) {
        AssetType.hook => 'HOOK',
        AssetType.broll => 'B-ROLL',
        AssetType.soundBite => 'SOUND BITE',
        AssetType.ocrText => 'OCR TEXT',
        AssetType.audio => 'AUDIO',
      };

  IconData _typeIcon(AssetType t) => switch (t) {
        AssetType.hook => Icons.anchor,
        AssetType.broll => Icons.image,
        AssetType.soundBite => Icons.volume_up,
        AssetType.ocrText => Icons.text_fields,
        AssetType.audio => Icons.music_note,
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Flat list asset + project owner-nya (untuk dapat source video path).
    final entries = <(AssetItem, Project)>[];
    for (final p in state.projects) {
      for (final a in p.assets) {
        if (_filter != null && a.type != _filter) continue;
        if (_searchCtrl.text.isNotEmpty &&
            !a.title.toLowerCase().contains(_searchCtrl.text.toLowerCase())) {
          continue;
        }
        entries.add((a, p));
      }
    }

    return Scaffold(
      backgroundColor: VC.bg,
      body: Column(
        children: [
          BTopBar(
            left: Clickable(
              onTap: () => Navigator.of(context).pop(),
              child: Row(children: [
                const Icon(Icons.arrow_back, size: 20),
                const SizedBox(width: 8),
                Text('ASSET LIBRARY · ${entries.length} ASSET',
                    style: VT.display(16)),
              ]),
            ),
            right: [
              SizedBox(
                width: 260,
                child: BInput(
                  controller: _searchCtrl,
                  hint: 'cari hook, b-roll...',
                  prefix: const Icon(Icons.search, size: 16),
                  borderless: false,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                _filterChip('SEMUA', null),
                const SizedBox(width: 8),
                ...AssetType.values.map((t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _filterChip(_typeLabel(t), t))),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text('Tidak ada asset',
                        style: VT.body(14, color: VC.muted)))
                : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (c, i) => _AssetCard(
                      asset: entries[i].$1,
                      project: entries[i].$2,
                      color: _typeColor(entries[i].$1.type),
                      label: _typeLabel(entries[i].$1.type),
                      icon: _typeIcon(entries[i].$1.type),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, AssetType? type) {
    final active = _filter == type;
    return Clickable(
      onTap: () => setState(() => _filter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? VC.ink : VC.paper,
          border: Border.all(color: VC.ink, width: 2),
        ),
        child: Text(label, style: VT.mono(10, color: active ? VC.paper : VC.ink)),
      ),
    );
  }
}

class _AssetCard extends StatefulWidget {
  const _AssetCard({
    required this.asset,
    required this.project,
    required this.color,
    required this.label,
    required this.icon,
  });
  final AssetItem asset;
  final Project project;
  final Color color;
  final String label;
  final IconData icon;

  @override
  State<_AssetCard> createState() => _AssetCardState();
}

class _AssetCardState extends State<_AssetCard> {
  String? _thumbPath;
  bool _loadingThumb = true;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    final p = widget.project;
    final a = widget.asset;
    if (p.filePath.isEmpty || !File(p.filePath).existsSync()) {
      if (mounted) setState(() => _loadingThumb = false);
      return;
    }
    try {
      final tempDir = await Directory.systemTemp.createTemp('visary_asset_thumb_');
      final outPath = '${tempDir.path}/thumb_${a.id}.jpg';
      final result = await VideoService.extractThumbnail(
        sourcePath: p.filePath,
        atSec: a.start,
        outPath: outPath,
      );
      if (mounted) {
        setState(() {
          _thumbPath = result;
          _loadingThumb = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingThumb = false);
    }
  }

  void _preview() {
    final state = context.read<AppState>();
    showBrutalSnack(context, 'Memuat preview ${widget.asset.title}...');
    state.previewSegment(
      projectId: widget.project.id,
      start: widget.asset.start,
      end: widget.asset.end,
    ).then((path) {
      if (mounted) showBrutalSnack(context, 'Preview tersimpan: $path');
    }).catchError((e) {
      if (mounted) showBrutalSnack(context, 'Preview gagal: $e');
    });
  }

  Future<void> _export() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih folder export asset',
    );
    if (dir == null) return;
    if (!mounted) return;

    final state = context.read<AppState>();
    showBrutalSnack(context, 'Mengekspor ${widget.asset.title}...');
    try {
      final path = await state.exportAsset(
        projectId: widget.project.id,
        asset: widget.asset,
        outputDir: dir,
      );
      if (mounted) {
        showBrutalSnack(context, 'Tersimpan: $path');
      }
    } catch (e) {
      if (mounted) showBrutalSnack(context, 'Export gagal: $e');
    }
  }

  Future<void> _delete() async {
    final state = context.read<AppState>();
    final ok = await showBrutalDialog<bool>(context,
        width: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('HAPUS ASSET?', style: VT.display(20)),
            const SizedBox(height: 10),
            Text(
              '"${widget.asset.title}" akan dihapus dari project '
              '"${widget.project.name}".',
              style: VT.body(13),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BButton(
                  label: 'BATAL',
                  kind: BtnKind.outline,
                  small: true,
                  onTap: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 10),
                BButton(
                  label: 'HAPUS',
                  icon: Icons.delete_outline,
                  kind: BtnKind.pink,
                  small: true,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ));
    if (ok == true) {
      state.removeAsset(widget.project.id, widget.asset.id);
      if (mounted) showBrutalSnack(context, 'Asset dihapus.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    return BBox(
      shadow: 4,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: type tag
          Row(children: [
            BTag(widget.label, color: widget.color, size: 9, icon: widget.icon),
            const Spacer(),
            Text(fmtTime(a.start), style: VT.mono(9, color: VC.muted)),
          ]),
          const SizedBox(height: 8),

          // Thumbnail preview nyata dari video
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: VC.bg,
                border: Border.all(color: VC.ink, width: 1.5),
              ),
              child: _loadingThumb
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: VC.muted),
                      ),
                    )
                  : (_thumbPath != null && File(_thumbPath!).existsSync())
                      ? Image.file(File(_thumbPath!),
                          fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                      : Center(
                          child: Icon(widget.icon, size: 28, color: VC.muted),
                        ),
            ),
          ),
          const SizedBox(height: 8),
          Text(a.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: VT.body(12, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              '${a.sourceFile} · ${fmtTime(a.start)}–${fmtTime(a.end)} · '
              '${(a.end - a.start).toStringAsFixed(0)}s',
              style: VT.mono(9, color: VC.muted)),
          const SizedBox(height: 8),

          // Buttons: PREVIEW + EXPORT + HAPUS
          Row(children: [
            Expanded(
              child: BButton(
                label: 'PREVIEW',
                kind: BtnKind.dark,
                small: true,
                onTap: _preview,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: BButton(
                label: 'EXPORT',
                kind: BtnKind.yellow,
                small: true,
                onTap: _export,
              ),
            ),
            const SizedBox(width: 6),
            BButton(
              label: 'HAPUS',
              kind: BtnKind.outline,
              small: true,
              onTap: _delete,
            ),
          ]),
        ],
      ),
    );
  }
}
