import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Kotak dasar neo-brutalism: fill solid, border ink, hard shadow, sudut siku.
class BBox extends StatelessWidget {
  const BBox({
    super.key,
    required this.child,
    this.color = VC.paper,
    this.border = VB.thick,
    this.borderColor = VC.ink,
    this.shadow = 0,
    this.shadowColor = VC.ink,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
  });

  final Widget child;
  final Color color;
  final double border;
  final Color borderColor;
  final double shadow;
  final Color shadowColor;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: border > 0
            ? Border.all(color: borderColor, width: border)
            : null,
        boxShadow: shadow > 0 ? VB.shadow(shadow, shadowColor) : null,
      ),
      child: child,
    );
  }
}

enum BtnKind { primary, dark, outline, pink, green, yellow }

/// Tombol neo-brutalism. Saat ditekan, tombol "turun" menutupi shadow.
class BButton extends StatefulWidget {
  const BButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.kind = BtnKind.primary,
    this.expand = false,
    this.small = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final BtnKind kind;
  final bool expand;
  final bool small;

  @override
  State<BButton> createState() => _BButtonState();
}

class _BButtonState extends State<BButton> {
  bool _hover = false;
  bool _down = false;

  (Color, Color) get _colors => switch (widget.kind) {
        BtnKind.primary => (VC.yellow, VC.ink),
        BtnKind.dark => (VC.ink, VC.paper),
        BtnKind.outline => (VC.paper, VC.ink),
        BtnKind.pink => (VC.pink, VC.ink),
        BtnKind.green => (VC.green, VC.ink),
        BtnKind.yellow => (VC.yellow, VC.ink),
      };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final (bg, fg) = _colors;
    final s = widget.small ? 3.0 : 4.0;
    final offset = _down ? s : (_hover ? -1.0 : 0.0);
    final shadow = _down ? 0.0 : (_hover ? s + 1 : s);

    Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: widget.small ? 14 : 18, color: fg),
          SizedBox(width: widget.small ? 6 : 10),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: widget.small
                ? VT.mono(11, color: fg)
                : VT.display(14, color: fg),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            transform: Matrix4.translationValues(offset, offset, 0),
            padding: widget.small
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
                : const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: VC.ink, width: widget.small ? 2 : 3),
              boxShadow: enabled && shadow > 0 ? VB.shadow(shadow) : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Badge mono kecil (skor, format, status).
class BTag extends StatelessWidget {
  const BTag(this.text,
      {super.key,
      this.color = VC.paper,
      this.fg = VC.ink,
      this.icon,
      this.border = 2,
      this.size = 11});

  final String text;
  final Color color;
  final Color fg;
  final IconData? icon;
  final double border;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        border: border > 0 ? Border.all(color: VC.ink, width: border) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: size + 2, color: fg),
          const SizedBox(width: 6),
        ],
        Text(text, style: VT.mono(size, color: fg)),
      ]),
    );
  }
}

/// Area klik generik dengan cursor pointer.
class Clickable extends StatelessWidget {
  const Clickable({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
            behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      );
}

/// Checkbox kotak siku.
class BCheck extends StatelessWidget {
  const BCheck(
      {super.key,
      required this.value,
      required this.label,
      required this.onChanged,
      this.enabled = true});
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Clickable(
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? VC.ink : VC.paper,
                border: Border.all(color: VC.ink, width: 2),
              ),
              child: value
                  ? const Icon(Icons.check, size: 14, color: VC.yellow)
                  : null,
            ),
            const SizedBox(width: 10),
            Flexible(child: Text(label, style: VT.body(13))),
          ]),
        ),
      ),
    );
  }
}

/// Top bar standar semua screen.
class BTopBar extends StatelessWidget {
  const BTopBar(
      {super.key, required this.left, this.center, this.right = const []});
  final Widget left;
  final Widget? center;
  final List<Widget> right;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      decoration: const BoxDecoration(
        color: VC.paper,
        border: Border(bottom: BorderSide(color: VC.ink, width: 3)),
      ),
      child: Row(children: [
        left,
        const SizedBox(width: 24),
        Expanded(child: Center(child: center ?? const SizedBox())),
        const SizedBox(width: 24),
        ...right.expand((w) => [w, const SizedBox(width: 12)]).toList()
          ..removeLast(),
        if (right.isEmpty) const SizedBox(),
      ]),
    );
  }
}

class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 22});
  final double size;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Transform.rotate(
        angle: -0.1,
        child: Container(
          width: size * 1.5,
          height: size * 1.5,
          decoration: BoxDecoration(
              color: VC.yellow, border: Border.all(color: VC.ink, width: 3)),
          child: Icon(Icons.bolt, size: size, color: VC.ink),
        ),
      ),
      SizedBox(width: size * 0.45),
      Text('VISARY', style: VT.display(size)),
    ]);
  }
}

/// Progress bar siku.
class BProgress extends StatelessWidget {
  const BProgress(
      {super.key, required this.value, this.color = VC.pink, this.height = 24});
  final double value;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
          color: VC.bg, border: Border.all(color: VC.ink, width: 3)),
      child: LayoutBuilder(
        builder: (c, box) => Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: box.maxWidth * value.clamp(0.0, 1.0),
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Input teks gaya brutal.
class BInput extends StatelessWidget {
  const BInput({
    super.key,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.onSubmitted,
    this.prefix,
    this.borderless = false,
  });
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefix;
  final bool borderless;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: borderless ? Colors.transparent : VC.bg,
        border: borderless ? null : Border.all(color: VC.ink, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        if (prefix != null) ...[prefix!, const SizedBox(width: 8)],
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            onSubmitted: onSubmitted,
            cursorColor: VC.ink,
            style: VT.body(14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: VT.body(14, color: VC.muted),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Header section kecil uppercase mono.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(text, style: VT.mono(12))),
        if (trailing != null) trailing!,
      ]);
}

Future<T?> showBrutalDialog<T>(BuildContext context,
    {required Widget child, double width = 520}) {
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0x99111111),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: SizedBox(
        width: width,
        child: BBox(
          shadow: 8,
          padding: const EdgeInsets.all(28),
          child: child,
        ),
      ),
    ),
  );
}

/// Sisipkan SizedBox vertikal antar children (pengganti `gap` yang tak ada
/// di Flutter Column/Row stock).
List<Widget> withGaps(List<Widget> children, double gap, {bool horizontal = false}) {
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    out.add(children[i]);
    if (i != children.length - 1) {
      out.add(horizontal ? SizedBox(width: gap) : SizedBox(height: gap));
    }
  }
  return out;
}

void showBrutalSnack(BuildContext context, String msg,
    {Color color = VC.ink, Color fg = VC.paper}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    width: 520,
    backgroundColor: color,
    elevation: 0,
    shape: const RoundedRectangleBorder(
        side: BorderSide(color: VC.ink, width: 3)),
    content: Text(msg, style: VT.mono(12, color: fg)),
  ));
}
