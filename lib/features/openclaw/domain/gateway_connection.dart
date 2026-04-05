/// Gateway 连接状态
enum GatewayConnState {
  disconnected,
  connecting,
  connected,
  error,
}

/// 本地存储的 Gateway 配置
class GatewayConfig {
  final String host;
  final int port;
  final String token;
  final String nodeId;
  final String displayName;

  const GatewayConfig({
    required this.host,
    required this.port,
    required this.token,
    required this.nodeId,
    required this.displayName,
  });

  String get wsUrl => 'ws://$host:$port';

  GatewayConfig copyWith({
    String? host,
    int? port,
    String? token,
    String? nodeId,
    String? displayName,
  }) {
    return GatewayConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      token: token ?? this.token,
      nodeId: nodeId ?? this.nodeId,
      displayName: displayName ?? this.displayName,
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'token': token,
        'nodeId': nodeId,
        'displayName': displayName,
      };

  factory GatewayConfig.fromJson(Map<String, dynamic> json) => GatewayConfig(
        host: json['host'] as String,
        port: json['port'] as int,
        token: json['token'] as String,
        nodeId: json['nodeId'] as String,
        displayName: json['displayName'] as String,
      );
}
