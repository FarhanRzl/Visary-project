import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';

/// PRD-SPRINT-12 §4 — Test 12.1: Transcript export format (.srt + .txt).
void main() {
  test('Transcript.toSrt format benar (index, timecode HH:MM:SS,mmm, text)', () {
    final t = Transcript(
      fullText: 'hello world',
      words: const [
        WordToken(word: 'hello', start: 0.0, end: 0.5),
        WordToken(word: 'world', start: 0.5, end: 1.0),
      ],
      language: 'en',
      provider: 'custom',
    );
    final srt = t.toSrt();
    expect(srt, contains('1\n00:00:00,000 --> 00:00:00,500\nhello'));
    expect(srt, contains('2\n00:00:00,500 --> 00:00:01,000\nworld'));
  });

  test('Transcript.toTxt return fullText apa adanya', () {
    const t = Transcript(
      fullText: 'ini adalah transkripsi lengkap.',
      words: [],
      provider: 'gemini',
    );
    expect(t.toTxt(), 'ini adalah transkripsi lengkap.');
  });

  test('Transcript.toSrt return empty string bila words kosong', () {
    const t = Transcript(
      fullText: 'text only tanpa timestamp',
      words: [],
      provider: 'gemini',
    );
    expect(t.toSrt(), '');
  });

  test('Transcript.toTxt return empty string bila fullText kosong', () {
    const t = Transcript(fullText: '', words: [], provider: 'server');
    expect(t.toTxt(), '');
  });

  test('Empty transcript: toSrt dan toTxt keduanya empty', () {
    const t = Transcript(fullText: '', words: [], provider: 'server');
    expect(t.isEmpty, isTrue);
    expect(t.toSrt(), '');
    expect(t.toTxt(), '');
  });

  test('Transcript dengan words banyak: toSrt index berurutan', () {
    final t = Transcript(
      fullText: 'satu dua tiga',
      words: const [
        WordToken(word: 'satu', start: 0.0, end: 1.0),
        WordToken(word: 'dua', start: 1.0, end: 2.0),
        WordToken(word: 'tiga', start: 2.0, end: 3.0),
      ],
      provider: 'custom',
    );
    final srt = t.toSrt();
    expect(srt, contains('1\n'));
    expect(srt, contains('2\n'));
    expect(srt, contains('3\n'));
    expect(srt, contains('00:00:03,000'));
  });
}
