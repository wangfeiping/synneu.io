class Note {
  final String id;
  final String title;
  final String content;
  final String projectId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String filePath;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.projectId,
    required this.createdAt,
    required this.updatedAt,
    required this.filePath,
  });

  Note copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    String? filePath,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      projectId: projectId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      filePath: filePath ?? this.filePath,
    );
  }
}
