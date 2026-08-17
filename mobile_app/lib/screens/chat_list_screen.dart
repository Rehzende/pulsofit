import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../models/chat_model.dart';
import '../core/constants.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.fetchConversations();
      chatProvider.fetchAvailableTrainers();
      // Start polling for conversation updates while on this screen
      chatProvider.startConversationsPolling();
    });
  }

  @override
  void dispose() {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.stopConversationsPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensagens'),
        elevation: 0,
        backgroundColor: const Color(AppConstants.cardDark),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          debugPrint('🔄 ChatListScreen.Consumer REBUILDING: conversations=${chatProvider.conversations.length}');
          if (chatProvider.loading && chatProvider.conversations.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (chatProvider.error != null && chatProvider.conversations.isEmpty) {
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
                    'Erro ao carregar conversas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chatProvider.error ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => chatProvider.fetchConversations(),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          if (chatProvider.conversations.isEmpty) {
            return _EmptyConversationsState();
          }

          return RefreshIndicator(
            onRefresh: () => chatProvider.fetchConversations(),
            child: ListView.separated(
              itemCount: chatProvider.conversations.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final conversation = chatProvider.conversations[index];
                return ConversationListTile(
                  conversation: conversation,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(
                          conversation: conversation,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: Consumer<ChatProvider>(
        builder: (ctx, chatProvider, _) {
          // FAB só aparece para students com trainers disponíveis
          if (chatProvider.isTrainer) return const SizedBox.shrink();
          if (chatProvider.availableTrainers.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: const Color(AppConstants.cardDark),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: _ChatListScreenState._buildTrainerPickerContent(context, chatProvider, isBottomSheet: true),
                ),
              );
            },
            tooltip: 'Nova conversa',
            child: const Icon(Icons.add_comment_outlined),
          );
        },
      ),
    );
  }

  static Widget _buildTrainerPickerContent(BuildContext context, ChatProvider chatProvider, {bool isBottomSheet = false}) {
    return ListView.builder(
      itemCount: chatProvider.availableTrainers.length,
      itemBuilder: (context, index) {
        final trainer = chatProvider.availableTrainers[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              // Open existing conversation or create new one
              final conversation = await chatProvider.openOrCreateConversation(
                contactId: trainer['id'],
                existingConversationId: trainer['conversation_id'],
              );
              
              if (!context.mounted) return;

              // Close bottom sheet if requested
              if (isBottomSheet && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              
              if (conversation != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(
                      conversation: conversation,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue[100],
                    backgroundImage: trainer['photo_url'] != null
                        ? NetworkImage(trainer['photo_url']!)
                        : null,
                    child: trainer['photo_url'] == null
                        ? Text(
                            (trainer['full_name'] != null && trainer['full_name'].toString().isNotEmpty)
                                ? trainer['full_name'][0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                trainer['full_name'] ?? 'Treinador',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (trainer['has_conversation'] == true)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Conversa aberta',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (trainer['brand_name'] != null)
                          Text(
                            trainer['brand_name'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    trainer['has_conversation'] == true ? Icons.chat : Icons.add_circle_outline,
                    size: 24,
                    color: trainer['has_conversation'] == true ? Colors.green : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ConversationListTile extends StatelessWidget {
  final ChatConversation conversation;
  final VoidCallback onTap;

  const ConversationListTile({
    Key? key,
    required this.conversation,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue[100],
                backgroundImage: conversation.otherUserPhotoUrl != null
                    ? NetworkImage(conversation.otherUserPhotoUrl!)
                    : null,
                child: conversation.otherUserPhotoUrl == null
                    ? Text(
                        conversation.otherUserName.isNotEmpty
                            ? conversation.otherUserName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            conversation.otherUserName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.lastMessageAt != null)
                          Text(
                            _formatTime(conversation.lastMessageAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessageBody ?? 'Sem mensagens',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              conversation.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck =
        DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateToCheck == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (dateToCheck == yesterday) {
      return 'Ontem';
    } else if (now.difference(dateTime).inDays < 7) {
      return DateFormat('EEEE', 'pt_BR').format(dateTime);
    } else {
      return DateFormat('dd/MM').format(dateTime);
    }
  }
}

class _EmptyConversationsState extends StatefulWidget {
  @override
  State<_EmptyConversationsState> createState() => _EmptyConversationsStateState();
}

class _EmptyConversationsStateState extends State<_EmptyConversationsState> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (chatProvider.availableTrainers.isEmpty) {
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
                  'Nenhuma conversa iniciada',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nenhum treinador disponível',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return _ChatListScreenState._buildTrainerPickerContent(context, chatProvider);
      },
    );
  }
}
