import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ai_provider_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/brutal.dart';

/// Settings & Account — canvas `E1uYY2` dengan fitur Bring Your Own Key (BYOK)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _navIdx = 0;
  final _navItems = const [
    'AKUN',
    'API KEYS (BYOK)',
    'KUOTA & PLAN',
    'PREFERENSI AI',
    'TENTANG'
  ];

  late final TextEditingController _geminiKeyCtrl;
  late final TextEditingController _openaiKeyCtrl;
  late final TextEditingController _groqKeyCtrl;
  late final TextEditingController _customKeyCtrl;
  late final TextEditingController _customBaseUrlCtrl;
  late final TextEditingController _customModelCtrl;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _geminiKeyCtrl = TextEditingController(text: state.geminiApiKey);
    _openaiKeyCtrl = TextEditingController(text: state.openAiApiKey);
    _groqKeyCtrl = TextEditingController(text: state.groqApiKey);
    _customKeyCtrl = TextEditingController(text: state.customApiKey);
    _customBaseUrlCtrl = TextEditingController(text: state.customBaseUrl);
    _customModelCtrl = TextEditingController(text: state.customModel);
  }

  @override
  void dispose() {
    _geminiKeyCtrl.dispose();
    _openaiKeyCtrl.dispose();
    _groqKeyCtrl.dispose();
    _customKeyCtrl.dispose();
    _customBaseUrlCtrl.dispose();
    _customModelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;

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
                Text('SETTINGS & CONFIGURATION', style: VT.display(16)),
              ],
            ),
          ),

          // 2. MAIN BODY (Sidebar + Content Panel)
          Expanded(
            child: Row(
              children: [
                // Left Navigation Sidebar
                Container(
                  width: 280,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(right: BorderSide(color: VC.ink, width: 3)),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: _navItems
                        .asMap()
                        .entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Clickable(
                                onTap: () => setState(() => _navIdx = e.key),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: _navIdx == e.key
                                        ? VC.yellow
                                        : Colors.white,
                                    border: Border.all(color: VC.ink, width: 2),
                                    boxShadow: VB.shadow(_navIdx == e.key ? 3 : 0),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(e.value,
                                          style: VT.mono(12,
                                              weight: _navIdx == e.key
                                                  ? FontWeight.w700
                                                  : FontWeight.w400)),
                                      const Spacer(),
                                      if (_navIdx == e.key)
                                        const Icon(Icons.chevron_right,
                                            size: 16, color: VC.ink),
                                    ],
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),

                // Right Content Panel
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: _buildPanel(_navIdx, user),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(int idx, user) {
    switch (idx) {
      case 1:
        return _apiKeysPanel();
      case 2:
        return _quotaPanel(user);
      case 0:
      default:
        return _accountPanel(user);
    }
  }

  Widget _accountPanel(user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AKUN PENGGUNA', style: VT.display(22)),
        const SizedBox(height: 20),
        BBox(
          shadow: 4,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NAMA', style: VT.mono(10, color: VC.muted)),
              const SizedBox(height: 4),
              Text(user.name, style: VT.body(16, weight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text('EMAIL', style: VT.mono(10, color: VC.muted)),
              const SizedBox(height: 4),
              Text(user.email, style: VT.body(16)),
              const SizedBox(height: 24),
              Row(children: [
                BButton(
                    label: 'EDIT PROFIL',
                    kind: BtnKind.outline,
                    small: true,
                    onTap: () => showBrutalSnack(context, 'Edit Profil')),
                const SizedBox(width: 12),
                BButton(
                    label: 'LOGOUT',
                    kind: BtnKind.dark,
                    small: true,
                    onTap: () async {
                      await context.read<AppState>().clearSession();
                      if (!mounted) return;
                      Navigator.of(context).pushReplacementNamed('/login');
                    }),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _apiKeysPanel() {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('BRING YOUR OWN KEY (BYOK)', style: VT.display(20)),
              const BTag('UNLIMITED PROCESSING', color: VC.green),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Masukkan API key pribadi Anda untuk membuka fitur AI tanpa batasan kuota internal Visary.',
            style: VT.body(13, color: VC.muted),
          ),
          const SizedBox(height: 16),
          BBox(
            shadow: 2,
            padding: const EdgeInsets.all(16),
            color: VC.paper,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.help_outline, size: 16, color: VC.purple),
                    const SizedBox(width: 8),
                    Text('API KEY YANG BISA DIPAKAI', style: VT.display(14)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                    '• Gemini (AIza...) — LLM/B-roll sekarang; ASR text-only (segera via S11).',
                    style: VT.mono(11, color: VC.ink)),
                Text(
                    '• OpenAI (sk-proj...) — LLM/B-roll sekarang; ASR whisper-1 + TTS tts-1 (segera/deferred).',
                    style: VT.mono(11, color: VC.ink)),
                Text(
                    '• Groq (gsk_...) — LLM/B-roll sekarang; ASR whisper-large-v3 (segera).',
                    style: VT.mono(11, color: VC.ink)),
                Text(
                    '• Custom / Tokonomix (tok_live...) — segera via S11: ASR + LLM via base URL konfigurabel.',
                    style: VT.mono(11, color: VC.ink)),
                Text(
                    '• Antigravity Pro — chat/vision LLM only, tidak support speech (ASR/TTS).',
                    style: VT.mono(11, color: VC.ink)),
                const SizedBox(height: 10),
                Text(
                  'Sekarang key dipakai untuk fitur AI B-roll. ASR (transkrip caption) segera via S11. TTS (voiceover) menunggu persetujuan. Tanpa key: app tetap jalan mode lokal (shots/energi/OCR).',
                  style: VT.body(11, color: VC.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Provider Selector
          BBox(
            shadow: 4,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('MODE AI PROVIDER', style: VT.display(16)),
                    const Spacer(),
                    Switch(
                      value: state.byokEnabled,
                      activeTrackColor: VC.green,
                      onChanged: (v) => _updateProviderSettings(state, enabled: v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Auto-Switch toggle (PRD-SPRINT-17).
                Row(
                  children: [
                    Text('AUTO-SWITCH PROVIDER', style: VT.body(14)),
                    const Spacer(),
                    Switch(
                      value: state.autoSwitchEnabled,
                      activeTrackColor: VC.blue,
                      onChanged: state.byokEnabled
                          ? (v) => _updateAutoSwitch(state, enabled: v)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.autoSwitchEnabled && state.byokEnabled) ...[
                  // Info + badges saat Auto-Switch ON.
                  Text(
                    'ASR \u2192 Groq (Whisper) | Vision+LLM \u2192 Gemini',
                    style: VT.mono(11, color: VC.muted),
                  ),
                  const SizedBox(height: 8),
                  _buildProviderBadges(state),
                ] else ...[
                  // Dropdown provider (existing behavior saat Auto-Switch OFF).
                  DropdownButton<AiProviderType>(
                    value: state.activeAiProvider,
                    isExpanded: true,
                    onChanged: (AiProviderType? val) {
                      if (val != null) _updateProviderSettings(state, provider: val);
                    },
                    items: AiProviderType.values
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.displayName, style: VT.body(14)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 1. Google Gemini Key Box
          _buildKeyBox(
            state,
            label: 'GEMINI API',
            description: 'Gemini 1.5 Flash (Gratis limit 15 RPM)',
            color: VC.blue,
            ctrl: _geminiKeyCtrl,
            provider: AiProviderType.gemini,
            hint: 'AIza...',
          ),

          const SizedBox(height: 20),

          // 2. OpenAI Key Box
          _buildKeyBox(
            state,
            label: 'OPENAI API',
            description: 'Digunakan untuk GPT-4o-mini',
            color: VC.yellow,
            ctrl: _openaiKeyCtrl,
            provider: AiProviderType.openai,
            hint: 'sk-proj-...',
          ),

          const SizedBox(height: 20),

          // 3. Groq API Box
          _buildKeyBox(
            state,
            label: 'GROQ API',
            description: 'Llama 3 Ultra-Cepat (Opsional)',
            color: VC.pink,
            ctrl: _groqKeyCtrl,
            provider: AiProviderType.groq,
            hint: 'gsk_...',
          ),

          const SizedBox(height: 20),

          // 4. Custom OpenAI-Compatible (Tokonomix, OpenRouter, dll.)
          BBox(
            shadow: 4,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: VC.purple,
                        border: Border.all(color: VC.ink, width: 1.5),
                      ),
                      child: Text('CUSTOM / OPENAI-COMPATIBLE',
                          style: VT.mono(11, weight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Tokonomix, OpenRouter, dll. — base URL konfigurabel (PRD-SPRINT-11)',
                          style: VT.body(12, color: VC.muted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('BASE URL', style: VT.mono(10)),
                const SizedBox(height: 6),
                BInput(
                  controller: _customBaseUrlCtrl,
                  hint: 'https://tokonomix.ai/api/v1',
                ),
                const SizedBox(height: 12),
                Text('API KEY', style: VT.mono(10)),
                const SizedBox(height: 6),
                BInput(
                  controller: _customKeyCtrl,
                  hint: 'tok_live_...',
                  obscure: true,
                ),
                const SizedBox(height: 12),
                Text('MODEL', style: VT.mono(10)),
                const SizedBox(height: 6),
                BInput(
                  controller: _customModelCtrl,
                  hint: 'gpt-4o-mini',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text('Tersimpan terenkripsi lokal.',
                          style: VT.mono(10, color: VC.muted)),
                    ),
                    const SizedBox(width: 8),
                    BButton(
                      label: 'TES KONEKSI',
                      kind: BtnKind.outline,
                      small: true,
                      onTap: () async {
                        final key = _customKeyCtrl.text.trim();
                        final base = _customBaseUrlCtrl.text.trim();
                        if (key.isEmpty || base.isEmpty) {
                          showBrutalSnack(context, 'Base URL & Key wajib diisi');
                          return;
                        }
                        showBrutalSnack(context, 'Menguji koneksi ke $base...');
                        final res = await state.testAiConnection(
                          AiProviderType.custom,
                          key,
                          baseUrl: base,
                        );
                        if (!mounted) return;
                        showBrutalSnack(context, res.message);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          BButton(
            label: 'SIMPAN KONFIGURASI API',
            icon: Icons.save,
            kind: BtnKind.yellow,
            onTap: () async {
              await state.saveAiSettings(
                enabled: state.byokEnabled,
                provider: state.activeAiProvider,
                geminiKey: _geminiKeyCtrl.text,
                openAiKey: _openaiKeyCtrl.text,
                groqKey: _groqKeyCtrl.text,
                customKey: _customKeyCtrl.text,
                customBaseUrl: _customBaseUrlCtrl.text,
                customModel: _customModelCtrl.text,
              );
              if (mounted) showBrutalSnack(context, 'Konfigurasi API Key berhasil disimpan!');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKeyBox(
    AppState state, {
    required String label,
    required String description,
    required Color color,
    required TextEditingController ctrl,
    required AiProviderType provider,
    required String hint,
  }) {
    return BBox(
      shadow: 4,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: VC.ink, width: 1.5),
                ),
                child: Text(label, style: VT.mono(11, weight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(description, style: VT.body(12, color: VC.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('API KEY', style: VT.mono(10)),
          const SizedBox(height: 6),
          BInput(
            controller: ctrl,
            hint: hint,
            obscure: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('Tersimpan terenkripsi lokal.', style: VT.mono(10, color: VC.muted)),
              ),
              const SizedBox(width: 8),
              BButton(
                label: 'TES KONEKSI',
                kind: BtnKind.outline,
                small: true,
                onTap: () async {
                  final key = ctrl.text.trim();
                  if (key.isEmpty) {
                    showBrutalSnack(context, 'Key masih kosong');
                    return;
                  }
                  showBrutalSnack(context, 'Menguji koneksi...');
                  final res = await state.testAiConnection(provider, key);
                  if (!mounted) return;
                  showBrutalSnack(context, res.message);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateProviderSettings(AppState state, {bool? enabled, AiProviderType? provider}) {
    state.saveAiSettings(
      enabled: enabled ?? state.byokEnabled,
      provider: provider ?? state.activeAiProvider,
    );
  }

  /// Toggle Auto-Switch provider (PRD-SPRINT-17).
  void _updateAutoSwitch(AppState state, {required bool enabled}) {
    state.autoSwitchEnabled = enabled;
    state.saveAiSettings(
      enabled: state.byokEnabled,
      provider: state.activeAiProvider,
    );
  }

  /// Provider status badges saat Auto-Switch ON (PRD-SPRINT-17 §2.8).
  Widget _buildProviderBadges(AppState state) {
    return FutureBuilder<List<(String, String, bool)>>(
      future: _resolveTaskProviders(state),
      builder: (ctx, snap) {
        final badges = snap.data ?? [];
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: badges.map((b) {
            final (task, providerName, ok) = b;
            return BTag(
              '$task: $providerName ${ok ? "\u2713" : "\u26a0"}',
              color: ok ? VC.green : VC.pink,
            );
          }).toList(),
        );
      },
    );
  }

  /// Resolve provider per task untuk badge display.
  Future<List<(String, String, bool)>> _resolveTaskProviders(AppState state) async {
    final ai = state.aiService;
    final results = <(String, String, bool)>[];

    for (final entry in [
      ('ASR', TaskType.asr),
      ('Vision', TaskType.vision),
      ('LLM', TaskType.llm),
    ]) {
      final (label, task) = entry;
      final provider = await ai.getProviderForTask(task);
      final ok = provider != AiProviderType.server;
      results.add((label, provider.displayName, ok));
    }

    return results;
  }

  Widget _quotaPanel(user) {
    final q = user.quota;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('KUOTA & PLAN', style: VT.display(22)),
        const SizedBox(height: 20),
        BBox(
          shadow: 4,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                BTag(q.planName, color: VC.yellow),
                const Spacer(),
                Text('${q.usedMinutes} / ${q.totalMinutes} MENIT', style: VT.mono(12)),
              ]),
              const SizedBox(height: 14),
              BProgress(value: q.ratio, color: VC.green),
              const SizedBox(height: 16),
              Text('Reset kuota: ${q.resetAt.day}/${q.resetAt.month}/${q.resetAt.year}',
                  style: VT.body(12, color: VC.muted)),
              const SizedBox(height: 24),
              BButton(
                  label: 'UPGRADE PLAN',
                  kind: BtnKind.yellow,
                  onTap: () => showBrutalSnack(context, 'Upgrade Plan')),
            ],
          ),
        ),
      ],
    );
  }
}
