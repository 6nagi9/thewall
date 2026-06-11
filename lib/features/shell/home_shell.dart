import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../shared/connectivity_banner.dart';
import '../../shared/wall_ui.dart';
import '../my_wall/my_wall_screen.dart';
import '../feedback/give_feedback_screen.dart';
import '../discover/discover_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = [
    MyWallScreen(),
    GiveFeedbackScreen(),
    DiscoverScreen(),
    SettingsScreen(),
  ];

  void _go(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: ConnectivityBanner(
        child: AnimatedSwitcher(
          duration: WallMotion.med,
          switchInCurve: WallMotion.ease,
          switchOutCurve: WallMotion.ease,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.012),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(_index),
            child: _tabs[_index],
          ),
        ),
      ),
      bottomNavigationBar: _WallNavBar(index: _index, onTap: _go),
    );
  }
}

/// Custom floating bottom nav — a frosted bar with a sliding clay pill.
class _WallNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _WallNavBar({required this.index, required this.onTap});

  static const _items = [
    (Icons.grid_view_rounded, Icons.grid_view_outlined, 'My Wall'),
    (Icons.edit_rounded, Icons.edit_outlined, 'Give'),
    (Icons.explore_rounded, Icons.explore_outlined, 'Discover'),
    (Icons.tune_rounded, Icons.tune_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: AppTheme.ink900.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.ink700),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / _items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: WallMotion.med,
                  curve: WallMotion.emphasized,
                  left: w * index + 8,
                  top: 8,
                  width: w - 16,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.clay.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.clay.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(_items.length, (i) {
                    final (active, idle, label) = _items[i];
                    final sel = i == index;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: sel ? 1.0 : 0.92,
                              duration: WallMotion.med,
                              curve: WallMotion.spring,
                              child: Icon(
                                sel ? active : idle,
                                size: 23,
                                color:
                                    sel ? AppTheme.clay : AppTheme.ink400,
                              ),
                            ),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration: WallMotion.fast,
                              style: AppTheme.body(
                                size: 10.5,
                                weight:
                                    sel ? FontWeight.w700 : FontWeight.w500,
                                color:
                                    sel ? AppTheme.clay : AppTheme.ink400,
                              ),
                              child: Text(label),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
