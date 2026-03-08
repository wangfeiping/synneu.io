import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/project.dart';
import 'project_provider.dart';

class ProjectListPage extends ConsumerWidget {
  const ProjectListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synneu'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建项目',
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: projectsAsync.when(
        loading: () => const LoadingWidget(message: '加载项目...'),
        error: (e, _) => ErrorWidget2(
          message: '加载失败：$e',
          onRetry: () => ref.invalidate(projectListProvider),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无项目，点击右上角 + 创建'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('创建第一个项目'),
                  ),
                ],
              ),
            );
          }

          // 正常项目在前（按创建时间倒序），待删除项目在后（按删除时间升序）
          final sorted = [...projects];
          sorted.sort((a, b) {
            if (a.isPendingDeletion != b.isPendingDeletion) {
              return a.isPendingDeletion ? 1 : -1;
            }
            if (a.isPendingDeletion) {
              return a.deletedAt!.compareTo(b.deletedAt!);
            }
            return b.createdAt.compareTo(a.createdAt);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final project = sorted[i];
              return project.isPendingDeletion
                  ? _buildDeletedCard(context, ref, project)
                  : _buildActiveCard(context, ref, project);
            },
          );
        },
      ),
    );
  }

  Widget _buildActiveCard(
      BuildContext context, WidgetRef ref, Project project) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            project.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(project.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          project.isGitRepo ? 'Git 已初始化' : '普通目录',
          style: TextStyle(
            color: project.isGitRepo ? Colors.green : Colors.grey,
            fontSize: 12,
          ),
        ),
        trailing: PopupMenuButton<_ProjectAction>(
          onSelected: (action) =>
              _onActiveAction(context, ref, project, action),
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: _ProjectAction.open, child: Text('打开')),
            PopupMenuItem(
                value: _ProjectAction.rename, child: Text('重命名')),
            PopupMenuItem(
                value: _ProjectAction.delete, child: Text('删除')),
            PopupMenuItem(
                value: _ProjectAction.setting, child: Text('设置')),
          ],
        ),
        onTap: () {
          ref.read(selectedProjectProvider.notifier).state = project;
          context.push('/project/${project.id}');
        },
      ),
    );
  }

  Widget _buildDeletedCard(
      BuildContext context, WidgetRef ref, Project project) {
    final days = project.daysUntilPurge;
    return Card(
      color: Colors.grey.shade800,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.black,
          child: Icon(Icons.delete_outline, color: Colors.grey.shade500, size: 20),
        ),
        title: Text(
          project.name,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.grey.shade500),
        ),
        subtitle: Text(
          '待删除 · 剩余 $days 天自动清理',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        trailing: PopupMenuButton<_ProjectAction>(
          onSelected: (action) =>
              _onDeletedAction(context, ref, project, action),
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: _ProjectAction.purge, child: Text('立即删除')),
          ],
        ),
      ),
    );
  }

  void _onActiveAction(BuildContext context, WidgetRef ref, Project project,
      _ProjectAction action) {
    switch (action) {
      case _ProjectAction.open:
        ref.read(selectedProjectProvider.notifier).state = project;
        context.push('/project/${project.id}');
      case _ProjectAction.rename:
        _showRenameDialog(context, ref, project);
      case _ProjectAction.delete:
        _showSoftDeleteConfirm(context, ref, project);
      case _ProjectAction.setting:
        _showSettingsDialog(context, ref, project);
      default:
        break;
    }
  }

  void _onDeletedAction(BuildContext context, WidgetRef ref, Project project,
      _ProjectAction action) {
    if (action == _ProjectAction.purge) {
      _showHardDeleteConfirm(context, ref, project);
    }
  }

  // ── Dialogs ──────────────────────────────────────────────────────

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建项目'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '项目名称',
            hintText: '例如：我的日记',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await ref
                  .read(projectListProvider.notifier)
                  .createProject(name);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  static final _nameRegExp = RegExp(r'^[a-zA-Z0-9\-_.]+$');

  void _showRenameDialog(
      BuildContext context, WidgetRef ref, Project project) {
    final controller = TextEditingController(text: project.name);
    showDialog(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setState) {
            final text = controller.text.trim();
            final canConfirm =
                error == null && text.isNotEmpty && text != project.name;
            return AlertDialog(
              title: const Text('重命名项目'),
              content: TextField(
                controller: controller,
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    final v = value.trim();
                    if (v.isEmpty || _nameRegExp.hasMatch(v)) {
                      error = null;
                    } else {
                      error = '只能含英文字母、数字、"-"、"_"、"."';
                    }
                  });
                },
                decoration: InputDecoration(
                  labelText: '项目名称',
                  errorText: error,
                  helperText: '仅限英文字母、数字、"-"、"_"、"."',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: canConfirm
                      ? () async {
                          final name = controller.text.trim();
                          Navigator.pop(ctx);
                          try {
                            await ref
                                .read(projectListProvider.notifier)
                                .renameProject(project, name);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('重命名失败：$e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  child: const Text('确认'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSoftDeleteConfirm(
      BuildContext context, WidgetRef ref, Project project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('将"${project.name}"移入待删除？30天后将自动清理所有数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(projectListProvider.notifier)
                  .deleteProject(project);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showHardDeleteConfirm(
      BuildContext context, WidgetRef ref, Project project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('立即删除'),
        content: Text('确认立即删除"${project.name}"的所有数据？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(projectListProvider.notifier)
                  .hardDeleteProject(project);
            },
            child: const Text('立即删除'),
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
    final tokenCtrl = TextEditingController(text: project.gitToken ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('项目设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!project.isGitRepo)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.source),
                  label: const Text('初始化 Git 仓库'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref
                          .read(projectListProvider.notifier)
                          .initGit(project);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Git 初始化成功')),
                        );
                      }
                    } catch (e, st) {
                      dev.log(
                        'initGit 失败: $e',
                        name: 'ProjectListPage',
                        level: 1000,
                        error: e,
                        stackTrace: st,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Git 初始化失败: $e'),
                          backgroundColor:
                              Theme.of(context).colorScheme.error,
                        ));
                      }
                    }
                  },
                ),
              ),
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
            TextField(
              controller: tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'Access Token（Push/Pull 认证）',
                helperText: '如 GitHub Personal Access Token',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final remoteUrl = remoteCtrl.text.trim();
              final updated = project.copyWith(
                gitUserName: nameCtrl.text.trim().isEmpty
                    ? null
                    : nameCtrl.text.trim(),
                gitUserEmail: emailCtrl.text.trim().isEmpty
                    ? null
                    : emailCtrl.text.trim(),
                remoteUrl: remoteUrl.isEmpty ? null : remoteUrl,
                gitToken: tokenCtrl.text.trim().isEmpty
                    ? null
                    : tokenCtrl.text.trim(),
              );
              await ref
                  .read(projectListProvider.notifier)
                  .updateProject(updated);

              if (remoteUrl.isNotEmpty) {
                try {
                  await ref
                      .read(projectListProvider.notifier)
                      .setRemote(updated, remoteUrl);
                } catch (e, st) {
                  dev.log(
                    'setRemote 失败: $e',
                    name: 'ProjectListPage',
                    level: 1000,
                    error: e,
                    stackTrace: st,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('git remote 设置失败: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ));
                  }
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

enum _ProjectAction { open, rename, delete, setting, purge }
