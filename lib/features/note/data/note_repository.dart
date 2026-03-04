import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../domain/note.dart';

class NoteRepository {
  final _uuid = const Uuid();
  final _dateFormat = DateFormat('yyyyMMdd_HHmmss');

  /// 在指定项目目录下创建笔记文件
  Future<Note> createNote({
    required String title,
    required String content,
    required String projectId,
    required String projectPath,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = '${_dateFormat.format(now)}_$safeTitle.md';
    final filePath = p.join(projectPath, fileName);

    final fileContent = '# $title\n\n$content\n';
    await File(filePath).writeAsString(fileContent, flush: true);

    return Note(
      id: id,
      title: title,
      content: content,
      projectId: projectId,
      createdAt: now,
      updatedAt: now,
      filePath: filePath,
    );
  }

  /// 更新已有笔记文件
  Future<Note> updateNote(Note note, {String? title, String? content}) async {
    final newTitle = title ?? note.title;
    final newContent = content ?? note.content;
    final now = DateTime.now();

    final fileContent = '# $newTitle\n\n$newContent\n';
    await File(note.filePath).writeAsString(fileContent, flush: true);

    return note.copyWith(
      title: newTitle,
      content: newContent,
      updatedAt: now,
    );
  }

  /// 从文件加载笔记内容
  Future<Note> loadNote(Note note) async {
    final raw = await File(note.filePath).readAsString();
    final lines = raw.split('\n');
    final title = lines.isNotEmpty
        ? lines.first.replaceFirst(RegExp(r'^#+\s*'), '').trim()
        : note.title;
    final content = lines.length > 2 ? lines.skip(2).join('\n').trim() : '';
    return note.copyWith(title: title, content: content);
  }

  /// 列出项目目录下所有 .md 笔记文件
  Future<List<Note>> listNotes({
    required String projectId,
    required String projectPath,
  }) async {
    final dir = Directory(projectPath);
    if (!await dir.exists()) return [];

    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.md'))
        .cast<File>()
        .toList();

    final notes = <Note>[];
    for (final file in files) {
      final stat = await file.stat();
      final raw = await file.readAsString();
      final lines = raw.split('\n');
      final title = lines.isNotEmpty
          ? lines.first.replaceFirst(RegExp(r'^#+\s*'), '').trim()
          : p.basenameWithoutExtension(file.path);
      final content = lines.length > 2 ? lines.skip(2).join('\n').trim() : '';

      notes.add(Note(
        id: p.basename(file.path),
        title: title,
        content: content,
        projectId: projectId,
        createdAt: stat.changed,
        updatedAt: stat.modified,
        filePath: file.path,
      ));
    }

    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  /// 删除笔记文件
  Future<void> deleteNote(Note note) async {
    final file = File(note.filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
