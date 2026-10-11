import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/brutal.dart';

/// Hook Finder — canvas `pEUGr` (05-hook-finder.png)
class HookFinderScreen extends StatefulWidget {
  const HookFinderScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<HookFinderScreen> createState() => _HookFinderScreenState();
}

class _HookFinderScreenState extends State<HookFinderScreen> {
  int _tab = 0; // 0=HOOK, 1=CLIP, 2=ASSET

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final project = state.byId(widget.projectId) ?? 
        (state.projects.isNotEmpty ? state.projects.first : null);

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
                  'HOOK FINDER · ${project.name.toUpperCase()}',
                  style: VT.display(15),
                ),
                const Spacer(),
                // TABS: HOOK, CLIP, ASSET
                Row(
                  children: [
                    _buildTab(0, 'HOOK'),
                    const SizedBox(width: 8),
                    _buildTab(1, 'CLIP'),
                    const SizedBox(width: 8),
                    _buildTab(2, 'ASSET'),
                  ],
                ),
              ],
            ),
          ),

          // 2. MAIN BODY (2 Columns)
          Expanded(
            child: Row(
              children: [
                // LEFT: Hook Candidates List
                Expanded(
                  flex: 7,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(28),
                    itemCount: project.hooks.length,
                    itemBuilder: (c, i) => _buildHookCard(project.hooks[i]),
                  ),
                ),

                // RIGHT: Signal Types Guide ("SINYAL HOOK")
                Container(
                  width: 360,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(left: BorderSide(color: VC.ink, width: 3)),
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SINYAL HOOK', style: VT.display(16)),
                      const SizedBox(height: 8),
                      Text(
                        '6 tipe pemicu atensi yang dideteksi AI dalam 2–5 detik pertama.',
                        style: VT.body(12, color: VC.muted),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView(
                          children: [
                            _buildSignalItem(
                              'Pertanyaan retoris',
                              'Memancing rasa penasaran audiens langsung.',
                              VC.yellow, // Yellow
                              Icons.help_outline,
                            ),
                            _buildSignalItem(
                              'Pernyataan mengejutkan',
                              'Klaim kontroversial atau fakta unik.',
                              VC.pink, // Pink
                              Icons.bolt,
                            ),
                            _buildSignalItem(
                              'Emosi kuat',
                              'Ekspresi wajah kaget, senang, atau marah.',
                              VC.pink, // Coral
                              Icons.sentiment_very_satisfied,
                            ),
                            _buildSignalItem(
                              'Perubahan visual',
                              'Transisi cepat, cut tajam, atau zoom mendadak.',
                              VC.blue, // Blue
                              Icons.movie_filter,
                            ),
                            _buildSignalItem(
                              'Teks overlay',
                              'Teks grafis mencolok terdeteksi oleh OCR.',
                              VC.green, // Teal
                              Icons.title,
                            ),
                            _buildSignalItem(
                              'Puncak energi audio',
                              'Intonasi tinggi atau kenaikan volume vokal.',
                              VC.green, // Green
                              Icons.graphic_eq,
                            ),
                          ],
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
  }

  Widget _buildTab(int index, String label) {
    final active = _tab == index;
    return Clickable(
      onTap: () {
        setState(() => _tab = index);
        if (index == 1) {
          Navigator.of(context).pushReplacementNamed('/editor', arguments: widget.projectId);
        } else if (index == 2) {
          Navigator.of(context).pushReplacementNamed('/assets');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? VC.yellow : Colors.white,
          border: Border.all(color: VC.ink, width: 2),
          boxShadow: VB.shadow(active ? 3 : 2),
        ),
        child: Text(label, style: VT.mono(11, weight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSignalItem(String title, String desc, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: VC.ink, width: 2),
            ),
            child: Icon(icon, size: 16, color: VC.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: VT.body(13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc, style: VT.body(11, color: VC.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHookCard(HookCandidate hook) {
    final scoreColor = hook.score >= 85
        ? VC.green // Green
        : (hook.score >= 70 ? VC.blue : VC.yellow);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: VC.ink, width: 2.5),
          boxShadow: VB.shadow(4),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail / Play Preview
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: VC.playerBg,
                border: Border.all(color: VC.ink, width: 2),
              ),
              child: const Center(
                child: Icon(Icons.play_arrow_rounded, color: VC.yellow, size: 44),
              ),
            ),
            const SizedBox(width: 20),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Score Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scoreColor,
                          border: Border.all(color: VC.ink, width: 1.5),
                        ),
                        child: Text('${hook.score}',
                            style: VT.mono(12, weight: FontWeight.w900, color: VC.ink)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${fmtTime(hook.start)} – ${fmtTime(hook.end)} (${(hook.end - hook.start).toStringAsFixed(1)}s)',
                        style: VT.mono(11, color: VC.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('"${hook.quote}"',
                      style: VT.body(15, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Alasan: ${hook.reason}',
                      style: VT.body(12, color: VC.muted)),
                  const SizedBox(height: 12),
                  // Signal tags
                  Wrap(
                    spacing: 8,
                    children: hook.signals
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: VC.bg,
                                border: Border.all(color: VC.ink, width: 1.5),
                              ),
                              child: Text(s, style: VT.mono(10, color: VC.ink)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  // Actions
                  Row(
                    children: [
                      BButton(
                        label: 'JADIKAN PEMBUKA',
                        icon: Icons.auto_awesome,
                        kind: BtnKind.dark,
                        small: true,
                        onTap: () {
                          showBrutalSnack(context, 'Hook dipindahkan sebagai pembuka klip!');
                        },
                      ),
                      const SizedBox(width: 12),
                      BButton(
                        label: 'SIMPAN KE ASSET',
                        icon: Icons.bookmark_border,
                        kind: BtnKind.outline,
                        small: true,
                        onTap: () {
                          showBrutalSnack(context, 'Hook berhasil disimpan ke Asset Library!');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
