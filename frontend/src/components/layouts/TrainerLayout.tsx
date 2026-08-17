import { ReactNode, useEffect, useState } from "react"
import Link from "next/link"
import { useRouter, usePathname } from "next/navigation"
import {
    LayoutDashboard, Users, Dumbbell, Settings, LogOut,
    Activity, Zap, Sparkles, BookOpen, MessageCircle, Menu, ChevronRight, MoreVertical,
} from "lucide-react"
import { Button } from "@/components/ui/button"
import Image from "next/image"
import { BottomNavigation } from "@/components/BottomNavigation"
import { ApiClient } from "@/lib/api"
import { NotificationBell } from "@/components/dashboard/NotificationBell"
import {
    AlertDialog, AlertDialogAction, AlertDialogCancel,
    AlertDialogContent, AlertDialogDescription,
    AlertDialogFooter, AlertDialogHeader, AlertDialogTitle,
    AlertDialogTrigger,
} from "@/components/ui/alert-dialog"
import {
    Popover,
    PopoverContent,
    PopoverTrigger,
} from "@/components/ui/popover"

interface TrainerLayoutProps {
    children: ReactNode
    brandName: string
    logoUrl: string | null
    primaryColor?: string
}

export function TrainerLayout({ children, brandName, logoUrl, primaryColor }: TrainerLayoutProps) {
    const router   = useRouter()
    const pathname = usePathname()
    const [atRiskCount, setAtRiskCount] = useState(0)

    useEffect(() => {
        ApiClient.trainer.getEngagement()
            .then((data) => setAtRiskCount(data.filter((s) => s.risk_level === "AT_RISK").length))
            .catch(() => {})
    }, [])

    // Sidebar nav (desktop)
    const navItems = [
        { href: "/dashboard",                     icon: LayoutDashboard, label: "Visão Geral",  badge: 0 },
        { href: "/dashboard/students",            icon: Users,           label: "Meus Alunos",  badge: atRiskCount },
        { href: "/dashboard/workouts",            icon: Dumbbell,        label: "Treinos",       badge: 0 },
        { href: "/dashboard/exercises",           icon: BookOpen,        label: "Exercícios",    badge: 0 },
        { href: "/dashboard/workouts/ai-generate",icon: Sparkles,        label: "IA Treinos",    badge: 0 },
        { href: "/dashboard/chat",                icon: MessageCircle,   label: "Mensagens",     badge: 0 },
        { href: "/dashboard/progress",            icon: Activity,        label: "Performance",   badge: 0 },
        { href: "/dashboard/settings",            icon: Settings,        label: "Ajustes",       badge: 0 },
    ]

    // Bottom nav mobile — IA no centro, logout vai para Ajustes/Menu
    const mobileNavItems = [
        { href: "/dashboard",                      icon: LayoutDashboard, label: "Visão Geral"  },
        { href: "/dashboard/students",             icon: Users,           label: "Meus Alunos"  },
        { href: "/dashboard/workouts/ai-generate", icon: Sparkles,        label: "IA Treinos"      },
        { href: "/dashboard/workouts",             icon: Dumbbell,        label: "Treinos" },
        { href: "/dashboard/settings",             icon: Menu,            label: "Ajustes"    },
    ]

    const handleLogout = () => {
        localStorage.removeItem("token")
        router.push("/login")
    }

    return (
        <div className="flex h-dvh w-full bg-background overflow-hidden"
            style={{
                '--primary': primaryColor ? `${primaryColor}` : 'hsl(266, 70%, 55%)',
            } as React.CSSProperties}
        >

            {/* ── Sidebar desktop ── */}
            <aside className="hidden w-72 flex-col bg-card/50 backdrop-blur-xl border-r border-border/40 md:flex fixed inset-y-0 z-50">

                {/* Brand */}
                <Link href="/dashboard" className="flex h-20 items-center px-7 border-b border-border/40 group">
                    <div className="flex items-center gap-3">
                        <div className="relative flex h-10 w-10 items-center justify-center rounded-xl bg-primary shadow-lg shadow-primary/30 group-hover:shadow-primary/50 transition-all">
                            {logoUrl ? (
                                <Image src={logoUrl} alt={brandName} width={24} height={24} className="h-6 w-6 object-contain" unoptimized />
                            ) : (
                                <Zap className="h-5 w-5 text-white" />
                            )}
                        </div>
                        <span className="font-bold text-lg tracking-tight text-foreground group-hover:text-primary transition-colors truncate max-w-[140px]">
                            {brandName}
                        </span>
                    </div>
                </Link>

                {/* Nav */}
                <div className="flex-1 overflow-y-auto py-6 px-4">
                    <div className="mb-3 px-2">
                        <span className="text-[10px] font-bold text-muted-foreground/60 tracking-widest uppercase">Menu</span>
                    </div>
                    <nav className="grid gap-1.5">
                        {navItems.map((item) => {
                            const isActive = pathname === item.href
                            return (
                                <Link
                                    key={item.href}
                                    href={item.href}
                                    className={`
                                        group flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-semibold transition-all duration-200
                                        ${isActive
                                            ? "bg-primary/15 text-primary border border-primary/20 shadow-[0_0_20px_hsla(266,70%,55%,0.08)]"
                                            : "text-muted-foreground hover:bg-card hover:text-foreground hover:translate-x-1"}
                                    `}
                                >
                                    <item.icon className={`h-4 w-4 flex-shrink-0 transition-colors ${isActive ? "text-primary" : "text-muted-foreground/70 group-hover:text-foreground"}`} />
                                    {item.label}
                                    <div className="ml-auto flex items-center gap-1">
                                        {item.badge > 0 && (
                                            <span className="flex h-5 w-5 items-center justify-center rounded-full bg-destructive text-[10px] font-bold text-destructive-foreground">
                                                {item.badge}
                                            </span>
                                        )}
                                        {isActive && <ChevronRight className="h-3 w-3 text-primary" />}
                                    </div>
                                </Link>
                            )
                        })}
                    </nav>
                </div>

                {/* Logout */}
                <div className="p-5 border-t border-border/40 bg-card/30">
                    <AlertDialog>
                        <AlertDialogTrigger asChild>
                            <Button
                                variant="ghost"
                                className="w-full justify-start gap-3 text-muted-foreground hover:text-destructive hover:bg-destructive/10 h-9 rounded-xl transition-all text-xs font-semibold"
                            >
                                <LogOut className="h-4 w-4" />
                                Encerrar Sessão
                            </Button>
                        </AlertDialogTrigger>
                        <AlertDialogContent>
                            <AlertDialogHeader>
                                <AlertDialogTitle>Sair da conta?</AlertDialogTitle>
                                <AlertDialogDescription>
                                    Tem certeza que deseja encerrar sua sessão atual?
                                </AlertDialogDescription>
                            </AlertDialogHeader>
                            <AlertDialogFooter>
                                <AlertDialogCancel>Cancelar</AlertDialogCancel>
                                <AlertDialogAction onClick={handleLogout} className="bg-destructive text-destructive-foreground hover:bg-destructive/90">
                                    Sair
                                </AlertDialogAction>
                            </AlertDialogFooter>
                        </AlertDialogContent>
                    </AlertDialog>
                </div>
            </aside>

            {/* ── Mobile header ── */}
            <header className="fixed top-0 z-40 w-full border-b border-border/40 bg-background/80 backdrop-blur-xl md:hidden">
                <div className="flex h-16 items-center justify-between px-4">
                    <div className="flex items-center gap-2.5">
                        <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
                            {logoUrl ? (
                                <Image src={logoUrl} alt={brandName} width={18} height={18} className="h-4 w-4 object-contain" unoptimized />
                            ) : (
                                <Zap className="h-4 w-4 text-white" />
                            )}
                        </div>
                        <span className="font-bold text-base text-foreground">{brandName}</span>
                    </div>
                    <div className="flex items-center gap-2">
                        <NotificationBell />
                        <Popover>
                            <PopoverTrigger asChild>
                                <Button
                                    variant="ghost"
                                    size="icon"
                                    className="h-9 w-9 rounded-lg text-muted-foreground hover:text-foreground hover:bg-secondary"
                                >
                                    <MoreVertical className="h-5 w-5" />
                                </Button>
                            </PopoverTrigger>
                            <PopoverContent className="w-48 p-0" align="end">
                                <div className="flex flex-col">
                                    <Link href="/dashboard/settings" className="w-full">
                                        <Button
                                            variant="ghost"
                                            className="w-full justify-start rounded-none text-foreground hover:bg-secondary"
                                        >
                                            <Settings className="mr-2 h-4 w-4" />
                                            Ajustes
                                        </Button>
                                    </Link>
                                    <AlertDialog>
                                        <AlertDialogTrigger asChild>
                                            <Button
                                                variant="ghost"
                                                className="w-full justify-start rounded-none text-destructive hover:text-destructive hover:bg-destructive/10"
                                            >
                                                <LogOut className="mr-2 h-4 w-4" />
                                                Sair
                                            </Button>
                                        </AlertDialogTrigger>
                                        <AlertDialogContent>
                                            <AlertDialogHeader>
                                                <AlertDialogTitle>Sair da conta?</AlertDialogTitle>
                                                <AlertDialogDescription>
                                                    Tem certeza que deseja encerrar sua sessão?
                                                </AlertDialogDescription>
                                            </AlertDialogHeader>
                                            <AlertDialogFooter>
                                                <AlertDialogCancel>Cancelar</AlertDialogCancel>
                                                <AlertDialogAction onClick={handleLogout} className="bg-destructive text-destructive-foreground hover:bg-destructive/90">
                                                    Sair
                                                </AlertDialogAction>
                                            </AlertDialogFooter>
                                        </AlertDialogContent>
                                    </AlertDialog>
                                </div>
                            </PopoverContent>
                        </Popover>
                    </div>
                </div>
            </header>

            {/* ── Main ── */}
            <main className="flex flex-col flex-1 md:ml-72 h-dvh relative pt-16 md:pt-0 pb-[calc(5rem+env(safe-area-inset-bottom))] md:pb-0">
                {/* Ambient bg */}
                <div className="fixed inset-0 pointer-events-none -z-10">
                    <div className="absolute top-0 left-0 max-w-[min(600px,100vw)] h-[600px] bg-primary/4 rounded-full blur-[150px] translate-x-[-50%]" />
                    <div className="absolute bottom-0 right-0 max-w-[min(400px,100vw)] h-[400px] bg-accent/3 rounded-full blur-[100px]" />
                </div>

                <div className="flex-1 flex flex-col p-6 md:p-10 w-full max-w-[1600px] mx-auto animate-in fade-in slide-in-from-bottom-4 duration-500 min-h-0 overflow-y-auto">
                    {children}
                </div>
            </main>

            {/* ── Mobile bottom nav ── */}
            <div className="md:hidden">
                <BottomNavigation items={mobileNavItems} />
            </div>
        </div>
    )
}
