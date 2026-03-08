import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../data/note_repository.dart';
import '../domain/note.dart';
import '../../project/presentation/project_provider.dart';

final noteRepositoryProvider = Provider<NoteRepository>(
  (_) => NoteRepository(),
);

/// family key: (projectId, subPath)，subPath 为空字符串表示项目根目录
final noteListProvider = AsyncNotifierProvider.family<
    NoteListNotifier, List<Note>, (String, String)>(
  NoteListNotifier.new,
);

final dirListProvider = AsyncNotifierProvider.family<
    DirListNotifier, List<String>, (String, String)>(
  DirListNotifier.new,
);

class DirListNotifier
    extends FamilyAsyncNotifier<List<String>, (String, String)> {
  @override
  Future<List<String>> build((String, String) arg) async {
    final projects = await ref.watch(projectListProvider.future);
    final project = projects.where((p) => p.id == arg.$1).firstOrNull;
    if (project == null) return [];
    final dirPath =
        arg.$2.isEmpty ? project.path : p.join(project.path, arg.$2);
    return ref.read(noteRepositoryProvider).listDirs(projectPath: dirPath);
  }

  Future<void> createDir(String dirName) async {
    final projects = await ref.read(projectListProvider.future);
    final project = projects.where((p) => p.id == arg.$1).firstOrNull;
    if (project == null) return;
    final dirPath =
        arg.$2.isEmpty ? project.path : p.join(project.path, arg.$2);
    await ref
        .read(noteRepositoryProvider)
        .createDir(projectPath: dirPath, dirName: dirName);
    final current = state.valueOrNull ?? [];
    final updated = [...current, dirName]..sort((a, b) => b.compareTo(a));
    state = AsyncData(updated);
  }
}

class NoteListNotifier
    extends FamilyAsyncNotifier<List<Note>, (String, String)> {
  @override
  Future<List<Note>> build((String, String) arg) async {
    final projects = await ref.watch(projectListProvider.future);
    final project = projects.where((p) => p.id == arg.$1).firstOrNull;
    if (project == null) return [];
    final dirPath =
        arg.$2.isEmpty ? project.path : p.join(project.path, arg.$2);
    return ref.read(noteRepositoryProvider).listNotes(
          projectId: arg.$1,
          projectPath: dirPath,
        );
  }

  Future<Note> createNote({
    required String title,
    required String content,
  }) async {
    final projects = await ref.read(projectListProvider.future);
    final project = projects.where((p) => p.id == arg.$1).first;
    final dirPath =
        arg.$2.isEmpty ? project.path : p.join(project.path, arg.$2);
    final repo = ref.read(noteRepositoryProvider);
    final note = await repo.createNote(
      title: title,
      content: content,
      projectId: arg.$1,
      projectPath: dirPath,
    );

    try {
      await ref.read(projectRepositoryProvider).gitAdd(project, note.filePath);
    } catch (e, st) {
      dev.log(
        'git add 失败（笔记已保存，仅 git 暂存失败）: $e',
        name: 'NoteProvider',
        level: 900,
        error: e,
        stackTrace: st,
      );
    }

    state = AsyncData([...(state.valueOrNull ?? []), note]);
    return note;
  }

  Future<Note> updateNote(Note note, {String? title, String? content}) async {
    final repo = ref.read(noteRepositoryProvider);
    final updated = await repo.updateNote(note, title: title, content: content);

    try {
      final projects = await ref.read(projectListProvider.future);
      final project = projects.where((p) => p.id == arg.$1).firstOrNull;
      if (project != null) {
        await ref
            .read(projectRepositoryProvider)
            .gitAdd(project, updated.filePath);
      }
    } catch (e, st) {
      dev.log(
        'git add 失败（笔记已更新，仅 git 暂存失败）: $e',
        name: 'NoteProvider',
        level: 900,
        error: e,
        stackTrace: st,
      );
    }

    state = AsyncData(
      (state.valueOrNull ?? [])
          .map((n) => n.id == note.id ? updated : n)
          .toList(),
    );
    return updated;
  }

  Future<Note> renameNote(Note note, String newFileName) async {
    final renamed =
        await ref.read(noteRepositoryProvider).renameNote(note, newFileName);

    try {
      final projects = await ref.read(projectListProvider.future);
      final project = projects.where((p) => p.id == arg.$1).firstOrNull;
      if (project != null) {
        final gitRepo = ref.read(projectRepositoryProvider);
        await gitRepo.gitRemove(project, note.filePath);
        await gitRepo.gitAdd(project, renamed.filePath);
      }
    } catch (e, st) {
      dev.log(
        'git rm/add 失败（文件已重命名，仅 git 暂存失败）: $e',
        name: 'NoteProvider',
        level: 900,
        error: e,
        stackTrace: st,
      );
    }

    state = AsyncData(
      (state.valueOrNull ?? [])
          .map((n) => n.id == note.id ? renamed : n)
          .toList(),
    );
    return renamed;
  }

  Future<void> deleteNote(Note note) async {
    await ref.read(noteRepositoryProvider).deleteNote(note);

    try {
      final projects = await ref.read(projectListProvider.future);
      final project = projects.where((p) => p.id == arg.$1).firstOrNull;
      if (project != null) {
        await ref
            .read(projectRepositoryProvider)
            .gitRemove(project, note.filePath);
      }
    } catch (e, st) {
      dev.log(
        'git rm 失败（文件已删除，仅 git 暂存失败）: $e',
        name: 'NoteProvider',
        level: 900,
        error: e,
        stackTrace: st,
      );
    }

    state = AsyncData(
      (state.valueOrNull ?? []).where((n) => n.id != note.id).toList(),
    );
  }
}
