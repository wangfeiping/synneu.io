import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/note.dart';
import 'note_provider.dart';
import '../../voice/presentation/voice_input_widget.dart';

class NoteEditPage extends ConsumerStatefulWidget {
  final String projectId;
  final String subPath;
  final Note? existingNote;

  const NoteEditPage({
    super.key,
    required this.projectId,
    this.subPath = '',
    this.existingNote,
  });

  @override
  ConsumerState<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends ConsumerState<NoteEditPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  bool _saving = false;

  bool get _isEditing => widget.existingNote != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existingNote?.title ?? '');
    _contentCtrl =
        TextEditingController(text: widget.existingNote?.content ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('标题不能为空')));
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await ref
            .read(noteListProvider((widget.projectId, widget.subPath)).notifier)
            .updateNote(
              widget.existingNote!,
              title: title,
              content: content,
            );
      } else {
        await ref
            .read(noteListProvider((widget.projectId, widget.subPath)).notifier)
            .createNote(title: title, content: content);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _appendVoiceText(String text) {
    final current = _contentCtrl.text;
    _contentCtrl.text = current.isEmpty ? text : '$current\n$text';
    _contentCtrl.selection = TextSelection.collapsed(
      offset: _contentCtrl.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑笔记' : '新建笔记'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('保存', style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _titleCtrl,
              autofocus: !_isEditing,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '笔记标题',
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _contentCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 16, height: 1.6),
                decoration: const InputDecoration(
                  hintText: '开始记录...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          // 语音输入条
          VoiceInputWidget(
            onTextReady: _appendVoiceText,
          ),
        ],
      ),
    );
  }
}
