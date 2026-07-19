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
    final state = context.watch<IdsState>();
    final stats = state.stats;
    final recent = state.alerts.take(6).toList();

    final critical = (stats['critical'] ?? 0) as int;
    final warning = (stats['warning'] ?? 0) as int;
    final total = (stats['total_alerts'] ?? 0) as int;
    final info = (total - critical - warning).clamp(0, total);

    return RefreshIndicator(
      onRefresh: state.refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Overview', style: Theme.of(context).textTheme.titleLarge),
              _MonitorToggle(state: state),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              StatCard(
                label: 'Total Alerts',
                value: '$total',
                color: Colors.indigo,
                icon: Icons.list_alt,
              ),
              StatCard(
                label: 'Critical',
                value: '$critical',
                color: severityColor(Severity.critical),
                icon: Icons.gpp_bad,
              ),
              StatCard(
                label: 'Warning',
                value: '$warning',
                color: severityColor(Severity.warning),
                icon: Icons.warning_amber_rounded,
              ),
              StatCard(
                label: 'Model',
                value: (stats['ml_model_loaded'] == true) ? 'Loaded' : 'Missing',
                color: (stats['ml_model_loaded'] == true) ? Colors.teal : Colors.grey,
                icon: Icons.psychology_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (total > 0) ...[
            Text('Severity Breakdown', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    if (critical > 0)
                      PieChartSectionData(
                        value: critical.toDouble(),
                        color: severityColor(Severity.critical),
                        title: '$critical',
                        radius: 55,
                      ),
                    if (warning > 0)
                      PieChartSectionData(
                        value: warning.toDouble(),
                        color: severityColor(Severity.warning),
                        title: '$warning',
                        radius: 55,
                      ),
                    if (info > 0)
                      PieChartSectionData(
                        value: info.toDouble(),
                        color: severityColor(Severity.info),
                        title: '$info',
                        radius: 55,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text('Recent Alerts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No alerts yet. Start monitoring to see live traffic.')),
            )
          else
            Card(
              child: Column(
                children: recent.map((a) => AlertTile(alert: a)).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonitorToggle extends StatelessWidget {
  final IdsState state;
  const _MonitorToggle({required this.state});

  @override
  Widget build(BuildContext context) {
    final active = state.monitoringActive;
    return FilledButton.icon(
      onPressed: () => state.toggleMonitoring(),
      icon: Icon(active ? Icons.stop_circle_outlined : Icons.play_circle_outline),
      label: Text(active ? 'Stop' : 'Start'),
      style: FilledButton.styleFrom(
        backgroundColor: active ? Colors.red : Colors.green,
      ),
    );
  }
}
