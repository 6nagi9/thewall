import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

/// Premium analytics screen — time-series trend charts for each dimension,
/// using decay-unweighted raw scores so the user sees actual change over time.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(receivedFeedbackProvider);
    final user = ref.watch(appUserProvider).value;

    if (user?.premium != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trend Analytics')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 48, color: AppTheme.slate500),
                SizedBox(height: 16),
                Text(
                  'Trend analytics is a Premium feature.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Upgrade to Premium to see how your reputation evolves over time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.slate300),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trend Analytics')),
      body: feedbackAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (feedback) {
          if (feedback.length < 3) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'You need at least 3 pieces of feedback before trends are meaningful.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.slate500),
                ),
              ),
            );
          }
          final sorted =
              [...feedback]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(feedback: sorted),
              const SizedBox(height: 20),
              ...FeedbackDimension.all.map((d) {
                final spots = _spotsFor(sorted, d.key);
                if (spots.length < 2) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _DimensionChart(dim: d, spots: spots, data: sorted),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  List<FlSpot> _spotsFor(List<ReceivedFeedback> sorted, String key) {
    final withVal =
        sorted.where((f) => f.dimensions.containsKey(key)).toList();
    if (withVal.isEmpty) return [];
    final t0 = withVal.first.createdAt.millisecondsSinceEpoch;
    return withVal
        .asMap()
        .entries
        .map((e) {
          final daysSince =
              (e.value.createdAt.millisecondsSinceEpoch - t0) / 86400000;
          return FlSpot(daysSince, e.value.dimensions[key]!.toDouble());
        })
        .toList();
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final List<ReceivedFeedback> feedback;
  const _SummaryCard({required this.feedback});

  @override
  Widget build(BuildContext context) {
    final first = feedback.first.createdAt;
    final last = feedback.last.createdAt;
    final span = last.difference(first).inDays;

    // Trend direction per dimension: compare first-half vs second-half averages.
    final mid = feedback.length ~/ 2;
    final firstHalf = feedback.sublist(0, mid);
    final secondHalf = feedback.sublist(mid);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: AppTheme.teal),
                const SizedBox(width: 8),
                Text(
                  '${feedback.length} reviews over $span days',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat("d MMM yy").format(first)} → '
              '${DateFormat("d MMM yy").format(last)}',
              style:
                  const TextStyle(color: AppTheme.slate500, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...FeedbackDimension.all.map((d) {
              final avgFirst = _avg(firstHalf, d.key);
              final avgLast = _avg(secondHalf, d.key);
              if (avgFirst == null || avgLast == null) {
                return const SizedBox.shrink();
              }
              final delta = avgLast - avgFirst;
              final up = delta > 0.1;
              final down = delta < -0.1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                        width: 110,
                        child: Text(d.label,
                            style: const TextStyle(fontSize: 13))),
                    Icon(
                      up
                          ? Icons.trending_up
                          : down
                              ? Icons.trending_down
                              : Icons.trending_flat,
                      size: 18,
                      color: up
                          ? AppTheme.emerald
                          : down
                              ? AppTheme.rose
                              : AppTheme.slate500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${avgLast.toStringAsFixed(1)}/5',
                      style: TextStyle(
                          color: up
                              ? AppTheme.emerald
                              : down
                                  ? AppTheme.rose
                                  : AppTheme.slate300,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    if (delta.abs() > 0.1)
                      Text(
                        ' (${delta > 0 ? "+" : ""}${delta.toStringAsFixed(1)})',
                        style: const TextStyle(
                            color: AppTheme.slate500, fontSize: 11),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  double? _avg(List<ReceivedFeedback> items, String key) {
    final vals = items
        .where((f) => f.dimensions.containsKey(key))
        .map((f) => f.dimensions[key]!.toDouble())
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }
}

// ─── Per-dimension line chart ─────────────────────────────────────────────────

class _DimensionChart extends StatelessWidget {
  final FeedbackDimension dim;
  final List<FlSpot> spots;
  final List<ReceivedFeedback> data;
  const _DimensionChart(
      {required this.dim, required this.spots, required this.data});

  @override
  Widget build(BuildContext context) {
    final minY = 1.0;
    final maxY = 5.0;
    final firstDate = data.first.createdAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text(dim.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.slate700,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.slate500),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: _xInterval(spots),
                        getTitlesWidget: (v, _) {
                          final date = firstDate
                              .add(Duration(days: v.toInt()));
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('MMM').format(date),
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.slate500),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: AppTheme.teal,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, _, _, _) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: AppTheme.teal,
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.teal.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
              child: Row(
                children: [
                  Text(dim.lowLabel,
                      style: const TextStyle(
                          color: AppTheme.slate500, fontSize: 10)),
                  const Spacer(),
                  Text(dim.highLabel,
                      style: const TextStyle(
                          color: AppTheme.slate500, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _xInterval(List<FlSpot> s) {
    if (s.isEmpty) return 30;
    final span = s.last.x - s.first.x;
    if (span <= 30) return 7;
    if (span <= 90) return 30;
    return 60;
  }
}
