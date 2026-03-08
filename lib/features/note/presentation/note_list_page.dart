import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/dashed_add_button.dart';
import '../../project/presentation/project_provider.dart';
import 'note_provider.dart';

class NoteListPage extends ConsumerStatefulWidget {
  final String projectId;
  final String subPath;
  const NoteListPage({
    super.key,
    required this.projectId,
    this.subPath = '',
  });

  @override
  ConsumerState<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends ConsumerState<NoteListPage> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final key = (widget.projectId, widget.subPath);
    final notesAsync = ref.watch(noteListProvider(key));
    final dirs = ref.watch(dirListProvider(key)).valueOrNull ?? [];

    final projectName = ref
            .watch(projectListProvider)
            .valueOrNull
            ?.where((proj) => proj.id == widget.projectId)
            .firstOrNull
            ?.name ??
        '笔记';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(projectName),
            if (widget.subPath.isNotEmpty)
              Text(
                widget.subPath,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .appBarTheme
                      .foregroundColor
                      ?.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                          '/project/${widget.projectId}/notes/edit',
                          extra: (widget.subPath, null),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.create_new_folder_outlined),
                      title: const Text('文件夹'),
                      onTap: () {
                        setState(() => _menuOpen = false);
                        _showCreateDirDialog(context);
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
                        const Icon(Icons.folder_open,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(widget.subPath.isEmpty
                            ? '还没有笔记，点击上方 + 创建'
                            : '此文件夹为空'),
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
                            '/project/${widget.projectId}/notes/edit',
                            extra: (widget.subPath, note),
                          ),
                          onLongPress: () =>
                              _showNoteOptions(context, note),
                        ),
                      );
                    } else {
                      final dirName = dirs[i - notes.length];
                      final newSubPath = widget.subPath.isEmpty
                          ? dirName
                          : '${widget.subPath}/$dirName';
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(
                            dirName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          onTap: () => context.push(
                            '/project/${widget.projectId}/notes',
                            extra: newSubPath,
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

  void _showNoteOptions(BuildContext context, note) {
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
                _showRenameDialog(context, note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('删除笔记', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, note) {
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
                  .read(noteListProvider(
                          (widget.projectId, widget.subPath))
                      .notifier)
                  .renameNote(note, newName);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, note) {
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
                  .read(noteListProvider(
                          (widget.projectId, widget.subPath))
                      .notifier)
                  .deleteNote(note);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showCreateDirDialog(BuildContext context) {
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
                  .read(dirListProvider(
                          (widget.projectId, widget.subPath))
                      .notifier)
                  .createDir(name);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
