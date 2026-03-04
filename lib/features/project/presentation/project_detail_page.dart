import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/project.dart';
import 'project_provider.dart';

class ProjectDetailPage extends ConsumerWidget {
  final String projectId;
  const ProjectDetailPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);

    return projectsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('错误：$e'))),
      data: (projects) {
        final project = projects.where((p) => p.id == projectId).firstOrNull;
        if (project == null) {
          return const Scaffold(body: Center(child: Text('项目不存在')));
        }
        return _ProjectDetailView(project: project);
      },
    );
  }
}

class _ProjectDetailView extends ConsumerStatefulWidget {
  final Project project;
  const _ProjectDetailView({required this.project});

  @override
  ConsumerState<_ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends ConsumerState<_ProjectDetailView> {
  String _gitOutput = '';

  @override
  Widget build(BuildContext context) {
    final project = widget.project;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context, ref, project),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 笔记入口
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              icon: const Icon(Icons.note_add),
              label: const Text('查看 / 创建笔记'),
              onPressed: () => context.push('/project/${project.id}/notes'),
            ),
          ),

          // Git 操作面板
          if (project.isGitRepo) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Git 操作',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _GitButton(
                    icon: Icons.history,
                    label: 'Status',
                    onTap: () async {
                      final out = await ref
                          .read(projectListProvider.notifier)
                          .gitStatus(project);
                      setState(() => _gitOutput = out.isEmpty ? '(无变更)' : out);
                    },
                  ),
                  const SizedBox(width: 8),
                  _GitButton(
                    icon: Icons.commit,
                    label: 'Commit',
                    onTap: () => _showCommitDialog(context, ref, project),
                  ),
                  const SizedBox(width: 8),
                  _GitButton(
                    icon: Icons.cloud_upload,
                    label: 'Push',
                    onTap: () async {
                      final out = await ref
                          .read(projectListProvider.notifier)
                          .gitPush(project);
                      setState(() => _gitOutput = out);
                    },
                  ),
                  const SizedBox(width: 8),
                  _GitButton(
                    icon: Icons.cloud_download,
                    label: 'Pull',
                    onTap: () async {
                      final out = await ref
                          .read(projectListProvider.notifier)
                          .gitPull(project);
                      setState(() => _gitOutput = out);
                    },
                  ),
                  const SizedBox(width: 8),
                  _GitButton(
                    icon: Icons.list_alt,
                    label: 'Log',
                    onTap: () async {
                      final out = await ref
                          .read(projectListProvider.notifier)
                          .gitLog(project);
                      setState(() => _gitOutput = out.isEmpty ? '(暂无提交)' : out);
                    },
                  ),
                ],
              ),
            ),
            if (_gitOutput.isNotEmpty) ...[
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _gitOutput,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );
  }

  void _showCommitDialog(BuildContext context, WidgetRef ref, Project project) {
    final ctrl = TextEditingController(
      text: 'feat: update notes ${DateTime.now().toString().substring(0, 16)}',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Git Commit'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Commit 信息'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final out = await ref
                  .read(projectListProvider.notifier)
                  .gitCommit(project, ctrl.text.trim());
              setState(() => _gitOutput = out);
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(
      BuildContext context, WidgetRef ref, Project project) {
    final nameCtrl = TextEditingController(text: project.gitUserName ?? '');
    final emailCtrl = TextEditingController(text: project.gitUserEmail ?? '');
    final remoteCtrl = TextEditingController(text: project.remoteUrl ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('项目设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Git 用户名'),
            ),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Git 邮箱'),
            ),
            TextField(
              controller: remoteCtrl,
              decoration:
                  const InputDecoration(labelText: 'Remote URL（可选）'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              var updated = project.copyWith(
                gitUserName:
                    nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                gitUserEmail: emailCtrl.text.trim().isEmpty
                    ? null
                    : emailCtrl.text.trim(),
              );
              await ref
                  .read(projectListProvider.notifier)
                  .updateProject(updated);

              if (remoteCtrl.text.trim().isNotEmpty) {
                await ref
                    .read(projectListProvider.notifier)
                    .setRemote(updated, remoteCtrl.text.trim());
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _GitButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GitButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
