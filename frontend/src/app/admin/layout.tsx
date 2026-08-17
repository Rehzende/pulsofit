"use client"

import { useEffect, useState } from "react"
import { useRouter, usePathname } from "next/navigation"
import Link from "next/link"
import {
    LayoutDashboard,
    Users,
    LogOut,
    Shield,
    UserSearch,
    CreditCard,
    Bell,
    Activity,
    ChevronRight,
} from "lucide-react"
import { Button } from "@/components/ui/button"
import { ApiClient } from "@/lib/api"
import {
    AlertDialog,
    AlertDialogAction,
    AlertDialogCancel,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogHeader,
    AlertDialogTitle,
    AlertDialogTrigger,
} from "@/components/ui/alert-dialog"

const navItems = [
    { href: "/admin",          icon: LayoutDashboard, label: "Dashboard"  },
    { href: "/admin/trainers", icon: Users,           label: "Trainers"   },
    { href: "/admin/users",    icon: UserSearch,      label: "Usuários"   },
    { href: "/admin/plans",    icon: CreditCard,      label: "Planos"     },
]

export default function AdminLayout({ children }: { children: React.ReactNode }) {
    const router   = useRouter()
    const pathname = usePathname()
    const [isLoading, setIsLoading] = useState(true)

    useEffect(() => {
        const checkAuth = async () => {
            const token = localStorage.getItem("token")
            if (!token) { router.push("/login"); return }
            try {
                const user = await ApiClient.getMe()
                if (user.role !== "SUPER_ADMIN") { router.push("/dashboard"); return }
                setIsLoading(false)
            } catch {
                router.push("/login")
            }
        }
        checkAuth()
    }, [router])

    const handleLogout = () => {
        localStorage.removeItem("token")
        router.push("/login")
    }

    if (isLoading) {
        return (
            <div className="flex h-dvh w-full items-center justify-center bg-background">
                <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
            </div>
        )
    }

    return (
        <div className="flex h-dvh w-full bg-background overflow-hidden">

            {/* ── Sidebar ── */}
            <aside className="hidden md:flex w-64 flex-col flex-shrink-0 border-r border-border/40 bg-card/30 backdrop-blur-xl fixed inset-y-0 z-50">

                {/* Brand */}
                <div className="flex h-16 items-center gap-3 px-6 border-b border-border/40">
                    <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary shadow-lg shadow-primary/30">
                        <Shield className="h-4 w-4 text-primary-foreground" />
                    </div>
                    <div>
                        <p className="text-sm font-bold text-foreground tracking-tight">PULSO Admin</p>
                        <p className="text-[10px] text-muted-foreground">Painel de controle</p>
                    </div>
                </div>

                {/* Nav */}
                <nav className="flex-1 py-6 px-3 space-y-1 overflow-y-auto">
                    <p className="text-[10px] font-bold text-muted-foreground/50 tracking-widest uppercase px-3 mb-3">
                        Navegação
                    </p>
                    {navItems.map((item) => {
                        const isActive = pathname === item.href ||
                            (item.href !== "/admin" && pathname.startsWith(item.href))
                        return (
                            <Link
                                key={item.href}
                                href={item.href}
                                className={`
                                    flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold
                                    transition-all duration-200 group
                                    ${isActive
                                        ? "bg-primary/15 text-primary border border-primary/20"
                                        : "text-muted-foreground hover:bg-card hover:text-foreground"}
                                `}
                            >
                                <item.icon className={`h-4 w-4 flex-shrink-0 ${isActive ? "text-primary" : "text-muted-foreground/60 group-hover:text-foreground"}`} />
                                {item.label}
                                {isActive && <ChevronRight className="ml-auto h-3 w-3 text-primary" />}
                            </Link>
                        )
                    })}
                </nav>

                {/* Footer */}
                <div className="p-4 border-t border-border/40">
                    <AlertDialog>
                        <AlertDialogTrigger asChild>
                            <Button
                                variant="ghost"
                                className="w-full justify-start gap-3 text-muted-foreground hover:text-destructive hover:bg-destructive/10 h-9 rounded-xl text-xs font-semibold"
                            >
                                <LogOut className="h-4 w-4" />
                                Encerrar Sessão
                            </Button>
                        </AlertDialogTrigger>
                        <AlertDialogContent>
                            <AlertDialogHeader>
                                <AlertDialogTitle>Sair do painel admin?</AlertDialogTitle>
                                <AlertDialogDescription>
                                    Sua sessão atual será encerrada.
                                </AlertDialogDescription>
                            </AlertDialogHeader>
                            <AlertDialogFooter>
                                <AlertDialogCancel>Cancelar</AlertDialogCancel>
                                <AlertDialogAction
                                    onClick={handleLogout}
                                    className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                                >
                                    Sair
                                </AlertDialogAction>
                            </AlertDialogFooter>
                        </AlertDialogContent>
                    </AlertDialog>
                </div>
            </aside>

            {/* ── Mobile header ── */}
            <header className="fixed top-0 z-40 w-full border-b border-border/40 bg-background/80 backdrop-blur-xl md:hidden">
                <div className="flex h-14 items-center justify-between px-4">
                    <div className="flex items-center gap-2.5">
                        <div className="w-7 h-7 rounded-lg bg-primary flex items-center justify-center">
                            <Shield className="h-3.5 w-3.5 text-primary-foreground" />
                        </div>
                        <span className="font-bold text-sm text-foreground">PULSO Admin</span>
                    </div>
                    {/* Mobile: show current section */}
                    <div className="flex items-center gap-1">
                        {navItems.map((item) => {
                            const isActive = pathname === item.href ||
                                (item.href !== "/admin" && pathname.startsWith(item.href))
                            if (!isActive) return null
                            return (
                                <span key={item.href} className="text-xs font-semibold text-primary">
                                    {item.label}
                                </span>
                            )
                        })}
                    </div>
                </div>
                {/* Mobile bottom nav */}
                <div className="flex border-t border-border/40">
                    {navItems.map((item) => {
                        const isActive = pathname === item.href ||
                            (item.href !== "/admin" && pathname.startsWith(item.href))
                        return (
                            <Link
                                key={item.href}
                                href={item.href}
                                className={`flex-1 flex flex-col items-center gap-1 py-2 text-[10px] font-semibold transition-colors ${isActive ? "text-primary" : "text-muted-foreground/50"}`}
                            >
                                <item.icon className="h-4 w-4" />
                                {item.label}
                            </Link>
                        )
                    })}
                </div>
            </header>

            {/* ── Main content ── */}
            <main className="flex flex-col flex-1 md:ml-64 overflow-y-auto pt-[88px] md:pt-0">
                <div className="flex-1 p-6 md:p-10 max-w-[1400px] w-full mx-auto">
                    {children}
                </div>
            </main>

        </div>
    )
}
