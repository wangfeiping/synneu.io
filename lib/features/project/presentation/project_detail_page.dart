import 'dart:developer' as dev;
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
  bool _gitOutputIsError = false;

  void _setOutput(String text, {bool isError = false}) {
    setState(() {
      _gitOutput = text;
      _gitOutputIsError = isError;
    });
  }

  /// 执行 git 操作并处理异常：异常一律显示在终端面板并输出日志。
  Future<void> _runGitOp(
    String opName,
    Future<String> Function() op,
  ) async {
    try {
      final out = await op();
      _setOutput(out.isEmpty ? '($opName 完成，无输出)' : out);
    } catch (e, st) {
      dev.log(
        '$opName 失败: $e',
        name: 'ProjectDetailPage',
        level: 1000,
        error: e,
        stackTrace: st,
      );
      _setOutput('[错误] $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 始终从 provider 取最新数据，避免重命名后使用过期 path
    final project = ref.watch(projectListProvider).valueOrNull
            ?.where((p) => p.id == widget.project.id)
            .firstOrNull ??
        widget.project;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
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
                    onTap: () => _runGitOp('git status', () async {
                      final out = await ref
                          .read(projectListProvider.notifier)
                          .gitStatus(project);
                      return out.isEmpty ? '(无变更)' : out;
                    }),
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
                    onTap: () => _runGitOp('git push', () =>
                        ref.read(projectListProvider.notifier).gitPush(project)),
                  ),
                  const SizedBox(width: 8),
                  _GitButton(
                    icon: Icons.cloud_download,
                    label: 'Pull',
                    onTap: () => _runGitOp('git pull', () =>
                        ref.read(projectListProvider.notifier).gitPull(project)),
                  ),
                  const SizedBox(width: 8),
                  _GitButton(
                    icon: Icons.list_alt,
                    label: 'Log',
                    onTap: () => _runGitOp('git log', () async {
                      final out = await ref
                          .read(projectListProvider.notifier)
                          .gitLog(project);
                      return out.isEmpty ? '(暂无提交)' : out;
                    }),
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
                        style: TextStyle(
                          color: _gitOutputIsError
                              ? Colors.redAccent
                              : Colors.greenAccent,
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
              await _runGitOp('git commit', () =>
                  ref.read(projectListProvider.notifier)
                      .gitCommit(project, ctrl.text.trim()));
            },
            child: const Text('提交'),
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
