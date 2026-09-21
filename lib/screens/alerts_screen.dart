import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = context.watch<IdsState>();

    final filteredAlerts = state.alerts.where((a) {
      if (_filter != null && a.severity != _filter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesRule = a.ruleOrLabel.toLowerCase().contains(q);
        final matchesSrc = a.sourceIp.toLowerCase().contains(q);
        final matchesDst = a.destinationIp.toLowerCase().contains(q);
        final matchesProto = a.protocol?.toLowerCase().contains(q) ?? false;
        return matchesRule || matchesSrc || matchesDst || matchesProto;
      }
      return true;
    }).toList();

    final criticalCount = state.alerts.where((a) => a.severity == Severity.critical).length;
    final warningCount = state.alerts.where((a) => a.severity == Severity.warning).length;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          'Security Alerts',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Feed',
            onPressed: state.refreshAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search IP, rule, protocol...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      count: state.alerts.length,
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Critical',
                      count: criticalCount,
                      color: severityColor(Severity.critical),
                      selected: _filter == Severity.critical,
                      onTap: () => setState(() => _filter = Severity.critical),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Warning',
                      count: warningCount,
                      color: severityColor(Severity.warning),
                      selected: _filter == Severity.warning,
                      onTap: () => setState(() => _filter = Severity.warning),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: state.refreshAll,
        child: filteredAlerts.isEmpty
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.shield_outlined,
                  size: 54,
                  color: colorScheme.outline.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 14),
                Text(
                  _searchQuery.isNotEmpty ? 'No Matching Alerts' : 'No Alerts Present',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No logged events match "$_searchQuery".'
                      : 'Sensor reports zero active anomalies on monitored interfaces.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: filteredAlerts.length,
          itemBuilder: (context, i) {
            final alert = filteredAlerts[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _showDetail(context, alert),
                  child: AlertTile(alert: alert),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, IdsAlert alert) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sevColor = severityColor(alert.severity);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header with badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sevColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    alert.severity.name.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: sevColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: 'Copy Payload Info',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: '${alert.ruleOrLabel}\n'
                          '${alert.sourceIp}:${alert.sourcePort ?? ''} -> ${alert.destinationIp}:${alert.destinationPort ?? ''}\n'
                          'Proto: ${alert.protocol ?? '-'}\nTime: ${alert.timestamp}',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Alert summary copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              alert.ruleOrLabel,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Network Flow Visualizer Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SOURCE', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                        const SizedBox(height: 2),
                        Text(
                          alert.sourceIp,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (alert.sourcePort != null)
                          Text('Port ${alert.sourcePort}', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: colorScheme.outline, size: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('DESTINATION', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                        const SizedBox(height: 2),
                        Text(
                          alert.destinationIp,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (alert.destinationPort != null)
                          Text('Port ${alert.destinationPort}', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text('Telemetry Metadata', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            _detailRow(context, 'Detection Engine', alert.detectionType),
            _detailRow(context, 'Transport Protocol', alert.protocol ?? 'N/A'),
            if (alert.confidence != null)
              _detailRow(
                context,
                'Model Confidence',
                '${(alert.confidence! * 100).toStringAsFixed(1)}%',
              ),
            _detailRow(context, 'Timestamp', alert.timestamp.toLocal().toString()),

            if (alert.description != null) ...[
              const SizedBox(height: 16),
              Text('Description & Context', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  alert.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = color ?? theme.colorScheme.primary;

    return FilterChip(
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: selected
                  ? activeColor.withValues(alpha: 0.2)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected ? activeColor : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: activeColor.withValues(alpha: 0.12),
      side: BorderSide(
        color: selected ? activeColor : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(
        color: selected ? activeColor : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      ),
    );
  }
}