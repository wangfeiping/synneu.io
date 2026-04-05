/// 一条聊天消息
class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;
  final bool isStreaming;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
    this.isStreaming = false,
  });

  ChatMessage copyWith({String? content, bool? isStreaming}) => ChatMessage(
        role: role,
        content: content ?? this.content,
        createdAt: createdAt,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

/// 会话摘要（用于列表展示）
class ChatSession {
  final String key;
  final String? title;
  final String? lastMessage;
  final DateTime? lastActivity;
  final String? agentId;

  const ChatSession({
    required this.key,
    this.title,
    this.lastMessage,
    this.lastActivity,
    this.agentId,
  });

  String get displayTitle => title?.isNotEmpty == true ? title! : key;

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        key: json['key'] as String? ?? json['sessionKey'] as String? ?? '',
        title: json['title'] as String?,
        lastMessage: json['lastMessage'] as String?,
        lastActivity: json['lastActivity'] != null
            ? DateTime.tryParse(json['lastActivity'] as String)
            : null,
        agentId: json['agentId'] as String?,
      );
}
