import 'dart:convert';
import 'dart:io';
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
                      // Strip MIME-style line wrapping from base64 — Gemini rejects it.
                      'data': imageBase64.replaceAll('\n', ''),
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
      return await _transcribeViaGemini(audioFilePath, language);
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

  /// Gemini inline audio ASR: send audio as inline_data → text.
  /// No word-level timestamps from API — estimated via even distribution
  /// (~2.5 words/sec, 150 WPM average speaking rate).
  /// PRD-SPRINT-11 (Gemini inline audio, previously TODO).
  Future<Transcript> _transcribeViaGemini(
    String audioFilePath,
    String? language,
  ) async {
    final key = (await storage.getGeminiKey()) ?? '';
    final file = File(audioFilePath);
    if (!file.existsSync()) {
      throw Exception('Gemini ASR: file audio tidak ditemukan ($audioFilePath)');
    }

    // Audio chunking: Gemini inline_data limit ~20MB raw (~26MB base64).
    // Files >18MB safety margin → split via FFmpeg, transcribe per chunk,
    // merge with offset word timestamps. PRD-SPRINT-15 §2.7.
    final fileSize = file.lengthSync();
    const maxBytes = 18 * 1024 * 1024; // 18MB safety margin
    if (fileSize > maxBytes) {
      return await _transcribeGeminiChunked(audioFilePath, language, fileSize);
    }

    final bytes = await file.readAsBytes();
    // Dart base64Encode wraps at 76 chars with \n (RFC 2045 MIME).
    // Gemini inline_data rejects wrapped base64 with 400 "Base64 decoding failed".
    final b64 = base64Encode(bytes).replaceAll('\n', '');

    final ext = audioFilePath.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'mp3' => 'audio/mp3',
      'wav' => 'audio/wav',
      'm4a' || 'mp4' => 'audio/mp4',
      'ogg' => 'audio/ogg',
      'flac' => 'audio/flac',
      'aac' => 'audio/aac',
      _ => 'audio/mp3',
    };

    final promptText = language != null
        ? 'Transcribe this audio accurately in $language. Return only the transcribed text.'
        : 'Transcribe this audio accurately. Return only the transcribed text.';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$key',
    );
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'inline_data': {'mime_type': mimeType, 'data': b64}},
            {'text': promptText},
          ]
        }
      ],
    });

    // Retry transient errors (502/503) up to 3 times with backoff.
    http.Response res;
    for (var attempt = 0; ; attempt++) {
      res = await _client.post(uri,
          headers: {'Content-Type': 'application/json'}, body: body);
      if (res.statusCode == 200) break;
      final transient = res.statusCode == 502 || res.statusCode == 503;
      if (!transient || attempt >= 2) break;
      debugPrint('[Gemini ASR] ${res.statusCode} — retry ${attempt + 1}/3');
      await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
    }

    if (res.statusCode != 200) {
      final msg = _extractGeminiError(res.body);
      debugPrint('[Gemini ASR] Error ${res.statusCode}: $msg');
      throw Exception('Gemini ASR ${res.statusCode}: $msg');
    }

    final data = jsonDecode(res.body);
    final text =
        (data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '')
            .toString()
            .trim();

    if (text.isEmpty) {
      throw Exception('Gemini ASR: transcript kosong (audio tidak terdeteksi?)');
    }

    // Gemini doesn't return word timestamps.
    // Estimate: ~2.5 words/second (150 WPM average speaking rate).
    final wordStrs = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    const wordsPerSec = 2.5;
    final words = <WordToken>[];
    for (var i = 0; i < wordStrs.length; i++) {
      final start = i / wordsPerSec;
      final end = (i + 1) / wordsPerSec;
      words.add(WordToken(word: wordStrs[i], start: start, end: end));
    }

    return Transcript(
      fullText: text,
      words: words,
      language: language,
      provider: 'gemini',
    );
  }

  /// Extract human-readable error message from Gemini API error response.
  String _extractGeminiError(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Response wasn't JSON — return raw body (truncated).
    }
    final trimmed = responseBody.trim();
    return trimmed.length > 200 ? '${trimmed.substring(0, 200)}...' : trimmed;
  }

  /// Transcribe audio yang >18MB dengan chunking FFmpeg.
  /// Split audio jadi segmen ~15MB, transcribe per segmen, merge word timestamps.
  /// PRD-SPRINT-15 §2.7.
  Future<Transcript> _transcribeGeminiChunked(
    String audioFilePath,
    String? language,
    int fileSize,
  ) async {
    debugPrint('[ASR] Chunking audio ${fileSize ~/ 1024}KB > 18MB limit');

    // Probe duration via FFmpeg untuk hitung chunk count.
    final probeResult = await Process.run('ffprobe', [
      '-v', 'quiet',
      '-print_format', 'json',
      '-show_format',
      audioFilePath,
    ]);
    double totalDuration = 0;
    if (probeResult.exitCode == 0) {
      final fmt = jsonDecode(probeResult.stdout)['format'];
      totalDuration = double.tryParse(fmt['duration']?.toString() ?? '') ?? 0;
    }
    if (totalDuration <= 0) {
      throw Exception('Gemini ASR chunking: cannot probe audio duration');
    }

    // Hitung chunk count: target ~15MB per chunk.
    final bytesPerSec = fileSize / totalDuration;
    const targetChunkBytes = 15 * 1024 * 1024.0; // 15MB
    final chunkDuration = targetChunkBytes / bytesPerSec;
    final numChunks = (totalDuration / chunkDuration).ceil();
    final actualChunkDur = totalDuration / numChunks;

    debugPrint('[ASR] Splitting ${totalDuration}s into $numChunks chunks '
        'of ~${actualChunkDur.toStringAsFixed(1)}s each');

    final tmpDir = Directory.systemTemp.createTempSync('visary_chunk');
    final allWords = <WordToken>[];
    String fullText = '';
    const provider = 'gemini-flash-latest';

    try {
      for (var i = 0; i < numChunks; i++) {
        final start = i * actualChunkDur;
        final chunkPath = '${tmpDir.path}/chunk_$i.m4a';
        final splitResult = await Process.run('ffmpeg', [
          '-y', '-i', audioFilePath,
          '-ss', start.toStringAsFixed(3),
          '-t', actualChunkDur.toStringAsFixed(3),
          '-vn', '-acodec', 'aac', '-b:a', '128k',
          chunkPath,
        ]);
        if (splitResult.exitCode != 0) {
          throw Exception('FFmpeg chunk $i failed: ${splitResult.stderr}');
        }

        // Transcribe chunk (recursive call, chunk < 18MB so no infinite loop).
        final chunkTranscript = await _transcribeViaGemini(
          chunkPath,
          language,
        );

        // Offset word timestamps by chunk start time.
        for (final w in chunkTranscript.words) {
          allWords.add(WordToken(
            word: w.word,
            start: w.start + start,
            end: w.end + start,
          ));
        }
        fullText += '${chunkTranscript.fullText} ';
      }

      return Transcript(
        fullText: fullText.trim(),
        words: allWords,
        language: language,
        provider: provider,
      );
    } finally {
      await tmpDir.delete(recursive: true);
    }
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
