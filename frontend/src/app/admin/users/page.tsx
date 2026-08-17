"use client"

import { useEffect, useState, useMemo } from "react"
import {
    Table, TableBody, TableCell, TableHead,
    TableHeader, TableRow,
} from "@/components/ui/table"
import { Badge }   from "@/components/ui/badge"
import { Input }   from "@/components/ui/input"
import { Button }  from "@/components/ui/button"
import { ApiClient, User } from "@/lib/api"
import { Search, Trash2, UserCheck, Users } from "lucide-react"
import {
    AlertDialog, AlertDialogAction, AlertDialogCancel,
    AlertDialogContent, AlertDialogDescription,
    AlertDialogFooter, AlertDialogHeader, AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { toast } from "sonner"

type RoleFilter = "ALL" | "TRAINER" | "STUDENT"

function formatDate(dateStr?: string) {
    if (!dateStr) return "—"
    const d = new Date(dateStr)
    return (
        d.toLocaleDateString("pt-BR", { day: "2-digit", month: "2-digit", year: "2-digit" }) +
        " " +
        d.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })
    )
}

function RoleBadge({ role }: { role: string }) {
    if (role === "TRAINER")
        return <Badge className="bg-primary/10 text-primary border-primary/20 font-bold text-xs">Trainer</Badge>
    if (role === "STUDENT")
        return <Badge className="bg-green-500/10 text-green-400 border-green-500/20 font-bold text-xs">Aluno</Badge>
    if (role === "SUPER_ADMIN")
        return <Badge className="bg-amber-500/10 text-amber-400 border-amber-500/20 font-bold text-xs">Admin</Badge>
    return <Badge variant="outline" className="text-xs">{role}</Badge>
}

function SkeletonRow() {
    return (
        <TableRow className="border-border/30 hover:bg-transparent">
            {[160, 200, 70, 70, 100, 120, 80].map((w, i) => (
                <TableCell key={i}>
                    <div className="h-4 rounded bg-muted animate-pulse" style={{ width: `${w}px` }} />
                </TableCell>
            ))}
        </TableRow>
    )
}

export default function UsersPage() {
    const [users, setUsers]           = useState<User[]>([])
    const [isLoading, setIsLoading]   = useState(true)
    const [search, setSearch]         = useState("")
    const [roleFilter, setRoleFilter] = useState<RoleFilter>("ALL")
    const [promoteTarget, setPromoteTarget] = useState<User | null>(null)
    const [promoting, setPromoting]   = useState(false)
    const [deleteTarget, setDeleteTarget] = useState<User | null>(null)
    const [deleting, setDeleting]     = useState(false)

    const fetchUsers = () => {
        ApiClient.getAllUsers()
            .then(setUsers)
            .catch(() => toast.error("Erro ao carregar usuários"))
            .finally(() => setIsLoading(false))
    }

    useEffect(() => { fetchUsers() }, [])

    const handleDelete = async () => {
        if (!deleteTarget) return
        setDeleting(true)
        try {
            await ApiClient.deleteUser(deleteTarget.id)
            setUsers((prev) => prev.filter((u) => u.id !== deleteTarget.id))
            toast.success("Conta removida com sucesso")
            setDeleteTarget(null)
        } catch {
            toast.error("Erro ao excluir usuário")
        } finally {
            setDeleting(false)
        }
    }

    const handlePromote = async () => {
        if (!promoteTarget) return
        setPromoting(true)
        try {
            const updated = await ApiClient.promoteToTrainer(promoteTarget.id)
            setUsers((prev) => prev.map((u) => (u.id === updated.id ? updated : u)))
            toast.success(`${promoteTarget.full_name || promoteTarget.email} promovido a Personal Trainer`)
            setPromoteTarget(null)
        } catch {
            toast.error("Erro ao promover usuário")
        } finally {
            setPromoting(false)
        }
    }

    const filtered = useMemo(() => {
        return users.filter((u) => {
            const q = search.toLowerCase()
            const matchSearch =
                !q ||
                u.email.toLowerCase().includes(q) ||
                (u.full_name ?? "").toLowerCase().includes(q)
            const matchRole = roleFilter === "ALL" || u.role === roleFilter
            return matchSearch && matchRole
        })
    }, [users, search, roleFilter])

    const rolePills: { value: RoleFilter; label: string; count: number }[] = [
        { value: "ALL",     label: "Todos",    count: users.length },
        { value: "TRAINER", label: "Trainers", count: users.filter((u) => u.role === "TRAINER").length },
        { value: "STUDENT", label: "Alunos",   count: users.filter((u) => u.role === "STUDENT").length },
    ]

    return (
        <div className="flex flex-col gap-8 animate-in fade-in duration-500">

            {/* Header */}
            <div>
                <h1 className="text-3xl font-black tracking-tight text-foreground">Usuários</h1>
                <p className="text-muted-foreground text-sm mt-1">
                    {isLoading ? "Carregando..." : `${users.length} cadastrados na plataforma`}
                </p>
            </div>

            {/* Filters */}
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
                <div className="flex gap-2">
                    {rolePills.map((pill) => (
                        <button
                            key={pill.value}
                            onClick={() => setRoleFilter(pill.value)}
                            className={`
                                flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-semibold
                                transition-all duration-200 border
                                ${roleFilter === pill.value
                                    ? "bg-primary/15 text-primary border-primary/20"
                                    : "bg-card/50 text-muted-foreground border-border/40 hover:bg-card hover:text-foreground"}
                            `}
                        >
                            {pill.label}
                            {!isLoading && (
                                <span className={`text-xs px-1.5 py-0.5 rounded-full font-bold ${
                                    roleFilter === pill.value
                                        ? "bg-primary/20 text-primary"
                                        : "bg-muted text-muted-foreground"
                                }`}>
                                    {pill.count}
                                </span>
                            )}
                        </button>
                    ))}
                </div>
            </div>

            {/* Table */}
            <div className="rounded-xl border border-border/40 bg-card/30 overflow-hidden overflow-x-auto">
                <Table>
                    <TableHeader>
                        <TableRow className="border-border/40 hover:bg-transparent">
                            <TableHead className="text-muted-foreground font-bold text-xs uppercase tracking-wider pl-5">Usuário</TableHead>
                            <TableHead className="text-muted-foreground font-bold text-xs uppercase tracking-wider">Perfil</TableHead>
                            <TableHead className="text-muted-foreground font-bold text-xs uppercase tracking-wider">Status</TableHead>
                            <TableHead className="text-muted-foreground font-bold text-xs uppercase tracking-wider">XP · Streak</TableHead>
                            <TableHead className="text-muted-foreground font-bold text-xs uppercase tracking-wider">Último login</TableHead>
                            <TableHead className="w-40 pr-5" />
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {isLoading ? (
                            Array.from({ length: 6 }).map((_, i) => <SkeletonRow key={i} />)
                        ) : filtered.length === 0 ? (
                            <TableRow className="hover:bg-transparent">
                                <TableCell colSpan={6} className="h-48 text-center">
                                    <div className="flex flex-col items-center gap-3 text-muted-foreground">
                                        <div className="h-12 w-12 rounded-full bg-muted flex items-center justify-center">
                                            <Users className="h-5 w-5" />
                                        </div>
                                        <p className="font-semibold text-foreground">Nenhum usuário encontrado</p>
                                        <p className="text-sm">Tente ajustar os filtros ou a busca</p>
                                    </div>
                                </TableCell>
                            </TableRow>
                        ) : (
                            filtered.map((user) => (
                                <TableRow key={user.id} className="border-border/30 hover:bg-card/50 transition-colors">
                                    <TableCell className="pl-5 py-4">
                                        <div className="flex flex-col">
                                            <span className="text-sm font-semibold text-foreground">
                                                {user.full_name || user.email.split("@")[0]}
                                            </span>
                                            <span className="text-xs text-muted-foreground mt-0.5">{user.email}</span>
                                        </div>
                                    </TableCell>
                                    <TableCell><RoleBadge role={user.role} /></TableCell>
                                    <TableCell>
                                        <Badge className={`font-bold text-xs ${
                                            user.is_active
                                                ? "bg-green-500/10 text-green-400 border-green-500/20"
                                                : "bg-muted text-muted-foreground border-border"
                                        }`}>
                                            {user.is_active ? "Ativo" : "Inativo"}
                                        </Badge>
                                    </TableCell>
                                    <TableCell>
                                        <div className="flex items-center gap-2 text-sm">
                                            <span className="font-semibold text-primary">
                                                {(user.xp_points ?? 0).toLocaleString("pt-BR")} XP
                                            </span>
                                            <span className="text-muted-foreground/40">·</span>
                                            <span className="text-muted-foreground">
                                                {user.current_streak ?? 0} dias
                                            </span>
                                        </div>
                                    </TableCell>
                                    <TableCell className="text-sm text-muted-foreground">
                                        {formatDate(user.last_login_at)}
                                    </TableCell>
                                    <TableCell className="pr-5">
                                        <div className="flex items-center justify-end gap-2">
                                            {user.role === "STUDENT" && (
                                                <Button
                                                    size="sm" variant="ghost"
                                                    className="h-8 text-xs text-primary hover:bg-primary/10 font-semibold"
                                                    onClick={() => setPromoteTarget(user)}
                                                >
                                                    <UserCheck className="h-3.5 w-3.5 mr-1.5" />
                                                    Promover
                                                </Button>
                                            )}
                                            {user.role !== "SUPER_ADMIN" && (
                                                <Button
                                                    size="icon" variant="ghost"
                                                    className="h-8 w-8 text-muted-foreground hover:text-destructive hover:bg-destructive/10"
                                                    onClick={() => setDeleteTarget(user)}
                                                >
                                                    <Trash2 className="h-3.5 w-3.5" />
                                                </Button>
                                            )}
                                        </div>
                                    </TableCell>
                                </TableRow>
                            ))
                        )}
                    </TableBody>
                </Table>
            </div>

            {/* Delete dialog */}
            <AlertDialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
                <AlertDialogContent>
                    <AlertDialogHeader>
                        <AlertDialogTitle>Excluir conta permanentemente?</AlertDialogTitle>
                        <AlertDialogDescription>
                            A conta de <strong>{deleteTarget?.full_name || deleteTarget?.email}</strong> e todos os
                            seus dados serão removidos. Esta ação não pode ser desfeita.
                            {deleteTarget?.role === "TRAINER" && (
                                <span className="block mt-2 text-amber-400 font-medium">
                                    Atenção: os alunos deste trainer perderão o vínculo.
                                </span>
                            )}
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogCancel disabled={deleting}>Cancelar</AlertDialogCancel>
                        <AlertDialogAction
                            onClick={handleDelete}
                            disabled={deleting}
                            className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                        >
                            {deleting ? "Excluindo..." : "Excluir permanentemente"}
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>

            {/* Promote dialog */}
            <AlertDialog open={!!promoteTarget} onOpenChange={(open) => !open && setPromoteTarget(null)}>
                <AlertDialogContent>
                    <AlertDialogHeader>
                        <AlertDialogTitle>Promover a Personal Trainer?</AlertDialogTitle>
                        <AlertDialogDescription>
                            <strong>{promoteTarget?.full_name || promoteTarget?.email}</strong> será promovido de Aluno
                            para Personal Trainer. Um perfil de treinador será criado automaticamente.
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogCancel disabled={promoting}>Cancelar</AlertDialogCancel>
                        <AlertDialogAction
                            onClick={handlePromote}
                            disabled={promoting}
                            className="bg-primary text-primary-foreground hover:bg-primary/90"
                        >
                            {promoting ? "Promovendo..." : "Confirmar promoção"}
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>

        </div>
    )
}
