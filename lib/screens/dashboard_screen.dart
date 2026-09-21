import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/ids_state.dart';
import '../widgets/stat_card.dart';
import '../widgets/alert_tile.dart';
import '../models/alert.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = context.watch<IdsState>();
    final stats = state.stats;
    final recent = state.alerts.take(6).toList();

    final critical = (stats['critical'] ?? 0) as int;
    final warning = (stats['warning'] ?? 0) as int;
    final total = (stats['total_alerts'] ?? 0) as int;
    final info = (total - critical - warning).clamp(0, total);
    final isModelLoaded = stats['ml_model_loaded'] == true;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: RefreshIndicator(
        onRefresh: state.refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Top App Bar / Header
            SliverAppBar(
              floating: true,
              pinned: true,
              elevation: 0,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Network Security',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.monitoringActive ? Colors.green: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state.monitoringActive ? 'Live Traffic Monitored' : 'Monitoring Paused',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _MonitorToggle(state: state),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Stats Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 600;
                      return GridView.count(
                        crossAxisCount: isWide ? 4 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isWide ? 1.6 : 1.35,
                        children: [
                          StatCard(
                            label: 'Total Events',
                            value: '$total',
                            color: colorScheme.primary,
                            icon: Icons.shield_outlined,
                          ),
                          StatCard(
                            label: 'Critical Threats',
                            value: '$critical',
                            color: severityColor(Severity.critical),
                            icon: Icons.error_outline_rounded,
                          ),
                          StatCard(
                            label: 'Suspicious',
                            value: '$warning',
                            color: severityColor(Severity.warning),
                            icon: Icons.warning_amber_rounded,
                          ),
                          StatCard(
                            label: 'Inference Engine',
                            value: isModelLoaded ? 'Active' : 'Offline',
                            color: isModelLoaded ? Colors.teal : Colors.blueGrey,
                            icon: Icons.hub_outlined,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Threat Severity Breakdown
                  if (total > 0) ...[
                    Text(
                      'Threat Distribution',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      color: colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Chart with total count in the donut hole
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      sectionsSpace: 3,
                                      centerSpaceRadius: 46,
                                      sections: [
                                        if (critical > 0)
                                          PieChartSectionData(
                                            value: critical.toDouble(),
                                            color: severityColor(Severity.critical),
                                            showTitle: false,
                                            radius: 16,
                                          ),
                                        if (warning > 0)
                                          PieChartSectionData(
                                            value: warning.toDouble(),
                                            color: severityColor(Severity.warning),
                                            showTitle: false,
                                            radius: 16,
                                          ),
                                        if (info > 0)
                                          PieChartSectionData(
                                            value: info.toDouble(),
                                            color: severityColor(Severity.info),
                                            showTitle: false,
                                            radius: 16,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$total',
                                        style: theme.textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'TOTAL',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colorScheme.outline,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Detailed Legend
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _LegendRow(
                                    label: 'Critical',
                                    count: critical,
                                    total: total,
                                    color: severityColor(Severity.critical),
                                  ),
                                  const SizedBox(height: 8),
                                  _LegendRow(
                                    label: 'Warning',
                                    count: warning,
                                    total: total,
                                    color: severityColor(Severity.warning),
                                  ),
                                  const SizedBox(height: 8),
                                  _LegendRow(
                                    label: 'Informational',
                                    count: info,
                                    total: total,
                                    color: severityColor(Severity.info),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Recent Activity Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Detections',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (recent.isNotEmpty)
                        Text(
                          'Last ${recent.length} events',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Recent Alerts List / Empty State
                  if (recent.isEmpty)
                    Card(
                      elevation: 0,
                      color: colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 48,
                              color: colorScheme.outline.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Threats Detected',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Network traffic is quiet. Turn on monitoring to capture live packets.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 0,
                      color: colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recent.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                        itemBuilder: (context, index) => AlertTile(alert: recent[index]),
                      ),
                    ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _LegendRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '$count',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 36,
          child: Text(
            '$percentage%',
            textAlign: TextAlign.end,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}

class _MonitorToggle extends StatelessWidget {
  final IdsState state;
  const _MonitorToggle({required this.state});

  @override
  Widget build(BuildContext context) {
    final active = state.monitoringActive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: FilledButton.tonalIcon(
        onPressed: () => state.toggleMonitoring(),
        icon: Icon(
          active ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
          size: 18,
          color: active ? Colors.red : Colors.green,
        ),
        label: Text(
          active ? 'Stop Sensor' : 'Start Sensor',
          style: TextStyle(
            color: active ? Colors.red.shade700 : Colors.green.shade800,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: active
              ? Colors.red.withValues(alpha: 0.1)
              : Colors.green.withValues(alpha: 0.1),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}