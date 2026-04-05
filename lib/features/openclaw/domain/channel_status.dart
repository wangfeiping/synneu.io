/// 单个渠道（Telegram、Slack 等）的连接状态
class ChannelStatus {
  final String id;
  final String name;
  final bool connected;
  final String? statusText;
  final String? error;

  const ChannelStatus({
    required this.id,
    required this.name,
    required this.connected,
    this.statusText,
    this.error,
  });

  factory ChannelStatus.fromJson(String id, Map<String, dynamic> json) {
    final status = json['status'] as String? ?? '';
    final connected =
        status == 'connected' || status == 'ok' || status == 'ready';
    return ChannelStatus(
      id: id,
      name: json['name'] as String? ?? id,
      connected: connected,
      statusText: status,
      error: json['error'] as String?,
    );
  }
}

/// Gateway 整体健康状态
class GatewayHealth {
  final bool healthy;
  final String? version;
  final Map<String, dynamic> raw;

  const GatewayHealth({
    required this.healthy,
    this.version,
    required this.raw,
  });

  factory GatewayHealth.fromJson(Map<String, dynamic> json) => GatewayHealth(
        healthy: json['ok'] == true || json['healthy'] == true,
        version: json['version'] as String?,
        raw: json,
      );
}

/// 日志条目
class LogEntry {
  final String level;
  final String message;
  final DateTime time;

  const LogEntry({
    required this.level,
    required this.message,
    required this.time,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        level: (json['level'] as String? ?? 'info').toUpperCase(),
        message: json['msg'] as String? ?? json['message'] as String? ?? '',
        time: json['time'] != null
            ? DateTime.tryParse(json['time'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
