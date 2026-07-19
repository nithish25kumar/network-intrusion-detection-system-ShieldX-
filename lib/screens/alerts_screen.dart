import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alert.dart';
import '../services/ids_state.dart';
import '../widgets/alert_tile.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Severity? _filter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<IdsState>();
    final alerts = _filter == null
        ? state.alerts
        : state.alerts.where((a) => a.severity == _filter).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _FilterChip(label: 'All', selected: _filter == null, onTap: () => setState(() => _filter = null)),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Critical',
                color: severityColor(Severity.critical),
                selected: _filter == Severity.critical,
                onTap: () => setState(() => _filter = Severity.critical),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Warning',
                color: severityColor(Severity.warning),
                selected: _filter == Severity.warning,
                onTap: () => setState(() => _filter = Severity.warning),
              ),
            ],
          ),
        ),
        Expanded(
          child: alerts.isEmpty
              ? const Center(child: Text('No alerts to show'))
              : RefreshIndicator(
                  onRefresh: state.refreshAll,
                  child: ListView.separated(
                    itemCount: alerts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => AlertTile(
                      alert: alerts[i],
                      onTap: () => _showDetail(context, alerts[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, IdsAlert alert) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.ruleOrLabel, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _row('Detection type', alert.detectionType),
            _row('Source', '${alert.sourceIp}${alert.sourcePort != null ? ':${alert.sourcePort}' : ''}'),
            _row('Destination',
                '${alert.destinationIp}${alert.destinationPort != null ? ':${alert.destinationPort}' : ''}'),
            _row('Protocol', alert.protocol ?? '-'),
            if (alert.confidence != null)
              _row('Confidence', '${(alert.confidence! * 100).toStringAsFixed(1)}%'),
            _row('Time', alert.timestamp.toLocal().toString()),
            if (alert.description != null) ...[
              const SizedBox(height: 8),
              Text(alert.description!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: (color ?? Theme.of(context).primaryColor).withOpacity(0.2),
    );
  }
}
