import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_review.dart';
import 'remote_config.dart';
import 'theme.dart';

/// Whole-app availability gate, driven by Remote Config so it can be flipped
/// without an app release:
///   • maintenance kill-switch (server outage / migration)
///   • forced update when the running build is older than the minimum supported
///
/// Evaluated once at startup and rendered over the entire app (see the
/// `builder:` in WallApp).
enum AppGateStatus { ok, maintenance, updateRequired }

class AppGateState {
  final AppGateStatus status;
  final String message;
  const AppGateState(this.status, this.message);
}

/// Resolves the gate. Ensures Remote Config is active before deciding so a
/// maintenance/forced-update flag takes effect on the current launch (not the
/// next one). Fails open (ok) on any error — a config hiccup must never brick
/// the app.
final appGateProvider = FutureProvider<AppGateState>((ref) async {
  try {
    await initRemoteConfig();
    final rc = FirebaseRemoteConfig.instance;

    if (rc.getBool(RemoteConfigKeys.maintenanceMode)) {
      return AppGateState(
          AppGateStatus.maintenance,
          rc.getString(RemoteConfigKeys.maintenanceMessage));
    }

    final minBuild = rc.getInt(RemoteConfigKeys.minSupportedBuild);
    if (minBuild > 0) {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      if (current > 0 && current < minBuild) {
        return AppGateState(
            AppGateStatus.updateRequired,
            rc.getString(RemoteConfigKeys.updateMessage));
      }
    }
  } catch (_) {
    // Fail open.
  }
  return const AppGateState(AppGateStatus.ok, '');
});

/// Wraps the whole app; shows a blocking screen when maintenance/update gates
/// are active, otherwise renders [child] unchanged.
class AppGate extends ConsumerWidget {
  final Widget child;
  const AppGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(appGateProvider).value;
    if (gate == null || gate.status == AppGateStatus.ok) return child;
    return _GateScreen(state: gate);
  }
}

class _GateScreen extends ConsumerWidget {
  final AppGateState state;
  const _GateScreen({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUpdate = state.status == AppGateStatus.updateRequired;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: AppTheme.ink950,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUpdate
                        ? Icons.system_update_alt_rounded
                        : Icons.construction_rounded,
                    size: 56,
                    color: AppTheme.clay,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isUpdate ? 'Update required' : 'Back shortly',
                    textAlign: TextAlign.center,
                    style: AppTheme.display(size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: AppTheme.body(
                        size: 14.5, color: AppTheme.ink300, height: 1.5),
                  ),
                  if (isUpdate) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            ref.read(appReviewProvider).openStoreListing(),
                        child: const Text('Update now'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
