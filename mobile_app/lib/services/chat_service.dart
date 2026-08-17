import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../core/constants.dart';

class ChatService {
  final Dio _dio;

  ChatService(this._dio);

  Future<List<ChatConversation>> fetchConversations() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/chat/conversations');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ChatConversation.fromJson(json as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to fetch conversations');
    } catch (e) {
      rethrow;
    }
  }

  Future<ChatConversationDetail> fetchConversation(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '${AppConstants.baseUrl}/chat/conversations/$conversationId/messages',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );

      if (response.statusCode == 200) {
        return ChatConversationDetail.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Failed to fetch conversation');
    } catch (e) {
      rethrow;
    }
  }

  Future<ChatMessage> sendMessage(String conversationId, String body) async {
    try {
      debugPrint('📤 ChatService: Sending message');
      debugPrint('   conversation_id: $conversationId');
      debugPrint('   body: ${body.length > 50 ? body.substring(0, 50) + '...' : body}');

      final response = await _dio.post(
        '${AppConstants.baseUrl}/chat/messages',
        data: {
          'conversation_id': conversationId,
          'body': body,
        },
      );

      debugPrint('📤 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final message = ChatMessage.fromJson(response.data as Map<String, dynamic>);
        debugPrint('✅ ChatService: Message created with ID: ${message.id}');
        return message;
      }

      final errorDetail = response.data is Map && response.data.containsKey('detail')
          ? response.data['detail']
          : 'Unknown error';
      throw Exception('Failed to send message (${response.statusCode}): $errorDetail');
    } catch (e) {
      debugPrint('❌ ChatService Error: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String messageId) async {
    try {
      final response = await _dio.patch(
        '${AppConstants.baseUrl}/chat/messages/$messageId/read',
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark message as read');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<ChatConversation> createOrGetConversation({
    required String contactId,
    required bool isTrainer,  // true if current user is trainer, false if student
  }) async {
    try {
      final paramName = isTrainer ? 'student_id' : 'trainer_id';
      debugPrint('📱 ChatService: Creating conversation with $paramName: $contactId');

      final response = await _dio.post(
        '${AppConstants.baseUrl}/chat/conversations',
        queryParameters: {
          paramName: contactId,
        },
      );

      debugPrint('📱 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return ChatConversation.fromJson(response.data as Map<String, dynamic>);
      }

      // Better error message
      String errorDetail = 'Unknown error';
      if (response.data is Map && response.data.containsKey('detail')) {
        errorDetail = response.data['detail'];
      }
      throw Exception('Failed to create conversation (${response.statusCode}): $errorDetail');
    } catch (e) {
      debugPrint('❌ ChatService Error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAvailableTrainers() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/chat/available-trainers');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => json as Map<String, dynamic>).toList();
      }
      throw Exception('Failed to fetch available trainers');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAvailableStudents() async {
    try {
      final response = await _dio.get('${AppConstants.baseUrl}/chat/available-students');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => json as Map<String, dynamic>).toList();
      }
      throw Exception('Failed to fetch available students');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> linkTrainer(String trainerId) async {
    try {
      final response = await _dio.post('${AppConstants.baseUrl}/users/link-trainer/$trainerId');

      if (response.statusCode != 200) {
        throw Exception('Failed to link trainer');
      }
    } catch (e) {
      rethrow;
    }
  }
}
