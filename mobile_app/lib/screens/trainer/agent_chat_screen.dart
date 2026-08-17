import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../providers/agent_provider.dart';
import '../../models/ai_agent.dart';
import '../../core/constants.dart';

class AgentChatScreen extends StatefulWidget {
  final String? studentId;

  const AgentChatScreen({super.key, this.studentId});

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AgentProvider>();
      provider.initSession(studentId: widget.studentId);
      provider.fetchSessions();
    });
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

  void _confirmNewSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(AppConstants.cardDark),
        title: const Text('Nova Conversa?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Deseja arquivar esta conversa e começar uma nova? Isso limpará a tela atual.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(AppConstants.neonAccent)),
            onPressed: () {
              Navigator.pop(context);
              context.read<AgentProvider>().initSession(forceNew: true, studentId: widget.studentId);
            },
            child: const Text('Sim, Nova Conversa', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      drawer: _buildHistoryDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              context.read<AgentProvider>().fetchSessions();
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agente Pulso',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            Consumer<AgentProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.currentSession == null) {
                  return Text(
                    'Conectando...',
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                  );
                }
                if (provider.currentSession != null) {
                  return Text(
                    'Online',
                    style: GoogleFonts.inter(color: const Color(AppConstants.successColor), fontSize: 11),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _confirmNewSession(),
            icon: const Icon(Icons.add_comment_outlined, color: Color(AppConstants.neonAccent), size: 18),
            label: Text(
              'Nova',
              style: GoogleFonts.inter(color: const Color(AppConstants.neonAccent), fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AgentProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.currentSession == null) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 16),
                        Text('Iniciando conversa segura...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                if (provider.errorMessage != null && provider.currentSession == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(provider.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => provider.initSession(),
                            child: const Text('Tentar Novamente'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final messages = provider.currentSession?.messages ?? [];

                if (messages.isEmpty) {
                  return _buildEmptyState();
                }

                // Scroll para o fim após o rebuild
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  key: ValueKey(provider.currentSession?.id),
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt, size: 64, color: Color(AppConstants.neonAccent)),
            const SizedBox(height: 16),
            Text(
              'Olá! Eu sou seu Agente Pulso.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Peça para criar treinos, templates ou pastas e eu cuido do resto.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(AppConstants.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      backgroundColor: const Color(AppConstants.primaryDark),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(AppConstants.borderColor))),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, color: Color(AppConstants.neonAccent), size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Conversas Recentes',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Selecione para retomar contexto',
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_comment, color: Color(AppConstants.neonAccent)),
            title: Text(
              'Nova Sessão Geral',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Sem aluno pré-definido', style: TextStyle(color: Colors.grey, fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              context.read<AgentProvider>().initSession(forceNew: true);
            },
          ),
          const Divider(color: Color(AppConstants.borderColor)),
          Expanded(
            child: Consumer<AgentProvider>(
              builder: (context, provider, child) {
                if (provider.sessions.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma conversa anterior', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: provider.sessions.length,
                  itemBuilder: (context, index) {
                    final session = provider.sessions[index];
                    final isSelected = provider.currentSession?.id == session.id;

                    return ListTile(
                      leading: Icon(
                        Icons.chat_bubble_outline, 
                        color: isSelected ? const Color(AppConstants.neonAccent) : Colors.grey,
                        size: 20,
                      ),
                      title: Text(
                        session.title ?? 'Conversa sem título',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: isSelected ? const Color(AppConstants.neonAccent) : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('dd/MM HH:mm').format(session.updatedAt),
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        provider.loadSession(session.id);
                      },
                      selected: isSelected,
                      selectedTileColor: const Color(AppConstants.neonAccent).withValues(alpha: 0.05),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AgentMessage message) {
    final bool isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser 
              ? const Color(AppConstants.neonAccent).withValues(alpha: 0.2)
              : const Color(AppConstants.cardElevated),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
          ),
          border: Border.all(
            color: isUser 
                ? const Color(AppConstants.neonAccent).withValues(alpha: 0.5)
                : const Color(AppConstants.borderColor),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.content != null)
              MarkdownBody(
                data: message.content!,
                styleSheet: MarkdownStyleSheet(
                  p: GoogleFonts.inter(color: Colors.white),
                  h1: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                  h2: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                  h3: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                  em: GoogleFonts.inter(color: Colors.white, fontStyle: FontStyle.italic),
                  strong: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                  listBullet: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            if (message.actionStatus != AgentActionStatus.NONE)
              _buildActionCard(message),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(AgentMessage message) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(AppConstants.neonAccent).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: Color(AppConstants.neonAccent)),
              const SizedBox(width: 8),
              Text(
                'Ação Proposta',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(AppConstants.neonAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getActionSummary(message),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Consumer<AgentProvider>(
            builder: (context, provider, child) {
              if (message.actionStatus == AgentActionStatus.PENDING) {
                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(AppConstants.neonAccent),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () async {
                          await provider.executeAction(message.id, 'approve');
                          if (provider.errorMessage != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(provider.errorMessage!), backgroundColor: Colors.red),
                            );
                          }
                        },
                        child: const Text('Confirmar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        await provider.executeAction(message.id, 'reject');
                        if (provider.errorMessage != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(provider.errorMessage!), backgroundColor: Colors.red),
                          );
                        }
                      },
                      child: const Text('Alterar', style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                );
              } else if (message.actionStatus == AgentActionStatus.EXECUTED) {
                return const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text('Executado', style: TextStyle(color: Colors.green, fontSize: 12)),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  String _getActionSummary(AgentMessage message) {
    final data = message.actionData;
    if (data == null) return "Ação não especificada";
    
    List<dynamic> actions = [];
    if (data['type'] == 'batch' && data.containsKey('actions')) {
      actions = data['actions'] as List<dynamic>;
    } else {
      actions = [data]; // Try to handle as a single action
    }

    List<String> summaries = [];
    for (var action in actions) {
      if (action is Map<String, dynamic>) {
        Map<String, dynamic> payload = action.containsKey('payload') ? action['payload'] : action;
        
        if (payload.containsKey('folder_name')) {
          summaries.add("Criar pasta: ${payload['folder_name']}");
        } else if (payload.containsKey('workout_name')) {
          summaries.add("Criar treino: ${payload['workout_name']}");
        } else if (payload.containsKey('template_name')) {
          summaries.add("Criar template: ${payload['template_name']}");
        }
      }
    }
    
    if (summaries.isEmpty) return "Preparar novos itens";
    return summaries.join('\n');
  }

  Widget _buildInputArea() {
    return Consumer<AgentProvider>(
      builder: (context, provider, child) {
        final bool isReady = provider.currentSession != null;
        
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: Color(AppConstants.cardDark),
              border: Border(top: BorderSide(color: Color(AppConstants.borderColor))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: isReady,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: isReady ? 'Como posso ajudar?' : 'Conectando...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(AppConstants.cardElevated),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                if (provider.isLoading && isReady)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  CircleAvatar(
                    backgroundColor: isReady 
                        ? const Color(AppConstants.neonAccent) 
                        : Colors.grey.withValues(alpha: 0.3),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: isReady ? _handleSend : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleSend() {
    final provider = context.read<AgentProvider>();
    if (provider.currentSession == null) return;

    if (_messageController.text.trim().isEmpty) return;
    if (provider.isLoading) return; // Evitar duplo envio
    
    final text = _messageController.text.trim();
    _messageController.clear();
    provider.sendMessage(text);
  }
}
