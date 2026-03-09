import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../domain/project.dart';
import 'project_provider.dart';
import '../../note/domain/note.dart';
import '../../note/presentation/note_provider.dart';
import '../../../shared/widgets/dashed_add_button.dart';

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

enum _GitPanelMode { defaultMode, abbrev, verbose }

class _ProjectDetailViewState extends ConsumerState<_ProjectDetailView> {
  String _gitOutput = '';
  bool _gitOutputIsError = false;
  bool _menuOpen = false;
  _GitPanelMode _gitMode = _GitPanelMode.defaultMode;

  void _setOutput(String text, {bool isError = false}) {
    setState(() {
      _gitOutput = text;
      _gitOutputIsError = isError;
    });
  }

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
    final project = ref.watch(projectListProvider).valueOrNull
            ?.where((p) => p.id == widget.project.id)
            .firstOrNull ??
        widget.project;

    final key = (project.id, '');
    final notesAsync = ref.watch(noteListProvider(key));
    final dirs = ref.watch(dirListProvider(key)).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Git 操作面板
          if (project.isGitRepo) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Git 操作：三态循环按钮，始终显示文字
                  _GitButton(
                    icon: Icons.terminal,
                    label: _gitMode == _GitPanelMode.verbose ? 'Git 操作' : 'Git',
                    showLabel: true,
                    dimmed: _gitMode == _GitPanelMode.defaultMode,
                    onTap: () => setState(() {
                      _gitMode = _GitPanelMode
                          .values[(_gitMode.index + 1) % _GitPanelMode.values.length];
                    }),
                  ),
                  // Status
                  _GitButton(
                    icon: Icons.history,
                    label: 'Status',
                    showLabel: _gitMode == _GitPanelMode.verbose,
                    dimmed: _gitMode == _GitPanelMode.defaultMode,
                    onTap: _gitMode == _GitPanelMode.defaultMode
                        ? null
                        : () => _runGitOp('git status', () async {
                              final out = await ref
                                  .read(projectListProvider.notifier)
                                  .gitStatus(project);
                              return out.isEmpty ? '(无变更)' : out;
                            }),
                  ),
                  // Commit
                  _GitButton(
                    icon: Icons.commit,
                    label: 'Commit',
                    showLabel: _gitMode == _GitPanelMode.verbose,
                    dimmed: _gitMode == _GitPanelMode.defaultMode,
                    onTap: _gitMode == _GitPanelMode.defaultMode
                        ? null
                        : () => _showCommitDialog(context, ref, project),
                  ),
                  // Push
                  _GitButton(
                    icon: Icons.cloud_upload,
                    label: 'Push',
                    showLabel: _gitMode == _GitPanelMode.verbose,
                    dimmed: _gitMode == _GitPanelMode.defaultMode,
                    onTap: _gitMode == _GitPanelMode.defaultMode
                        ? null
                        : () => _runGitOp('git push', () =>
                              ref.read(projectListProvider.notifier).gitPush(project)),
                  ),
                  // Pull
                  _GitButton(
                    icon: Icons.cloud_download,
                    label: 'Pull',
                    showLabel: _gitMode == _GitPanelMode.verbose,
                    dimmed: _gitMode == _GitPanelMode.defaultMode,
                    onTap: _gitMode == _GitPanelMode.defaultMode
                        ? null
                        : () => _runGitOp('git pull', () =>
                              ref.read(projectListProvider.notifier).gitPull(project)),
                  ),
                  // Log
                  _GitButton(
                    icon: Icons.list_alt,
                    label: 'Log',
                    showLabel: _gitMode == _GitPanelMode.verbose,
                    dimmed: _gitMode == _GitPanelMode.defaultMode,
                    onTap: _gitMode == _GitPanelMode.defaultMode
                        ? null
                        : () => _runGitOp('git log', () async {
                              final out = await ref
                                  .read(projectListProvider.notifier)
                                  .gitLog(project);
                              return out.isEmpty ? '(暂无提交)' : out;
                            }),
                  ),
                  // Sync：默认态正常，其他态灰色不可用
                  _GitButton(
                    icon: Icons.sync,
                    label: 'Sync',
                    showLabel: true,
                    dimmed: _gitMode != _GitPanelMode.defaultMode,
                    onTap: _gitMode == _GitPanelMode.defaultMode ? () {} : null,
                  ),
                ],
              ),
            ),
            if (_gitOutput.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
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
              const SizedBox(height: 8),
            ],
          ],

          // 新建按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DashedAddButton(
              onTap: () => setState(() => _menuOpen = !_menuOpen),
            ),
          ),
          // 下滑菜单
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              heightFactor: _menuOpen ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    ListTile(
                      leading: const Icon(Icons.note_add_outlined),
                      title: const Text('笔记'),
                      onTap: () {
                        setState(() => _menuOpen = false);
                        context.push(
                          '/project/${project.id}/notes/edit',
                          extra: ('', null),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.create_new_folder_outlined),
                      title: const Text('文件夹'),
                      onTap: () {
                        setState(() => _menuOpen = false);
                        _showCreateDirDialog(context, ref, project);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 文件列表
          const Divider(),
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (notes) {
                if (notes.isEmpty && dirs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('还没有笔记，点击上方 + 创建'),
                      ],
                    ),
                  );
                }
                final fmt = DateFormat('MM-dd HH:mm');
                final totalCount = notes.length + dirs.length;
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: totalCount,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i < notes.length) {
                      final note = notes[i];
                      return Card(
                        child: ListTile(
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.basename(note.filePath),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500),
                              ),
                              Text(
                                fmt.format(note.updatedAt),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade400),
                              ),
                              Text(
                                note.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          subtitle: Text(
                            note.content.isEmpty ? '（无内容）' : note.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => context.push(
                            '/project/${project.id}/notes/edit',
                            extra: ('', note),
                          ),
                          onLongPress: () =>
                              _showNoteOptions(context, ref, project, note),
                        ),
                      );
                    } else {
                      final dirName = dirs[i - notes.length];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(
                            dirName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          onTap: () => context.push(
                            '/project/${project.id}/notes',
                            extra: dirName,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showNoteOptions(
      BuildContext context, WidgetRef ref, Project project, Note note) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名文件'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, ref, project, note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除笔记',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref, project, note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
      BuildContext context, WidgetRef ref, Project project, Note note) {
    final controller = TextEditingController(
      text: p.basenameWithoutExtension(note.filePath),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名文件'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '文件名（不含扩展名）',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              await ref
                  .read(noteListProvider((project.id, '')).notifier)
                  .renameNote(note, newName);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, Project project, Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定删除「${note.title}」？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(noteListProvider((project.id, '')).notifier)
                  .deleteNote(note);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showCreateDirDialog(
      BuildContext context, WidgetRef ref, Project project) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final validPattern = RegExp(r'^[a-zA-Z0-9_\-.]+$');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '文件夹名称',
              hintText: '仅限英文、数字及 _ - .',
            ),
            validator: (v) {
              final name = v?.trim() ?? '';
              if (name.isEmpty) return '名称不能为空';
              if (!validPattern.hasMatch(name)) return '仅允许英文、数字及 _ - . 字符';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = controller.text.trim();
              Navigator.pop(ctx);
              await ref
                  .read(dirListProvider((project.id, '')).notifier)
                  .createDir(name);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showCommitDialog(
      BuildContext context, WidgetRef ref, Project project) {
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _runGitOp(
                  'git commit',
                  () => ref
                      .read(projectListProvider.notifier)
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
  final VoidCallback? onTap;
  final bool showLabel;
  final bool dimmed;

  const _GitButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.showLabel = true,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = dimmed
        ? OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            disabledForegroundColor: Colors.black,
            backgroundColor: Colors.grey.shade800,
            disabledBackgroundColor: Colors.grey.shade800,
            side: const BorderSide(color: Colors.black),
          )
        : null;

    if (showLabel) {
      return OutlinedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label),
        onPressed: onTap,
        style: style,
      );
    } else {
      return OutlinedButton(
        onPressed: onTap,
        style: style,
        child: Icon(icon, size: 16),
      );
    }
  }
}
