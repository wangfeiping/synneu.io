class Project {
  final String id;
  final String name;
  final String path;
  final bool isGitRepo;
  final String? remoteUrl;
  final String? gitUserName;
  final String? gitUserEmail;
  final DateTime createdAt;

  const Project({
    required this.id,
    required this.name,
    required this.path,
    required this.isGitRepo,
    this.remoteUrl,
    this.gitUserName,
    this.gitUserEmail,
    required this.createdAt,
  });

  Project copyWith({
    String? name,
    String? remoteUrl,
    String? gitUserName,
    String? gitUserEmail,
    bool? isGitRepo,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      path: path,
      isGitRepo: isGitRepo ?? this.isGitRepo,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      gitUserName: gitUserName ?? this.gitUserName,
      gitUserEmail: gitUserEmail ?? this.gitUserEmail,
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
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
