import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Tipe provider AI yang didukung Visary (PRD-SPRINT-06 §2.2).
enum AiProviderType {
  server('Server Visary (Default Kuota)'),
  gemini('Google Gemini API'),
  openai('OpenAI API'),
  groq('Groq Cloud API'),
  custom('OpenAI-Compatible (custom base URL)');

  const AiProviderType(this.displayName);
  final String displayName;
}

/// Hasil verifikasi koneksi API key.
class ConnectionTestResult {
  const ConnectionTestResult({
    required this.success,
    required this.message,
    this.statusCode,
  });

  final bool success;
  final String message;
  final int? statusCode;
}

/// Penyimpanan kredensial terenkripsi lokal (Windows Credential Manager / Keychain / libsecret).
class SecureKeyStorage {
  SecureKeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              wOptions: WindowsOptions(),
              lOptions: LinuxOptions(),
            );

  final FlutterSecureStorage _storage;

  static const keyGemini = 'byok_gemini_api_key';
  static const keyOpenAi = 'byok_openai_api_key';
  static const keyGroq = 'byok_groq_api_key';
  static const keyByokEnabled = 'byok_enabled';
  static const keyActiveProvider = 'byok_active_provider';

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();

  Future<void> saveGeminiKey(String key) => write(keyGemini, key);
  Future<String?> getGeminiKey() => read(keyGemini);

  Future<void> saveOpenAiKey(String key) => write(keyOpenAi, key);
  Future<String?> getOpenAiKey() => read(keyOpenAi);

  Future<void> saveGroqKey(String key) => write(keyGroq, key);
  Future<String?> getGroqKey() => read(keyGroq);

  // Custom OpenAI-compatible provider (e.g. Tokonomix) — PRD-SPRINT-11 §2.1.
  static const keyCustomApi = 'byok_custom_api_key';
  static const keyCustomBaseUrl = 'byok_custom_base_url';
  static const keyCustomModel = 'byok_custom_model';

  Future<void> saveCustomKey(String key) => write(keyCustomApi, key);
  Future<String?> getCustomKey() => read(keyCustomApi);
  Future<void> saveCustomBaseUrl(String url) => write(keyCustomBaseUrl, url);
  Future<String?> getCustomBaseUrl() => read(keyCustomBaseUrl);
  Future<void> saveCustomModel(String model) => write(keyCustomModel, model);
  Future<String?> getCustomModel() => read(keyCustomModel);

  Future<void> setByokEnabled(bool enabled) => write(keyByokEnabled, enabled.toString());
  Future<bool> getByokEnabled() async {
    final v = await read(keyByokEnabled);
    return v == 'true';
  }

  Future<void> setActiveProvider(AiProviderType provider) =>
      write(keyActiveProvider, provider.name);

  Future<AiProviderType> getActiveProvider() async {
    final v = await read(keyActiveProvider);
    if (v == null) return AiProviderType.server;
    return AiProviderType.values.firstWhere(
      (e) => e.name == v,
      orElse: () => AiProviderType.server,
    );
  }
}

/// Service abstraksi Multi-Provider AI & Request Router (PRD-SPRINT-06 §3).
class AiProviderService {
  AiProviderService({
    SecureKeyStorage? storage,
    http.Client? httpClient,
  })  : storage = storage ?? SecureKeyStorage(),
        _client = httpClient ?? http.Client();

  final SecureKeyStorage storage;
  final http.Client _client;

  /// Menguji validitas koneksi API key langsung ke endpoint provider.
  Future<ConnectionTestResult> testConnection(
    AiProviderType provider,
    String apiKey, {
    String? baseUrl,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      return const ConnectionTestResult(
        success: false,
        message: 'API Key tidak boleh kosong',
      );
    }

    try {
      switch (provider) {
        case AiProviderType.gemini:
          final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models?key=$key',
          );
          final res = await _client.get(uri);
          if (res.statusCode == 200) {
            return const ConnectionTestResult(
              success: true,
              message: 'Koneksi Gemini API berhasil! Key valid.',
              statusCode: 200,
            );
          } else if (res.statusCode == 400 || res.statusCode == 403) {
            return ConnectionTestResult(
              success: false,
              message: 'API Key Gemini tidak valid atau izin ditolak (HTTP ${res.statusCode}).',
              statusCode: res.statusCode,
            );
          } else if (res.statusCode == 429) {
            return const ConnectionTestResult(
              success: false,
              message: 'Rate limit Gemini tercapai (HTTP 429). Coba beberapa saat lagi.',
              statusCode: 429,
            );
          } else {
            return ConnectionTestResult(
              success: false,
              message: 'Gagal menghubungi Gemini API: HTTP ${res.statusCode}.',
              statusCode: res.statusCode,
            );
          }

        case AiProviderType.openai:
          final uri = Uri.parse('https://api.openai.com/v1/models');
          final res = await _client.get(
            uri,
            headers: {'Authorization': 'Bearer $key'},
          );
          if (res.statusCode == 200) {
            return const ConnectionTestResult(
              success: true,
              message: 'Koneksi OpenAI API berhasil! Key valid.',
              statusCode: 200,
            );
          } else if (res.statusCode == 401) {
            return const ConnectionTestResult(
              success: false,
              message: 'API Key OpenAI tidak valid (HTTP 401).',
              statusCode: 401,
            );
          } else if (res.statusCode == 429) {
            return const ConnectionTestResult(
              success: false,
              message: 'Quota atau Rate limit OpenAI habis (HTTP 429).',
              statusCode: 429,
            );
          } else {
            return ConnectionTestResult(
              success: false,
              message: 'Gagal menghubungi OpenAI: HTTP ${res.statusCode}.',
              statusCode: res.statusCode,
            );
          }

        case AiProviderType.groq:
          final uri = Uri.parse('https://api.groq.com/openai/v1/models');
          final res = await _client.get(
            uri,
            headers: {'Authorization': 'Bearer $key'},
          );
          if (res.statusCode == 200) {
            return const ConnectionTestResult(
              success: true,
              message: 'Koneksi Groq API berhasil! Key valid.',
              statusCode: 200,
            );
          } else if (res.statusCode == 401) {
            return const ConnectionTestResult(
              success: false,
              message: 'API Key Groq tidak valid (HTTP 401).',
              statusCode: 401,
            );
          } else {
            return ConnectionTestResult(
              success: false,
              message: 'Gagal menghubungi Groq: HTTP ${res.statusCode}.',
              statusCode: res.statusCode,
            );
          }

        case AiProviderType.custom:
          final b = (baseUrl ?? '').trim();
          if (b.isEmpty) {
            return const ConnectionTestResult(
              success: false,
              message: 'Base URL wajib untuk provider custom.',
            );
          }
          final modelsUrl = b.endsWith('/') ? '${b}models' : '$b/models';
          final res = await _client.get(
            Uri.parse(modelsUrl),
            headers: {'Authorization': 'Bearer $key'},
          );
          if (res.statusCode == 200) {
            return ConnectionTestResult(
              success: true,
              message: 'Koneksi ke $b berhasil! Key valid.',
              statusCode: 200,
            );
          } else if (res.statusCode == 401 || res.statusCode == 403) {
            return ConnectionTestResult(
              success: false,
              message: 'API Key tidak valid atau izin ditolak (HTTP ${res.statusCode}).',
              statusCode: res.statusCode,
            );
          } else {
            return ConnectionTestResult(
              success: false,
              message: 'Gagal menghubungi $b: HTTP ${res.statusCode}.',
              statusCode: res.statusCode,
            );
          }

        case AiProviderType.server:
          return const ConnectionTestResult(
            success: true,
            message: 'Mode Server Visary aktif (menggunakan kuota akun).',
          );
      }
    } catch (e) {
      return ConnectionTestResult(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }

  /// Cek apakah mode BYOK aktif dan key tersedia untuk provider yang dipilih.
  Future<bool> isByokActive() async {
    final enabled = await storage.getByokEnabled();
    if (!enabled) return false;
    final provider = await storage.getActiveProvider();
    if (provider == AiProviderType.server) return false;

    switch (provider) {
      case AiProviderType.gemini:
        final k = await storage.getGeminiKey();
        return k != null && k.trim().isNotEmpty;
      case AiProviderType.openai:
        final k = await storage.getOpenAiKey();
        return k != null && k.trim().isNotEmpty;
      case AiProviderType.groq:
        final k = await storage.getGroqKey();
        return k != null && k.trim().isNotEmpty;
      case AiProviderType.custom:
        final k = await storage.getCustomKey();
        final b = await storage.getCustomBaseUrl();
        return k != null &&
            k.trim().isNotEmpty &&
            b != null &&
            b.trim().isNotEmpty;
      case AiProviderType.server:
        return false;
    }
  }

  /// Direct prompt inference via active provider (Gemini / OpenAI / Groq / Server)
  Future<String> sendPrompt({
    required String prompt,
    String? systemInstruction,
  }) async {
    final active = await isByokActive();
    if (!active) {
      // Server Mode: disimulasikan via internal gateway atau kuota Visary
      debugPrint('[AiProviderService] Menggunakan Server Visary Gateway.');
      return 'Hasil inferensi Server Visary: $prompt';
    }

    final provider = await storage.getActiveProvider();
    switch (provider) {
      case AiProviderType.gemini:
        final key = (await storage.getGeminiKey()) ?? '';
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key',
        );
        final res = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  if (systemInstruction != null) {'text': systemInstruction},
                  {'text': prompt},
                ]
              }
            ]
          }),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
          return text.toString();
        } else {
          throw Exception('Gemini API Error ${res.statusCode}: ${res.body}');
        }

      case AiProviderType.openai:
      case AiProviderType.groq:
        final isGroq = provider == AiProviderType.groq;
        final key = isGroq ? (await storage.getGroqKey()) ?? '' : (await storage.getOpenAiKey()) ?? '';
        final endpoint = isGroq
            ? 'https://api.groq.com/openai/v1/chat/completions'
            : 'https://api.openai.com/v1/chat/completions';
        final model = isGroq ? 'llama-3.1-8b-instant' : 'gpt-4o-mini';

        final res = await _client.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              if (systemInstruction != null) {'role': 'system', 'content': systemInstruction},
              {'role': 'user', 'content': prompt},
            ],
          }),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          return data['choices']?[0]?['message']?['content'] ?? '';
        } else {
          throw Exception('${provider.name.toUpperCase()} API Error ${res.statusCode}: ${res.body}');
        }

      case AiProviderType.custom:
        final key = (await storage.getCustomKey()) ?? '';
        final base = ((await storage.getCustomBaseUrl()) ?? '').trim();
        final model = (await storage.getCustomModel()) ?? 'gpt-4o-mini';
        if (base.isEmpty) {
          throw StateError('Base URL custom belum diisi (Settings).');
        }
        final chatUrl = base.endsWith('/')
            ? '${base}chat/completions'
            : '$base/chat/completions';
        final res = await _client.post(
          Uri.parse(chatUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              if (systemInstruction != null)
                {'role': 'system', 'content': systemInstruction},
              {'role': 'user', 'content': prompt},
            ],
          }),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          return data['choices']?[0]?['message']?['content'] ?? '';
        } else {
          throw Exception(
              'Custom provider ($base) Error ${res.statusCode}: ${res.body}');
        }

      case AiProviderType.server:
        return 'Server Visary: $prompt';
    }
  }
}
