import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/alert.dart';

Color severityColor(Severity s) {
  switch (s) {
    case Severity.critical:
      return const Color(0xFFE53935);
    case Severity.warning:
      return const Color(0xFFFB8C00);
    case Severity.info:
      return const Color(0xFF43A047);
  }
}

IconData severityIcon(Severity s) {
  switch (s) {
    case Severity.critical:
      return Icons.gpp_bad;
    case Severity.warning:
      return Icons.warning_amber_rounded;
    case Severity.info:
      return Icons.check_circle_outline;
  }
}

class AlertTile extends StatelessWidget {
  final IdsAlert alert;
  final VoidCallback? onTap;

  const AlertTile({super.key, required this.alert, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = severityColor(alert.severity);
    final timeStr = DateFormat('HH:mm:ss').format(alert.timestamp.toLocal());

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(severityIcon(alert.severity), color: color, size: 20),
      ),
      title: Text(
        alert.ruleOrLabel,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${alert.sourceIp}${alert.sourcePort != null ? ':${alert.sourcePort}' : ''}  →  '
        '${alert.destinationIp}${alert.destinationPort != null ? ':${alert.destinationPort}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timeStr, style: Theme.of(context).textTheme.bodySmall),
          if (alert.confidence != null)
            Text(
              '${(alert.confidence! * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
