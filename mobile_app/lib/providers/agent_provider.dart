import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/ai_agent.dart';

class AgentProvider with ChangeNotifier {
  final Dio _dio;
  
  AgentSession? _currentSession;
  List<AgentSession> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;

  AgentProvider(this._dio);

  AgentSession? get currentSession => _currentSession;
  List<AgentSession> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchSessions() async {
    try {
      final response = await _dio.get('${AppConstants.aiAgentEndpoint}/sessions');
      _sessions = (response.data as List).map((s) => AgentSession.fromJson(s)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
    }
  }

  Future<void> loadSession(String sessionId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.get('${AppConstants.aiAgentEndpoint}/session/$sessionId');
      _currentSession = AgentSession.fromJson(response.data);
    } catch (e) {
      _errorMessage = 'Erro ao carregar conversa';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initSession({bool forceNew = false, String? studentId}) async {
    _isLoading = true;
    _errorMessage = null;
    if (forceNew) {
      _currentSession = null;
    }
    notifyListeners();

    try {
      final response = await _dio.post(
        '${AppConstants.aiAgentEndpoint}/session',
        queryParameters: {
          'force_new': forceNew,
          if (studentId != null) 'student_id': studentId,
        },
      );
      debugPrint('Agent Session Response: ${response.data}');
      
      if (response.data is Map<String, dynamic>) {
        _currentSession = AgentSession.fromJson(response.data);
      } else {
        _errorMessage = 'Formato de resposta inválido';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data['detail'] ?? 'Erro ao carregar sessão';
    } catch (e, stack) {
      debugPrint('Error parsing session: $e');
      debugPrint(stack.toString());
      _errorMessage = 'Erro interno ao processar dados';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (_currentSession == null) {
      _errorMessage = 'Sessão não iniciada. Tente recarregar.';
      notifyListeners();
      return;
    }

    // Criar mensagem temporária do usuário para feedback imediato (Optimistic UI)
    final tempUserMsg = AgentMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: _currentSession!.id,
      role: 'user',
      content: text,
      actionStatus: AgentActionStatus.NONE,
      createdAt: DateTime.now(),
    );

    // Criar uma nova lista para disparar o rebuild do Consumer
    final updatedMessages = List<AgentMessage>.from(_currentSession!.messages)..add(tempUserMsg);
    
    _currentSession = AgentSession(
      id: _currentSession!.id,
      trainerId: _currentSession!.trainerId,
      title: _currentSession!.title,
      messages: updatedMessages,
      createdAt: _currentSession!.createdAt,
      updatedAt: _currentSession!.updatedAt,
    );

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.post(
        '${AppConstants.aiAgentEndpoint}/chat',
        data: {
          'message': text,
          'session_id': _currentSession!.id,
        },
      );
      
      final aiMessage = AgentMessage.fromJson(response.data);
      
      // Adicionar a resposta da IA criando uma nova lista novamente
      final withAiMessages = List<AgentMessage>.from(_currentSession!.messages)..add(aiMessage);
      
      _currentSession = AgentSession(
        id: _currentSession!.id,
        trainerId: _currentSession!.trainerId,
        title: _currentSession!.title,
        messages: withAiMessages,
        createdAt: _currentSession!.createdAt,
        updatedAt: _currentSession!.updatedAt,
      );
    } on DioException catch (e) {
      _errorMessage = e.response?.data['detail'] ?? 'Erro ao enviar mensagem';
      // Bug Fix #8: Remover a mensagem temporária exata usando comparação de objeto
      if (_currentSession != null) {
        final rollbackMessages = List<AgentMessage>.from(_currentSession!.messages)
            ..removeWhere((m) => identical(m, tempUserMsg) || m.id == tempUserMsg.id);
        
        _currentSession = AgentSession(
          id: _currentSession!.id,
          trainerId: _currentSession!.trainerId,
          title: _currentSession!.title,
          messages: rollbackMessages,
          createdAt: _currentSession!.createdAt,
          updatedAt: _currentSession!.updatedAt,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> executeAction(String messageId, String action) async {
    if (_currentSession == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.post(
        '${AppConstants.aiAgentEndpoint}/execute-action',
        data: {
          'message_id': messageId,
          'action': action,
        },
      );
      
      final resultMessage = AgentMessage.fromJson(response.data);
      
      // Atualizar a lista local: 
      // 1. Marcar a mensagem original como EXECUTADA ou REJEITADA
      // 2. Adicionar a mensagem de confirmação do sistema
      final updatedMessages = _currentSession!.messages.map((m) {
        if (m.id == messageId) {
          return AgentMessage(
            id: m.id,
            sessionId: m.sessionId,
            role: m.role,
            content: m.content,
            toolCalls: m.toolCalls,
            toolCallId: m.toolCallId,
            actionStatus: action == 'approve' ? AgentActionStatus.EXECUTED : AgentActionStatus.REJECTED,
            actionData: m.actionData,
            createdAt: m.createdAt,
          );
        }
        return m;
      }).toList();

      updatedMessages.add(resultMessage);
      
      _currentSession = AgentSession(
        id: _currentSession!.id,
        trainerId: _currentSession!.trainerId,
        title: _currentSession!.title,
        messages: updatedMessages,
        createdAt: _currentSession!.createdAt,
        updatedAt: DateTime.now(), // Atualizar timestamp
      );
    } on DioException catch (e) {
      _errorMessage = e.response?.data['detail'] ?? 'Erro ao executar ação';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
