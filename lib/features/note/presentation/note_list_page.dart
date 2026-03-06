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
  const NoteListPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(noteListProvider(projectId));
    final projectsAsync = ref.watch(projectListProvider);
    final projectName = projectsAsync.valueOrNull
            ?.where((p) => p.id == projectId)
            .firstOrNull
            ?.name ??
        '笔记';

    return Scaffold(
      appBar: AppBar(
        title: Text(projectName),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/project/$projectId/notes/edit'),
        icon: const Icon(Icons.add),
        label: const Text('新建笔记'),
      ),
      body: notesAsync.when(
        loading: () => const LoadingWidget(message: '加载笔记...'),
        error: (e, _) => ErrorWidget2(
          message: '加载失败：$e',
          onRetry: () => ref.invalidate(noteListProvider(projectId)),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.note, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('还没有笔记，点击右下角创建'),
                ],
              ),
            );
          }
          final fmt = DateFormat('MM-dd HH:mm');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
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
                      Text(note.title,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
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
                    extra: note,
                  ),
                  onLongPress: () => _showNoteOptions(context, ref, note),
                ),
              );
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
              title: const Text('删除笔记', style: TextStyle(color: Colors.red)),
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
                  .read(noteListProvider(projectId).notifier)
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
                  .read(noteListProvider(projectId).notifier)
                  .deleteNote(note);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
