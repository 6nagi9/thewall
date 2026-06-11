import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';

/// Live connectivity status. Offline when the only result is `none`.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);

/// A thin animated "no connection" bar that slides in below the app bar when
/// the device goes offline. Wrap page content with this.
class ConnectivityBanner extends ConsumerWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityProvider).value;
    final offline =
        status != null && status.every((r) => r == ConnectivityResult.none);
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: offline
              ? Container(
                  width: double.infinity,
                  color: AppTheme.rose,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off,
                          size: 16, color: AppTheme.ink950),
                      const SizedBox(width: 8),
                      Text('No internet connection',
                          style: AppTheme.body(
                              size: 13,
                              weight: FontWeight.w700,
                              color: AppTheme.ink950)),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: child),
      ],
    );
  }
}
