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
      color: AppTheme.slate900,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: AppTheme.slate500),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                message ?? 'Please try again in a moment.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.slate300),
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
          const Icon(Icons.cloud_off, color: AppTheme.slate500, size: 32),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.slate500)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
