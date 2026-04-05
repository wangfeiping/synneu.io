import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../openclaw_provider.dart';

class ConfigPage extends ConsumerStatefulWidget {
  const ConfigPage({super.key});

  @override
  ConsumerState<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends ConsumerState<ConfigPage> {
  Map<String, dynamic>? _configData;
  bool _loading = false;
  bool _editing = false;
  bool _saving = false;
  String? _error;
  String? _baseHash;
  late TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController();
    _loadConfig();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(gatewayRepositoryProvider).getConfig();
      if (mounted) {
        setState(() {
          _configData = result;
          _baseHash = result['hash'] as String?;
          final raw = result['raw'] as String? ??
              result['config'] as String? ??
              _formatJson(result);
          _editCtrl.text = raw;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    final raw = _editCtrl.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(gatewayRepositoryProvider).patchConfig(
            raw,
            baseHash: _baseHash,
          );
      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已保存')),
        );
        await _loadConfig();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
      }
    }
  }

  String _formatJson(Map<String, dynamic> data) {
    final sb = StringBuffer();
    data.forEach((k, v) => sb.writeln('$k: $v'));
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _configData == null
              ? _ErrorView(
                  error: _error!,
                  onRetry: _loadConfig,
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 工具栏
                            Row(
                              children: [
                                const Icon(Icons.tune_outlined),
                                const SizedBox(width: 8),
                                const Text('Gateway 配置',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Spacer(),
                                if (!_editing) ...[
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: _loadConfig,
                                    tooltip: '刷新',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(
                                          text: _editCtrl.text));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text('已复制'),
                                        duration: Duration(seconds: 1),
                                      ));
                                    },
                                    tooltip: '复制',
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () =>
                                        setState(() => _editing = true),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('编辑'),
                                  ),
                                ] else ...[
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _editing = false;
                                      _error = null;
                                    }),
                                    child: const Text('取消'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: _saving ? null : _saveConfig,
                                    child: _saving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Text('保存'),
                                  ),
                                ],
                              ],
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            // 配置内容
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints:
                                  const BoxConstraints(minHeight: 300),
                              child: _editing
                                  ? TextField(
                                      controller: _editCtrl,
                                      maxLines: null,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.all(12),
                                        border: InputBorder.none,
                                      ),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        _editCtrl.text,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                            ),
                            if (_editing) ...[
                              const SizedBox(height: 8),
                              Text(
                                '提示：直接编辑原始配置文本（YAML/JSON），保存时将以增量 patch 方式应用。',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
}
