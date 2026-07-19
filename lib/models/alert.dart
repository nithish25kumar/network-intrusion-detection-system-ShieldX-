enum Severity { info, warning, critical }

Severity severityFromString(String s) {
  switch (s.toLowerCase()) {
    case 'critical':
      return Severity.critical;
    case 'warning':
      return Severity.warning;
    default:
      return Severity.info;
  }
}

class IdsAlert {
  final int? id;
  final DateTime timestamp;
  final String sourceIp;
  final String destinationIp;
  final int? sourcePort;
  final int? destinationPort;
  final String? protocol;
  final String detectionType; // "signature" | "anomaly"
  final String ruleOrLabel;
  final Severity severity;
  final double? confidence;
  final String? description;

  IdsAlert({
    this.id,
    required this.timestamp,
    required this.sourceIp,
    required this.destinationIp,
    this.sourcePort,
    this.destinationPort,
    this.protocol,
    required this.detectionType,
    required this.ruleOrLabel,
    required this.severity,
    this.confidence,
    this.description,
  });

  factory IdsAlert.fromJson(Map<String, dynamic> json) {
    return IdsAlert(
      id: json['id'] is int ? json['id'] as int : null,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      sourceIp: json['source_ip']?.toString() ?? 'unknown',
      destinationIp: json['destination_ip']?.toString() ?? 'unknown',
      sourcePort: json['source_port'] is int ? json['source_port'] as int : null,
      destinationPort: json['destination_port'] is int ? json['destination_port'] as int : null,
      protocol: json['protocol']?.toString(),
      detectionType: json['detection_type']?.toString() ?? 'unknown',
      ruleOrLabel: json['rule_or_label']?.toString() ?? 'Unknown',
      severity: severityFromString(json['severity']?.toString() ?? 'info'),
      confidence: (json['confidence'] is num) ? (json['confidence'] as num).toDouble() : null,
      description: json['description']?.toString(),
    );
  }
}
