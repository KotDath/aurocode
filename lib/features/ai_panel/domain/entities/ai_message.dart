enum AiMessageRole {
  user,
  assistant,
  system,
}

class AiMessage {
  final String id;
  final String content;
  final AiMessageRole role;
  final DateTime timestamp;

  const AiMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
  });

  AiMessage copyWith({
    String? id,
    String? content,
    AiMessageRole? role,
    DateTime? timestamp,
  }) {
    return AiMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
