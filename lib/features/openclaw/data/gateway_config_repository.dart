import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../domain/gateway_connection.dart';

/// 持久化 Gateway 配置（host/port/token/nodeId）到 shared_preferences。
/// 生产环境应使用 flutter_secure_storage 保护 token。
class GatewayConfigRepository {
  static const _key = 'openclaw_gateway_config';

  Future<GatewayConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return GatewayConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(GatewayConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// 生成一个稳定的 nodeId（首次调用后固定）。
  Future<String> getOrCreateNodeId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('openclaw_node_id');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('openclaw_node_id', id);
    }
    return id;
  }
}
