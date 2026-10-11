# PRD Sprint 06 — BYOK (Bring Your Own Key) & Hybrid AI Routing

**Dokumen ID:** PRD-SPRINT-06  
**Modul Fokus:** Secure Credential Storage, Multi-Provider AI Abstraction, Hybrid Request Routing  
**Target File:** `lib/screens/settings_screen.dart`, `lib/services/ai_provider_service.dart` (Baru), `lib/state/app_state.dart`  
**Fitur Terkait:** Fitur Utama 1 (Auth & Quota) & Fitur Utama 4 (Clip Engine & Prompt)

---

## 1. Latar Belakang & Masalah
Pada PRD awal (§2 & §6), analisis AI (VLM/LLM) bergantung pada server backend Visary dengan sistem kuota menit. Namun, untuk pengguna daya tinggi (*power users*), developer, atau pengguna yang ingin pemrosesan tanpa batas kuota server, aplikasi perlu mendukung mode **BYOK (Bring Your Own Key)**.

Fitur BYOK memungkinkan pengguna memasukkan API Key milik mereka sendiri (seperti Google Gemini API Key atau OpenAI API Key) secara langsung di aplikasi desktop.

---

## 2. Sasaran Perbaikan (Scope of Work)
1. **Penyimpanan Enkripsi Kredensial Lokal:**
   * Menyimpan API Key secara aman di Windows Credential Manager melalui `flutter_secure_storage` (bukan *plain text* di SQLite/SharedPreferences).
2. **Abstraksi Multi-Provider AI:**
   * Membuat layer service `AiProviderService` yang mendukung provider:
     * Google Gemini API (Gemini 1.5 Flash / 2.0 Flash)
     * OpenAI API (GPT-4o-mini / GPT-4o)
3. **Hybrid AI Request Router:**
   * Sistem memilih jalur secara otomatis:
     * **Mode Server (Default):** Menggunakan kuota menit akun Visary.
     * **Mode BYOK:** Request langsung dikirim dari aplikasi lokal ke endpoint provider (Gemini/OpenAI) tanpa memotong kuota server Visary.
4. **Validasi & Connection Tester UI:**
   * Fitur tes koneksi API Key di `SettingsScreen` untuk memverifikasi keabsahan key sebelum dipakai dalam job analisis.

---

## 3. Spesifikasi Teknis & Arsitektur Implementasi

### 3.0 Tools & Library Referensi
* **[`mogol/flutter_secure_storage`](https://github.com/flutter/packages/tree/main/packages/flutter_secure_storage):** Enkripsi kredensial via Windows Credential Manager API.
* **[`google/generative-ai-dart`](https://github.com/google/generative-ai-dart):** SDK resmi Google Gemini untuk Dart/Flutter.
* **[`AneoDuo/dart_openai`](https://github.com/AneoDuo/dart_openai):** Client SDK Dart untuk API OpenAI.
* **[`artbyjazi/autoclip`](https://github.com/artbyjazi/autoclip):** Blueprint arsitektur multi-provider BYOK (OpenAI, Gemini, Anthropic, Ollama), verifikasi koneksi API key, dan fallback offline local.
* **[`chang-pro/clippro`](https://github.com/chang-pro/clippro):** Blueprint prompt Gemini API virality ranking (Hook, Flow, Value, Trend 0–99).

### 3.0.1 Blueprint User Story & Pipeline Flow (Adopted from AutoClip & ClipPro)
* **User Story:** "Sebagai power-user, saya ingin memasukkan Gemini/OpenAI API Key saya sendiri agar dapat memproses video tanpa terhalang kuota server Visary dan memiliki kontrol penuh atas biaya inferensi AI."
* **Pipeline Flow:**
```
[User Input API Key] ──► [Test Connection Ping] ──► [Save Encrypted di Windows Credential Manager]
                                                              │
[Job Analisis] ◄──────────────────────────────────────────────┘
      ├── Jika BYOK Aktif  ──► Direct HTTP Call ke Gemini/OpenAI (Bypass Server Quota)
      └── Jika BYOK Nonaktif ──► Kirim ke Backend Visary (Potong Kuota Menit Akun)
```

### 3.1 Alur Request Router (Hybrid Routing Mechanism)

```
[User Memulai Analisis Job]
           │
           ▼
  Apakah Mode BYOK Aktif?
     ├── YA ──► [AiProviderService (Lokal Engine)]
     │               │
     │               ├── Mengambil API Key dari Windows Credential Manager
     │               ├── Direct HTTP ke API Gemini / OpenAI
     │               └── Skip potong kuota server
     │
     └── TIDAK ──► [Visary Backend Gateway API]
                     │
                     ├── Autentikasi JWT User
                     ├── Cek & Reservasi Kuota Menit
                     └── Forward ke Server AI Gateway
```

### 3.2 Implementasi Enkripsi & Service (`AiProviderService`)

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(),
  );

  static const _geminiKey = 'byok_gemini_api_key';
  static const _openAiKey = 'byok_openai_api_key';

  static Future<void> saveGeminiKey(String key) async =>
      await _storage.write(key: _geminiKey, value: key);

  static Future<String?> getGeminiKey() async =>
      await _storage.read(key: _geminiKey);
}
```

---

## 4. Rencana Automation Testing

* **Test 6.1:** `test/unit/services/secure_key_storage_test.dart`
  * Validasi operasi write, read, dan delete API Key pada mock secure storage.
* **Test 6.2:** `test/unit/services/ai_provider_service_test.dart`
  * Mock HTTP Client untuk menguji request payload JSON ke endpoint Gemini/OpenAI API.
  * Validasi error handling saat API key bernilai invalid (HTTP 401) atau rate limit (HTTP 429).
* **Test 6.3:** `test/widget/settings_byok_ui_test.dart`
  * Widget test komponen input API key dan tombol "TEST KONEKSI" pada `SettingsScreen`.

---

## 5. Kriteria Penerimaan (Acceptance Criteria)
* Pengguna dapat menginput, menguji, dan menyimpan API Key (Gemini/OpenAI) di halaman Pengaturan.
* API Key tersimpan terenkripsi di Windows Credential Manager.
* Saat mode BYOK aktif, analisis klip berhasil menggunakan API key pengguna tanpa mengurangi kuota menit server.
* Error akibat API key kedaluwarsa/invalid ditampilkan secara informatif di UI.
