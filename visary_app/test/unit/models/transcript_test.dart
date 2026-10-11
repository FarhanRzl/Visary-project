import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';

/// PRD-SPRINT-11 §4 — Test 11.2: Transcript model + .srt generator.
void main() {
  test('Transcript.toSrt format benar (index, timecode, text)', () {
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

  test('Transcript.toSrt kosong bila tidak ada words', () {
    const t = Transcript(fullText: 'text only', words: [], provider: 'gemini');
    expect(t.toSrt(), '');
  });

  test('Transcript.isEmpty benar', () {
    const empty = Transcript(fullText: '', words: [], provider: 'server');
    expect(empty.isEmpty, isTrue);
    const nonEmpty =
        Transcript(fullText: 'hi', words: [], provider: 'custom');
    expect(nonEmpty.isEmpty, isFalse);
  });

  test('WordToken menyimpan word + start + end', () {
    const w = WordToken(word: 'test', start: 1.5, end: 2.0);
    expect(w.word, 'test');
    expect(w.start, 1.5);
    expect(w.end, 2.0);
  });
}
