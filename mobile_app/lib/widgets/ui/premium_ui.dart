import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Premium UI kit — shared primitives so the home screens (student + trainer)
/// share one cohesive, high-end visual language. Keeps the existing violet/
/// cyan dark palette; adds a display typeface, consistent icon badges, depth
/// (gradients + glow), motion (entrance + press feedback) and skeletons.
/// ─────────────────────────────────────────────────────────────────────────

class AppRadius {
  static const double card = 18;
  static const double hero = 24;
  static const double pill = 24;
  static const double badge = 14;
}

/// Display typeface for numbers and titles (paired with Inter for body).
/// Sora gives a modern, technical-premium voice that fits the violet/cyan theme.
TextStyle displayStyle({
  double size = 24,
  FontWeight weight = FontWeight.w800,
  Color color = const Color(AppConstants.textPrimary),
  double height = 1.0,
  double letterSpacing = -0.5,
}) {
  return GoogleFonts.sora(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// Uppercase section label with consistent tracking.
class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const SectionLabel(this.text,
      {super.key, this.padding = const EdgeInsets.symmetric(horizontal: 24)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          color: const Color(AppConstants.textSecondary),
        ),
      ),
    );
  }
}

/// Cohesive icon badge: a rounded-square tinted container with a centered icon.
/// Use the SAME widget everywhere so every icon reads as one family.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double boxSize;
  final double iconSize;
  final bool gradient;

  const IconBadge(
    this.icon, {
    super.key,
    this.color = const Color(AppConstants.neonAccent),
    this.boxSize = 44,
    this.iconSize = 22,
    this.gradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        gradient: gradient
            ? const LinearGradient(
                colors: [Color(AppConstants.neonAccent), Color(AppConstants.cyanAccent)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: gradient ? null : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: gradient ? null : Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, color: gradient ? Colors.white : color, size: iconSize),
    );
  }
}

/// Card with subtle depth: gradient surface, hairline border and a soft shadow.
/// An optional [glow] paints a colored halo (used behind primary surfaces).
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? glow;
  final Color? borderColor;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadius.card,
    this.glow,
    this.borderColor,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ??
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(AppConstants.cardElevated), Color(AppConstants.cardDark)],
            ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          if (glow != null)
            BoxShadow(
              color: glow!.withValues(alpha: 0.22),
              blurRadius: 28,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return PressableScale(onTap: onTap!, child: card);
  }
}

/// Primary CTA with the signature violet→cyan gradient + glow.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final double height;
  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(AppConstants.neonAccent), Color(AppConstants.cyanAccent)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            BoxShadow(
              color: const Color(AppConstants.neonAccent).withValues(alpha: 0.35),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scales + light-haptic on press for a tactile, premium feel.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const PressableScale({super.key, required this.child, required this.onTap});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  double _scale = 1.0;
  void _set(double v) => setState(() => _scale = v);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(0.97),
      onTapCancel: () => _set(1.0),
      onTapUp: (_) => _set(1.0),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Staggered fade + slide-up entrance.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const FadeSlideIn({super.key, required this.child, this.delayMs = 0});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 460));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
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
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Shimmering skeleton block for loading states (no external dependency).
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 12});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * _c.value, 0),
              end: Alignment(1 - 2 * _c.value, 0),
              colors: const [
                Color(AppConstants.cardDark),
                Color(AppConstants.cardElevated),
                Color(AppConstants.cardDark),
              ],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}
