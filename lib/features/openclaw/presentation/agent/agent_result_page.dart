import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/agent_job.dart';
import '../openclaw_provider.dart';

class AgentResultPage extends ConsumerWidget {
  final String runId;
  const AgentResultPage({super.key, required this.runId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(agentJobListProvider);
    final job = jobs.where((j) => j.runId == runId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务状态'),
      ),
      body: job == null
          ? Center(child: Text('任务 $runId 不存在'))
          : _JobDetail(job: job),
    );
  }
}

class _JobDetail extends StatelessWidget {
  final AgentJob job;
  const _JobDetail({required this.job});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (statusIcon, statusColor, statusText) = switch (job.status) {
      AgentJobStatus.running => (
          Icons.hourglass_top,
          Colors.orange,
          '执行中…'
        ),
      AgentJobStatus.ok => (Icons.check_circle, Colors.green, '执行成功'),
      AgentJobStatus.error => (Icons.error, Colors.red, '执行失败'),
      AgentJobStatus.timeout => (Icons.timer_off, Colors.amber, '执行超时'),
      AgentJobStatus.unknown => (Icons.help_outline, Colors.grey, '状态未知'),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 状态卡片
          Card(
            color: statusColor.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  job.status == AgentJobStatus.running
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : Icon(statusIcon, color: statusColor, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    statusText,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: statusColor),
                  ),
                  if (job.elapsed != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '耗时 ${job.elapsed!.inSeconds} 秒',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 任务详情
          _DetailCard(
            title: '任务内容',
            child: Text(job.prompt),
          ),
          if (job.agentId != null)
            _DetailCard(
              title: 'Agent',
              child: Text(job.agentId!),
            ),
          if (job.model != null)
            _DetailCard(
              title: '模型',
              child: Text(job.model!),
            ),
          _DetailCard(
            title: '运行 ID',
            child: Text(
              job.runId,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          _DetailCard(
            title: '开始时间',
            child: Text(job.startedAt.toLocal().toString()),
          ),
          if (job.endedAt != null)
            _DetailCard(
              title: '结束时间',
              child: Text(job.endedAt!.toLocal().toString()),
            ),

          if (job.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('错误信息',
                      style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(job.errorMessage!,
                      style: TextStyle(
                          color: scheme.onErrorContainer, fontSize: 12)),
                ],
              ),
            ),
          ],

          if (job.status == AgentJobStatus.ok && job.sessionKey != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                context.push(
                    '/openclaw/chat/${Uri.encodeComponent(job.sessionKey!)}');
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('查看对话结果'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _DetailCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey),
              ),
              const SizedBox(height: 4),
              child,
            ],
          ),
        ),
      );
}
