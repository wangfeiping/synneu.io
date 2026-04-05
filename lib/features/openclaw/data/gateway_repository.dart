import '../domain/channel_status.dart';
import '../domain/chat_session.dart';
import 'gateway_ws_service.dart';

/// 封装 Gateway 各业务 API 方法。
/// 所有方法在失败时抛出 Exception，由 UI 层捕获。
class GatewayRepository {
  final GatewayWsService _ws;
  GatewayRepository(this._ws);

  // ── 会话（Sessions）────────────────────────────────────────────────

  Future<List<ChatSession>> listSessions({int limit = 50}) async {
    final result = await _ws.request('sessions.list', {
      'limit': limit,
      'includeDerivedTitles': true,
      'includeLastMessage': true,
    });
    final items = result['sessions'] as List<dynamic>? ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ChatSession.fromJson)
        .toList();
  }

  Future<ChatSession> createSession({String? agentId, String? task}) async {
    final params = <String, dynamic>{};
    if (agentId != null) params['agentId'] = agentId;
    if (task != null) params['task'] = task;
    final result = await _ws.request('sessions.create', params);
    return ChatSession.fromJson(result);
  }

  Future<void> sendMessage(String sessionKey, String message,
      {String? thinking}) async {
    final params = <String, dynamic>{
      'key': sessionKey,
      'message': message,
    };
    if (thinking != null) params['thinking'] = thinking;
    await _ws.request('sessions.send', params);
  }

  Future<void> subscribeSession(String sessionKey) async {
    await _ws.request('sessions.messages.subscribe', {'key': sessionKey});
  }

  Future<void> unsubscribeSession(String sessionKey) async {
    await _ws.request('sessions.messages.unsubscribe', {'key': sessionKey});
  }

  Future<void> abortSession(String sessionKey) async {
    await _ws.request('sessions.abort', {'key': sessionKey});
  }

  Future<void> resetSession(String sessionKey) async {
    await _ws.request('sessions.reset', {'key': sessionKey});
  }

  Future<void> deleteSession(String sessionKey) async {
    await _ws.request('sessions.delete', {'key': sessionKey});
  }

  Future<List<Map<String, dynamic>>> getChatHistory(
      String sessionKey, int limit) async {
    final result = await _ws.request('chat.history', {
      'sessionKey': sessionKey,
      'limit': limit,
    });
    return (result['messages'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
  }

  // ── AI Agent ───────────────────────────────────────────────────────

  Future<String> runAgent({
    required String message,
    String? agentId,
    String? model,
    String? thinking,
    String? sessionKey,
  }) async {
    final params = <String, dynamic>{'message': message};
    if (agentId != null) params['agentId'] = agentId;
    if (model != null) params['model'] = model;
    if (thinking != null) params['thinking'] = thinking;
    if (sessionKey != null) params['sessionKey'] = sessionKey;
    final result = await _ws.request('agent', params);
    return result['runId'] as String? ??
        result['id'] as String? ??
        'unknown';
  }

  Future<Map<String, dynamic>> waitAgent(String runId,
      {int timeoutMs = 120000}) async {
    return _ws.request('agent.wait', {
      'runId': runId,
      'timeoutMs': timeoutMs,
    });
  }

  Future<List<Map<String, dynamic>>> listAgents() async {
    final result = await _ws.request('agents.list', {});
    return (result['agents'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
  }

  Future<List<Map<String, dynamic>>> listModels() async {
    final result = await _ws.request('models.list', {});
    return (result['models'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
  }

  // ── 状态监控 ───────────────────────────────────────────────────────

  Future<GatewayHealth> getHealth() async {
    final result = await _ws.request('health', {});
    return GatewayHealth.fromJson(result);
  }

  Future<List<ChannelStatus>> getChannelsStatus() async {
    final result = await _ws.request('channels.status', {});
    final channels = result['channels'] as Map<String, dynamic>? ?? {};
    return channels.entries
        .map((e) => ChannelStatus.fromJson(
            e.key, e.value as Map<String, dynamic>? ?? {}))
        .toList();
  }

  // ── 配置管理 ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getConfig() async {
    return _ws.request('config.get', {});
  }

  Future<void> patchConfig(String raw, {String? baseHash}) async {
    final params = <String, dynamic>{'raw': raw};
    if (baseHash != null) params['baseHash'] = baseHash;
    await _ws.request('config.patch', params);
  }

  Future<Map<String, dynamic>> getConfigSchema() async {
    return _ws.request('config.schema', {});
  }

  // ── 节点配对 ───────────────────────────────────────────────────────

  Future<void> nodePairRequest({
    required String nodeId,
    required String displayName,
    required String platform,
    List<String> caps = const ['chat', 'agent'],
  }) async {
    await _ws.request('node.pair.request', {
      'nodeId': nodeId,
      'displayName': displayName,
      'platform': platform,
      'caps': caps,
    });
  }

  Future<void> nodePendingAck(List<String> ids) async {
    await _ws.request('node.pending.ack', {'ids': ids});
  }

  Future<void> nodeInvokeResult({
    required String id,
    required String nodeId,
    required Map<String, dynamic> result,
  }) async {
    await _ws.request('node.invoke.result', {
      'id': id,
      'nodeId': nodeId,
      'result': result,
    });
  }
}
