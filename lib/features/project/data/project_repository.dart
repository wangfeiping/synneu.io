import 'dart:convert';
import 'dart:developer' as dev;
import 'package:git2dart/git2dart.dart';
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
    return p.join(appDir.path, 'synneu_projects');
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
      jsonEncode(projects.map((pp) => pp.toJson()).toList()),
    );
  }

  Future<Project> createProject(String name) async {
    final base = await _baseDir;
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final projectPath = p.join(base, safeName);

    bool isGitRepo = false;
    try {
      Repository.init(path: projectPath);
      isGitRepo = true;
      dev.log('OK: git init $projectPath', name: 'git');
    } catch (e, st) {
      dev.log(
        'git init 异常，项目将以非 git 模式创建: $e',
        name: 'git',
        level: 1000,
        error: e,
        stackTrace: st,
      );
    }

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
    final idx = projects.indexWhere((pp) => pp.id == project.id);
    if (idx >= 0) projects[idx] = project;
    await _saveProjects(projects);
    return project;
  }

  Future<void> deleteProject(Project project) async {
    final projects = await loadProjects();
    projects.removeWhere((pp) => pp.id == project.id);
    await _saveProjects(projects);
  }

  // ── Git helpers ──────────────────────────────────────────────────

  Repository _openRepo(Project project) {
    try {
      return Repository.open(project.path);
    } catch (e, st) {
      dev.log(
        'ERROR: 无法打开 git 仓库 ${project.path}: $e',
        name: 'git',
        level: 1000,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Signature _signature(Project project) {
    return Signature.create(
      name: project.gitUserName ?? 'Synneu User',
      email: project.gitUserEmail ?? 'user@synneu.io',
    );
  }

  Callbacks _callbacks(Project project) {
    final token = project.gitToken;
    if (token == null || token.isEmpty) {
      dev.log(
        'WARN: 未配置 Access Token，将以匿名方式请求（私有仓库会 401）',
        name: 'git',
        level: 900,
      );
      return const Callbacks();
    }
    final username = project.gitUserName ?? 'git';
    dev.log('使用 Basic Auth 认证 (username: $username)', name: 'git');
    return Callbacks(
      credentials: UserPass(username: username, password: token),
    );
  }

  // ── Git operations ───────────────────────────────────────────────

  /// git add filePath。失败时抛出异常。
  Future<void> gitAdd(Project project, String filePath) async {
    final relativePath = p.relative(filePath, from: project.path);
    dev.log('执行: git add $relativePath', name: 'git');
    try {
      final repo = _openRepo(project);
      final index = repo.index;
      index.add(relativePath);
      index.write();
      dev.log('OK: git add $relativePath', name: 'git');
    } catch (e, st) {
      dev.log(
        'ERROR: git add $relativePath -> $e',
        name: 'git',
        level: 1000,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// git commit -m message。失败时抛出异常，成功返回 "shortHash message"。
  Future<String> gitCommit(Project project, String message) async {
    dev.log('执行: git commit -m "$message"', name: 'git');
    try {
      final repo = _openRepo(project);
      final sig = _signature(project);
      final index = repo.index;
      final tree = Tree.lookup(repo: repo, oid: index.writeTree());

      final Oid oid;
      if (repo.isEmpty || repo.isBranchUnborn) {
        // 首次提交，无父 commit
        dev.log('首次提交（无父 commit）', name: 'git');
        oid = Commit.create(
          repo: repo,
          updateRef: 'refs/heads/main',
          author: sig,
          committer: sig,
          message: message,
          tree: tree,
          parents: [],
        );
      } else {
        final parent = Commit.lookup(repo: repo, oid: repo.head.target);
        oid = Commit.create(
          repo: repo,
          updateRef: 'HEAD',
          author: sig,
          committer: sig,
          message: message,
          tree: tree,
          parents: [parent],
        );
      }
      final shortHash = oid.sha.substring(0, 7);
      dev.log('OK: git commit -> $shortHash $message', name: 'git');
      return '$shortHash $message';
    } catch (e, st) {
      dev.log(
        'ERROR: git commit -> $e',
        name: 'git',
        level: 1000,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// git status。失败时返回错误文本，同时记录 WARN 日志。
  Future<String> gitStatus(Project project) async {
    dev.log('执行: git status', name: 'git');
    try {
      final repo = _openRepo(project);
      final status = repo.status;
      if (status.isEmpty) {
        dev.log('OK: git status -> 无变更', name: 'git');
        return '(无变更)';
      }
      final output = status.entries.map((e) {
        final flags = e.value.map(_statusFlag).join('');
        return '$flags ${e.key}';
      }).join('\n');
      dev.log('OK: git status\n$output', name: 'git');
      return output;
    } catch (e, st) {
      dev.log(
        'WARN: git status -> $e',
        name: 'git',
        level: 900,
        error: e,
        stackTrace: st,
      );
      return 'git status 失败: $e';
    }
  }

  String _statusFlag(GitStatus s) {
    switch (s) {
      case GitStatus.indexNew:
        return 'A';
      case GitStatus.indexModified:
        return 'M';
      case GitStatus.indexDeleted:
        return 'D';
      case GitStatus.wtModified:
        return 'm';
      case GitStatus.wtNew:
        return '?';
      case GitStatus.wtDeleted:
        return 'd';
      default:
        return s.name.substring(0, 1);
    }
  }

  /// git log --oneline -10。失败时返回错误文本，同时记录 WARN 日志。
  Future<String> gitLog(Project project) async {
    dev.log('执行: git log', name: 'git');
    try {
      final repo = _openRepo(project);
      if (repo.isEmpty || repo.isBranchUnborn) {
        return '(暂无提交)';
      }
      final commits = repo.log(oid: repo.head.target).take(10).toList();
      if (commits.isEmpty) return '(暂无提交)';
      final output = commits.map((c) {
        final hash = c.oid.sha.substring(0, 7);
        final msg = c.message.split('\n').first.trim();
        return '$hash $msg';
      }).join('\n');
      dev.log('OK: git log\n$output', name: 'git');
      return output;
    } catch (e, st) {
      dev.log(
        'WARN: git log -> $e',
        name: 'git',
        level: 900,
        error: e,
        stackTrace: st,
      );
      return 'git log 失败: $e';
    }
  }

  /// git push。失败时抛出异常，成功返回输出。
  Future<String> gitPush(Project project) async {
    dev.log('执行: git push origin', name: 'git');
    try {
      final repo = _openRepo(project);
      final branch = repo.head.shorthand;
      final refspec = 'refs/heads/$branch:refs/heads/$branch';
      dev.log('push refspec: $refspec', name: 'git');
      final remote = Remote.lookup(repo: repo, name: 'origin');
      remote.push(
        refspecs: [refspec],
        callbacks: _callbacks(project),
      );
      dev.log('OK: git push', name: 'git');
      return 'git push 成功 ($branch)';
    } catch (e, st) {
      dev.log(
        'ERROR: git push -> $e',
        name: 'git',
        level: 1000,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// git pull（fetch + fast-forward merge）。失败时抛出异常，成功返回输出。
  Future<String> gitPull(Project project) async {
    dev.log('执行: git pull origin', name: 'git');
    try {
      final repo = _openRepo(project);
      final branch = repo.head.shorthand;
      final callbacks = _callbacks(project);

      // Step 1: fetch
      dev.log('fetch from origin...', name: 'git');
      final remote = Remote.lookup(repo: repo, name: 'origin');
      remote.fetch(callbacks: callbacks);
      dev.log('fetch 完成', name: 'git');

      // Step 2: 尝试快进合并
      final remoteRefName = 'refs/remotes/origin/$branch';
      try {
        final remoteRef = Reference.lookup(repo: repo, name: remoteRefName);
        final analysis = Merge.analysis(repo: repo, theirHead: remoteRef.target);
        dev.log('merge analysis: ${analysis.result}', name: 'git');

        if (analysis.result.contains(GitMergeAnalysis.upToDate)) {
          dev.log('OK: 已是最新', name: 'git');
          return '已是最新（up-to-date）';
        } else if (analysis.result.contains(GitMergeAnalysis.fastForward)) {
          // 快进：直接移动分支指针
          Reference.setTarget(
            repo: repo,
            name: 'refs/heads/$branch',
            target: remoteRef.target,
            logMessage: 'pull: Fast-forward',
          );
          Checkout.head(repo: repo, strategy: {GitCheckout.force});
          dev.log('OK: git pull fast-forward', name: 'git');
          return 'git pull 成功（Fast-forward）';
        } else {
          throw Exception(
            'pull 需要合并（非快进）操作，请手动处理冲突后再试',
          );
        }
      } on Git2DartError catch (e) {
        // 远端引用不存在（首次 fetch）
        dev.log('远端引用 $remoteRefName 不存在: $e', name: 'git', level: 900);
        return 'fetch 完成（首次拉取，无本地变更）';
      }
    } catch (e, st) {
      dev.log(
        'ERROR: git pull -> $e',
        name: 'git',
        level: 1000,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// git remote add/set-url origin remoteUrl。失败时抛出异常。
  Future<void> setRemote(Project project, String remoteUrl) async {
    dev.log('执行: git remote set-url origin $remoteUrl', name: 'git');
    try {
      final repo = _openRepo(project);
      // 先尝试删除旧 remote（可能不存在，忽略失败）
      try {
        Remote.delete(repo: repo, name: 'origin');
        dev.log('git remote delete origin OK', name: 'git');
      } catch (e) {
        dev.log('git remote delete 忽略（可能不存在）: $e', name: 'git');
      }
      Remote.create(repo: repo, name: 'origin', url: remoteUrl);
      dev.log('OK: git remote add origin $remoteUrl', name: 'git');
    } catch (e, st) {
      dev.log(
        'ERROR: git remote -> $e',
        name: 'git',
        level: 1000,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// git init。失败时抛出异常。
  Future<void> gitInit(Project project) async {
    dev.log('执行: git init ${project.path}', name: 'git');
    try {
      Repository.init(path: project.path);
      dev.log('OK: git init', name: 'git');
    } catch (e, st) {
      dev.log(
        'ERROR: git init -> $e',
        name: 'git',
        level: 1000,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
