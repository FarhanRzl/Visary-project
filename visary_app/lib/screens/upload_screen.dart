import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/video_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/brutal.dart';

/// Upload & Analysis — canvas `GHDoN` (03-upload-analysis.png)
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _processing = false;
  String? _uploadingFileName;

  final _stageLabels = const {
    JobStage.probe: 'Normalisasi video',
    JobStage.asr: 'Transkrip audio (ASR)',
    JobStage.shotOcr: 'Deteksi shot + OCR',
    JobStage.vlm: 'Deskripsi visual (VLM)',
    JobStage.llmSelect: 'Seleksi clip (LLM)',
  };

  Future<void> _startUploadProcess(String fileName, {String? filePath}) async {
    setState(() {
      _uploadingFileName = fileName;
      _processing = true;
    });
    final state = context.read<AppState>();
    try {
      await state.addProjectFromUpload(fileName, filePath: filePath);
      if (mounted) {
        // ASR mungkin gagal (non-fatal) — tampilkan warning sebelum navigasi.
        if (state.asrError != null) {
          setState(() {
            _processing = false;
            _uploadingFileName = null;
          });
          _showErrorDialog(
            'Transkripsi Audio Gagal',
            'Video berhasil diproses, tapi transkripsi ASR gagal:\n\n'
            '${state.asrError}\n\n'
            'Klip tetap dibuat tanpa caption word-level. '
            'Cek API key/provider di Settings atau coba lagi nanti.',
          );
          state.asrError = null;
          return;
        }
        setState(() {
          _processing = false;
          _uploadingFileName = null;
        });
        Navigator.of(context).pushReplacementNamed(
          '/editor',
          arguments: state.activeProjectId,
        );
      }
    } on FfmpegMissingException catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _uploadingFileName = null;
        });
        _showErrorDialog(
          'FFmpeg Tidak Ditemukan',
          'Aplikasi membutuhkan FFmpeg/FFprobe biner di PATH sistem. (Detail: ${e.binary})',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _uploadingFileName = null;
        });
        _showErrorDialog('Gagal Memproses Video', e.toString());
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: VC.bg,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: VC.ink, width: 3),
        ),
        title: Text(title, style: VT.display(18)),
        content: Text(message, style: VT.body(14)),
        actions: [
          BButton(
            label: 'OK',
            kind: BtnKind.yellow,
            onTap: () => Navigator.of(c).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        // User membatalkan file picker → kembali ke Dashboard.
        if (mounted) Navigator.of(context).pop();
        return;
      }
      
      final picked = result.files.single;
      if (picked.path == null || picked.name.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      
      await _startUploadProcess(picked.name, filePath: picked.path);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final activeProject = state.activeProject;
    
    final progress = _processing ? (activeProject?.progress ?? 0.0) : 0.0;
    final stage = _processing ? (activeProject?.stage ?? JobStage.probe) : JobStage.probe;
    final dispName = _uploadingFileName ?? '';
    
    final quotaText = state.user != null 
        ? '${state.user!.quota.usedMinutes} / ${state.user!.quota.totalMinutes}' 
        : '-- / --';

    return Scaffold(
      backgroundColor: VC.bg,
      body: Column(
        children: [
          // Top Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: VC.ink, width: 3)),
            ),
            child: Row(
              children: [
                Text('VISARY', style: VT.display(24)),
                const Spacer(),
                BTag('⚡ KUOTA $quotaText MENIT', color: VC.blue),
              ],
            ),
          ),
          
          // Main Body: 2 Columns
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LEFT: Dropzone (2/3 width)
                  Expanded(
                    flex: 6,
                    child: Clickable(
                      onTap: _pickFile,
                      child: BBox(
                        color: Colors.white,
                        borderColor: VC.ink,
                        border: 3,
                        shadow: 8,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.rotate(
                                angle: -0.1,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: VC.yellow,
                                    border: Border.all(color: VC.ink, width: 3),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.file_upload_outlined, size: 48, color: VC.ink),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text('DROP VIDEO DI SINI',
                                  style: VT.display(30)),
                              const SizedBox(height: 12),
                              Text(
                                'MP4 · MOV · MKV · WEBM — tanpa batas durasi',
                                style: VT.mono(13, color: VC.muted),
                              ),
                              const SizedBox(height: 36),
                              BButton(
                                label: 'PILIH FILE',
                                icon: Icons.folder,
                                kind: BtnKind.yellow,
                                onTap: _pickFile,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 36),

                  // RIGHT: Analysis Panel ("ANALISIS BERJALAN", 1/3 width)
                  Expanded(
                    flex: 4,
                    child: _buildAnalysisPanel(dispName, stage, progress, activeProject),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisPanel(String fileName, JobStage stage, double progress, Project? project) {
    final stages = _stageLabels.entries.toList();
    final currentIdx = stages.indexWhere((e) => e.key == stage);
    
    String durationStr = '--:--';
    if (project != null && (project.probe?.durationSec ?? 0) > 0) {
      final sec = project.probe!.durationSec.toInt();
      durationStr = '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    
    return BBox(
      color: Colors.white,
      border: 3,
      shadow: 8,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ANALISIS BERJALAN', style: VT.display(20)),
          const SizedBox(height: 6),
          Text('$fileName · $durationStr', style: VT.mono(12, color: VC.muted)),
          
          const SizedBox(height: 28),
          
          // Steps List
          Expanded(
            child: ListView(
              children: stages.asMap().entries.map((e) {
                final idx = e.key;
                final label = e.value.value;
                final done = idx < currentIdx || stage == JobStage.done;
                final active = idx == currentIdx && stage != JobStage.done;
                
                Color bgColor = VC.bg;
                Widget icon = const Text('○', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
                Color textColor = VC.muted;

                if (done) {
                  bgColor = VC.blue; // Teal Green
                  icon = const Icon(Icons.check, size: 18, color: VC.ink);
                  textColor = VC.ink;
                } else if (active) {
                  bgColor = VC.yellow;
                  icon = const Text('❇', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
                  textColor = VC.ink;
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.all(color: VC.ink, width: 2),
                        ),
                        child: icon,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        label,
                        style: VT.mono(13,
                            color: textColor,
                            weight: active || done ? FontWeight.bold : FontWeight.normal),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Progress Bar
          Container(
            height: 26,
            width: double.infinity,
            decoration: BoxDecoration(
              color: VC.bg,
              border: Border.all(color: VC.ink, width: 2),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  color: VC.pink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${(progress * 100).toInt()}%',
            style: VT.mono(12, color: VC.ink, weight: FontWeight.bold),
          ),
          
          const SizedBox(height: 24),
          
          // Cancel Button — kembali ke Dashboard.
          SizedBox(
            width: double.infinity,
            child: BButton(
              label: 'BATALKAN',
              kind: BtnKind.outline,
              onTap: () {
                setState(() => _processing = false);
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}
