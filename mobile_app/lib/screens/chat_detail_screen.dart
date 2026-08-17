import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../models/chat_model.dart';
import '../providers/auth_provider.dart';
import '../core/constants.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatConversation conversation;

  const ChatDetailScreen({
    Key? key,
    required this.conversation,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late TextEditingController _messageController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('Loading conversation: ${widget.conversation.id}');
      context.read<ChatProvider>().selectConversation(widget.conversation);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.conversation.otherUserName ?? 'Conversa',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: const Color(AppConstants.cardDark),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                debugPrint('🔄 ChatDetailScreen.Consumer REBUILDING: loading=${chatProvider.loading}, messages=${chatProvider.messages.length}');

                if (chatProvider.loading && chatProvider.messages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (chatProvider.error != null && chatProvider.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Erro ao carregar mensagens',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          chatProvider.error ?? 'Erro desconhecido',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => chatProvider.selectConversation(widget.conversation),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  );
                }

                if (chatProvider.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mail_outline,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma mensagem ainda',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Comece a conversa enviando uma mensagem',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                // Scroll to bottom when messages change
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (context, index) {
                    final message = chatProvider.messages[index];
                    final isOwnMessage = message.senderId == currentUserId;

                    return ChatMessageBubble(
                      message: message,
                      isOwnMessage: isOwnMessage,
                    );
                  },
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(AppConstants.cardDark),
              border: Border(
                top: BorderSide(
                  color: const Color(AppConstants.borderColor),
                ),
              ),
            ),
            child: SafeArea(
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Digite uma mensagem...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(AppConstants.borderColor),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(AppConstants.borderColor),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(AppConstants.neonAccent),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(AppConstants.primaryDark),
                          ),
                          enabled: true,  // Always allow typing, even if loading
                          maxLines: null,
                          minLines: 1,
                          style: const TextStyle(color: Color(AppConstants.textPrimary)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: const Color(AppConstants.neonAccent),
                        borderRadius: BorderRadius.circular(50),
                        child: InkWell(
                          onTap: () async {
                            if (_messageController.text.isEmpty) {
                              debugPrint('⚠️ ChatDetailScreen: Message is empty');
                              return;
                            }

                                  if (widget.conversation.id.isEmpty) {
                                    debugPrint('❌ ChatDetailScreen: conversation.id is empty!');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Erro: ID da conversa inválido'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  debugPrint('📤 ChatDetailScreen: Sending message to conversation ${widget.conversation.id}');
                                  final message = _messageController.text;
                                  _messageController.clear();

                                  // Refresh UI after clearing
                                  if (mounted) {
                                    (context as Element).markNeedsBuild();
                                  }

                                  try {
                                    await chatProvider.sendMessage(
                                      widget.conversation.id,
                                      message,
                                    );

                                    if (mounted && chatProvider.error != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(chatProvider.error!),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('❌ ChatDetailScreen: Error sending message: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erro ao enviar: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          borderRadius: BorderRadius.circular(50),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: chatProvider.loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(AppConstants.primaryDark),
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send,
                                      color: Color(AppConstants.primaryDark),
                                      size: 20,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwnMessage;

  const ChatMessageBubble({
    Key? key,
    required this.message,
    required this.isOwnMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isOwnMessage
                ? Colors.blue[500]
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: isOwnMessage
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isOwnMessage)
                Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                message.body,
                style: TextStyle(
                  color: isOwnMessage ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isOwnMessage
                          ? Colors.white70
                          : Colors.grey[600],
                    ),
                  ),
                  if (isOwnMessage) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead
                          ? Icons.done_all
                          : Icons.done,
                      size: 12,
                      color: message.isRead
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
