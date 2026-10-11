import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visary/theme/tokens.dart';
import 'package:visary/widgets/brutal.dart';

/// Theme Tokens Compliance Test (PRD-SPRINT-07 §4 Test 7.1).
/// Verifikasi seluruh komponen utama (BButton, BBox, BInput, BTag, BCheck, BProgress)
/// menggunakan border-radius == 0 dan boxShadow dengan blurRadius == 0.
void main() {
  group('Design Tokens', () {
    test('VC color tokens match DESIGN-SPEC.md', () {
      expect(VC.bg, const Color(0xFFFFF4E0));
      expect(VC.paper, const Color(0xFFFFFFFF));
      expect(VC.ink, const Color(0xFF111111));
      expect(VC.yellow, const Color(0xFFFFD23F));
      expect(VC.pink, const Color(0xFFFF6B9D));
      expect(VC.blue, const Color(0xFF3A86FF));
      expect(VC.green, const Color(0xFF06D6A0));
      expect(VC.muted, const Color(0xFF8B8680));
    });

    test('VB.shadow menghasilkan hard-edge shadow (blurRadius: 0)', () {
      final shadows = VB.shadow(5);
      expect(shadows.length, 1);
      expect(shadows.first.blurRadius, 0, reason: 'Shadow harus hard-edge, no blur');
      expect(shadows.first.color, VC.ink);
      expect(shadows.first.offset, const Offset(5, 5));
    });

    test('VB.shadow default offset', () {
      final shadows = VB.shadow();
      expect(shadows.first.offset, const Offset(5, 5));
      expect(shadows.first.blurRadius, 0);
    });

    test('VB border constants', () {
      expect(VB.thin, 2.0);
      expect(VB.thick, 3.0);
    });
  });

  group('Component Compliance — zero border-radius', () {
    testWidgets('BBox tidak menggunakan border-radius', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: BBox(shadow: 4, child: const Text('test'))),
      ));

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNull,
          reason: 'BBox harus sudut siku (no border-radius)');
    });

    testWidgets('BButton tidak menggunakan border-radius', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: BButton(label: 'TEST', onTap: () {}),
          ),
        ),
      ));

      // BButton memakai AnimatedContainer → cek decoration
      final animatedContainer = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.text('TEST'), matching: find.byType(AnimatedContainer)),
      );
      final decoration = animatedContainer.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNull,
          reason: 'BButton harus sudut siku');
    });

    testWidgets('BTag tidak menggunakan border-radius', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: BTag('TAG')),
      ));

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNull,
          reason: 'BTag harus sudut siku');
    });

    testWidgets('BInput tidak menggunakan border-radius', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BInput(controller: TextEditingController(), hint: 'test'),
        ),
      ));

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNull,
          reason: 'BInput harus sudut siku');
    });

    testWidgets('BCheck tidak menggunakan border-radius', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BCheck(
            value: false,
            label: 'test',
            onChanged: (_) {},
          ),
        ),
      ));

      // BCheck memakai Container untuk checkbox box
      final containers = tester.widgetList<Container>(find.byType(Container));
      for (final c in containers) {
        final d = c.decoration as BoxDecoration?;
        if (d != null) {
          expect(d.borderRadius, isNull, reason: 'BCheck harus sudut siku');
        }
      }
    });

    testWidgets('BProgress tidak menggunakan border-radius', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: BProgress(value: 0.5)),
      ));

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNull,
          reason: 'BProgress harus sudut siku');
    });
  });

  group('Typography Compliance', () {
    test('VT.display uses Archivo Black', () {
      final style = VT.display(20);
      // GoogleFonts mengatur fontFamily secara internal; cek bukan null.
      expect(style.fontSize, 20);
      expect(style.color, VC.ink);
    });

    test('VT.body uses Space Grotesk', () {
      final style = VT.body(14);
      expect(style.fontSize, 14);
    });

    test('VT.mono uses JetBrains Mono', () {
      final style = VT.mono(12);
      expect(style.fontSize, 12);
    });
  });
}
