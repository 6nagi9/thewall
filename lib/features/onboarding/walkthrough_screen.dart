import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../core/theme.dart';
import '../../shared/wall_ui.dart';

/// First-launch intro carousel. Shown once (before login) to explain the
/// consent-first, owner-controlled model. Completion is persisted in prefs;
/// finishing flips [walkthroughSeenProvider] and the router redirects to login.
class WalkthroughScreen extends ConsumerStatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  ConsumerState<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends ConsumerState<WalkthroughScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = <_Slide>[
    _Slide(
      icon: Icons.grid_view_rounded,
      kicker: 'WELCOME',
      title: 'Claim your wall',
      body: 'Honest, structured feedback from the people who know you — '
          'each one a brick, on your terms, in one place.',
    ),
    _Slide(
      icon: Icons.visibility_outlined,
      kicker: 'CONSENT FIRST',
      title: "You're in control",
      body: 'Everything others write about you stays private until YOU '
          'choose what to make public on your wall.',
    ),
    _Slide(
      icon: Icons.trending_up_rounded,
      kicker: 'A MIRROR, NOT A SCORE',
      title: 'Grow with insight',
      body: 'See your strengths, track streaks, and watch your growth and '
          'openness improve over time.',
    ),
    _Slide(
      icon: Icons.lock_outline_rounded,
      kicker: 'PRIVATE BY DESIGN',
      title: 'Your data is yours',
      body: 'Contacts are hashed on your device, never stored raw. Export or '
          'permanently delete your data anytime (DPDP Act, 2023).',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _slides.length - 1;

  Future<void> _finish() async {
    await ref.read(walkthroughSeenProvider.notifier).markSeen();
    // Router refreshListenable picks up the change and redirects to /login.
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: WallMotion.med,
        curve: WallMotion.emphasized,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  const BrickMark(size: 30, animate: false),
                  const SizedBox(width: 10),
                  Text('The Wall', style: AppTheme.display(size: 17)),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _page = i);
                },
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            const SizedBox(height: 8),
            // Brick-shaped page dots.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: WallMotion.med,
                  curve: WallMotion.emphasized,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 10,
                  width: active ? 30 : 10,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.clay : AppTheme.ink700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: AnimatedSwitcher(
                    duration: WallMotion.fast,
                    child: Text(
                      _isLast ? 'Get started' : 'Next',
                      key: ValueKey(_isLast),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String kicker;
  final String title;
  final String body;
  const _Slide({
    required this.icon,
    required this.kicker,
    required this.title,
    required this.body,
  });
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon tile sitting on a faint brick lattice.
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 168,
                height: 168,
                child: CustomPaint(painter: _BrickLatticePainter()),
              ),
              Container(
                height: 96,
                width: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.ink800, AppTheme.ink850],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTheme.ink700),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.clay.withValues(alpha: 0.14),
                      blurRadius: 36,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(slide.icon, size: 44, color: AppTheme.clay),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1, 1),
                    duration: WallMotion.slow,
                    curve: WallMotion.spring,
                  )
                  .fadeIn(duration: WallMotion.med),
            ],
          ),
          const SizedBox(height: 36),
          Text(
            slide.kicker,
            style: AppTheme.body(
              size: 12,
              weight: FontWeight.w700,
              color: AppTheme.clay,
              letterSpacing: 1.6,
            ),
          ).animate().fadeIn(delay: 120.ms, duration: WallMotion.med),
          const SizedBox(height: 10),
          Text(
            slide.title,
            style: AppTheme.display(size: 32, height: 1.1),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: WallMotion.slow)
              .slideY(begin: 0.12, end: 0, delay: 200.ms, curve: WallMotion.ease),
          const SizedBox(height: 14),
          Text(
            slide.body,
            style: AppTheme.body(
                size: 15.5, color: AppTheme.ink300, height: 1.6),
          )
              .animate()
              .fadeIn(delay: 320.ms, duration: WallMotion.slow)
              .slideY(begin: 0.12, end: 0, delay: 320.ms, curve: WallMotion.ease),
        ],
      ),
    );
  }
}

/// Faint offset-brick pattern behind the walkthrough icon.
class _BrickLatticePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.ink700.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const rows = 4;
    final rowH = size.height / rows;
    final brickW = size.width / 3;
    for (var r = 0; r < rows; r++) {
      final offset = r.isOdd ? brickW / 2 : 0.0;
      for (var c = -1; c < 4; c++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(c * brickW + offset + 2, r * rowH + 2,
              brickW - 4, rowH - 4),
          const Radius.circular(6),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
