import 'dart:convert';
import 'dart:io';
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

    // git init
    final result = await Process.run('git', ['init'], workingDirectory: projectPath);
    final isGitRepo = result.exitCode == 0;

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

  Future<bool> gitAdd(Project project, String filePath) async {
    final result = await Process.run(
      'git', ['add', filePath],
      workingDirectory: project.path,
    );
    return result.exitCode == 0;
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

    final result = await Process.run(
      'git', ['commit', '-m', message],
      workingDirectory: project.path,
      environment: env,
    );
    if (result.exitCode == 0) return result.stdout as String;
    return result.stderr as String;
  }

  Future<String> gitStatus(Project project) async {
    final result = await Process.run(
      'git', ['status', '--short'],
      workingDirectory: project.path,
    );
    return result.stdout as String;
  }

  Future<String> gitLog(Project project) async {
    final result = await Process.run(
      'git', ['log', '--oneline', '-10'],
      workingDirectory: project.path,
    );
    return result.stdout as String;
  }

  Future<String> gitPush(Project project) async {
    final result = await Process.run(
      'git', ['push'],
      workingDirectory: project.path,
    );
    if (result.exitCode == 0) return result.stdout as String;
    return result.stderr as String;
  }

  Future<String> gitPull(Project project) async {
    final result = await Process.run(
      'git', ['pull'],
      workingDirectory: project.path,
    );
    if (result.exitCode == 0) return result.stdout as String;
    return result.stderr as String;
  }

  Future<bool> setRemote(Project project, String remoteUrl) async {
    // 先移除旧 remote
    await Process.run('git', ['remote', 'remove', 'origin'],
        workingDirectory: project.path);
    final result = await Process.run(
      'git', ['remote', 'add', 'origin', remoteUrl],
      workingDirectory: project.path,
    );
    return result.exitCode == 0;
  }
}
