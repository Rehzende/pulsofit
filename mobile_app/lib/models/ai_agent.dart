enum AgentActionStatus {
  NONE,
  PENDING,
  APPROVED,
  REJECTED,
  EXECUTED
}

class AgentMessage {
  final String id;
  final String sessionId;
  final String role;
  final String? content;
  final List<dynamic>? toolCalls;
  final String? toolCallId;
  final AgentActionStatus actionStatus;
  final Map<String, dynamic>? actionData;
  final DateTime createdAt;

  AgentMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
    required this.actionStatus,
    this.actionData,
    required this.createdAt,
  });

  factory AgentMessage.fromJson(Map<String, dynamic> json) {
    return AgentMessage(
      id: json['id'],
      sessionId: json['session_id'],
      role: json['role'],
      content: json['content'],
      toolCalls: json['tool_calls'],
      toolCallId: json['tool_call_id'],
      actionStatus: _parseStatus(json['action_status']),
      actionData: json['action_data'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  static AgentActionStatus _parseStatus(String? status) {
    switch (status) {
      case 'PENDING': return AgentActionStatus.PENDING;
      case 'APPROVED': return AgentActionStatus.APPROVED;
      case 'REJECTED': return AgentActionStatus.REJECTED;
      case 'EXECUTED': return AgentActionStatus.EXECUTED;
      default: return AgentActionStatus.NONE;
    }
  }
}

class AgentSession {
  final String id;
  final String trainerId;
  final String? title;
  final List<AgentMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  AgentSession({
    required this.id,
    required this.trainerId,
    this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AgentSession.fromJson(Map<String, dynamic> json) {
    return AgentSession(
      id: json['id'],
      trainerId: json['trainer_id'],
      title: json['title'],
      messages: (json['messages'] as List? ?? [])
          .map((m) => AgentMessage.fromJson(m))
          .toList(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
