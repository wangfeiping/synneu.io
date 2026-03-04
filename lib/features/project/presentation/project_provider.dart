import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';

final projectRepositoryProvider = Provider<ProjectRepository>(
  (_) => ProjectRepository(),
);

final projectListProvider =
    AsyncNotifierProvider<ProjectListNotifier, List<Project>>(
  ProjectListNotifier.new,
);

final selectedProjectProvider = StateProvider<Project?>((ref) => null);

class ProjectListNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    return ref.read(projectRepositoryProvider).loadProjects();
  }

  Future<void> createProject(String name) async {
    final repo = ref.read(projectRepositoryProvider);
    final previous = state.valueOrNull ?? [];
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final project = await repo.createProject(name);
      return [...previous, project];
    });
  }

  Future<void> updateProject(Project project) async {
    final repo = ref.read(projectRepositoryProvider);
    await repo.updateProject(project);
    state = AsyncData(
      (state.valueOrNull ?? []).map((p) => p.id == project.id ? project : p).toList(),
    );
  }

  Future<void> deleteProject(Project project) async {
    final repo = ref.read(projectRepositoryProvider);
    await repo.deleteProject(project);
    state = AsyncData(
      (state.valueOrNull ?? []).where((p) => p.id != project.id).toList(),
    );
  }

  Future<String> gitCommit(Project project, String message) async {
    return ref.read(projectRepositoryProvider).gitCommit(project, message);
  }

  Future<String> gitPush(Project project) async {
    return ref.read(projectRepositoryProvider).gitPush(project);
  }

  Future<String> gitPull(Project project) async {
    return ref.read(projectRepositoryProvider).gitPull(project);
  }

  Future<String> gitStatus(Project project) async {
    return ref.read(projectRepositoryProvider).gitStatus(project);
  }

  Future<String> gitLog(Project project) async {
    return ref.read(projectRepositoryProvider).gitLog(project);
  }

  Future<bool> setRemote(Project project, String remoteUrl) async {
    final ok = await ref.read(projectRepositoryProvider).setRemote(project, remoteUrl);
    if (ok) {
      final updated = project.copyWith(remoteUrl: remoteUrl);
      await updateProject(updated);
    }
    return ok;
  }
}
