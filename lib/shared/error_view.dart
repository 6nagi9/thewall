import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Friendly full-screen fallback shown (in release) when a widget subtree throws,
/// replacing Flutter's default grey/red error box. Optionally offers a retry.
class AppErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  const AppErrorView({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.ink950,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.ink850,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.ink700),
                ),
                child: const Icon(Icons.build_outlined,
                    size: 32, color: AppTheme.clay),
              ),
              const SizedBox(height: 18),
              Text(
                'A brick came loose',
                style: AppTheme.display(size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                message ?? 'Something went wrong. Please try again in a moment.',
                textAlign: TextAlign.center,
                style: AppTheme.body(
                    size: 14, color: AppTheme.ink300, height: 1.5),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact inline error row for use inside lists / cards (e.g. a failed
/// StreamBuilder section) without taking the whole screen.
class InlineError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const InlineError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: AppTheme.ink400, size: 32),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 13, color: AppTheme.ink400)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
