import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/channel_status.dart';
import '../openclaw_provider.dart';

class MonitorPage extends ConsumerStatefulWidget {
  const MonitorPage({super.key});

  @override
  ConsumerState<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends ConsumerState<MonitorPage> {
  GatewayHealth? _health;
  List<ChannelStatus> _channels = [];
  final List<String> _logs = [];
  bool _loadingHealth = false;
  bool _loadingChannels = false;
  String? _healthError;
  String? _channelError;
  Timer? _healthTimer;
  StreamSubscription? _logSub;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refreshHealth();
    });
    _subscribeLogs();
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _logSub?.cancel();
    super.dispose();
  }

  void _subscribeLogs() {
    final ws = ref.read(gatewayWsServiceProvider);
    _logSub = ws.events.listen((e) {
      if (e.event == 'log' || e.event == 'log.entry') {
        final entry = LogEntry.fromJson(e.payload);
        if (mounted) {
          setState(() {
            _logs.insert(0, '[${entry.level}] ${entry.message}');
            if (_logs.length > 200) _logs.removeLast();
          });
        }
      }
    });
    // 请求日志订阅（非关键，失败不影响其他功能）
    ws.request('logs.tail', {}).ignore();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_refreshHealth(), _refreshChannels()]);
  }

  Future<void> _refreshHealth() async {
    setState(() {
      _loadingHealth = true;
      _healthError = null;
    });
    try {
      final h = await ref.read(gatewayRepositoryProvider).getHealth();
      if (mounted) setState(() => _health = h);
    } catch (e) {
      if (mounted) setState(() => _healthError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingHealth = false);
    }
  }

  Future<void> _refreshChannels() async {
    setState(() {
      _loadingChannels = true;
      _channelError = null;
    });
    try {
      final ch = await ref.read(gatewayRepositoryProvider).getChannelsStatus();
      if (mounted) setState(() => _channels = ch);
    } catch (e) {
      if (mounted) setState(() => _channelError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingChannels = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HealthSection(
            health: _health,
            loading: _loadingHealth,
            error: _healthError,
            onRefresh: _refreshHealth,
          ),
          const SizedBox(height: 16),
          _ChannelsSection(
            channels: _channels,
            loading: _loadingChannels,
            error: _channelError,
            onRefresh: _refreshChannels,
          ),
          const SizedBox(height: 16),
          _LogsSection(logs: _logs),
        ],
      ),
    );
  }
}

class _HealthSection extends StatelessWidget {
  final GatewayHealth? health;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  const _HealthSection({
    required this.health,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart_outlined),
                const SizedBox(width: 8),
                const Text('Gateway 健康状态',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (loading)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints()),
              ],
            ),
            const Divider(height: 16),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red))
            else if (health == null)
              const Text('加载中…', style: TextStyle(color: Colors.grey))
            else
              Row(
                children: [
                  Icon(
                    health!.healthy ? Icons.check_circle : Icons.error,
                    color: health!.healthy ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    health!.healthy ? '正常运行' : '异常',
                    style: TextStyle(
                        color: health!.healthy ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold),
                  ),
                  if (health!.version != null) ...[
                    const Spacer(),
                    Text(
                      'v${health!.version}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ChannelsSection extends StatelessWidget {
  final List<ChannelStatus> channels;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  const _ChannelsSection({
    required this.channels,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_outlined),
                const SizedBox(width: 8),
                const Text('渠道状态',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (loading)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints()),
              ],
            ),
            const Divider(height: 16),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red))
            else if (channels.isEmpty)
              const Text('暂无渠道数据', style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: channels.map((ch) {
                  return Chip(
                    avatar: Icon(
                      ch.connected ? Icons.circle : Icons.circle_outlined,
                      color: ch.connected ? Colors.green : Colors.grey,
                      size: 14,
                    ),
                    label: Text(ch.name, style: const TextStyle(fontSize: 12)),
                    backgroundColor: ch.connected
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogsSection extends StatelessWidget {
  final List<String> logs;
  const _LogsSection({required this.logs});

  Color _levelColor(String log) {
    if (log.contains('[ERROR]')) return Colors.red;
    if (log.contains('[WARN]')) return Colors.orange;
    if (log.contains('[DEBUG]')) return Colors.blue;
    return Colors.grey.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.terminal_outlined),
                SizedBox(width: 8),
                Text('实时日志', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 16),
            if (logs.isEmpty)
              const Text('等待日志…', style: TextStyle(color: Colors.grey))
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  shrinkWrap: true,
                  reverse: true,
                  itemCount: logs.length,
                  itemBuilder: (_, i) => Text(
                    logs[i],
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: _levelColor(logs[i]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
