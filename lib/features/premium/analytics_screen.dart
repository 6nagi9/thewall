import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';

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
        appBar: AppBar(title: const Text('Trends')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'Trends is a Premium feature',
          message:
              'Upgrade to Premium to see how your reputation evolves over time.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: feedbackAsync.when(
        loading: () => const WallLoader(),
        error: (e, _) => Center(
            child: Text('$e', style: AppTheme.body(color: AppTheme.rose))),
        data: (feedback) {
          if (feedback.length < 3) {
            return const EmptyState(
              icon: Icons.show_chart_rounded,
              title: 'Not enough bricks yet',
              message:
                  'You need at least 3 pieces of feedback before trends are meaningful.',
            );
          }
          final sorted =
              [...feedback]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          var i = 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _SummaryCard(feedback: sorted).entrance(++i),
              const SizedBox(height: 20),
              ...FeedbackDimension.all.map((d) {
                final spots = _spotsFor(sorted, d.key);
                if (spots.length < 2) return const SizedBox.shrink();
                i++;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _DimensionChart(dim: d, spots: spots, data: sorted)
                      .entrance(i),
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
        .map((f) {
          final daysSince =
              (f.createdAt.millisecondsSinceEpoch - t0) / 86400000;
          return FlSpot(daysSince, f.dimensions[key]!.toDouble());
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

    return WallCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: AppTheme.clay, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${feedback.length} reviews over $span days',
                  style: AppTheme.display(size: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat("d MMM yy").format(first)} → '
            '${DateFormat("d MMM yy").format(last)}',
            style: AppTheme.body(size: 12, color: AppTheme.ink400),
          ),
          const SizedBox(height: 14),
          ...FeedbackDimension.all.map((d) {
            final avgFirst = _avg(firstHalf, d.key);
            final avgLast = _avg(secondHalf, d.key);
            if (avgFirst == null || avgLast == null) {
              return const SizedBox.shrink();
            }
            final delta = avgLast - avgFirst;
            final up = delta > 0.1;
            final down = delta < -0.1;
            final c = up
                ? AppTheme.sage
                : down
                    ? AppTheme.rose
                    : AppTheme.ink300;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                      width: 116,
                      child: Text(d.label,
                          style: AppTheme.body(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: AppTheme.ink200))),
                  Icon(
                    up
                        ? Icons.trending_up
                        : down
                            ? Icons.trending_down
                            : Icons.trending_flat,
                    size: 18,
                    color: c,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${avgLast.toStringAsFixed(1)}/5',
                    style: AppTheme.body(
                        size: 13.5, weight: FontWeight.w700, color: c),
                  ),
                  if (delta.abs() > 0.1)
                    Text(
                      '  ${delta > 0 ? "+" : ""}${delta.toStringAsFixed(1)}',
                      style: AppTheme.body(
                          size: 11.5, color: AppTheme.ink400),
                    ),
                ],
              ),
            );
          }),
        ],
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
    const minY = 1.0;
    const maxY = 5.0;
    final firstDate = data.first.createdAt;

    return WallCard(
      padding: const EdgeInsets.fromLTRB(10, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 14),
            child: Text(dim.label, style: AppTheme.display(size: 16)),
          ),
          SizedBox(
            height: 160,
            child: LineChart(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              LineChartData(
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppTheme.ink700,
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
                        style: AppTheme.body(
                            size: 10, color: AppTheme.ink400),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: _xInterval(spots),
                      getTitlesWidget: (v, _) {
                        final date =
                            firstDate.add(Duration(days: v.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('MMM').format(date),
                            style: AppTheme.body(
                                size: 10, color: AppTheme.ink400),
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
                    gradient: const LinearGradient(
                      colors: [AppTheme.clayDeep, AppTheme.clayBright],
                    ),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 3.5,
                        color: AppTheme.clayBright,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.clay.withValues(alpha: 0.16),
                          AppTheme.clay.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 6, bottom: 4),
            child: Row(
              children: [
                Text(dim.lowLabel,
                    style: AppTheme.body(
                        size: 10, color: AppTheme.ink400)),
                const Spacer(),
                Text(dim.highLabel,
                    style: AppTheme.body(
                        size: 10, color: AppTheme.ink400)),
              ],
            ),
          ),
        ],
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
