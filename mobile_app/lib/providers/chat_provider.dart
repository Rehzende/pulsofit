import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService;
  final AuthProvider? _authProvider;

  ChatProvider(this._chatService, [this._authProvider]);

  List<ChatConversation> _conversations = [];
  ChatConversationDetail? _currentConversation;
  List<ChatMessage> _messages = [];
  bool _loading = false;
  String? _error;
  Timer? _pollingTimer;
  Timer? _conversationsPollingTimer;
  List<Map<String, dynamic>> _availableTrainers = [];

  // Getters
  List<ChatConversation> get conversations => _conversations;
  ChatConversationDetail? get currentConversation => _currentConversation;
  List<ChatMessage> get messages => _messages;
  bool get loading => _loading;
  String? get error => _error;
  List<Map<String, dynamic>> get availableTrainers => _availableTrainers;
  bool get isTrainer => _authProvider?.isTrainer ?? false;

  Future<void> fetchConversations() async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      debugPrint('📱 ChatProvider: Fetching conversations...');
      _conversations = await _chatService.fetchConversations();
      debugPrint('✅ ChatProvider: Got ${_conversations.length} conversations');
      _error = null;
    } catch (e) {
      _error = 'Falha ao carregar conversas: $e';
      debugPrint('❌ Chat error: $_error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchConversation(String conversationId) async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      debugPrint('📱 ChatProvider: Fetching conversation $conversationId...');
      _currentConversation = await _chatService.fetchConversation(conversationId);
      _messages = _currentConversation?.messages ?? [];

      debugPrint('✅ ChatProvider: Got ${_messages.length} messages');

      // Mark unread messages as read
      for (final msg in _messages) {
        if (!msg.isRead) {
          await markAsRead(msg.id);
        }
      }

      _error = null;
    } catch (e) {
      _error = 'Falha ao carregar conversa: $e';
      print('Chat error: $_error');
    } finally {
      _loading = false;
      notifyListeners();
    }

    // Start polling for new messages
    _startPolling(conversationId);
  }

  Future<void> sendMessage(String conversationId, String body) async {
    if (body.trim().isEmpty) {
      debugPrint('⚠️ ChatProvider: Message body is empty, ignoring');
      return;
    }

    _error = null;
    _loading = true;
    notifyListeners();

    try {
      debugPrint('📤 ChatProvider: Sending message to conversation: $conversationId');
      debugPrint('📝 Message body: $body');

      final message = await _chatService.sendMessage(conversationId, body);
      debugPrint('✅ ChatProvider: Message sent successfully: ${message.id}');

      _messages.add(message);
      debugPrint('📢 sendMessage: Added message to list, notifying listeners (${_messages.length} total)');
      notifyListeners();  // Notify immediately after adding message

      // Update conversation locally instead of full reload to avoid race condition with polling
      final convIndex = _conversations.indexWhere((c) => c.id == conversationId);
      if (convIndex >= 0) {
        // Move conversation to top and update last message
        final conv = _conversations[convIndex];
        _conversations.removeAt(convIndex);
        _conversations.insert(0, ChatConversation(
          id: conv.id,
          otherUserId: conv.otherUserId,
          otherUserName: conv.otherUserName,
          otherUserPhotoUrl: conv.otherUserPhotoUrl,
          lastMessageBody: body,
          lastMessageAt: DateTime.now(),
          unreadCount: 0,
          isFromTrainer: conv.isFromTrainer,
        ));
      }

      _error = null;
    } catch (e) {
      _error = 'Falha ao enviar mensagem: $e';
      debugPrint('❌ Chat error: $_error');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String messageId) async {
    try {
      await _chatService.markAsRead(messageId);

      // Update local message state
      _messages = _messages.map((msg) {
        if (msg.id == messageId) {
          return ChatMessage(
            id: msg.id,
            conversationId: msg.conversationId,
            senderId: msg.senderId,
            senderName: msg.senderName,
            body: msg.body,
            isRead: true,
            createdAt: msg.createdAt,
            readAt: DateTime.now(),
          );
        }
        return msg;
      }).toList();

      notifyListeners();
    } catch (e) {
      print('Failed to mark message as read: $e');
    }
  }

  void _startPolling(String conversationId) {
    // Stop existing polling
    _pollingTimer?.cancel();

    debugPrint('⏱️ Polling: STARTED for conversation $conversationId');

    // Poll every 1 second for new messages (incremental, not full reload)
    _pollingTimer = Timer.periodic(Duration(seconds: 1), (_) {
      debugPrint('⏱️ Polling: Timer tick for conversation $conversationId');
      _pollMessages(conversationId);
    });
  }

  Future<void> _pollMessages(String conversationId) async {
    try {
      debugPrint('🔍 PollMessages: Checking conversation $conversationId, current=${_currentConversation?.id}');

      // Verify we're still in this conversation (avoid mixing messages from different chats)
      if (_currentConversation?.id != conversationId) {
        debugPrint('⚠️ Polling: Conversation changed, ignoring old polling for $conversationId');
        return;
      }

      debugPrint('🔍 PollMessages: Fetching conversation from service...');
      final updated = await _chatService.fetchConversation(conversationId);

      // Capture old length before updating
      final oldLength = _messages.length;
      final newLength = updated.messages.length;

      debugPrint('🔍 PollMessages: Got ${newLength} messages from service (had ${oldLength})');

      // Only update if there are new messages (compare count and timestamps)
      if (newLength > oldLength) {
        // New messages arrived - only add the ones not already in local list
        // This preserves locally-sent messages and prevents duplicates
        final localIds = _messages.map((m) => m.id).toSet();
        final newMessages = updated.messages.where((m) => !localIds.contains(m.id)).toList();
        _messages.addAll(newMessages);
        _currentConversation = updated;
        debugPrint('✅ Polling: Found ${newMessages.length} new message(s) (${_messages.length} total)');
        debugPrint('📢 Polling: NOTIFYING LISTENERS');
        notifyListeners();
        debugPrint('📢 Polling: NOTIFIED LISTENERS');
      } else if (updated.unreadCount != (_currentConversation?.unreadCount ?? 0)) {
        // Read receipts changed, update metadata only
        _currentConversation = updated;
        debugPrint('📢 Polling: Read receipt changed, NOTIFYING LISTENERS');
        notifyListeners();
        debugPrint('📢 Polling: NOTIFIED LISTENERS for read receipts');
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void startConversationsPolling() {
    // Stop existing polling
    _conversationsPollingTimer?.cancel();

    debugPrint('⏱️ ConversationsPolling: STARTED');

    // Poll every 2 seconds for updated conversations list
    _conversationsPollingTimer = Timer.periodic(Duration(seconds: 2), (_) {
      _pollConversations();
    });
  }

  Future<void> _pollConversations() async {
    try {
      debugPrint('🔍 PollConversations: Fetching conversations...');
      final updated = await _chatService.fetchConversations();

      final oldLength = _conversations.length;
      final newLength = updated.length;

      debugPrint('🔍 PollConversations: Got ${newLength} conversations (had ${oldLength})');

      // Update conversations list
      _conversations = updated;
      debugPrint('📢 PollConversations: NOTIFYING LISTENERS');
      notifyListeners();
      debugPrint('📢 PollConversations: NOTIFIED LISTENERS');
    } catch (e) {
      debugPrint('PollConversations error: $e');
    }
  }

  void stopConversationsPolling() {
    _conversationsPollingTimer?.cancel();
    _conversationsPollingTimer = null;
    debugPrint('⏱️ ConversationsPolling: STOPPED');
  }

  void selectConversation(ChatConversation conversation) {
    fetchConversation(conversation.id);
  }

  void clearCurrentConversation() {
    _currentConversation = null;
    _messages = [];
    _stopPolling();
    notifyListeners();
  }

  Future<void> fetchAvailableTrainers() async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final isTrainer = _authProvider?.isTrainer ?? false;

      if (isTrainer) {
        debugPrint('📱 ChatProvider: Fetching available students...');
        _availableTrainers = await _chatService.fetchAvailableStudents();
        debugPrint('✅ ChatProvider: Got ${_availableTrainers.length} available students');
      } else {
        debugPrint('📱 ChatProvider: Fetching available trainers...');
        _availableTrainers = await _chatService.fetchAvailableTrainers();
        debugPrint('✅ ChatProvider: Got ${_availableTrainers.length} available trainers');
      }
      _error = null;
    } catch (e) {
      _error = 'Falha ao carregar contatos: $e';
      debugPrint('❌ Chat error: $_error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Open conversation by ID (if already exists) or create new with trainer/student ID
  Future<ChatConversation?> openOrCreateConversation({
    required String contactId,
    String? existingConversationId,
  }) async {
    _error = null;
    _loading = true;
    notifyListeners();

    try {
      // If conversation already exists, use it directly
      if (existingConversationId != null && existingConversationId.isNotEmpty) {
        debugPrint('📱 ChatProvider: Opening existing conversation: $existingConversationId');
        await fetchConversation(existingConversationId);
        
        // Find and return the conversation from the list
        return _conversations.firstWhere(
          (c) => c.id == existingConversationId,
          orElse: () => _conversations.first,
        );
      } else {
        // Create new conversation
        debugPrint('📱 ChatProvider: Creating new conversation with contact: $contactId');
        return await startConversation(contactId);
      }
    } catch (e) {
      _error = 'Falha ao abrir conversa: $e';
      debugPrint('❌ Chat error: $_error');
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<ChatConversation?> startConversation(String contactId) async {
    _error = null;
    _loading = true;
    notifyListeners();

    try {
      final isTrainer = _authProvider?.isTrainer ?? false;
      debugPrint('📱 ChatProvider: Starting conversation with contact: $contactId (isTrainer: $isTrainer)');

      try {
        debugPrint('📱 ChatProvider: Calling createOrGetConversation($contactId, isTrainer: $isTrainer)');
        final conversation = await _chatService.createOrGetConversation(
          contactId: contactId,
          isTrainer: isTrainer,
        );

        // Check if conversation already exists in list
        if (!_conversations.any((c) => c.id == conversation.id)) {
          _conversations.insert(0, conversation);
        }

        debugPrint('✅ ChatProvider: Conversation started');
        notifyListeners();

        // Fetch the new conversation to get details
        await fetchConversation(conversation.id);
        return conversation;
      } catch (e) {
        // If 403 (not linked), try linking first
        if (e.toString().contains('403')) {
          debugPrint('📱 ChatProvider: Not linked to trainer, attempting to link...');
          await _chatService.linkTrainer(contactId);
          debugPrint('✅ ChatProvider: Trainer linked, retrying conversation...');

          // Retry creating conversation
          final conversation = await _chatService.createOrGetConversation(
            contactId: contactId,
            isTrainer: isTrainer,
          );

          if (!_conversations.any((c) => c.id == conversation.id)) {
            _conversations.insert(0, conversation);
          }

          debugPrint('✅ ChatProvider: Conversation started after linking');
          notifyListeners();

          await fetchConversation(conversation.id);
          return conversation;
        } else {
          rethrow;
        }
      }
    } catch (e) {
      _error = 'Falha ao iniciar conversa: $e';
      debugPrint('❌ Chat error: $_error');
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    stopConversationsPolling();
    super.dispose();
  }
}
