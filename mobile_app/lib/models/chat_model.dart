class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String? ?? 'Unknown',
      body: json['body'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'body': body,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }
}

class ChatConversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isFromTrainer;

  ChatConversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
    this.lastMessageBody,
    this.lastMessageAt,
    required this.unreadCount,
    required this.isFromTrainer,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      otherUserId: json['other_user_id'] as String,
      otherUserName: json['other_user_name'] as String? ?? 'Unknown',
      otherUserPhotoUrl: json['other_user_photo_url'] as String?,
      lastMessageBody: json['last_message_body'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      isFromTrainer: json['is_from_trainer'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'other_user_id': otherUserId,
      'other_user_name': otherUserName,
      'other_user_photo_url': otherUserPhotoUrl,
      'last_message_body': lastMessageBody,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'unread_count': unreadCount,
      'is_from_trainer': isFromTrainer,
    };
  }
}

class ChatConversationDetail {
  final String id;
  final String studentId;
  final String trainerId;
  final String? studentName;
  final String? trainerName;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final List<ChatMessage> messages;
  final int unreadCount;

  ChatConversationDetail({
    required this.id,
    required this.studentId,
    required this.trainerId,
    this.studentName,
    this.trainerName,
    required this.createdAt,
    this.lastMessageAt,
    required this.messages,
    required this.unreadCount,
  });

  factory ChatConversationDetail.fromJson(Map<String, dynamic> json) {
    return ChatConversationDetail(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      trainerId: json['trainer_id'] as String,
      studentName: json['student_name'] as String?,
      trainerName: json['trainer_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      messages: (json['messages'] as List?)
          ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'trainer_id': trainerId,
      'student_name': studentName,
      'trainer_name': trainerName,
      'created_at': createdAt.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'unread_count': unreadCount,
    };
  }
}
