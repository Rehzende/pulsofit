"use client"

import { useEffect, useRef, useState } from "react"
import { Bell, CheckCheck, Dumbbell, Star, UserPlus, UserCheck, UserX, Flame, Activity } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { ApiClient, AppNotification, NotificationType } from "@/lib/api"
import { cn } from "@/lib/utils"

function notificationIcon(type: NotificationType) {
    const cls = "h-4 w-4"
    switch (type) {
        case "HIRING_REQUEST": return <UserPlus className={cn(cls, "text-primary")} />
        case "HIRING_ACCEPTED": return <UserCheck className={cn(cls, "text-green-400")} />
        case "HIRING_REJECTED": return <UserX className={cn(cls, "text-destructive")} />
        case "NEW_REVIEW": return <Star className={cn(cls, "text-yellow-400")} />
        case "NEW_WORKOUT": return <Dumbbell className={cn(cls, "text-cyan-400")} />
        case "STREAK_WARNING": return <Flame className={cn(cls, "text-orange-400")} />
        case "STUDENT_TRAINING": return <Activity className={cn(cls, "text-green-400")} />
        default: return <Bell className={cls} />
    }
}

function relativeTime(iso: string) {
    const diff = (Date.now() - new Date(iso).getTime()) / 1000
    if (diff < 60) return "agora"
    if (diff < 3600) return `${Math.floor(diff / 60)}min atrás`
    if (diff < 86400) return `${Math.floor(diff / 3600)}h atrás`
    return `${Math.floor(diff / 86400)}d atrás`
}

export function NotificationBell() {
    const [notifications, setNotifications] = useState<AppNotification[]>([])
    const [unread, setUnread] = useState(0)
    const [open, setOpen] = useState(false)
    const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

    const fetchCount = async () => {
        try {
            const count = await ApiClient.notifications.getUnreadCount()
            setUnread(count)
        } catch { /* silent */ }
    }

    const fetchAll = async () => {
        try {
            const items = await ApiClient.notifications.getAll(0, 20)
            setNotifications(items)
            setUnread(items.filter(n => !n.is_read).length)
        } catch { /* silent */ }
    }

    useEffect(() => {
        fetchCount()
        intervalRef.current = setInterval(fetchCount, 60_000)
        return () => { if (intervalRef.current) clearInterval(intervalRef.current) }
    }, [])

    const handleOpen = (isOpen: boolean) => {
        setOpen(isOpen)
        if (isOpen) fetchAll()
    }

    const handleMarkRead = async (n: AppNotification) => {
        if (n.is_read) return
        await ApiClient.notifications.markRead(n.id)
        setNotifications(prev => prev.map(x => x.id === n.id ? { ...x, is_read: true } : x))
        setUnread(c => Math.max(0, c - 1))
    }

    const handleMarkAll = async () => {
        await ApiClient.notifications.markAllRead()
        setNotifications(prev => prev.map(x => ({ ...x, is_read: true })))
        setUnread(0)
    }

    return (
        <Popover open={open} onOpenChange={handleOpen}>
            <PopoverTrigger asChild>
                <Button variant="ghost" size="icon" className="relative h-9 w-9 rounded-xl">
                    <Bell className="h-4 w-4" />
                    {unread > 0 && (
                        <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-white">
                            {unread > 9 ? "9+" : unread}
                        </span>
                    )}
                </Button>
            </PopoverTrigger>
            <PopoverContent
                align="end"
                className="w-80 p-0 border-border/60 bg-card/95 backdrop-blur-xl"
            >
                <div className="flex items-center justify-between px-4 py-3 border-b border-border/40">
                    <span className="text-sm font-semibold">Notificações</span>
                    {unread > 0 && (
                        <Button
                            variant="ghost"
                            size="sm"
                            className="h-7 gap-1 text-xs text-muted-foreground hover:text-foreground"
                            onClick={handleMarkAll}
                        >
                            <CheckCheck className="h-3.5 w-3.5" />
                            Marcar todas
                        </Button>
                    )}
                </div>

                <div className="max-h-80 overflow-y-auto">
                    {notifications.length === 0 ? (
                        <div className="flex flex-col items-center gap-2 py-10 text-muted-foreground">
                            <Bell className="h-8 w-8 opacity-30" />
                            <span className="text-xs">Nenhuma notificação</span>
                        </div>
                    ) : (
                        notifications.map(n => (
                            <button
                                key={n.id}
                                onClick={() => handleMarkRead(n)}
                                className={cn(
                                    "w-full flex items-start gap-3 px-4 py-3 text-left hover:bg-muted/50 transition-colors",
                                    !n.is_read && "bg-primary/5"
                                )}
                            >
                                <div className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-muted/60">
                                    {notificationIcon(n.type)}
                                </div>
                                <div className="flex-1 min-w-0">
                                    <p className={cn("text-xs leading-snug", !n.is_read ? "font-semibold text-foreground" : "font-medium text-muted-foreground")}>
                                        {n.title}
                                    </p>
                                    <p className="text-xs text-muted-foreground mt-0.5 truncate">{n.body}</p>
                                    <p className="text-[10px] text-muted-foreground/60 mt-1">{relativeTime(n.created_at)}</p>
                                </div>
                                {!n.is_read && (
                                    <div className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-primary" />
                                )}
                            </button>
                        ))
                    )}
                </div>
            </PopoverContent>
        </Popover>
    )
}
