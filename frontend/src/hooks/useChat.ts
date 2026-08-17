'use client';

import { useEffect, useState, useCallback, useRef } from 'react';
import { api } from '@/lib/api';

export interface ChatMessage {
  id: string;
  conversation_id: string;
  sender_id: string;
  sender_name?: string;
  body: string;
  is_read: boolean;
  created_at: string;
  read_at?: string;
}

export interface ChatConversation {
  id: string;
  other_user_id: string;
  other_user_name?: string;
  other_user_photo_url?: string;
  last_message_body?: string;
  last_message_at?: string;
  unread_count: number;
  is_from_trainer: boolean;
}

export interface AvailableTrainer {
  id: string;
  full_name: string;
  photo_url?: string;
  brand_name?: string;
}

export interface ChatConversationDetail {
  id: string;
  student_id: string;
  trainer_id: string;
  student_name?: string;
  trainer_name?: string;
  created_at: string;
  last_message_at?: string;
  messages: ChatMessage[];
  unread_count: number;
  is_from_trainer?: boolean;
}

interface UseChat {
  conversations: ChatConversation[];
  currentConversation: ChatConversationDetail | null;
  messages: ChatMessage[];
  loading: boolean;
  error: string | null;
  availableTrainers: AvailableTrainer[];
  fetchConversations: () => Promise<void>;
  fetchConversation: (conversationId: string) => Promise<void>;
  sendMessage: (conversationId: string, body: string) => Promise<void>;
  markAsRead: (messageId: string) => Promise<void>;
  fetchAvailableTrainers: () => Promise<void>;
  startConversation: (trainerId: string) => Promise<void>;
  isTyping: boolean;
}

export function useChat(): UseChat {
  const [conversations, setConversations] = useState<ChatConversation[]>([]);
  const [currentConversation, setCurrentConversation] = useState<ChatConversationDetail | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isTyping, setIsTyping] = useState(false);
  const [availableTrainers, setAvailableTrainers] = useState<AvailableTrainer[]>([]);
  const wsRef = useRef<WebSocket | null>(null);
  const messagePollingRef = useRef<NodeJS.Timeout | null>(null);

  // Fetch all conversations
  const fetchConversations = useCallback(async () => {
    try {
      setLoading(true);
      const response = await api.get<ChatConversation[]>('/chat/conversations/');
      setConversations(response.data);
      setError(null);
    } catch (err) {
      console.error('Failed to fetch conversations:', err);
      setError('Falha ao carregar conversas');
    } finally {
      setLoading(false);
    }
  }, []);

  // Fetch conversation with messages
  const fetchConversation = useCallback(async (conversationId: string, showLoading: boolean = true, markReads: boolean = true) => {
    try {
      if (showLoading) setLoading(true);
      const response = await api.get<ChatConversationDetail>(
        `/chat/conversations/${conversationId}/messages`
      );
      setCurrentConversation(response.data);
      setMessages(response.data.messages);
      setError(null);

      // Mark unread messages as read — skipped during the 3s poll to avoid
      // re-issuing PATCH calls on every tick.
      if (markReads) {
        for (const msg of response.data.messages) {
          const isFromOtherUser = response.data.is_from_trainer
            ? msg.sender_id === response.data.student_id
            : msg.sender_id === response.data.trainer_id;

          if (!msg.is_read && isFromOtherUser) {
            await markAsRead(msg.id);
          }
        }
      }
    } catch (err) {
      console.error('Failed to fetch conversation:', err);
      setError('Falha ao carregar conversa');
    } finally {
      if (showLoading) setLoading(false);
    }
  }, []);

  // Send message
  const sendMessage = useCallback(async (conversationId: string, body: string) => {
    if (!body.trim()) return;

    try {
      const response = await api.post<ChatMessage>('/chat/messages', {
        conversation_id: conversationId,
        body,
      });

      setMessages((prev) => [...prev, response.data]);

      // Refresh conversations to update last_message_at
      await fetchConversations();
    } catch (err) {
      console.error('Failed to send message:', err);
      setError('Falha ao enviar mensagem');
    }
  }, [fetchConversations]);

  // Mark message as read
  const markAsRead = useCallback(async (messageId: string) => {
    try {
      await api.patch(`/chat/messages/${messageId}/read`);

      setMessages((prev) =>
        prev.map((msg) =>
          msg.id === messageId ? { ...msg, is_read: true } : msg
        )
      );
    } catch (err) {
      console.error('Failed to mark message as read:', err);
    }
  }, []);

  // Setup WebSocket for real-time messages (optional, can start simple with polling)
  useEffect(() => {
    if (!currentConversation) return;

    // Polling fallback (simpler than WebSocket for MVP)
    messagePollingRef.current = setInterval(() => {
      fetchConversation(currentConversation.id, false, false);
    }, 3000); // Poll every 3 seconds (no loading spinner, no read-marking)

    return () => {
      if (messagePollingRef.current) {
        clearInterval(messagePollingRef.current);
      }
    };
  }, [currentConversation?.id, fetchConversation]);

  // Fetch available trainers to start conversations
  const fetchAvailableTrainers = useCallback(async () => {
    try {
      setLoading(true);
      const response = await api.get<AvailableTrainer[]>('/chat/available-trainers/');
      setAvailableTrainers(response.data);
      setError(null);
    } catch (err: any) {
      if (err?.response?.status === 403) {
        setAvailableTrainers([]);
        setError(null); // Silent ignore for trainers
        return;
      }
      console.error('Failed to fetch available trainers:', err);
      setError('Falha ao carregar contatos');
    } finally {
      setLoading(false);
    }
  }, []);

  // Start a conversation with a trainer (auto-creates if doesn't exist)
  const startConversation = useCallback(async (trainerId: string) => {
    try {
      setLoading(true);
      const response = await api.post<ChatConversation>('/chat/conversations/', null, {
        params: { trainer_id: trainerId }
      });

      // Add to conversations if not already there
      setConversations((prev) => {
        const exists = prev.some((c) => c.id === response.data.id);
        return exists ? prev : [response.data, ...prev];
      });

      // Fetch the conversation details
      await fetchConversation(response.data.id);
      setError(null);
    } catch (err) {
      console.error('Failed to start conversation:', err);
      setError('Falha ao iniciar conversa');
    } finally {
      setLoading(false);
    }
  }, [fetchConversation]);

  // Cleanup WebSocket on unmount
  useEffect(() => {
    return () => {
      if (wsRef.current) {
        wsRef.current.close();
      }
      if (messagePollingRef.current) {
        clearInterval(messagePollingRef.current);
      }
    };
  }, []);

  return {
    conversations,
    currentConversation,
    messages,
    loading,
    error,
    availableTrainers,
    fetchConversations,
    fetchConversation,
    sendMessage,
    markAsRead,
    fetchAvailableTrainers,
    startConversation,
    isTyping,
  };
}
