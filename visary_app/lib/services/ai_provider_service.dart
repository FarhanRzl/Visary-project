import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

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
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$key',
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

  /// Vision inference: kirim image + text prompt ke VLM. PRD-SPRINT-14 §2.1.
  ///
  /// Gemini: `inline_data {mime_type, data: base64}` dalam `parts`.
  /// OpenAI: `image_url {url: "data:image/jpeg;base64,..."}` dalam `messages`.
  /// Groq / Server: tidak support vision → `UnsupportedError`.
  /// Custom: coba format OpenAI-compatible vision.
  Future<String> visionPrompt({
    required String prompt,
    required String imageBase64,
    String mimeType = 'image/jpeg',
  }) async {
    final active = await isByokActive();
    if (!active) throw StateError('BYOK tidak aktif');

    final provider = await storage.getActiveProvider();
    switch (provider) {
      case AiProviderType.gemini:
        final key = (await storage.getGeminiKey()) ?? '';
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$key',
        );
        final res = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                  {
                    'inline_data': {
                      'mime_type': mimeType,
                      'data': imageBase64,
                    }
                  },
                ]
              }
            ]
          }),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final text =
              data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
          return text.toString();
        } else {
          throw Exception('Gemini Vision API Error ${res.statusCode}: ${res.body}');
        }

      case AiProviderType.openai:
        final key = (await storage.getOpenAiKey()) ?? '';
        final dataUri = 'data:$mimeType;base64,$imageBase64';
        final res = await _client.post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': prompt},
                  {
                    'type': 'image_url',
                    'image_url': {'url': dataUri}
                  },
                ]
              },
            ],
          }),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          return data['choices']?[0]?['message']?['content'] ?? '';
        } else {
          throw Exception('OpenAI Vision API Error ${res.statusCode}: ${res.body}');
        }

      case AiProviderType.groq:
        throw UnsupportedError(
            'Groq tidak support vision API. Switch ke Gemini/OpenAI di Settings.');

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
        final dataUri = 'data:$mimeType;base64,$imageBase64';
        final res = await _client.post(
          Uri.parse(chatUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': prompt},
                  {
                    'type': 'image_url',
                    'image_url': {'url': dataUri}
                  },
                ]
              },
            ],
          }),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          return data['choices']?[0]?['message']?['content'] ?? '';
        } else {
          throw Exception(
              'Custom Vision API ($base) Error ${res.statusCode}: ${res.body}');
        }

      case AiProviderType.server:
        throw UnsupportedError(
            'Server Visary tidak support vision API. Aktifkan BYOK dengan Gemini/OpenAI.');
    }
  }

  /// ASR: transkripsi audio → [Transcript] (PRD-SPRINT-11 §2.2).
  ///
  /// Cloud via provider aktif (custom/openai/groq: multipart POST
  /// `{baseUrl}/audio/transcriptions`, model whisper, `verbose_json` +
  /// word timestamp). Fallback: transkrip kosong bila BYOK off — pipeline
  /// tetap jalan (degraded). Gemini inline audio = future (text only).
  Future<Transcript> transcribe({
    required String audioFilePath,
    String? language, // 'id'/'en'/null=auto
  }) async {
    final active = await isByokActive();
    if (!active) {
      return const Transcript(
          fullText: '', words: [], language: null, provider: 'server');
    }
    final provider = await storage.getActiveProvider();
    if (provider == AiProviderType.gemini) {
      // TODO(PRD-SPRINT-11): Gemini inline audio base64 → text (no word ts).
      return const Transcript(
          fullText: '', words: [], language: null, provider: 'gemini');
    }

    final (base, key, model) = await _asrEndpoint(provider);
    if (base.isEmpty) {
      return Transcript(
          fullText: '', words: [], language: null, provider: provider.name);
    }
    final url = base.endsWith('/')
        ? '${base}audio/transcriptions'
        : '$base/audio/transcriptions';
    final req = http.MultipartRequest('POST', Uri.parse(url))
      ..headers['Authorization'] = 'Bearer $key'
      ..fields['model'] = model
      ..fields['response_format'] = 'verbose_json'
      ..fields['timestamp_granularities[]'] = 'word';
    if (language != null) req.fields['language'] = language;
    req.files.add(await http.MultipartFile.fromPath('file', audioFilePath));

    final streamed = await _client.send(req);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw Exception('ASR $provider Error ${streamed.statusCode}: $body');
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    final text = (data['text'] as String?) ?? '';
    final words = <WordToken>[];
    final wList = data['words'] as List?;
    if (wList != null) {
      for (final w in wList) {
        final wm = w as Map<String, dynamic>;
        words.add(WordToken(
          word: (wm['word'] as String?) ?? '',
          start: ((wm['start'] as num?) ?? 0).toDouble(),
          end: ((wm['end'] as num?) ?? 0).toDouble(),
        ));
      }
    }
    return Transcript(
      fullText: text,
      words: words,
      language: (data['language'] as String?) ?? language,
      provider: provider.name,
    );
  }

  /// Resolve (baseUrl, apiKey, asrModel) untuk provider OpenAI-compatible.
  /// Model ASR hardcoded per provider (whisper-1 / whisper-large-v3);
  /// customModel (chat) tidak dipakai untuk ASR.
  Future<(String, String, String)> _asrEndpoint(AiProviderType provider) async {
    switch (provider) {
      case AiProviderType.custom:
        final base = (await storage.getCustomBaseUrl()) ?? '';
        final key = (await storage.getCustomKey()) ?? '';
        return (base, key, 'whisper-1');
      case AiProviderType.openai:
        return ('https://api.openai.com/v1/',
            (await storage.getOpenAiKey()) ?? '',
            'whisper-1');
      case AiProviderType.groq:
        return ('https://api.groq.com/openai/v1/',
            (await storage.getGroqKey()) ?? '',
            'whisper-large-v3');
      case AiProviderType.gemini:
      case AiProviderType.server:
        return ('', '', '');
    }
  }
}
