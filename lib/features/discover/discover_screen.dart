import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/repositories.dart';

/// Discover: opt-in leaderboards ranking CONTRIBUTION, GROWTH and OPENNESS.
/// Never "highest-rated people" (avoids comparison harm + defamation).
/// Only users who have opted in appear on leaderboards.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(firestoreProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Discover'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Contribution'),
              Tab(text: 'Growth'),
              Tab(text: 'Openness'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Board(
              stream: db
                  .collection('gamification')
                  .where('leaderboardOptIn', isEqualTo: true)
                  .orderBy('contributionPoints', descending: true)
                  .limit(50)
                  .snapshots(),
              metric: 'contributionPoints',
              suffix: ' pts',
            ),
            _Board(
              stream: db
                  .collection('gamification')
                  .where('leaderboardOptIn', isEqualTo: true)
                  .orderBy('growthScore', descending: true)
                  .limit(50)
                  .snapshots(),
              metric: 'growthScore',
              suffix: '',
            ),
            _Board(
              stream: db
                  .collection('gamification')
                  .where('leaderboardOptIn', isEqualTo: true)
                  .orderBy('opennessScore', descending: true)
                  .limit(50)
                  .snapshots(),
              metric: 'opennessScore',
              suffix: '',
            ),
          ],
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  final Stream stream;
  final String metric;
  final String suffix;
  const _Board(
      {required this.stream, required this.metric, required this.suffix});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = (snap.data as dynamic).docs as List;
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Leaderboards fill up as the community grows.\n'
                'Enable "Appear on leaderboards" in Settings to join.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.slate500),
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final raw = d[metric];
            final value = raw is double
                ? raw.toStringAsFixed(raw == raw.truncateToDouble() ? 0 : 1)
                : (raw as num?)?.toString() ?? '0';
            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    i < 3 ? AppTheme.amber : AppTheme.slate700,
                child: Text('${i + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700)),
              ),
              title: Text(d['displayName'] as String? ?? 'Member'),
              trailing: Text(
                '$value$suffix',
                style: const TextStyle(
                    color: AppTheme.teal,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
            );
          },
        );
      },
    );
  }
}
