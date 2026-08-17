import React from 'react';
import { Bell } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Separator } from '@/components/ui/separator';
import { Skeleton } from '@/components/ui/skeleton';

import { api } from '@/lib/api';
import { cn } from '@/lib/utils';

interface Notification {
  id: string;
  type: string;
  title: string;
  body: string;
  is_read: boolean;
  created_at: string;
  data?: Record<string, any>;
}

interface NotificationItemProps {
  notification: Notification;
  onMarkAsRead: (id: string) => void;
}

const NotificationItem: React.FC<NotificationItemProps> = ({ notification, onMarkAsRead }) => {
  const [isRead, setIsRead] = React.useState(notification.is_read);

  const handleMarkRead = async () => {
    if (!isRead) {
      try {
        await api.put(`/notifications/${notification.id}/read`);
        setIsRead(true);
        onMarkAsRead(notification.id);
      } catch (error) {
        console.error('Failed to mark notification as read:', error);
      }
    }
  };

  const getIcon = (type: string) => {
    switch (type) {
      case 'HIRING_REQUEST':
      case 'HIRING_ACCEPTED':
        return <Bell className="h-4 w-4 text-violet-500" />;
      case 'HIRING_REJECTED':
        return <Bell className="h-4 w-4 text-red-500" />;
      case 'NEW_REVIEW':
        return <Bell className="h-4 w-4 text-yellow-500" />;
      case 'NEW_WORKOUT':
        return <Bell className="h-4 w-4 text-cyan-500" />;
      case 'STREAK_WARNING':
        return <Bell className="h-4 w-4 text-orange-500" />;
      case 'STUDENT_TRAINING':
        return <Bell className="h-4 w-4 text-green-500" />;
      default:
        return <Bell className="h-4 w-4 text-gray-400" />;
    }
  };

  return (
    <div
      className={cn(
        'flex items-start space-x-3 p-4 hover:bg-gray-800 transition-colors cursor-pointer',
        !isRead && 'bg-violet-950/20'
      )}
      onClick={handleMarkRead}
    >
      <div className="flex-shrink-0 mt-1">
        {getIcon(notification.type)}
      </div>
      <div className="flex-1">
        <div className="flex items-center justify-between">
          <h4 className={cn('text-sm font-medium', !isRead && 'font-semibold text-white')}>
            {notification.title}
          </h4>
          {!isRead && <span className="h-2 w-2 rounded-full bg-violet-500" />}
        </div>
        <p className="text-sm text-gray-400 mt-1">
          {notification.body}
        </p>
        <p className="text-xs text-gray-500 mt-1">
          {new Date(notification.created_at).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })}
        </p>
      </div>
    </div>
  );
};

export const NotificationsDropdown: React.FC = () => {
  const [notifications, setNotifications] = React.useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = React.useState<number>(0);
  const [loading, setLoading] = React.useState<boolean>(true);
  const [isOpen, setIsOpen] = React.useState<boolean>(false);

  const fetchNotifications = React.useCallback(async () => {
    setLoading(true);
    try {
      const [notificationsResp, unreadResp] = await Promise.all([
        api.get<Notification[]>('/notifications/'),
        api.get<{ unread_count: number }>('/notifications/unread-count'),
      ]);
      setNotifications(notificationsResp.data);
      setUnreadCount(unreadResp.data.unread_count);
    } catch (error) {
      console.error('Failed to fetch notifications:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    fetchNotifications();

    // Polling for unread count (every 30 seconds)
    const interval = setInterval(() => {
      if (!isOpen) {
        // Only fetch unread count if dropdown is closed to avoid unnecessary full fetches
        api.get<{ unread_count: number }>('/notifications/unread-count')
          .then(resp => setUnreadCount(resp.data.unread_count))
          .catch(error => console.error('Failed to fetch unread count:', error));
      }
    }, 30000);

    return () => clearInterval(interval);
  }, [fetchNotifications, isOpen]);

  const handleMarkAsRead = (id: string) => {
    setNotifications(prev =>
      prev.map(n => (n.id === id ? { ...n, is_read: true } : n))
    );
    setUnreadCount(prev => Math.max(0, prev - 1));
  };

  const handleMarkAllAsRead = async () => {
    try {
      await api.put('/notifications/read-all');
      setNotifications(prev => prev.map(n => ({ ...n, is_read: true })));
      setUnreadCount(0);
    } catch (error) {
      console.error('Failed to mark all notifications as read:', error);
    }
  };

  return (
    <Popover open={isOpen} onOpenChange={setIsOpen}>
      <PopoverTrigger asChild>
        <Button variant="ghost" size="icon" className="relative">
          <Bell className="h-5 w-5" />
          {unreadCount > 0 && (
            <span className="absolute top-1 right-1 flex h-3 w-3">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-violet-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-3 w-3 bg-violet-500" />
            </span>
          )}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-80 p-0" align="end">
        <div className="flex items-center justify-between p-4">
          <h3 className="text-lg font-semibold">Notificações</h3>
          {unreadCount > 0 && (
            <Button variant="link" onClick={handleMarkAllAsRead} className="text-violet-500">
              Marcar todas como lidas
            </Button>
          )}
        </div>
        <Separator />
        {loading ? (
          <div className="p-4 space-y-3">
            <Skeleton className="h-12 w-full" />
            <Skeleton className="h-12 w-full" />
            <Skeleton className="h-12 w-full" />
          </div>
        ) : notifications.length === 0 ? (
          <div className="p-4 text-center text-gray-500">
            Nenhuma notificação.
          </div>
        ) : (
          <ScrollArea className="h-[300px]">
            {notifications.map((notification) => (
              <NotificationItem
                key={notification.id}
                notification={notification}
                onMarkAsRead={handleMarkAsRead}
              />
            ))}
          </ScrollArea>
        )}
      </PopoverContent>
    </Popover>
  );
};
