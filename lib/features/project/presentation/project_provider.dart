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

  /// 失败时抛出异常，由 UI 层捕获并展示。
  Future<String> gitCommit(Project project, String message) async {
    return ref.read(projectRepositoryProvider).gitCommit(project, message);
  }

  /// 失败时抛出异常，由 UI 层捕获并展示。
  Future<String> gitPush(Project project) async {
    return ref.read(projectRepositoryProvider).gitPush(project);
  }

  /// 失败时抛出异常，由 UI 层捕获并展示。
  Future<String> gitPull(Project project) async {
    return ref.read(projectRepositoryProvider).gitPull(project);
  }

  Future<String> gitStatus(Project project) async {
    return ref.read(projectRepositoryProvider).gitStatus(project);
  }

  Future<String> gitLog(Project project) async {
    return ref.read(projectRepositoryProvider).gitLog(project);
  }

  /// 运行 git remote add 并将 remoteUrl 持久化到项目。失败时抛出异常。
  Future<void> setRemote(Project project, String remoteUrl) async {
    await ref.read(projectRepositoryProvider).setRemote(project, remoteUrl);
    final updated = project.copyWith(remoteUrl: remoteUrl);
    await updateProject(updated);
  }

  /// 运行 git init 并将 isGitRepo 更新为 true。失败时抛出异常。
  Future<void> initGit(Project project) async {
    await ref.read(projectRepositoryProvider).gitInit(project);
    final updated = project.copyWith(isGitRepo: true);
    await updateProject(updated);
  }
}
