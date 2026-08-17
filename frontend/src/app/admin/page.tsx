"use client"

import { useEffect, useState } from "react"
import { ApiClient } from "@/lib/api"
import {
    Users, UserCheck, TrendingUp, Activity, Plus,
    Zap, AlertTriangle, Clock, ArrowUpRight, Wifi, UserSearch,
} from "lucide-react"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
    Dialog, DialogContent, DialogDescription, DialogFooter,
    DialogHeader, DialogTitle, DialogTrigger,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { toast } from "sonner"

interface AdminStats {
    active_trainers: number
    active_plans: number
    active_students: number
    total_revenue: number
    total_users: number
    logged_24h: number
    logged_7d: number
}

function StatCard({
    icon: Icon,
    label,
    value,
    sub,
    subColor = "text-muted-foreground",
    href,
    iconClass,
}: {
    icon: React.ElementType
    label: string
    value: string | number
    sub?: string
    subColor?: string
    href?: string
    iconClass: string
}) {
    const content = (
        <div className="bg-card/50 border border-border/40 rounded-xl p-5 hover:bg-card/80 hover:border-border/60 transition-all duration-200 group">
            <div className={`inline-flex h-9 w-9 items-center justify-center rounded-lg mb-4 ${iconClass}`}>
                <Icon className="h-4 w-4" />
            </div>
            <p className="text-3xl font-black text-foreground tracking-tight leading-none mb-1">{value}</p>
            <p className="text-xs font-medium text-muted-foreground">{label}</p>
            {sub && <p className={`text-xs font-semibold mt-2 ${subColor}`}>{sub}</p>}
            {href && (
                <div className="mt-3 flex items-center gap-1 text-xs font-semibold text-primary opacity-0 group-hover:opacity-100 transition-opacity">
                    Ver detalhes <ArrowUpRight className="h-3 w-3" />
                </div>
            )}
        </div>
    )
    return href ? <Link href={href}>{content}</Link> : content
}

function StatCardSkeleton() {
    return (
        <div className="bg-card/50 border border-border/40 rounded-xl p-5 animate-pulse">
            <div className="h-9 w-9 rounded-lg bg-muted mb-4" />
            <div className="h-8 w-16 rounded bg-muted mb-2" />
            <div className="h-3 w-24 rounded bg-muted" />
        </div>
    )
}

interface ActivityEvent {
    type: "new_trainer" | "plan_upgrade" | "churn_risk" | "new_student" | "iot_enabled"
    text: string
    time: string
}

const MOCK_ACTIVITY: ActivityEvent[] = [
    { type: "new_trainer",  text: "Novo trainer cadastrado: João P.",           time: "2min" },
    { type: "plan_upgrade", text: "Carol M. ativou plano Pro",                   time: "18min" },
    { type: "churn_risk",   text: "Rafael S. sem login há 14 dias",             time: "—" },
    { type: "new_student",  text: "João P. adicionou aluno Lucas T.",            time: "1h" },
    { type: "iot_enabled",  text: "Fernanda K. habilitou integração IoT",       time: "3h" },
]

const activityDot: Record<ActivityEvent["type"], string> = {
    new_trainer:  "bg-green-500",
    plan_upgrade: "bg-primary",
    churn_risk:   "bg-red-500",
    new_student:  "bg-cyan-400",
    iot_enabled:  "bg-amber-400",
}

export default function AdminDashboard() {
    const [stats, setStats]         = useState<AdminStats | null>(null)
    const [isLoading, setIsLoading] = useState(true)
    const [inviteEmail, setInviteEmail] = useState("")
    const [isInviteOpen, setIsInviteOpen] = useState(false)
    const [isSending, setIsSending] = useState(false)

    useEffect(() => {
        ApiClient.admin.getStats()
            .then((s) => setStats(s as AdminStats))
            .catch(() => toast.error("Erro ao carregar métricas"))
            .finally(() => setIsLoading(false))
    }, [])

    const handleInviteTrainer = async () => {
        if (!inviteEmail.trim()) return
        setIsSending(true)
        try {
            await ApiClient.admin.inviteTrainer(inviteEmail.trim())
            toast.success("Convite enviado com sucesso!")
            setIsInviteOpen(false)
            setInviteEmail("")
        } catch {
            toast.error("Erro ao enviar convite. Verifique o e-mail e tente novamente.")
        } finally {
            setIsSending(false)
        }
    }

    const mrr = stats ? `R$ ${(stats.total_revenue / 100).toLocaleString("pt-BR", { minimumFractionDigits: 2 })}` : "—"

    return (
        <div className="flex flex-col gap-8 animate-in fade-in duration-500">

            {/* ── Header ── */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <h1 className="text-3xl font-black tracking-tight text-foreground">
                        Painel de Controle
                    </h1>
                    <p className="text-muted-foreground text-sm mt-1">
                        Visão geral da plataforma · {new Date().toLocaleDateString("pt-BR", { weekday: "long", day: "numeric", month: "long" })}
                    </p>
                </div>
                <Dialog open={isInviteOpen} onOpenChange={setIsInviteOpen}>
                    <DialogTrigger asChild>
                        <Button className="bg-primary text-primary-foreground hover:bg-primary/90 font-bold rounded-xl h-10 px-5 shadow-lg shadow-primary/20">
                            <Plus className="mr-2 h-4 w-4" /> Convidar Trainer
                        </Button>
                    </DialogTrigger>
                    <DialogContent className="sm:max-w-[420px]">
                        <DialogHeader>
                            <DialogTitle>Convidar Personal Trainer</DialogTitle>
                            <DialogDescription>
                                Um link de acesso será enviado para o e-mail informado.
                            </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-3 py-2">
                            <Label htmlFor="invite-email">E-mail do trainer</Label>
                            <Input
                                id="invite-email"
                                type="email"
                                placeholder="trainer@exemplo.com"
                                value={inviteEmail}
                                onChange={(e) => setInviteEmail(e.target.value)}
                                onKeyDown={(e) => e.key === "Enter" && handleInviteTrainer()}
                            />
                        </div>
                        <DialogFooter>
                            <Button variant="outline" onClick={() => setIsInviteOpen(false)}>Cancelar</Button>
                            <Button
                                onClick={handleInviteTrainer}
                                disabled={isSending || !inviteEmail.trim()}
                                className="bg-primary text-primary-foreground hover:bg-primary/90 font-bold"
                            >
                                {isSending ? "Enviando..." : "Enviar Convite"}
                            </Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </div>

            {/* ── Stats grid ── */}
            <div>
                <p className="text-xs font-bold text-muted-foreground/60 uppercase tracking-widest mb-4">
                    Métricas gerais
                </p>
                <div className="grid gap-4 grid-cols-2 lg:grid-cols-4">
                    {isLoading ? (
                        Array.from({ length: 4 }).map((_, i) => <StatCardSkeleton key={i} />)
                    ) : (
                        <>
                            <StatCard
                                icon={Users}
                                label="Trainers ativos"
                                value={stats?.active_trainers ?? 0}
                                sub={`${stats?.total_users ?? 0} usuários total`}
                                iconClass="bg-primary/15 text-primary"
                                href="/admin/trainers"
                            />
                            <StatCard
                                icon={UserCheck}
                                label="Alunos ativos"
                                value={stats?.active_students ?? 0}
                                sub="Na plataforma"
                                iconClass="bg-cyan-500/15 text-cyan-400"
                            />
                            <StatCard
                                icon={TrendingUp}
                                label="Receita estimada"
                                value={mrr}
                                sub="Planos ativos"
                                subColor="text-green-500"
                                iconClass="bg-green-500/15 text-green-400"
                            />
                            <StatCard
                                icon={Activity}
                                label="Ativos hoje"
                                value={stats?.logged_24h ?? 0}
                                sub={`${stats?.logged_7d ?? 0} nos últimos 7 dias`}
                                iconClass="bg-amber-500/15 text-amber-400"
                            />
                        </>
                    )}
                </div>
            </div>

            {/* ── Bottom: quick links + activity ── */}
            <div className="grid gap-6 md:grid-cols-3">

                {/* Quick actions */}
                <div className="md:col-span-1 flex flex-col gap-3">
                    <p className="text-xs font-bold text-muted-foreground/60 uppercase tracking-widest">
                        Acesso rápido
                    </p>
                    {[
                        { href: "/admin/trainers", icon: Users,         label: "Gerenciar Trainers",  sub: `${stats?.active_trainers ?? "—"} ativos` },
                        { href: "/admin/users",    icon: UserSearch,    label: "Todos os Usuários",   sub: `${stats?.total_users ?? "—"} cadastrados` },
                        { href: "/admin/plans",    icon: Zap,           label: "Planos e Features",   sub: `${stats?.active_plans ?? "—"} planos` },
                    ].map((item) => (
                        <Link
                            key={item.href}
                            href={item.href}
                            className="flex items-center gap-4 p-4 bg-card/50 border border-border/40 rounded-xl hover:bg-card/80 hover:border-border/60 transition-all group"
                        >
                            <div className="h-9 w-9 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0 group-hover:bg-primary/20 transition-colors">
                                <item.icon className="h-4 w-4 text-primary" />
                            </div>
                            <div className="flex-1 min-w-0">
                                <p className="text-sm font-semibold text-foreground">{item.label}</p>
                                <p className="text-xs text-muted-foreground">{isLoading ? "..." : item.sub}</p>
                            </div>
                            <ArrowUpRight className="h-4 w-4 text-muted-foreground/40 group-hover:text-primary transition-colors flex-shrink-0" />
                        </Link>
                    ))}

                    {/* Alert row */}
                    <div className="flex items-center gap-4 p-4 bg-red-500/5 border border-red-500/20 rounded-xl">
                        <div className="h-9 w-9 rounded-lg bg-red-500/10 flex items-center justify-center flex-shrink-0">
                            <AlertTriangle className="h-4 w-4 text-red-400" />
                        </div>
                        <div className="flex-1 min-w-0">
                            <p className="text-sm font-semibold text-foreground">Trainers em risco</p>
                            <p className="text-xs text-muted-foreground">Sem login há 7d+</p>
                        </div>
                        <Badge className="bg-red-500/10 text-red-400 border-red-500/20 font-bold text-xs flex-shrink-0">
                            ver
                        </Badge>
                    </div>
                </div>

                {/* Activity feed */}
                <div className="md:col-span-2 bg-card/50 border border-border/40 rounded-xl overflow-hidden">
                    <div className="flex items-center justify-between px-5 py-4 border-b border-border/40">
                        <div className="flex items-center gap-2">
                            <Clock className="h-4 w-4 text-muted-foreground" />
                            <p className="text-sm font-bold text-foreground">Atividade recente</p>
                        </div>
                        <Badge variant="outline" className="text-xs font-semibold">
                            Hoje
                        </Badge>
                    </div>
                    <div className="divide-y divide-border/30">
                        {MOCK_ACTIVITY.map((event, i) => (
                            <div key={i} className="flex items-start gap-4 px-5 py-3.5 hover:bg-card/80 transition-colors">
                                <div className={`mt-1.5 h-2 w-2 rounded-full flex-shrink-0 ${activityDot[event.type]}`} />
                                <p className="text-sm text-muted-foreground flex-1 leading-snug">
                                    {event.text}
                                </p>
                                <span className="text-xs text-muted-foreground/50 flex-shrink-0 font-medium">
                                    {event.time}
                                </span>
                            </div>
                        ))}
                    </div>
                    <div className="px-5 py-3 border-t border-border/40">
                        <p className="text-xs text-muted-foreground/50 text-center">
                            Feed em tempo real — implemente via Supabase Realtime ou polling
                        </p>
                    </div>
                </div>

            </div>
        </div>
    )
}
