import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../domain/project.dart';

class ProjectRepository {
  static const _projectsKey = 'synneu_projects';
  final _uuid = const Uuid();

  Future<String> get _baseDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'synneu_projects'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<List<Project>> loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_projectsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveProjects(List<Project> projects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _projectsKey,
      jsonEncode(projects.map((p) => p.toJson()).toList()),
    );
  }

  Future<Project> createProject(String name) async {
    final base = await _baseDir;
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final projectPath = p.join(base, safeName);
    final dir = Directory(projectPath);
    if (!await dir.exists()) await dir.create(recursive: true);

    // git init (may not be available on all platforms)
    final gitResult = await _runGit(['init'], workingDirectory: projectPath);
    final isGitRepo = gitResult != null && gitResult.exitCode == 0;

    final project = Project(
      id: _uuid.v4(),
      name: name,
      path: projectPath,
      isGitRepo: isGitRepo,
      createdAt: DateTime.now(),
    );

    final projects = await loadProjects();
    projects.add(project);
    await _saveProjects(projects);
    return project;
  }

  Future<Project> updateProject(Project project) async {
    final projects = await loadProjects();
    final idx = projects.indexWhere((p) => p.id == project.id);
    if (idx >= 0) projects[idx] = project;
    await _saveProjects(projects);
    return project;
  }

  Future<void> deleteProject(Project project) async {
    final projects = await loadProjects();
    projects.removeWhere((p) => p.id == project.id);
    await _saveProjects(projects);
  }

  // ── Git operations ──────────────────────────────────────────────

  /// 统一封装 git 子进程调用，捕获平台不支持时的权限异常。
  /// 返回 null 表示无法执行 git（如 Android 限制）。
  Future<ProcessResult?> _runGit(
    List<String> args, {
    required String workingDirectory,
    Map<String, String>? environment,
  }) async {
    try {
      return await Process.run(
        'git', args,
        workingDirectory: workingDirectory,
        environment: environment,
      );
    } catch (e) {
      debugPrint('git ${args.first} unavailable: $e');
      return null;
    }
  }

  Future<bool> gitAdd(Project project, String filePath) async {
    final result = await _runGit(['add', filePath], workingDirectory: project.path);
    return result != null && result.exitCode == 0;
  }

  Future<String> gitCommit(Project project, String message) async {
    final env = <String, String>{};
    if (project.gitUserName != null) {
      env['GIT_AUTHOR_NAME'] = project.gitUserName!;
      env['GIT_COMMITTER_NAME'] = project.gitUserName!;
    }
    if (project.gitUserEmail != null) {
      env['GIT_AUTHOR_EMAIL'] = project.gitUserEmail!;
      env['GIT_COMMITTER_EMAIL'] = project.gitUserEmail!;
    }
    final result = await _runGit(
      ['commit', '-m', message],
      workingDirectory: project.path,
      environment: env,
    );
    if (result == null) return 'git 在此平台不可用';
    if (result.exitCode == 0) return result.stdout as String;
    return result.stderr as String;
  }

  Future<String> gitStatus(Project project) async {
    final result = await _runGit(['status', '--short'], workingDirectory: project.path);
    if (result == null) return '';
    return result.stdout as String;
  }

  Future<String> gitLog(Project project) async {
    final result = await _runGit(['log', '--oneline', '-10'], workingDirectory: project.path);
    if (result == null) return '';
    return result.stdout as String;
  }

  Future<String> gitPush(Project project) async {
    final result = await _runGit(['push'], workingDirectory: project.path);
    if (result == null) return 'git 在此平台不可用';
    if (result.exitCode == 0) return result.stdout as String;
    return result.stderr as String;
  }

  Future<String> gitPull(Project project) async {
    final result = await _runGit(['pull'], workingDirectory: project.path);
    if (result == null) return 'git 在此平台不可用';
    if (result.exitCode == 0) return result.stdout as String;
    return result.stderr as String;
  }

  Future<bool> setRemote(Project project, String remoteUrl) async {
    // 先移除旧 remote（忽略失败）
    await _runGit(['remote', 'remove', 'origin'], workingDirectory: project.path);
    final result = await _runGit(
      ['remote', 'add', 'origin', remoteUrl],
      workingDirectory: project.path,
    );
    return result != null && result.exitCode == 0;
  }
}
