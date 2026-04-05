import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../domain/gateway_connection.dart';

/// 服务端推送的事件
class GatewayEvent {
  final String event;
  final Map<String, dynamic> payload;
  const GatewayEvent({required this.event, required this.payload});
}

/// WebSocket 连接到 OpenClaw Gateway 的核心服务。
///
/// 帧格式：
///   请求  {"id":"uuid","method":"sessions.list","params":{}}
///   响应  {"id":"uuid","ok":true,"result":{...}}
///   事件  {"event":"chat.delta","payload":{...}}
class GatewayWsService extends ChangeNotifier {
  GatewayConnState _state = GatewayConnState.disconnected;
  String? _errorMessage;
  GatewayConfig? _config;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  int _reconnectDelay = 2;

  final _eventController = StreamController<GatewayEvent>.broadcast();
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  final _uuid = const Uuid();

  GatewayConnState get state => _state;
  String? get errorMessage => _errorMessage;
  GatewayConfig? get config => _config;
  bool get isConnected => _state == GatewayConnState.connected;
  Stream<GatewayEvent> get events => _eventController.stream;

  // ── Public API ────────────────────────────────────────────────────

  Future<void> connect(GatewayConfig config) async {
    _reconnectTimer?.cancel();
    await _disconnect(notify: false);
    _config = config;
    await _doConnect();
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _config = null;
    _disconnect(notify: true);
  }

  /// 发送一个请求帧，返回响应的 payload 字段。
  /// 失败时抛出包含 error message 的 Exception。
  Future<Map<String, dynamic>> request(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    if (_channel == null || _state != GatewayConnState.connected) {
      throw Exception('Gateway 未连接');
    }
    final id = _uuid.v4();
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    // 实际帧格式：{"type":"req","id":"...","method":"...","params":{...}}
    final frame = jsonEncode({
      'type': 'req',
      'id': id,
      'method': method,
      'params': params ?? {},
    });
    try {
      _channel!.sink.add(frame);
    } catch (e) {
      _pending.remove(id);
      rethrow;
    }

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('请求超时：$method');
      },
    );
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _disconnect(notify: false);
    _eventController.close();
    super.dispose();
  }

  // ── Internal ──────────────────────────────────────────────────────

  Future<void> _doConnect() async {
    final cfg = _config;
    if (cfg == null) return;
    _setState(GatewayConnState.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(cfg.wsUrl));
      // 等待握手完成（web_socket_channel 3.x）
      await _channel!.ready;
    } catch (e) {
      dev.log('WebSocket 连接失败: $e', name: 'GatewayWsService', level: 1000);
      _channel = null;
      _setState(GatewayConnState.error, error: '连接失败：$e');
      _scheduleReconnect();
      return;
    }

    _sub = _channel!.stream.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
    );

    // 发送 connect 帧（首帧，格式来自 ConnectParamsSchema）
    // 先将 _state 临时设为 connected 以允许 request() 通过校验
    _state = GatewayConnState.connected;
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final connectResult = await request('connect', {
        'minProtocol': 1,
        'maxProtocol': 1,
        'client': {
          'id': Platform.isIOS ? 'openclaw-ios' : 'openclaw-android',
          'displayName': cfg.displayName,
          'version': '1.0.0',
          'platform': platform,
          'mode': 'node',
        },
        'auth': {
          'token': cfg.token,
        },
        'caps': ['tool-events'],
      });
      final serverVersion =
          (connectResult['server'] as Map<String, dynamic>?)?['version'] ?? '';
      dev.log(
        'Gateway 连接成功：v$serverVersion',
        name: 'GatewayWsService',
      );
      _reconnectDelay = 2;
      // 保留 connected 状态（_state 已在上面设置）
      notifyListeners();
    } catch (e) {
      dev.log('connect 帧失败: $e', name: 'GatewayWsService', level: 1000);
      await _disconnect(notify: false);
      _setState(GatewayConnState.error, error: '认证失败：$e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> frame;
    try {
      frame = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = frame['type'] as String?;

    // 响应帧 type=res（含 id）
    if (type == 'res' || frame['id'] != null) {
      final id = frame['id'] as String?;
      if (id != null) {
        final completer = _pending.remove(id);
        if (completer != null) {
          if (frame['ok'] == true) {
            // 响应字段名为 payload（不是 result）
            completer.complete(
                (frame['payload'] as Map<String, dynamic>?) ?? {});
          } else {
            final err = frame['error'] as Map<String, dynamic>?;
            completer.completeError(
              Exception(err?['message'] ?? err?['code'] ?? '未知错误'),
            );
          }
        }
      }
      return;
    }

    // 事件帧 type=event（含 event 字段）
    final eventName = frame['event'] as String?;
    if (type == 'event' || eventName != null) {
      _eventController.add(GatewayEvent(
        event: eventName ?? '',
        payload: (frame['payload'] as Map<String, dynamic>?) ?? {},
      ));
    }
  }

  void _onError(Object error) {
    dev.log('WebSocket 错误: $error', name: 'GatewayWsService', level: 1000);
    _failPending('连接中断');
    _setState(GatewayConnState.error, error: '连接错误：$error');
    _scheduleReconnect();
  }

  void _onDone() {
    dev.log('WebSocket 已关闭', name: 'GatewayWsService');
    _failPending('连接已关闭');
    if (_config != null && _state == GatewayConnState.connected) {
      _setState(GatewayConnState.disconnected);
      _scheduleReconnect();
    }
  }

  Future<void> _disconnect({required bool notify}) async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _failPending('已断开连接');
    if (notify) _setState(GatewayConnState.disconnected);
  }

  void _failPending(String reason) {
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(Exception(reason));
    }
    _pending.clear();
  }

  void _scheduleReconnect() {
    if (_config == null || _reconnectTimer != null) return;
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      _reconnectTimer = null;
      _reconnectDelay = (_reconnectDelay * 2).clamp(2, 30);
      _doConnect();
    });
  }

  void _setState(GatewayConnState s, {String? error}) {
    _state = s;
    _errorMessage = error;
    notifyListeners();
  }
}
