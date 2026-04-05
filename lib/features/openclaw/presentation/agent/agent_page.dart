import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/agent_job.dart';
import '../openclaw_provider.dart';

class AgentPage extends ConsumerStatefulWidget {
  const AgentPage({super.key});

  @override
  ConsumerState<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends ConsumerState<AgentPage> {
  final _promptCtrl = TextEditingController();
  String? _selectedAgentId;
  String? _selectedModel;
  String _thinking = 'none';
  bool _running = false;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;
    setState(() => _running = true);
    try {
      final runner = ref.read(agentRunnerProvider);
      final job = await runner.run(
        message: prompt,
        agentId: _selectedAgentId,
        model: _selectedModel,
        thinking: _thinking == 'none' ? null : _thinking,
      );
      if (mounted) {
        _promptCtrl.clear();
        context.push('/openclaw/agent/${job.runId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('任务启动失败：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(agentJobListProvider);
    final agentsAsync = ref.watch(agentsListProvider);
    final modelsAsync = ref.watch(modelsListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 任务发起区 ────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('发起 AI 任务',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _promptCtrl,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: '描述任务，例如：总结今天的新闻，发送到 Telegram',
                      labelText: 'Prompt',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Agent 选择
                  agentsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (agents) {
                      if (agents.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<String?>(
                        initialValue: _selectedAgentId,
                        decoration: const InputDecoration(labelText: 'Agent（可选）'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('默认')),
                          ...agents.map((a) => DropdownMenuItem(
                                value: a['id'] as String?,
                                child: Text(a['name'] as String? ??
                                    a['id'] as String? ??
                                    ''),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedAgentId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // 模型选择
                  modelsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (models) {
                      if (models.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<String?>(
                        initialValue: _selectedModel,
                        decoration: const InputDecoration(labelText: '模型（可选）'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('默认')),
                          ...models.map((m) => DropdownMenuItem(
                                value: m['id'] as String?,
                                child: Text(m['id'] as String? ?? ''),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedModel = v),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // Thinking 级别
                  DropdownButtonFormField<String>(
                    initialValue: _thinking,
                    decoration: const InputDecoration(labelText: '推理深度'),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('不推理')),
                      DropdownMenuItem(value: 'low', child: Text('浅层推理')),
                      DropdownMenuItem(value: 'high', child: Text('深度推理')),
                    ],
                    onChanged: (v) =>
                        setState(() => _thinking = v ?? 'none'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _running ? null : _run,
                    icon: _running
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_running ? '启动中…' : '执行任务'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 任务历史 ──────────────────────────────────────────
          if (jobs.isNotEmpty) ...[
            Text('最近任务', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...jobs.map((job) => _JobCard(job: job)),
          ],
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final AgentJob job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (job.status) {
      AgentJobStatus.running => (Icons.hourglass_top, Colors.orange),
      AgentJobStatus.ok => (Icons.check_circle, Colors.green),
      AgentJobStatus.error => (Icons.error, Colors.red),
      AgentJobStatus.timeout => (Icons.timer_off, Colors.amber),
      AgentJobStatus.unknown => (Icons.help_outline, Colors.grey),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          job.prompt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          job.elapsed != null
              ? '耗时 ${job.elapsed!.inSeconds}s · ${_statusText(job.status)}'
              : _statusText(job.status),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/openclaw/agent/${job.runId}'),
      ),
    );
  }

  String _statusText(AgentJobStatus s) => switch (s) {
        AgentJobStatus.running => '执行中…',
        AgentJobStatus.ok => '成功',
        AgentJobStatus.error => '失败',
        AgentJobStatus.timeout => '超时',
        AgentJobStatus.unknown => '未知',
      };
}
