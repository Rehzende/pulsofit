'use client';

import { useEffect, useState } from 'react';
import { useChat, ChatConversation } from '@/hooks/useChat';
import { ConversationList } from '@/components/chat/ConversationList';
import { ChatBubble } from '@/components/chat/ChatBubble';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Card } from '@/components/ui/card';
import { Send, ArrowLeft } from 'lucide-react';

export default function ChatPage() {
  const {
    conversations,
    currentConversation,
    messages,
    loading,
    availableTrainers,
    fetchConversations,
    fetchConversation,
    sendMessage,
    fetchAvailableTrainers,
    startConversation,
  } = useChat();

  const [messageInput, setMessageInput] = useState('');
  const [showDetailMobile, setShowDetailMobile] = useState(false);

  // Load conversations and available trainers on mount
  useEffect(() => {
    fetchConversations();
    fetchAvailableTrainers();
  }, [fetchConversations, fetchAvailableTrainers]);

  const handleSelectConversation = (conv: ChatConversation) => {
    fetchConversation(conv.id);
    setShowDetailMobile(true);
  };

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentConversation || !messageInput.trim()) return;

    await sendMessage(currentConversation.id, messageInput);
    setMessageInput('');
  };

  return (
    <div className="flex-1 flex flex-col md:flex-row gap-4 min-h-0">
      {/* Sidebar - Hidden on mobile if detail is shown */}
      <Card className={`w-full md:w-80 overflow-hidden flex-col ${showDetailMobile ? 'hidden md:flex' : 'flex'}`}>
        <div className="p-4 border-b shrink-0">
          <h2 className="font-semibold">Mensagens</h2>
        </div>
        <ScrollArea className="flex-1 min-h-0">
          <ConversationList
            conversations={conversations}
            selectedId={currentConversation?.id}
            onSelect={handleSelectConversation}
            loading={loading}
          />
        </ScrollArea>
      </Card>

      {/* Chat Detail - Hidden on mobile if detail is NOT shown */}
      {currentConversation ? (
        <Card className={`flex-1 min-h-0 overflow-hidden flex-col ${showDetailMobile ? 'flex' : 'hidden md:flex'}`}>
          {/* Header */}
          <div className="p-4 border-b flex items-center gap-2 shrink-0">
            <Button
              variant="ghost"
              size="icon"
              className="md:hidden"
              onClick={() => setShowDetailMobile(false)}
            >
              <ArrowLeft className="h-4 w-4" />
            </Button>
            <h3 className="font-semibold">
              {currentConversation.is_from_trainer
                ? currentConversation.student_name
                : currentConversation.trainer_name}
            </h3>
          </div>

          {/* Messages */}
          <ScrollArea className="flex-1 min-h-0 p-4">
            <div className="space-y-4">
              {messages.map((msg) => (
                <ChatBubble
                  key={msg.id}
                  message={msg.body}
                  sender={
                    (currentConversation.is_from_trainer && msg.sender_id === currentConversation.trainer_id) ||
                    (!currentConversation.is_from_trainer && msg.sender_id === currentConversation.student_id)
                      ? 'self'
                      : 'other'
                  }
                  senderName={msg.sender_name}
                  timestamp={msg.created_at}
                  isRead={msg.is_read}
                />
              ))}
            </div>
          </ScrollArea>

          {/* Input */}
          <div className="p-4 border-t shrink-0 bg-card">
            <form onSubmit={handleSendMessage} className="flex gap-2">
              <Input
                value={messageInput}
                onChange={(e) => setMessageInput(e.target.value)}
                placeholder="Digite uma mensagem..."
                disabled={loading}
              />
              <Button
                type="submit"
                size="icon"
                disabled={loading || !messageInput.trim()}
              >
                <Send className="h-4 w-4" />
              </Button>
            </form>
          </div>
        </Card>
      ) : conversations.length === 0 && availableTrainers.length > 0 ? (
        <Card className={`flex-1 min-h-0 overflow-hidden flex-col ${showDetailMobile ? 'flex' : 'hidden md:flex'}`}>
          <div className="p-4 border-b flex items-center gap-2 shrink-0">
            <Button
              variant="ghost"
              size="icon"
              className="md:hidden"
              onClick={() => setShowDetailMobile(false)}
            >
              <ArrowLeft className="h-4 w-4" />
            </Button>
            <h3 className="font-semibold">Iniciar Conversa</h3>
          </div>
          <ScrollArea className="flex-1 min-h-0 p-4">
            <div className="space-y-2">
              {availableTrainers.map((trainer) => (
                <div
                  key={trainer.id}
                  className="flex items-center justify-between p-3 border rounded-lg hover:bg-zinc-800 cursor-pointer"
                  onClick={() => {
                    startConversation(trainer.id);
                    setShowDetailMobile(true);
                  }}
                >
                  <div className="flex items-center gap-3">
                    {trainer.photo_url && (
                      <img
                        src={trainer.photo_url}
                        alt={trainer.full_name}
                        className="w-10 h-10 rounded-full"
                      />
                    )}
                    <div>
                      <p className="font-medium text-sm">{trainer.full_name}</p>
                      {trainer.brand_name && (
                        <p className="text-xs text-zinc-400">{trainer.brand_name}</p>
                      )}
                    </div>
                  </div>
                  <span className="text-xs text-zinc-500">→</span>
                </div>
              ))}
            </div>
          </ScrollArea>
        </Card>
      ) : (
        <Card className={`flex-1 items-center justify-center text-zinc-400 ${showDetailMobile ? 'flex' : 'hidden md:flex'}`}>
          {loading ? 'Carregando...' : 'Selecione uma conversa para começar'}
        </Card>
      )}
    </div>
  );
}
