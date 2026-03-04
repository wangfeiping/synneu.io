import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/note_repository.dart';
import '../domain/note.dart';
import '../../project/presentation/project_provider.dart';

final noteRepositoryProvider = Provider<NoteRepository>(
  (_) => NoteRepository(),
);

final noteListProvider =
    AsyncNotifierProvider.family<NoteListNotifier, List<Note>, String>(
  NoteListNotifier.new,
);

class NoteListNotifier extends FamilyAsyncNotifier<List<Note>, String> {
  @override
  Future<List<Note>> build(String projectId) async {
    final projects = await ref.watch(projectListProvider.future);
    final project = projects.where((p) => p.id == projectId).firstOrNull;
    if (project == null) return [];
    return ref.read(noteRepositoryProvider).listNotes(
          projectId: projectId,
          projectPath: project.path,
        );
  }

  Future<Note> createNote({
    required String title,
    required String content,
  }) async {
    final projects = await ref.read(projectListProvider.future);
    final project = projects.where((p) => p.id == arg).first;
    final repo = ref.read(noteRepositoryProvider);
    final note = await repo.createNote(
      title: title,
      content: content,
      projectId: arg,
      projectPath: project.path,
    );

    // Auto git add
    final projectRepo = ref.read(projectRepositoryProvider);
    await projectRepo.gitAdd(project, note.filePath);

    state = AsyncData([...(state.valueOrNull ?? []), note]);
    return note;
  }

  Future<Note> updateNote(Note note, {String? title, String? content}) async {
    final repo = ref.read(noteRepositoryProvider);
    final updated = await repo.updateNote(note, title: title, content: content);

    // Auto git add
    final projects = await ref.read(projectListProvider.future);
    final project = projects.where((p) => p.id == arg).firstOrNull;
    if (project != null) {
      await ref.read(projectRepositoryProvider).gitAdd(project, updated.filePath);
    }

    state = AsyncData(
      (state.valueOrNull ?? []).map((n) => n.id == note.id ? updated : n).toList(),
    );
    return updated;
  }

  Future<void> deleteNote(Note note) async {
    await ref.read(noteRepositoryProvider).deleteNote(note);
    state = AsyncData(
      (state.valueOrNull ?? []).where((n) => n.id != note.id).toList(),
    );
  }
}
