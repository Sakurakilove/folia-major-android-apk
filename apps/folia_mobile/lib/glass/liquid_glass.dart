import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// A finite clipped backdrop reads the same Flutter scene; never capture a View or a screenshot.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    required this.program,
    required this.child,
    this.radius = 28,
  });
  final ui.FragmentProgram program;
  final Widget child;
  final double radius;
  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  late final ui.FragmentShader shader = widget.program.fragmentShader();
  @override
  void dispose() {
    shader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // The engine binds the first vec2 and first sampler for ImageFilter.shader.
    shader.setFloat(2, widget.radius * dpr);
    shader.setFloat(3, dpr);
    final blur = ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24);
    final filter = ui.ImageFilter.isShaderFilterSupported
        ? ui.ImageFilter.compose(
            outer: ui.ImageFilter.shader(shader),
            inner: blur,
          )
        : blur;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: BackdropFilter(
        filter: filter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .28),
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: Colors.white.withValues(alpha: .45)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .3),
                Colors.white.withValues(alpha: .08),
              ],
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
