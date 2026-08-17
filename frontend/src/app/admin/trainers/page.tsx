"use client"

import { useEffect, useState, useMemo } from "react"
import Link from "next/link"
import {
    Table, TableBody, TableCell, TableHead,
    TableHeader, TableRow,
} from "@/components/ui/table"
import { Switch }  from "@/components/ui/switch"
import { Badge }   from "@/components/ui/badge"
import { Button }  from "@/components/ui/button"
import { Input }   from "@/components/ui/input"
import {
    Select, SelectContent, SelectItem,
    SelectTrigger, SelectValue,
} from "@/components/ui/select"
import {
    AlertDialog, AlertDialogAction, AlertDialogCancel,
    AlertDialogContent, AlertDialogDescription,
    AlertDialogFooter, AlertDialogHeader, AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { ApiClient, User, SubscriptionPlan } from "@/lib/api"
import { CreateTrainerDialog } from "./create-trainer-dialog"
import { toast } from "sonner"
import {
    Trash2, Copy, CheckCircle, Sparkles, Search,
    Users, Filter, Wifi,
} from "lucide-react"

type StatusFilter = "ALL" | "ACTIVE" | "INACTIVE" | "PENDING"

function SkeletonRow() {
    return (
        <TableRow className="border-border/40 hover:bg-transparent">
            {Array.from({ length: 5 }).map((_, i) => (
                <TableCell key={i}>
                    <div className="h-4 rounded bg-muted animate-pulse" style={{ width: `${[140, 180, 80, 120, 60][i]}px` }} />
                </TableCell>
            ))}
        </TableRow>
    )
}

export default function TrainersPage() {
    const [trainers, setTrainers] = useState<User[]>([])
    const [plans, setPlans]       = useState<SubscriptionPlan[]>([])
    const [isLoading, setIsLoading] = useState(true)
    const [search, setSearch]     = useState("")
    const [statusFilter, setStatusFilter] = useState<StatusFilter>("ALL")
    const [deleteTarget, setDeleteTarget] = useState<{ id: string; isInvite: boolean; name: string } | null>(null)
    const [isDeleting, setIsDeleting] = useState(false)

    const fetchData = async () => {
        try {
            const [trainersData, plansData] = await Promise.all([
                ApiClient.admin.getTrainers(),
                ApiClient.admin.getPlans(),
            ])
            setTrainers(trainersData)
            setPlans(plansData)
        } catch {
            toast.error("Erro ao carregar dados")
        } finally {
            setIsLoading(false)
        }
    }

    useEffect(() => { fetchData() }, [])

    const handleToggleStatus = async (trainerId: string, current: boolean) => {
        try {
            await ApiClient.admin.toggleTrainerStatus(trainerId, !current)
            toast.success(`Trainer ${!current ? "ativado" : "desativado"} com sucesso`)
            fetchData()
        } catch {
            toast.error("Falha ao alterar status")
        }
    }

    const handleToggleIoT = async (trainerId: string, current: boolean) => {
        try {
            await ApiClient.admin.toggleTrainerIoT(trainerId, !current)
            toast.success(`IoT ${!current ? "habilitado" : "desabilitado"}`)
            fetchData()
        } catch {
            toast.error("Falha ao alterar IoT")
        }
    }

    const handleAssignPlan = async (trainerId: string, planId: string) => {
        try {
            await ApiClient.admin.assignTrainerPlan(trainerId, planId)
            const plan = plans.find((p) => p.id === planId)
            toast.success(`Plano "${plan?.name}" atribuído com sucesso`)
            fetchData()
        } catch {
            toast.error("Falha ao atribuir plano")
        }
    }

    const handleDelete = async () => {
        if (!deleteTarget) return
        setIsDeleting(true)
        try {
            if (deleteTarget.isInvite) {
                await ApiClient.deleteInvite(deleteTarget.id)
            } else {
                await ApiClient.admin.deleteTrainer(deleteTarget.id)
            }
            toast.success(`${deleteTarget.isInvite ? "Convite" : "Trainer"} removido`)
            fetchData()
        } catch {
            toast.error("Falha ao remover")
        } finally {
            setIsDeleting(false)
            setDeleteTarget(null)
        }
    }

    const handleApprove = async (trainerId: string) => {
        try {
            await ApiClient.admin.verifyTrainer(trainerId)
            toast.success("Trainer aprovado com sucesso")
            fetchData()
        } catch {
            toast.error("Falha ao aprovar trainer")
        }
    }

    const copyLink = (link: string) => {
        navigator.clipboard.writeText(link)
        toast.success("Link copiado!")
    }

    const pendingApproval = trainers.filter(
        (t) => t.invite_status !== "PENDING" && t.trainer_profile?.is_verified === false
    )

    const filtered = useMemo(() => {
        const active = trainers.filter(
            (t) => t.invite_status === "PENDING" || t.trainer_profile?.is_verified !== false
        )
        return active.filter((t) => {
            const q = search.toLowerCase()
            const matchSearch =
                !q ||
                t.email.toLowerCase().includes(q) ||
                (t.full_name?.toLowerCase().includes(q) ?? false)

            const isInvite = t.invite_status === "PENDING"
            const matchStatus =
                statusFilter === "ALL" ||
                (statusFilter === "PENDING"  && isInvite) ||
                (statusFilter === "ACTIVE"   && !isInvite && (t.is_active ?? false)) ||
                (statusFilter === "INACTIVE" && !isInvite && !(t.is_active ?? false))

            return matchSearch && matchStatus
        })
    }, [trainers, search, statusFilter])

    return (
        <div className="flex flex-col gap-8 animate-in fade-in duration-500">

            {/* Header */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <h1 className="text-3xl font-black tracking-tight text-foreground">Trainers</h1>
                    <p className="text-muted-foreground text-sm mt-1">
                        {isLoading ? "Carregando..." : `${trainers.length} cadastrados · ${trainers.filter(t => t.is_active).length} ativos`}
                    </p>
                </div>
                <CreateTrainerDialog onTrainerCreated={fetchData} />
            </div>

            {/* Pending approval */}
            {(isLoading || pendingApproval.length > 0) && (
                <div className="flex flex-col gap-3">
                    <div className="flex items-center gap-2">
                        <h2 className="text-sm font-bold text-foreground">Aguardando aprovação</h2>
                        {pendingApproval.length > 0 && (
                            <Badge className="bg-amber-500/10 text-amber-400 border-amber-500/20 font-bold">
                                {pendingApproval.length}
                            </Badge>
                        )}
                    </div>
                    <div className="rounded-xl border border-amber-500/20 bg-amber-500/5 overflow-hidden">
                        <Table>
                            <TableHeader>
                                <TableRow className="border-amber-500/20 hover:bg-transparent">
                                    <TableHead className="text-muted-foreground font-bold text-xs uppercase tracking-wider">Nome</TableHead>
                                    <TableHead className="text-muted-foreground font-bold text-xs uppercase tracking-wider">Email</TableHead>
                                    <TableHead className="w-40" />
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {isLoading ? (
                                    <TableRow><TableCell colSpan={3} className="text-center text-muted-foreground py-6 text-sm">Carregando...</TableCell></TableRow>
                                ) : pendingApproval.map((t) => (
                                    <TableRow key={t.id} className="border-border/30 hover:bg-card/50">
                                        <TableCell className="font-semibold text-foreground">
                                            {t.full_name || t.email.split("@")[0]}
                                        </TableCell>
                                        <TableCell className="text-muted-foreground">{t.email}</TableCell>
                                        <TableCell>
                                            <div className="flex items-center justify-end gap-2">
                                                <Button
                                                    size="sm"
                                                    className="bg-primary/15 text-primary hover:bg-primary/25 border border-primary/20 font-semibold h-8"
                                                    onClick={() => handleApprove(t.id)}
                                                >
                                                    <CheckCircle className="h-3.5 w-3.5 mr-1.5" />
                                                    Aprovar
                                                </Button>
                                                <Button
                                                    variant="ghost" size="icon"
                                                    className="h-8 w-8 text-muted-foreground hover:text-destructive hover:bg-destructive/10"
                                                    onClick={() => setDeleteTarget({ id: t.id, isInvite: false, name: t.full_name || t.email })}
                                                >
                                                    <Trash2 className="h-3.5 w-3.5" />
                                                </Button>
                                            </div>
                                        </TableCell>
                                    </TableRow>
                                ))}
                            </TableBody>
                        </Table>
                    </div>
                </div>
            )}

            {/* Search + filter */}
            <div className="flex flex-col sm:flex-row gap-3">
                <div className="relative flex-1">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <Input
                        placeholder="Buscar por nome ou email..."
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        className="pl-9"
                    />
                </div>
                <Select value={statusFilter} onValueChange={(v) => setStatusFilter(v as StatusFilter)}>
                    <SelectTrigger className="w-full sm:w-44">
                        <Filter className="h-3.5 w-3.5 mr-2 text-muted-foreground" />
                        <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="ALL">Todos os status</SelectItem>
                        <SelectItem value="ACTIVE">Ativos</SelectItem>
                        <SelectItem value="INACTIVE">Inativos</SelectItem>
                        <SelectItem value="PENDING">Convite pendente</SelectItem>
                    </SelectContent>
                </Select>
            </div>

            {/* Main table */}
            <div className="rounded-xl border border-border/40 bg-card/30 overflow-hidden">
                <Table>
                    <TableHeader>
                        <TableRow className="border-border/40 hover:bg-transparent">
                            <TableHead className="text-muted-foreground font-bold text-xs uppercase tracking-wider pl-5">Trainer</TableHead>
                            <TableHead className="text-muted-foreground font-bold text-xs uppercase tracking-wider">Status</TableHead>
                            <TableHead className="text-muted-foreground font-bold text-xs uppercase tracking-wider">Plano</TableHead>
                            <TableHead className="text-muted-foreground font-bold text-xs uppercase tracking-wider text-center">IoT</TableHead>
                            <TableHead className="w-20 pr-5" />
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {isLoading ? (
                            Array.from({ length: 5 }).map((_, i) => <SkeletonRow key={i} />)
                        ) : filtered.length === 0 ? (
                            <TableRow className="hover:bg-transparent">
                                <TableCell colSpan={5} className="h-48 text-center">
                                    <div className="flex flex-col items-center gap-3 text-muted-foreground">
                                        <div className="h-12 w-12 rounded-full bg-muted flex items-center justify-center">
                                            <Users className="h-5 w-5" />
                                        </div>
                                        <p className="font-semibold text-foreground">
                                            {search || statusFilter !== "ALL" ? "Nenhum resultado" : "Nenhum trainer cadastrado"}
                                        </p>
                                        <p className="text-sm">
                                            {search || statusFilter !== "ALL"
                                                ? "Tente ajustar os filtros"
                                                : "Convide o primeiro trainer usando o botão acima"}
                                        </p>
                                    </div>
                                </TableCell>
                            </TableRow>
                        ) : (
                            filtered.map((trainer) => {
                                const isInvite  = trainer.invite_status === "PENDING"
                                const hasAI     = trainer.trainer_profile?.enable_ai_workouts ?? false
                                const currentPlan = plans.find((p) => p.id === trainer.plan_id)
                                return (
                                    <TableRow key={trainer.id} className="border-border/30 hover:bg-card/50 transition-colors">
                                        <TableCell className="pl-5 py-4">
                                            <div className="flex flex-col">
                                                {isInvite ? (
                                                    <span className="text-sm font-medium text-muted-foreground italic">Convite pendente</span>
                                                ) : (
                                                    <Link
                                                        href={`/admin/trainers/${trainer.id}`}
                                                        className="text-sm font-semibold text-foreground hover:text-primary transition-colors"
                                                    >
                                                        {trainer.full_name || trainer.email.split("@")[0]}
                                                    </Link>
                                                )}
                                                <span className="text-xs text-muted-foreground mt-0.5">{trainer.email}</span>
                                            </div>
                                        </TableCell>

                                        <TableCell>
                                            {isInvite ? (
                                                <Badge className="bg-amber-500/10 text-amber-400 border-amber-500/20 font-bold text-xs">
                                                    Pendente
                                                </Badge>
                                            ) : (
                                                <div className="flex items-center gap-2">
                                                    <Switch
                                                        checked={trainer.is_active ?? false}
                                                        onCheckedChange={() => handleToggleStatus(trainer.id, trainer.is_active ?? false)}
                                                        className="data-[state=checked]:bg-primary scale-90"
                                                    />
                                                    <Badge className={`font-bold text-xs ${
                                                        trainer.is_active
                                                            ? "bg-green-500/10 text-green-400 border-green-500/20"
                                                            : "bg-muted text-muted-foreground border-border"
                                                    }`}>
                                                        {trainer.is_active ? "Ativo" : "Inativo"}
                                                    </Badge>
                                                </div>
                                            )}
                                        </TableCell>

                                        <TableCell>
                                            {!isInvite && (
                                                <div className="flex flex-col gap-1.5">
                                                    <Select
                                                        value={trainer.plan_id ?? ""}
                                                        onValueChange={(planId) => handleAssignPlan(trainer.id, planId)}
                                                    >
                                                        <SelectTrigger className="h-7 w-36 text-xs border-border/40 bg-background/50">
                                                            <SelectValue placeholder="Sem plano" />
                                                        </SelectTrigger>
                                                        <SelectContent>
                                                            {plans.map((plan) => (
                                                                <SelectItem key={plan.id} value={plan.id} className="text-xs">
                                                                    {plan.name}
                                                                </SelectItem>
                                                            ))}
                                                        </SelectContent>
                                                    </Select>
                                                    {hasAI && (
                                                        <Badge className="gap-1 text-primary border-primary/20 bg-primary/10 w-fit text-[10px] px-1.5 py-0 font-bold">
                                                            <Sparkles className="h-2.5 w-2.5" /> IA Ativa
                                                        </Badge>
                                                    )}
                                                </div>
                                            )}
                                        </TableCell>

                                        <TableCell className="text-center">
                                            {!isInvite && (
                                                <Switch
                                                    checked={trainer.trainer_profile?.enable_iot ?? false}
                                                    onCheckedChange={() => handleToggleIoT(trainer.id, trainer.trainer_profile?.enable_iot ?? false)}
                                                    className="data-[state=checked]:bg-cyan-500 scale-90"
                                                />
                                            )}
                                        </TableCell>

                                        <TableCell className="pr-5">
                                            <div className="flex items-center justify-end gap-1">
                                                {isInvite && trainer.invite_link && (
                                                    <Button
                                                        variant="ghost" size="icon"
                                                        className="h-8 w-8 text-muted-foreground hover:text-primary hover:bg-primary/10"
                                                        onClick={() => copyLink(trainer.invite_link!)}
                                                        title="Copiar link do convite"
                                                    >
                                                        <Copy className="h-3.5 w-3.5" />
                                                    </Button>
                                                )}
                                                <Button
                                                    variant="ghost" size="icon"
                                                    className="h-8 w-8 text-muted-foreground hover:text-destructive hover:bg-destructive/10"
                                                    onClick={() => setDeleteTarget({
                                                        id: trainer.id,
                                                        isInvite,
                                                        name: trainer.full_name || trainer.email,
                                                    })}
                                                    title="Remover"
                                                >
                                                    <Trash2 className="h-3.5 w-3.5" />
                                                </Button>
                                            </div>
                                        </TableCell>
                                    </TableRow>
                                )
                            })
                        )}
                    </TableBody>
                </Table>
            </div>

            {/* Delete confirm dialog */}
            <AlertDialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
                <AlertDialogContent>
                    <AlertDialogHeader>
                        <AlertDialogTitle>
                            Remover {deleteTarget?.isInvite ? "convite" : "trainer"}?
                        </AlertDialogTitle>
                        <AlertDialogDescription>
                            <strong>{deleteTarget?.name}</strong> será removido permanentemente. Esta ação não pode ser desfeita.
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogCancel disabled={isDeleting}>Cancelar</AlertDialogCancel>
                        <AlertDialogAction
                            onClick={handleDelete}
                            disabled={isDeleting}
                            className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                        >
                            {isDeleting ? "Removendo..." : "Sim, remover"}
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>

        </div>
    )
}
