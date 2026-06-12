import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';
import '../circles/circles_screen.dart';

/// Deep-link target for escrow invites (/i/{phoneHash}).
///
/// Escrowed feedback releases automatically the moment the *right* person
/// joins and consents (matched by their own phone hash in onUserJoin) — so
/// this screen never reveals anything about the link's hash. For a signed-in
/// user it simply explains where unlocked feedback lives.
class InviteLandingScreen extends ConsumerWidget {
  final String phoneHash;
  const InviteLandingScreen({super.key, required this.phoneHash});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(appUserProvider).value;
    final isMine = me != null && me.phoneHash == phoneHash;
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback invite')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrickMark(size: 56),
              const SizedBox(height: 22),
              Text(
                isMine
                    ? 'Your feedback is unlocked'
                    : 'This invite was for someone else',
                style: AppTheme.display(size: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                isMine
                    ? 'Everything that was waiting for you is now on your wall.'
                    : 'Feedback unlocks only for the person it was written '
                        'about — when they join with their own number. '
                        'That\'s consent-first.',
                style: AppTheme.body(
                    size: 14, color: AppTheme.ink300, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: Text(isMine ? 'See my wall' : 'Go to my wall'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deep-link target for circle invites (/c/{code}): joins then goes home.
class CircleJoinLandingScreen extends ConsumerStatefulWidget {
  final String code;
  const CircleJoinLandingScreen({super.key, required this.code});

  @override
  ConsumerState<CircleJoinLandingScreen> createState() =>
      _CircleJoinLandingScreenState();
}

class _CircleJoinLandingScreenState
    extends ConsumerState<CircleJoinLandingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await joinCircleByCode(context, ref, widget.code.toUpperCase());
      if (mounted) context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: WallLoader());
}
