import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/brutal.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VC.bg,
      body: Column(
        children: [
          BTopBar(
            left: const Logo(),
            right: [
              BButton(
                label: 'UPLOAD',
                icon: Icons.upload,
                kind: BtnKind.yellow,
                small: true,
                onTap: () => Navigator.of(context).pushNamed('/upload'),
              ),
              BButton(
                label: 'ASSETS',
                icon: Icons.perm_media,
                kind: BtnKind.outline,
                small: true,
                onTap: () => Navigator.of(context).pushNamed('/assets'),
              ),
              BButton(
                label: 'PENGATURAN',
                icon: Icons.settings,
                kind: BtnKind.outline,
                small: true,
                onTap: () => Navigator.of(context).pushNamed('/settings'),
              ),
            ],
          ),
          Expanded(
            child: Row(
              children: [
                // Sidebar nav
                Container(
                  width: 200,
                  decoration: const BoxDecoration(
                    color: VC.paper,
                    border: Border(
                        right: BorderSide(color: VC.ink, width: 3)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child:
                            Text('PROJECTS', style: VT.display(14)),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Consumer<AppState>(
                            builder: (c, state, _) => ListView(
                              children: state.projects
                                  .map((p) => Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 8),
                                        child: Clickable(
                                          onTap: () =>
                                              state.setActiveProject(p.id),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10),
                                            decoration: BoxDecoration(
                                              color: state.activeProjectId ==
                                                      p.id
                                                  ? VC.yellow
                                                  : VC.paper,
                                              border: Border.all(
                                                  color: VC.ink, width: 2),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(p.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: VT.body(12,
                                                        weight:
                                                            FontWeight.w700)),
                                                Text(
                                                  fmtTime(p.probe?.durationSec ?? 0),
                                                  style: VT.mono(10,
                                                      color: VC.muted),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Main grid
                Expanded(
                  child: Consumer<AppState>(
                    builder: (c, state, _) {
                      if (state.projects.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.video_library,
                                  size: 48, color: VC.muted),
                              const SizedBox(height: 16),
                              Text('Tidak ada project',
                                  style: VT.body(14, color: VC.muted)),
                            ],
                          ),
                        );
                      }
                      return GridView.count(
                        crossAxisCount:
                            (MediaQuery.of(context).size.width - 200) ~/ 340,
                        padding: const EdgeInsets.all(32),
                        mainAxisSpacing: 24,
                        crossAxisSpacing: 24,
                        childAspectRatio: 1.0,
                        children: state.projects
                            .map((p) => _ProjectCard(p))
                            .toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard(this.project);
  final Project project;

  Future<void> _confirmDelete(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await showBrutalDialog<bool>(
      context,
      width: 440,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('HAPUS PROJECT?', style: VT.display(20)),
          const SizedBox(height: 10),
          Text(
            '"${project.name}" beserta seluruh clip, asset, thumbnail, dan '
            'file cache-nya akan dihapus permanen. Tindakan ini tidak bisa '
            'dibatalkan.',
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
      ),
    );
    if (ok == true) await state.removeProject(project.id);
  }

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: () => Navigator.of(context).pushNamed('/editor', arguments: project.id),
      child: BBox(
        shadow: 6,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail nyata dari keyframe video (PRD-SPRINT-07 §2.2)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: VC.blue,
                  border: Border.all(color: VC.ink, width: 2),
                ),
                child: (project.thumbnailPath != null &&
                        File(project.thumbnailPath!).existsSync())
                    ? Image.file(File(project.thumbnailPath!),
                        fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                    : const Center(
                        child: Icon(Icons.play_arrow, size: 48, color: VC.paper)),
              ),
            ),
            const SizedBox(height: 8),
            Text(project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VT.body(12, weight: FontWeight.w700)),
            Text(
                project.probe == null
                    ? 'Analyzing...'
                    : '${project.probe!.width}×${project.probe!.height} · ${fmtTime(project.probe!.durationSec)}',
                style: VT.mono(10, color: VC.muted)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.stage.name.toUpperCase(),
                    style: VT.mono(10, color: VC.ink),
                  ),
                ),
                if (project.clips.isNotEmpty)
                  BTag(project.clips.length.toString(),
                      fg: VC.yellow, color: VC.yellow),
                const SizedBox(width: 6),
                Clickable(
                  onTap: () => _confirmDelete(context),
                  child: Tooltip(
                    message: 'Hapus project',
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        border: Border.all(color: VC.ink, width: 2),
                        color: VC.paper,
                      ),
                      child: const Icon(Icons.delete_outline,
                          size: 14, color: VC.ink),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
