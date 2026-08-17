'use client';

import { ChatConversation } from '@/hooks/useChat';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { cn } from '@/lib/utils';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import { Badge } from '@/components/ui/badge';

interface ConversationListProps {
  conversations: ChatConversation[];
  selectedId?: string;
  onSelect: (conversation: ChatConversation) => void;
  loading?: boolean;
}

export function ConversationList({
  conversations,
  selectedId,
  onSelect,
  loading = false,
}: ConversationListProps) {
  if (loading) {
    return <div className="p-4 text-center text-sm text-gray-500">Carregando...</div>;
  }

  if (conversations.length === 0) {
    return (
      <div className="p-4 text-center text-sm text-gray-500">
        Nenhuma conversa iniciada
      </div>
    );
  }

  return (
    <div className="space-y-1">
      {conversations.map((conv) => (
        <button
          key={conv.id}
          onClick={() => onSelect(conv)}
          className={cn(
            'w-full text-left px-4 py-3 rounded-lg hover:bg-gray-100 transition-colors',
            selectedId === conv.id && 'bg-blue-50 border border-blue-200'
          )}
        >
          <div className="flex items-center gap-3">
            <Avatar className="h-10 w-10">
              <AvatarImage src={conv.other_user_photo_url} />
              <AvatarFallback>
                {conv.other_user_name?.charAt(0).toUpperCase() || '?'}
              </AvatarFallback>
            </Avatar>

            <div className="flex-1 min-w-0">
              <div className="flex items-center justify-between gap-2">
                <h4 className="font-medium text-sm truncate">
                  {conv.other_user_name || 'Usuário'}
                </h4>
                {conv.last_message_at && (
                  <span className="text-xs text-gray-500 whitespace-nowrap">
                    {format(new Date(conv.last_message_at), 'HH:mm', {
                      locale: ptBR,
                    })}
                  </span>
                )}
              </div>
              <p className="text-xs text-gray-600 truncate">
                {conv.last_message_body || 'Sem mensagens'}
              </p>
            </div>

            {conv.unread_count > 0 && (
              <Badge variant="default" className="h-6 w-6 flex items-center justify-center p-0">
                {conv.unread_count}
              </Badge>
            )}
          </div>
        </button>
      ))}
    </div>
  );
}
