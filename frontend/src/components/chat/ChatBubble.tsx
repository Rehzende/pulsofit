'use client';

import { cn } from '@/lib/utils';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

interface ChatBubbleProps {
  message: string;
  sender: 'self' | 'other';
  senderName?: string;
  timestamp: string;
  isRead?: boolean;
}

export function ChatBubble({
  message,
  sender,
  senderName,
  timestamp,
  isRead,
}: ChatBubbleProps) {
  const isSelf = sender === 'self';

  return (
    <div className={cn('flex gap-3 mb-4', isSelf && 'flex-row-reverse')}>
      <div
        className={cn(
          'max-w-xs px-4 py-2 rounded-lg',
          isSelf
            ? 'bg-blue-500 text-white rounded-br-none'
            : 'bg-gray-100 text-gray-900 rounded-bl-none'
        )}
      >
        {!isSelf && senderName && (
          <p className="text-xs font-semibold mb-1">{senderName}</p>
        )}
        <p className="break-words">{message}</p>
        <div
          className={cn(
            'text-xs mt-1 flex items-center gap-1',
            isSelf ? 'text-blue-100' : 'text-gray-500'
          )}
        >
          {format(new Date(timestamp), 'HH:mm', { locale: ptBR })}
          {isSelf && isRead && (
            <span title="Lido">✓✓</span>
          )}
        </div>
      </div>
    </div>
  );
}
