const _sentinel = Object();

class Project {
  final String id;
  final String name;
  final String path;
  final bool isGitRepo;
  final String? remoteUrl;
  final String? gitUserName;
  final String? gitUserEmail;
  /// HTTPS 认证 Token（如 GitHub Personal Access Token）
  final String? gitToken;
  final DateTime createdAt;

  Project({
    required this.id,
    required this.name,
    required this.path,
    required this.isGitRepo,
    this.remoteUrl,
    this.gitUserName,
    this.gitUserEmail,
    this.gitToken,
    required this.createdAt,
  });

  Project copyWith({
    String? name,
    Object? remoteUrl = _sentinel,
    Object? gitUserName = _sentinel,
    Object? gitUserEmail = _sentinel,
    Object? gitToken = _sentinel,
    bool? isGitRepo,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      path: path,
      isGitRepo: isGitRepo ?? this.isGitRepo,
      remoteUrl: remoteUrl == _sentinel ? this.remoteUrl : remoteUrl as String?,
      gitUserName: gitUserName == _sentinel ? this.gitUserName : gitUserName as String?,
      gitUserEmail: gitUserEmail == _sentinel ? this.gitUserEmail : gitUserEmail as String?,
      gitToken: gitToken == _sentinel ? this.gitToken : gitToken as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'isGitRepo': isGitRepo,
        'remoteUrl': remoteUrl,
        'gitUserName': gitUserName,
        'gitUserEmail': gitUserEmail,
        'gitToken': gitToken,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        isGitRepo: json['isGitRepo'] as bool? ?? false,
        remoteUrl: json['remoteUrl'] as String?,
        gitUserName: json['gitUserName'] as String?,
        gitUserEmail: json['gitUserEmail'] as String?,
        gitToken: json['gitToken'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
