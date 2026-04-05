import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/gateway_connection.dart';
import 'openclaw_provider.dart';
import 'chat/chat_list_page.dart';
import 'agent/agent_page.dart';
import 'monitor/monitor_page.dart';
import 'config/config_page.dart';

class OpenClawHomePage extends ConsumerStatefulWidget {
  final int initialTab;
  const OpenClawHomePage({super.key, this.initialTab = 0});

  @override
  ConsumerState<OpenClawHomePage> createState() => _OpenClawHomePageState();
}

class _OpenClawHomePageState extends ConsumerState<OpenClawHomePage> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(
      gatewayWsServiceProvider.select((s) => s.state),
    );
    final configAsync = ref.watch(savedGatewayConfigProvider);

    // 未配置时跳转到设置页
    if (configAsync is AsyncData && configAsync.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/openclaw/setup');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      const ChatListPage(),
      const AgentPage(),
      const MonitorPage(),
      const ConfigPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenClaw AI'),
        actions: [
          _ConnectionIndicator(state: connState),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              if (action == 'setup') context.push('/openclaw/setup');
              if (action == 'disconnect') {
                ref.read(savedGatewayConfigProvider.notifier).clear();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'setup', child: Text('重新配置')),
              PopupMenuItem(value: 'disconnect', child: Text('断开连接')),
            ],
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '会话',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: '任务',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: '监控',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '配置',
          ),
        ],
      ),
    );
  }
}

class _ConnectionIndicator extends StatelessWidget {
  final GatewayConnState state;
  const _ConnectionIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, icon, tooltip) = switch (state) {
      GatewayConnState.connected => (Colors.green, Icons.circle, '已连接'),
      GatewayConnState.connecting => (Colors.orange, Icons.circle, '连接中…'),
      GatewayConnState.error => (Colors.red, Icons.error_outline, '连接错误'),
      GatewayConnState.disconnected => (Colors.grey, Icons.circle_outlined, '未连接'),
    };
    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color, size: 14),
    );
  }
}
