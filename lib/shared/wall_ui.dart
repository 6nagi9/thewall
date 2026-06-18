import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Shared UI kit for Known — "Clay & Ink".
/// Cards, press feedback, the brick mark, brick progress, rating bricks,
/// chips, entrance animations. Keep every screen on this vocabulary.
/// ─────────────────────────────────────────────────────────────────────────

/// Staggered entrance: fade + rise. Use on list children with their index.
extension WallEntrance on Widget {
  Widget entrance(int index, {double dy = 0.06}) => animate()
      .fadeIn(
        delay: Duration(milliseconds: 55 * index),
        duration: WallMotion.slow,
        curve: WallMotion.ease,
      )
      .slideY(
        begin: dy,
        end: 0,
        delay: Duration(milliseconds: 55 * index),
        duration: WallMotion.slow,
        curve: WallMotion.ease,
      );
}

/// Press-scale wrapper — everything tappable should feel springy.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Standard surface card.
class WallCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;
  const WallCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.borderColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppTheme.ink850) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? AppTheme.ink700),
      ),
      child: child,
    );
    return Pressable(onTap: onTap, child: card);
  }
}

/// Small uppercase section label.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Row(
          children: [
            Text(
              text.toUpperCase(),
              style: AppTheme.body(
                size: 11.5,
                weight: FontWeight.w700,
                color: AppTheme.ink400,
                letterSpacing: 1.2,
              ),
            ),
            if (trailing != null) ...[const Spacer(), trailing!],
          ],
        ),
      );
}

/// The brand mark — a 2×2 brick grid that assembles itself.
class BrickMark extends StatelessWidget {
  final double size;
  final bool animate;
  const BrickMark({super.key, this.size = 56, this.animate = true});

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppTheme.clayBright,
      AppTheme.clay,
      AppTheme.clayDeep,
      AppTheme.clay,
    ];
    final gap = size * 0.10;
    final brick = (size - gap) / 2;
    Widget cell(int i) {
      Widget w = Container(
        width: brick,
        height: brick,
        decoration: BoxDecoration(
          color: colors[i],
          borderRadius: BorderRadius.circular(size * 0.13),
        ),
      );
      if (!animate) return w;
      return w
          .animate()
          .scale(
            begin: const Offset(0.4, 0.4),
            end: const Offset(1, 1),
            delay: Duration(milliseconds: 120 * i),
            duration: WallMotion.slow,
            curve: WallMotion.spring,
          )
          .fadeIn(
            delay: Duration(milliseconds: 120 * i),
            duration: WallMotion.med,
          );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [cell(0), cell(1)],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [cell(2), cell(3)],
          ),
        ],
      ),
    );
  }
}

/// Animated rounded progress bar (0–1) that sweeps in.
class WallProgress extends StatelessWidget {
  final double value;
  final double height;
  final Color? color;
  const WallProgress({
    super.key,
    required this.value,
    this.height = 9,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: WallMotion.emphasized,
      builder: (context, v, child) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          children: [
            Container(height: height, color: AppTheme.ink700),
            FractionallySizedBox(
              widthFactor: v == 0 ? 0.001 : v,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color ?? AppTheme.clayDeep,
                      color ?? AppTheme.clayBright,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of brick "slots" — n of total filled, each landing with a pop.
/// The literal wall: progress you can watch being built.
class BrickProgress extends StatelessWidget {
  final int filled;
  final int total;
  final double height;
  const BrickProgress({
    super.key,
    required this.filled,
    required this.total,
    this.height = 26,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        Widget brick = Container(
          height: height,
          decoration: BoxDecoration(
            color: isFilled ? AppTheme.clay : AppTheme.ink800,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isFilled ? AppTheme.clayDeep : AppTheme.ink700,
            ),
          ),
        );
        if (isFilled) {
          brick = brick.animate().scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                delay: Duration(milliseconds: 130 * i + 200),
                duration: WallMotion.slow,
                curve: WallMotion.spring,
              );
        }
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 7),
            child: brick,
          ),
        );
      }),
    );
  }
}

/// 1–5 rating as five tappable bricks. Replaces sliders for ratings.
class RatingBricks extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const RatingBricks({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final n = i + 1;
        final active = n <= value;
        final isTop = n == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 4 ? 0 : 8),
            child: Pressable(
              onTap: () => onChanged(n),
              pressedScale: 0.9,
              child: AnimatedContainer(
                duration: WallMotion.med,
                curve: WallMotion.ease,
                height: 46,
                decoration: BoxDecoration(
                  color: active
                      ? Color.lerp(AppTheme.clayDeep, AppTheme.clay, n / 5)
                      : AppTheme.ink850,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? AppTheme.clayDeep : AppTheme.ink700,
                  ),
                  boxShadow: isTop
                      ? [
                          BoxShadow(
                            color: AppTheme.clay.withValues(alpha: .35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: WallMotion.fast,
                    style: AppTheme.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: active ? AppTheme.ink950 : AppTheme.ink400,
                    ),
                    child: Text('$n'),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Selectable pill chip with a springy press.
class TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;
  const TagChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final a = accent ?? AppTheme.clay;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.92,
      child: AnimatedContainer(
        duration: WallMotion.med,
        curve: WallMotion.ease,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? a.withValues(alpha: 0.16) : AppTheme.ink850,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? a : AppTheme.ink700,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.body(
            size: 13,
            weight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? a : AppTheme.ink300,
          ),
        ),
      ),
    );
  }
}

/// Big friendly empty state.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.ink850,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.ink700),
            ),
            child: Icon(icon, color: AppTheme.clay, size: 32),
          )
              .animate()
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: WallMotion.slow,
                curve: WallMotion.spring,
              )
              .fadeIn(),
          const SizedBox(height: 18),
          Text(title,
              textAlign: TextAlign.center, style: AppTheme.display(size: 19)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTheme.body(size: 14, color: AppTheme.ink400, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Loading state — a small pulsing brick grid, on brand.
class WallLoader extends StatelessWidget {
  const WallLoader({super.key});

  @override
  Widget build(BuildContext context) {
    // NB: use the Animate widget directly rather than the `.animate()`
    // extension — BrickMark has its own `bool animate` field, which shadows
    // the flutter_animate extension on a BrickMark instance.
    return Center(
      child: Animate(
        onPlay: (c) => c.repeat(reverse: true),
        effects: [
          FadeEffect(begin: 0.35, end: 1, duration: 700.ms),
          ScaleEffect(
            begin: const Offset(0.92, 0.92),
            end: const Offset(1, 1),
            duration: 700.ms,
            curve: Curves.easeInOut,
          ),
        ],
        child: const BrickMark(size: 44, animate: false),
      ),
    );
  }
}

/// Score pill, e.g. "4.6".
class ScorePill extends StatelessWidget {
  final double score;
  final double size;
  const ScorePill(this.score, {super.key, this.size = 13});

  Color get _color {
    if (score >= 4) return AppTheme.sage;
    if (score >= 3) return AppTheme.gold;
    return AppTheme.rose;
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          score.toStringAsFixed(1),
          style: AppTheme.body(
              size: size, weight: FontWeight.w800, color: _color),
        ),
      );
}

/// Standard screen header used inside scrollable bodies — big display title
/// with an optional kicker line above and trailing widget.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? kicker;
  final Widget? trailing;
  const ScreenHeader({
    super.key,
    required this.title,
    this.kicker,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null) ...[
                  Text(
                    kicker!.toUpperCase(),
                    style: AppTheme.body(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: AppTheme.clay,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(title, style: AppTheme.display(size: 30)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    ).entrance(0);
  }
}
