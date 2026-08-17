import { ReactNode } from "react"
import Link from "next/link"
import { usePathname, useRouter } from "next/navigation"
import { BottomNavigation } from "@/components/BottomNavigation"
import { Dumbbell, LayoutDashboard, Settings, TrendingUp, LogOut, Activity, Users, Zap, MessageCircle, Bluetooth } from "lucide-react"
import { UserNav } from "@/components/dashboard/UserNav"
import { User } from "@/lib/api"
import { Button } from "@/components/ui/button"
import Image from "next/image"
import { getImageUrl } from "@/lib/utils"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { NotificationBell } from "@/components/dashboard/NotificationBell"

interface StudentLayoutProps {
    children: ReactNode
    user?: User | null
}

export function StudentLayout({ children, user }: StudentLayoutProps) {
    const router = useRouter()
    const pathname = usePathname()

    // Trainer Branding Logic
    const brandName = user?.trainer_brand_name || "PULSO"
    const logoUrl = getImageUrl(user?.trainer_logo_url)

    const navItems = [
        { href: "/dashboard", icon: LayoutDashboard, label: "Visão Geral" },
        { href: "/dashboard/workouts", icon: Dumbbell, label: "Meus Treinos" },
        { href: "/dashboard/history", icon: Activity, label: "Histórico" },
        { href: "/dashboard/progress", icon: TrendingUp, label: "Performance" },
        { href: "/dashboard/devices", icon: Bluetooth, label: "Dispositivos" },
        { href: "/dashboard/chat", icon: MessageCircle, label: "Mensagens" },
        { href: "/dashboard/marketplace", icon: Users, label: "Marketplace" },
        { href: "/dashboard/settings", icon: Settings, label: "Perfil" },
    ]

    const mobileNavItems = [
        { href: "/dashboard", icon: LayoutDashboard, label: "Visão Geral" },
        { href: "/dashboard/workouts", icon: Dumbbell, label: "Meus Treinos" },
        { href: "/dashboard/chat", icon: MessageCircle, label: "Mensagens" },
        { href: "/dashboard/marketplace", icon: Users, label: "Marketplace" },
        { href: "/dashboard/settings", icon: Settings, label: "Perfil" },
    ]

    return (
        <div className="flex h-dvh w-full bg-background overflow-hidden">
            {/* --- DESKTOP SIDEBAR --- */}
            <aside className="hidden w-72 flex-col bg-card/50 backdrop-blur-xl border-r border-border/40 md:flex fixed inset-y-0 z-50 transition-all duration-300">

                {/* Brand Header */}
                <div className="flex h-20 items-center px-7 border-b border-border/40">
                    <div className="flex items-center gap-3 group">
                        <div className="relative flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-primary to-purple-400 shadow-lg shadow-primary/30 transition-all group-hover:shadow-primary/50">
                            {logoUrl ? (
                                <Image src={logoUrl} alt={brandName} width={24} height={24} className="h-6 w-6 object-contain" unoptimized />
                            ) : (
                                <Zap className="h-5 w-5 text-white" />
                            )}
                        </div>
                        <span className="font-bold text-lg tracking-tight text-foreground truncate max-w-[140px]">
                            {brandName === "PULSO" ? (
                                <span>PULSO<span className="text-primary">.</span></span>
                            ) : (
                                brandName
                            )}
                        </span>
                    </div>
                </div>

                {/* Navigation */}
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
                                            ? 'bg-primary/15 text-primary border border-primary/20 shadow-[0_0_20px_hsla(266,70%,55%,0.1)]'
                                            : 'text-muted-foreground hover:bg-card hover:text-foreground hover:translate-x-1'}
                                    `}
                                >
                                    <item.icon className={`h-4.5 w-4.5 transition-colors flex-shrink-0 ${isActive ? 'text-primary' : 'text-muted-foreground/70 group-hover:text-foreground'}`} />
                                    {item.label}
                                    {isActive && (
                                        <div className="ml-auto h-1.5 w-1.5 rounded-full bg-primary animate-pulse-glow" />
                                    )}
                                </Link>
                            )
                        })}
                    </nav>
                </div>

                {/* User Profile & Logout */}
                <div className="p-5 border-t border-border/40 bg-card/30">
                    <div className="flex items-center gap-3 mb-4 px-1">
                        <Avatar className="h-9 w-9 ring-2 ring-primary/20 ring-offset-1 ring-offset-background">
                            <AvatarImage src={getImageUrl(user?.photo_url)} />
                            <AvatarFallback className="bg-primary/10 text-primary font-bold text-xs">
                                {user?.full_name?.substring(0, 2).toUpperCase() || 'EU'}
                            </AvatarFallback>
                        </Avatar>
                        <div className="flex flex-col overflow-hidden">
                            <span className="text-sm font-bold text-foreground truncate">{user?.full_name}</span>
                            <span className="text-xs text-muted-foreground truncate">{user?.email}</span>
                        </div>
                    </div>
                    <Button
                        variant="ghost"
                        className="w-full justify-start gap-3 text-muted-foreground hover:text-destructive hover:bg-destructive/10 h-9 rounded-xl transition-all text-xs font-semibold"
                        onClick={() => {
                            localStorage.removeItem("token")
                            router.push("/login")
                        }}
                    >
                        <LogOut className="h-4 w-4" />
                        Sair
                    </Button>
                </div>
            </aside>

            {/* --- MOBILE HEADER --- */}
            <header className="fixed top-0 z-40 w-full border-b border-border/40 bg-background/80 backdrop-blur-xl md:hidden">
                <div className="flex h-16 items-center justify-between px-4">
                    <div className="flex items-center gap-2.5">
                        <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary to-purple-400 flex items-center justify-center">
                            {logoUrl ? (
                                <Image src={logoUrl} alt={brandName} width={18} height={18} className="h-4.5 w-4.5 object-contain" unoptimized />
                            ) : (
                                <Zap className="h-4 w-4 text-white" />
                            )}
                        </div>
                        <span className="font-bold text-base text-foreground">{brandName}</span>
                    </div>
                    <div className="flex items-center gap-1">
                        <NotificationBell />
                        <UserNav user={user} />
                    </div>
                </div>
            </header>

            {/* --- MAIN CONTENT --- */}
            <main className="flex flex-col flex-1 md:ml-72 h-dvh relative pt-16 md:pt-0 pb-[calc(5rem+env(safe-area-inset-bottom))] md:pb-0">
                {/* Background Ambient */}
                <div className="fixed inset-0 pointer-events-none -z-10">
                    <div className="absolute top-0 right-0 w-[600px] h-[600px] bg-primary/4 rounded-full blur-[150px]" />
                    <div className="absolute bottom-0 left-0 w-[400px] h-[400px] bg-accent/3 rounded-full blur-[100px]" />
                </div>

                {/* Anamnesis Banner */}
                {user && user.anamnesis_completed === false && (
                    <div className="bg-amber-500/10 border-b border-amber-500/20 px-4 py-3 md:px-10">
                        <div className="flex items-center justify-between gap-4 max-w-[1600px] mx-auto">
                            <div className="flex items-center gap-3 text-amber-200">
                                <Activity className="h-4 w-4 text-amber-400 flex-shrink-0" />
                                <span className="text-sm font-medium">
                                    <strong className="text-amber-400">Atenção:</strong> Sua anamnese está pendente. Responda para que seu treinador possa montar seu treino.
                                </span>
                            </div>
                            <Link href="/dashboard/anamnesis">
                                <Button size="sm" className="border border-amber-500/30 bg-amber-500/10 text-amber-400 hover:bg-amber-500/20 h-8 text-xs font-bold rounded-lg">
                                    Responder
                                </Button>
                            </Link>
                        </div>
                    </div>
                )}

                <div className="flex-1 flex flex-col p-4 md:p-10 w-full max-w-[1600px] mx-auto animate-in fade-in slide-in-from-bottom-4 duration-500 min-h-0 overflow-y-auto">
                    {children}
                </div>
            </main>

            {/* --- MOBILE BOTTOM NAV --- */}
            <div className="md:hidden">
                <BottomNavigation items={mobileNavItems} />
            </div>
        </div>
    )
}
