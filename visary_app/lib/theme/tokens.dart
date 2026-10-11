import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — sumber: design/DESIGN-SPEC.md (canvas pen.dev).
class VC {
  static const bg = Color(0xFFFFF4E0);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111111);
  static const yellow = Color(0xFFFFD23F);
  static const pink = Color(0xFFFF6B9D);
  static const blue = Color(0xFF3A86FF);
  static const green = Color(0xFF06D6A0);
  static const purple = Color(0xFF9B5DE5);
  static const muted = Color(0xFF8B8680);
  static const dark = Color(0xFF2B2B2B);
  /// Background area video player (canvas tMv8K: #181818).
  static const playerBg = Color(0xFF181818);
}

/// Border & shadow neo-brutalism.
class VB {
  static const thin = 2.0;
  static const thick = 3.0;

  static List<BoxShadow> shadow([double o = 5, Color c = VC.ink]) =>
      [BoxShadow(color: c, offset: Offset(o, o), blurRadius: 0)];
}

class VT {
  static TextStyle display(double size, {Color color = VC.ink}) =>
      GoogleFonts.archivoBlack(fontSize: size, color: color, height: 1.15);

  static TextStyle body(double size,
          {Color color = VC.ink, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.spaceGrotesk(
          fontSize: size, color: color, fontWeight: weight, height: 1.35);

  static TextStyle mono(double size,
          {Color color = VC.ink, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.jetBrainsMono(
          fontSize: size, color: color, fontWeight: weight, height: 1.3);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: VC.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: VC.yellow,
      primary: VC.ink,
      surface: VC.paper,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme)
        .apply(bodyColor: VC.ink, displayColor: VC.ink),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
          color: VC.ink, border: Border.all(color: VC.ink, width: 2)),
      textStyle: VT.mono(11, color: VC.paper),
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(VC.ink),
      radius: Radius.zero,
      thickness: WidgetStatePropertyAll(6),
    ),
  );
}

String fmtTime(double sec) {
  if (sec.isNaN || sec < 0) sec = 0;
  final m = sec ~/ 60;
  final s = sec - m * 60;
  return '${m.toString().padLeft(2, '0')}:${s.floor().toString().padLeft(2, '0')}';
}

String fmtTimePrecise(double sec) {
  final m = sec ~/ 60;
  final s = sec - m * 60;
  return '${m.toString().padLeft(2, '0')}:${s.toStringAsFixed(2).padLeft(5, '0')}';
}
