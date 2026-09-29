import 'package:flutter/material.dart';

/// Vrai si l'utilisateur a demandé à réduire les animations.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Apparition en fondu + glissement, décalée selon [index] (effet cascade).
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 70 * widget.index.clamp(0, 8)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - _curve.value)), child: child),
      ),
    );
  }
}

/// Effet interactif : léger soulèvement au survol et compression à l'appui.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.lift = 3,
    this.tilt = 0,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double lift;
  final double tilt;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final scale = _down ? .96 : 1.0;
    final dy = _hover && enabled ? -widget.lift : 0.0;
    final angle = _hover && enabled ? widget.tilt : 0.0;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            transformAlignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(0, dy, 0, 1)
              ..rotateZ(angle)
              ..scaleByDouble(scale, scale, 1, 1),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
