import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/gateway_connection.dart';
import 'openclaw_provider.dart';

class GatewaySetupPage extends ConsumerStatefulWidget {
  const GatewaySetupPage({super.key});

  @override
  ConsumerState<GatewaySetupPage> createState() => _GatewaySetupPageState();
}

class _GatewaySetupPageState extends ConsumerState<GatewaySetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _hostCtrl = TextEditingController(text: '192.168.1.100');
  final _portCtrl = TextEditingController(text: '18789');
  final _tokenCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(text: 'Synneu');

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _tokenCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(gatewayConfigRepoProvider);
      final nodeId = await repo.getOrCreateNodeId();
      final config = GatewayConfig(
        host: _hostCtrl.text.trim(),
        port: int.parse(_portCtrl.text.trim()),
        token: _tokenCtrl.text.trim(),
        nodeId: nodeId,
        displayName: _nameCtrl.text.trim().isNotEmpty
            ? _nameCtrl.text.trim()
            : 'Synneu',
      );

      // 先尝试连接验证
      final svc = ref.read(gatewayWsServiceProvider);
      await svc.connect(config);

      // 等待连接结果（最多 10s）
      for (var i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (svc.state == GatewayConnState.connected) break;
        if (svc.state == GatewayConnState.error) {
          throw Exception(svc.errorMessage ?? '连接失败');
        }
      }
      if (svc.state != GatewayConnState.connected) {
        throw Exception('连接超时，请检查地址和 Token');
      }

      // 保存配置
      await ref.read(savedGatewayConfigProvider.notifier).save(config);

      // 注册节点（非阻塞，失败不影响使用）
      try {
        await ref.read(gatewayRepositoryProvider).nodePairRequest(
              nodeId: nodeId,
              displayName: config.displayName,
              platform: Platform.isIOS ? 'ios' : 'android',
            );
      } catch (_) {}

      if (mounted) context.go('/openclaw');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('连接 OpenClaw Gateway'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.smart_toy_outlined, size: 64, color: Colors.blueGrey),
              const SizedBox(height: 16),
              Text(
                '配置 Gateway 连接',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '在 OpenClaw Gateway Web UI → Settings → Tokens 中创建 Token，粘贴到下方。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _hostCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Gateway 地址',
                        hintText: '192.168.1.100',
                      ),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? '请输入地址' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _portCtrl,
                      decoration: const InputDecoration(labelText: '端口'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final port = int.tryParse(v?.trim() ?? '');
                        if (port == null || port < 1 || port > 65535) {
                          return '无效';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tokenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Token',
                  hintText: '粘贴 Gateway Token',
                ),
                obscureText: true,
                validator: (v) =>
                    v?.trim().isEmpty == true ? '请输入 Token' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '设备名称',
                  hintText: 'Synneu',
                ),
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _saving ? null : _connect,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: Text(_saving ? '连接中…' : '连接'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
