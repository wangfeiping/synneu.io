import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../../../shared/widgets/loading_widget.dart';
import '../../project/presentation/project_provider.dart';
import 'note_provider.dart';

class NoteListPage extends ConsumerWidget {
  final String projectId;
  final String subPath;
  const NoteListPage({
    super.key,
    required this.projectId,
    this.subPath = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (projectId, subPath);
    final notesAsync = ref.watch(noteListProvider(key));
    final dirsAsync = ref.watch(dirListProvider(key));
    final dirs = dirsAsync.valueOrNull ?? [];

    final projectsAsync = ref.watch(projectListProvider);
    final projectName = projectsAsync.valueOrNull
            ?.where((proj) => proj.id == projectId)
            .firstOrNull
            ?.name ??
        '笔记';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(projectName),
            if (subPath.isNotEmpty)
              Text(
                subPath,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .appBarTheme
                      .foregroundColor
                      ?.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateMenu(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
      body: notesAsync.when(
        loading: () => const LoadingWidget(message: '加载中...'),
        error: (e, _) => ErrorWidget2(
          message: '加载失败：$e',
          onRetry: () => ref.invalidate(noteListProvider(key)),
        ),
        data: (notes) {
          if (notes.isEmpty && dirs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(subPath.isEmpty ? '还没有笔记，点击右下角创建' : '此文件夹为空'),
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                      '/project/$projectId/notes/edit',
                      extra: (subPath, note),
                    ),
                    onLongPress: () => _showNoteOptions(context, ref, note),
                  ),
                );
              } else {
                final dirName = dirs[i - notes.length];
                final newSubPath =
                    subPath.isEmpty ? dirName : '$subPath/$dirName';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(
                      dirName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () => context.push(
                      '/project/$projectId/notes',
                      extra: newSubPath,
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  void _showNoteOptions(BuildContext context, WidgetRef ref, note) {
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
                _showRenameDialog(context, ref, note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('删除笔记', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref, note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, note) {
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
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              await ref
                  .read(noteListProvider((projectId, subPath)).notifier)
                  .renameNote(note, newName);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定删除「${note.title}」？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(noteListProvider((projectId, subPath)).notifier)
                  .deleteNote(note);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showCreateMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('笔记'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(
                  '/project/$projectId/notes/edit',
                  extra: (subPath, null),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('文件夹'),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateDirDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDirDialog(BuildContext context, WidgetRef ref) {
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
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = controller.text.trim();
              Navigator.pop(ctx);
              await ref
                  .read(dirListProvider((projectId, subPath)).notifier)
                  .createDir(name);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
