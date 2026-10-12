# PRD Sprint 17 — Auto-Switch Provider per Task

**Dokumen ID:** PRD-SPRINT-17
**Modul Fokus:** BYOK provider routing — ASR via Groq (Whisper), Vision+LLM via Gemini
**Target File:** `lib/services/ai_provider_service.dart`, `lib/services/secure_key_storage.dart`, `lib/state/app_state.dart`, `lib/screens/settings_screen.dart`, `lib/widgets/audio_panel.dart`, `test/*`
**Referensi:** `PRD-SPRINT-06` (BYOK), `PRD-SPRINT-11` (ASR), `PRD-SPRINT-14` (content matching), `PRD-SPRINT-15` (ASR fixes), `PRD-SPRINT-16` (semantic matching)
**Status:** 📝 Draft

---

## 1. Latar Belakang & Masalah

Saat ini BYOK menggunakan satu `activeAiProvider` untuk semua task (ASR, vision, LLM). Masalah:

1. **Gemini tidak punya word-level timestamps.** ASR via Gemini estimasi ~150 WPM — segment boundary tidak presisi untuk semantic matching (S16).
2. **Groq tidak support vision.** Match konten butuh VLM (describeFrames) — Groq tidak bisa.
3. **User harus switch manual.** Untuk ASR pakai Groq (Whisper, presisi), lalu switch ke Gemini untuk match konten (vision). Repetitif dan error-prone.
4. **Quota terpisah.** Gemini free tier cepat habis untuk semua task. Split beban: Groq untuk ASR (quota terpisah), Gemini untuk vision+LLM.

**Solusi:** Auto-switch provider per task. User isi semua key sekali, sistem route otomatis:
- ASR → Groq (Whisper, word-level timestamps)
- Vision (describeFrames) → Gemini
- LLM (segmentByContext + matchContent) → Gemini

---

## 2. Sasaran (Scope of Work)

### 2.1 Task Provider Routing (`AiProviderService`)
- Konsep baru: **task-specific provider** alih-alih single `activeAiProvider`.
- Method baru: `getProviderForTask(TaskType task)` → resolve provider optimal per task.
- Routing logic:
  - `TaskType.asr` → Groq (Whisper) jika key available, fallback Gemini, fallback OpenAI.
  - `TaskType.vision` → Gemini jika key available, fallback OpenAI, fallback Custom.
  - `TaskType.llm` → Gemini jika key available, fallback OpenAI, fallback Groq, fallback Custom.
- Prioritas berdasarkan: (1) key availability, (2) capability match, (3) cost (free first).
- Bila Auto-Switch OFF → fallback ke `activeAiProvider` (existing behavior).

### 2.2 Auto-Switch Toggle (`SecureKeyStorage`)
- New setting: `byok_auto_switch` (bool, default false).
- OFF (default): single `activeAiProvider` untuk semua task (existing behavior, backward compat).
- ON: sistem route per task otomatis berdasarkan key availability + capability.

### 2.3 Transcribe Routing (`AiProviderService.transcribe`)
- Bila Auto-Switch ON:
  - Cek Groq key → jika ada, route ASR ke Groq (Whisper, word-level timestamps).
  - Groq key kosong → cek Gemini key → jika ada, route ke Gemini (estimasi timestamps).
  - Gemini key kosong → cek OpenAI key → jika ada, route ke OpenAI (Whisper-1).
- Bila Auto-Switch OFF: existing behavior (route ke `activeAiProvider`).

### 2.4 Vision Routing (`AiProviderService.visionPrompt`)
- Bila Auto-Switch ON:
  - Cek Gemini key → jika ada, route vision ke Gemini (inline_data).
  - Gemini key kosong → cek OpenAI key → jika ada, route ke OpenAI (image_url).
  - OpenAI key kosong → cek Custom key → coba format OpenAI-compatible vision.
  - Semua kosong → throw `UnsupportedError` dengan daftar key yang perlu diisi.
- Bila Auto-Switch OFF: existing behavior.

### 2.5 LLM Routing (`AiProviderService.sendPrompt`)
- Bila Auto-Switch ON:
  - Cek Gemini key → jika ada, route LLM ke Gemini (generateContent).
  - Gemini key kosong → cek OpenAI key → jika ada, route ke OpenAI (chat/completions).
  - OpenAI key kosong → cek Groq key → jika ada, route ke Groq (chat/completions, model `llama-3.1-8b-instant`).
  - Groq key kosong → cek Custom → route ke Custom.
- Bila Auto-Switch OFF: existing behavior.

### 2.6 Settings UI (`settings_screen.dart`)
- New toggle: "AUTO-SWITCH PROVIDER" di bawah "MODE AI PROVIDER".
- Saat ON:
  - Dropdown `activeAiProvider` disembunyikan atau disabled (greyed out).
  - Tampilkan info: "ASR → Groq (Whisper) | Vision+LLM → Gemini".
  - Key boxes tetap semua visible (Gemini, OpenAI, Groq, Custom).
- Saat OFF:
  - Dropdown `activeAiProvider` visible (existing behavior).
  - Key boxes tetap visible.

### 2.7 Audio Panel Info (`audio_panel.dart`)
- Saat Auto-Switch ON dan user klik TRANSCRIBE:
  - Snackbar info: "ASR via Groq (Whisper) — word-level timestamps."
  - Tidak ada Gemini timestamp warning (karena ASR pakai Groq, bukan Gemini).
- Saat Auto-Switch OFF dan provider = Gemini:
  - Existing Gemini timestamp warning tetap.

### 2.8 Provider Status Indicator
- Saat Auto-Switch ON, tampilkan status badge di Settings:
  - "ASR: Groq ✓" (jika Groq key ada) atau "ASR: Gemini ⚠" (jika Groq key kosong, fallback Gemini).
  - "Vision: Gemini ✓" atau "Vision: OpenAI ✓" atau "Vision: ✗ (no key)".
  - "LLM: Gemini ✓" atau "LLM: OpenAI ✓" atau "LLM: Groq ✓".

---

## 3. Spesifikasi Teknis

### 3.1 `lib/services/ai_provider_service.dart` — TaskType + Routing

```dart
/// Jenis task AI yang butuh provider routing berbeda.
enum TaskType {
  asr,    // Transcribe audio → text + word timestamps
  vision, // Describe image/frame → text
  llm,    // Text inference (segment, match, summary)
}

/// Resolve provider optimal untuk task tertentu.
/// Bila Auto-Switch ON: route berdasarkan key availability + capability.
/// Bila OFF: return activeAiProvider (existing behavior).
Future<AiProviderType> getProviderForTask(TaskType task) async {
  final autoSwitch = await storage.getAutoSwitch();
  if (!autoSwitch) {
    return storage.getActiveProvider();
  }

  // Auto-Switch ON: route per task.
  final hasGroq = (await storage.getGroqKey())?.isNotEmpty ?? false;
  final hasGemini = (await storage.getGeminiKey())?.isNotEmpty ?? false;
  final hasOpenAi = (await storage.getOpenAiKey())?.isNotEmpty ?? false;
  final hasCustom = (await storage.getCustomKey())?.isNotEmpty ?? false;

  switch (task) {
    case TaskType.asr:
      // Prefer Groq (Whisper, word-level timestamps).
      if (hasGroq) return AiProviderType.groq;
      if (hasGemini) return AiProviderType.gemini; // fallback (estimasi)
      if (hasOpenAi) return AiProviderType.openai;
      return AiProviderType.server; // no key
    case TaskType.vision:
      // Prefer Gemini (free vision API).
      if (hasGemini) return AiProviderType.gemini;
      if (hasOpenAi) return AiProviderType.openai;
      if (hasCustom) return AiProviderType.custom;
      return AiProviderType.server;
    case TaskType.llm:
      // Prefer Gemini (free, capable).
      if (hasGemini) return AiProviderType.gemini;
      if (hasOpenAi) return AiProviderType.openai;
      if (hasGroq) return AiProviderType.groq;
      if (hasCustom) return AiProviderType.custom;
      return AiProviderType.server;
  }
}
```

### 3.2 `transcribe` — Auto-Switch routing

```dart
Future<Transcript> transcribe({...}) async {
  final provider = await getProviderForTask(TaskType.asr);
  // ... existing routing logic, tapi pakai `provider` dari getProviderForTask ...
}
```

### 3.3 `visionPrompt` — Auto-Switch routing

```dart
Future<String> visionPrompt({...}) async {
  final provider = await getProviderForTask(TaskType.vision);
  // ... existing routing logic, tapi pakai `provider` dari getProviderForTask ...
}
```

### 3.4 `sendPrompt` — Auto-Switch routing

```dart
Future<String> sendPrompt({...}) async {
  final provider = await getProviderForTask(TaskType.llm);
  // ... existing routing logic, tapi pakai `provider` dari getProviderForTask ...
}
```

### 3.5 `SecureKeyStorage` — Auto-Switch setting

```dart
static const keyAutoSwitch = 'byok_auto_switch';

Future<bool> getAutoSwitch() async {
  final v = await read(keyAutoSwitch);
  return v == 'true';
}

Future<void> setAutoSwitch(bool enabled) =>
    write(keyAutoSwitch, enabled ? 'true' : 'false');
```

### 3.6 Settings UI — Auto-Switch toggle

```dart
// Di bawah "MODE AI PROVIDER" toggle:
Switch(
  value: state.autoSwitchEnabled,
  activeTrackColor: VC.blue,
  onChanged: (v) => _updateAutoSwitch(state, enabled: v),
),
Text('AUTO-SWITCH PROVIDER'),
if (state.autoSwitchEnabled) ...[
  Text('ASR → Groq (Whisper) | Vision+LLM → Gemini'),
  _buildProviderStatusBadges(state),
] else ...[
  // Existing dropdown
  DropdownButton<AiProviderType>(...),
],
```

---

## 4. Rencana Testing

* **Test 17.1** `test/unit/services/task_routing_test.dart`
  * Auto-Switch ON + Groq key → ASR routes to Groq.
  * Auto-Switch ON + no Groq key + Gemini key → ASR routes to Gemini.
  * Auto-Switch ON + Gemini key → Vision routes to Gemini.
  * Auto-Switch ON + no Gemini key + OpenAI key → Vision routes to OpenAI.
  * Auto-Switch ON + Gemini key → LLM routes to Gemini.
  * Auto-Switch OFF → all tasks route to `activeAiProvider`.

* **Test 17.2** `test/unit/services/auto_switch_transcribe_test.dart`
  * Auto-Switch ON + Groq key → transcribe uses Groq (Whisper) endpoint.
  * Auto-Switch ON + no Groq key + Gemini key → transcribe uses Gemini endpoint.

* **Test 17.3** `test/unit/services/auto_switch_vision_test.dart`
  * Auto-Switch ON + Gemini key → visionPrompt uses Gemini endpoint.
  * Auto-Switch ON + no Gemini key → visionPrompt throws UnsupportedError.

* **Test 17.4** `test/unit/services/auto_switch_llm_test.dart`
  * Auto-Switch ON + Gemini key → sendPrompt uses Gemini endpoint.
  * Auto-Switch ON + no Gemini key + Groq key → sendPrompt uses Groq endpoint.

* **Test 17.5** `test/widget/auto_switch_settings_test.dart`
  * Auto-Switch toggle ON → dropdown hidden, info text visible.
  * Auto-Switch toggle OFF → dropdown visible.
  * Provider status badges correct.

---

## 5. Kriteria Penerimaan

* Settings: "AUTO-SWITCH PROVIDER" toggle tampil di bawah "MODE AI PROVIDER".
* Auto-Switch ON + Groq + Gemini key terisi → ASR pakai Groq, Vision+LLM pakai Gemini.
* Auto-Switch OFF → existing behavior (single `activeAiProvider`).
* Audio panel: saat Auto-Switch ON, TRANSCRIBE → info "ASR via Groq (Whisper)".
* Provider status badges tampil di Settings saat Auto-Switch ON.
* `flutter analyze lib` → 0; `flutter test` hijau.

---

## 6. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Groq LLM model deprecated (`llama-3.3-70b-versatile` NOT_FOUND) | Sedang | LLM routing prefer Gemini. Groq hanya untuk ASR (Whisper model stabil). |
| Gemini quota exhausted untuk Vision+LLM | Sedang | Fallback ke OpenAI jika Gemini 429/503. User lihat badge status. |
| User hanya isi 1 key (Groq atau Gemini saja) | Rendah | Auto-Switch hanya route ke provider dengan key. Jika salah satu task tidak punya provider → tampilkan warning di badge. |
| Backward compat: user existing dengan single provider | Rendah | Auto-Switch default OFF. Existing behavior tidak berubah sampil user enable. |
| Custom provider vision support tidak terjamin | Rendah | Custom hanya dipakai untuk Vision jika Gemini+OpenAI kosong. Coba format OpenAI-compatible, catch error. |

---

## 7. Definition of Done

- `flutter analyze lib` → 0.
- `flutter test` hijau (existing + 5 suite baru).
- Smoke test: Auto-Switch ON + Groq key + Gemini key → TRANSCRIBE → ASR via Groq, MATCH CONTENT → Vision+LLM via Gemini.
- Smoke test: Auto-Switch OFF → existing behavior tetap jalan.
- Settings UI: toggle + badges tampil benar.
- Backward compat: user tanpa Auto-Switch tetap bisa pakai single provider.

---

## 8. Dependency & Posisi Roadmap

- **Dependensi:** S06 (BYOK), S11 (ASR), S14 (content matching), S15 (ASR fixes), S16 (semantic matching).
- **Integrasi:** AiProviderService (routing), SecureKeyStorage (auto_switch setting), AppState (loadAutoSwitch), SettingsScreen (toggle + badges), AudioPanel (info snackbar).
- **Urutan:** setelah S16. Independen dari S07 (UI fidelity).
- **Estimasi:** 2–3 hari (routing logic + storage + UI + tests).

---

## 9. Catatan & Out of Scope

- **Auto-failover saat quota exhausted** (switch provider mid-task saat 429/503) — out of scope. S17 route per task di awal, tidak retry dengan provider lain mid-call.
- **User-configurable priority** (ubah urutan preferensi provider) — out of scope. Priority hardcoded: ASR→Groq, Vision+LLM→Gemini.
- **Per-task model selection** (user pilih model Whisper per provider) — out of scope. Model hardcoded: Groq=`whisper-large-v3`, Gemini=`gemini-flash-latest`.
- **Cost estimation / quota tracking** — out of scope. User monitor sendiri via provider dashboard.
- **Multi-key rotation** (multiple Gemini keys, round-robin) — out of scope.
