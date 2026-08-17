"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { ApiClient, User, HiringRequest } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import {
    DropdownMenu, DropdownMenuContent, DropdownMenuItem,
    DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
    Table, TableBody, TableCell, TableHead,
    TableHeader, TableRow,
} from "@/components/ui/table"
import {
    Plus, Search, MoreHorizontal, User as UserIcon,
    CheckCircle, XCircle, Users, Copy,
} from "lucide-react"
import { toast } from "sonner"

export default function StudentsPage() {
    const [students, setStudents]               = useState<User[]>([])
    const [filteredStudents, setFilteredStudents] = useState<User[]>([])
    const [hiringRequests, setHiringRequests]   = useState<HiringRequest[]>([])
    const [loading, setLoading]                 = useState(true)
    const [requestsLoading, setRequestsLoading] = useState(true)
    const [searchQuery, setSearchQuery]         = useState("")
    const router = useRouter()

    const fetchStudents = async () => {
        try {
            const data = await ApiClient.getStudents()
            setStudents(data)
            setFilteredStudents(data)
        } catch (err) {
            console.error(err)
        } finally {
            setLoading(false)
        }
    }

    const fetchHiringRequests = async () => {
        try {
            const data = await ApiClient.getHiringRequests()
            setHiringRequests(data)
        } catch {
            // Not a trainer or no requests
        } finally {
            setRequestsLoading(false)
        }
    }

    useEffect(() => {
        fetchStudents()
        fetchHiringRequests()
    }, [])

    useEffect(() => {
        const q = searchQuery.toLowerCase()
        setFilteredStudents(
            students.filter(
                (s) =>
                    s.email.toLowerCase().includes(q) ||
                    (s.full_name?.toLowerCase().includes(q) ?? false)
            )
        )
    }, [searchQuery, students])

    const handleAccept = async (requestId: string) => {
        try {
            await ApiClient.acceptHiringRequest(requestId)
            toast.success("Solicitação aceita! Aluno adicionado à sua lista.")
            fetchHiringRequests()
            fetchStudents()
        } catch {
            toast.error("Erro ao aceitar solicitação")
        }
    }

    const handleReject = async (requestId: string) => {
        try {
            await ApiClient.rejectHiringRequest(requestId)
            toast.success("Solicitação recusada.")
            fetchHiringRequests()
        } catch {
            toast.error("Erro ao recusar solicitação")
        }
    }

    const getInitials = (name: string) =>
        name.split(" ").map((w) => w[0]).slice(0, 2).join("").toUpperCase()

    const formatXP = (xp: number) => xp.toLocaleString("pt-BR")

    // Skeleton rows for loading state
    const SkeletonCard = () => (
        <div className="flex items-center gap-3 p-3 rounded-xl border border-border/40 animate-pulse">
            <div className="h-10 w-10 rounded-full bg-muted flex-shrink-0" />
            <div className="flex-1 min-w-0 space-y-1.5">
                <div className="h-3.5 w-28 rounded bg-muted" />
                <div className="h-2.5 w-36 rounded bg-muted" />
            </div>
            <div className="flex flex-col items-end gap-1.5">
                <div className="h-5 w-12 rounded-full bg-muted" />
                <div className="h-2.5 w-16 rounded bg-muted" />
            </div>
        </div>
    )

    return (
        <div className="flex flex-col gap-8 animate-in fade-in duration-500 w-full min-w-0">

            {/* ── Header ── */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <h1 className="text-3xl font-black tracking-tight text-foreground">Alunos</h1>
                    <p className="text-muted-foreground text-sm mt-1">Gerencie todos os seus atletas em um só lugar.</p>
                </div>
                <Link href="/dashboard/students/new" className="w-full md:w-auto">
                    <Button className="w-full md:w-auto bg-primary text-primary-foreground hover:bg-primary/90 font-bold shadow-lg shadow-primary/20">
                        <Plus className="mr-2 h-4 w-4" /> Novo Aluno
                    </Button>
                </Link>
            </div>

            {/* ── Hiring requests ── */}
            {(requestsLoading || hiringRequests.length > 0) && (
                <div className="flex flex-col gap-3">
                    <div className="flex items-center gap-2">
                        <h2 className="text-sm font-bold text-foreground">Solicitações pendentes</h2>
                        {hiringRequests.length > 0 && (
                            <Badge className="bg-amber-500/10 text-amber-400 border-amber-500/20 font-bold">
                                {hiringRequests.length}
                            </Badge>
                        )}
                    </div>
                    <div className="rounded-xl border border-amber-500/20 bg-amber-500/5 divide-y divide-border/30 overflow-hidden">
                        {requestsLoading ? (
                            <div className="flex gap-3 p-4">
                                {[1, 2].map((i) => (
                                    <div key={i} className="h-16 flex-1 bg-muted rounded-lg animate-pulse" />
                                ))}
                            </div>
                        ) : (
                            hiringRequests.map((req) => (
                                <div key={req.id} className="flex items-center justify-between gap-4 px-4 py-3.5">
                                    <div className="flex items-center gap-3 min-w-0">
                                        <Avatar className="h-9 w-9 flex-shrink-0 border border-border/40">
                                            <AvatarImage src={req.student_photo ?? undefined} />
                                            <AvatarFallback className="bg-muted text-muted-foreground font-bold text-sm">
                                                {req.student_name ? getInitials(req.student_name) : "?"}
                                            </AvatarFallback>
                                        </Avatar>
                                        <div className="min-w-0">
                                            <p className="text-sm font-semibold text-foreground truncate">
                                                {req.student_name || "Aluno"}
                                            </p>
                                            <p className="text-xs text-muted-foreground">
                                                {new Date(req.created_at).toLocaleDateString("pt-BR", {
                                                    day: "2-digit", month: "short", year: "numeric",
                                                })}
                                            </p>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-2 flex-shrink-0">
                                        <Button
                                            size="sm"
                                            className="bg-primary/15 text-primary hover:bg-primary/25 border border-primary/20 font-semibold h-8"
                                            onClick={() => handleAccept(req.id)}
                                        >
                                            <CheckCircle className="h-3.5 w-3.5 mr-1.5" /> Aceitar
                                        </Button>
                                        <Button
                                            size="sm" variant="ghost"
                                            className="h-8 text-muted-foreground hover:text-destructive hover:bg-destructive/10 border border-border/40"
                                            onClick={() => handleReject(req.id)}
                                        >
                                            <XCircle className="h-3.5 w-3.5 mr-1.5" /> Recusar
                                        </Button>
                                    </div>
                                </div>
                            ))
                        )}
                    </div>
                </div>
            )}

            {/* ── Search ── */}
            <div className="relative w-full md:w-80">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                    type="search"
                    placeholder="Buscar por nome ou email..."
                    className="pl-10"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                />
            </div>

            {/* ── Mobile: card list ── */}
            <div className="flex flex-col gap-2 md:hidden">
                {loading ? (
                    Array.from({ length: 4 }).map((_, i) => <SkeletonCard key={i} />)
                ) : filteredStudents.length === 0 ? (
                    <div className="flex flex-col items-center justify-center py-16 text-muted-foreground gap-3">
                        <div className="h-14 w-14 rounded-full bg-primary/10 flex items-center justify-center ring-1 ring-primary/20">
                            {searchQuery ? <Search className="h-6 w-6 text-muted-foreground" /> : <Users className="h-6 w-6 text-muted-foreground" />}
                        </div>
                        <p className="font-bold text-foreground text-base">
                            {searchQuery ? "Nenhum aluno encontrado" : "Nenhum aluno adicionado"}
                        </p>
                        <p className="text-sm text-center max-w-xs">
                            {searchQuery
                                ? "Tente ajustar sua busca."
                                : 'Clique em "Novo Aluno" para começar.'}
                        </p>
                    </div>
                ) : (
                    filteredStudents.map((student) => (
                        <div
                            key={student.id}
                            onClick={() => router.push(`/dashboard/students/${student.id}`)}
                            className="flex items-center gap-3 p-3 rounded-xl border border-border/40 bg-card/30 hover:bg-card/60 active:scale-[0.99] transition-all cursor-pointer"
                        >
                            <Avatar className="h-10 w-10 flex-shrink-0 border border-border/40">
                                <AvatarImage src={`https://api.dicebear.com/7.x/initials/svg?seed=${student.full_name}`} />
                                <AvatarFallback className="bg-muted text-muted-foreground font-bold text-sm">
                                    {student.full_name ? getInitials(student.full_name) : "??"}
                                </AvatarFallback>
                            </Avatar>

                            <div className="flex-1 min-w-0">
                                <p className="text-sm font-semibold text-foreground truncate">
                                    {student.full_name || "Sem nome"}
                                </p>
                                <p className="text-xs text-muted-foreground truncate">{student.email}</p>
                                <p className="text-xs text-muted-foreground/60 mt-0.5">Nível {student.level || 1}</p>
                            </div>

                            <div className="flex flex-col items-end gap-1 flex-shrink-0">
                                <Badge className={`text-[10px] font-bold px-2 py-0.5 ${
                                    student.is_active
                                        ? "bg-green-500/10 text-green-400 border-green-500/20"
                                        : "bg-muted text-muted-foreground border-border"
                                }`}>
                                    {student.is_active ? "ATIVO" : "INATIVO"}
                                </Badge>
                                <span className="text-[11px] font-semibold text-primary">
                                    {formatXP(student.xp_points || 0)} XP
                                </span>
                            </div>
                        </div>
                    ))
                )}
            </div>

            {/* ── Desktop: table ── */}
            <div className="hidden md:block rounded-xl border border-border/40 bg-card/30 overflow-hidden shadow-xl">
                <div className="overflow-x-auto">
                    <Table>
                        <TableHeader className="bg-card/50">
                            <TableRow className="border-border/40 hover:bg-transparent">
                                <TableHead className="text-muted-foreground font-bold uppercase text-xs tracking-wider pl-5">Atleta</TableHead>
                                <TableHead className="text-muted-foreground font-bold uppercase text-xs tracking-wider text-center">Status</TableHead>
                                <TableHead className="text-muted-foreground font-bold uppercase text-xs tracking-wider text-center">Nível / XP</TableHead>
                                <TableHead className="text-muted-foreground font-bold uppercase text-xs tracking-wider text-right pr-5">Ações</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {loading ? (
                                Array.from({ length: 5 }).map((_, i) => (
                                    <TableRow key={i} className="border-border/30">
                                        <TableCell className="pl-5"><div className="h-10 w-48 bg-muted rounded animate-pulse" /></TableCell>
                                        <TableCell className="text-center"><div className="h-6 w-14 bg-muted rounded-full animate-pulse mx-auto" /></TableCell>
                                        <TableCell className="text-center"><div className="h-4 w-20 bg-muted rounded animate-pulse mx-auto" /></TableCell>
                                        <TableCell className="pr-5 text-right"><div className="h-8 w-8 bg-muted rounded-full animate-pulse ml-auto" /></TableCell>
                                    </TableRow>
                                ))
                            ) : filteredStudents.length === 0 ? (
                                <TableRow className="hover:bg-transparent">
                                    <TableCell colSpan={4} className="h-64 text-center">
                                        <div className="flex flex-col items-center gap-3 text-muted-foreground py-12">
                                            <div className="bg-primary/10 p-4 rounded-full ring-1 ring-primary/20">
                                                {searchQuery
                                                    ? <Search className="h-8 w-8 text-muted-foreground" />
                                                    : <Users className="h-8 w-8 text-muted-foreground" />}
                                            </div>
                                            <p className="text-base font-bold text-foreground">
                                                {searchQuery ? "Nenhum aluno encontrado" : "Nenhum aluno adicionado"}
                                            </p>
                                            <p className="text-sm max-w-xs">
                                                {searchQuery
                                                    ? "Tente ajustar sua busca."
                                                    : 'Clique em "Novo Aluno" para começar.'}
                                            </p>
                                        </div>
                                    </TableCell>
                                </TableRow>
                            ) : (
                                filteredStudents.map((student) => (
                                    <TableRow
                                        key={student.id}
                                        className="border-border/30 hover:bg-card/50 transition-colors cursor-pointer"
                                        onClick={() => router.push(`/dashboard/students/${student.id}`)}
                                    >
                                        <TableCell className="pl-5 py-4">
                                            <div className="flex items-center gap-3">
                                                <Avatar className="h-9 w-9 border border-border/40 flex-shrink-0">
                                                    <AvatarImage src={`https://api.dicebear.com/7.x/initials/svg?seed=${student.full_name}`} />
                                                    <AvatarFallback className="bg-muted text-muted-foreground font-bold text-sm">
                                                        {student.full_name ? getInitials(student.full_name) : "??"}
                                                    </AvatarFallback>
                                                </Avatar>
                                                <div className="min-w-0">
                                                    <p className="text-sm font-semibold text-foreground truncate">
                                                        {student.full_name || "Sem nome"}
                                                    </p>
                                                    <p className="text-xs text-muted-foreground truncate">{student.email}</p>
                                                </div>
                                            </div>
                                        </TableCell>
                                        <TableCell className="text-center">
                                            <Badge className={`font-bold text-xs ${
                                                student.is_active
                                                    ? "bg-green-500/10 text-green-400 border-green-500/20"
                                                    : "bg-muted text-muted-foreground border-border"
                                            }`}>
                                                {student.is_active ? "ATIVO" : "INATIVO"}
                                            </Badge>
                                        </TableCell>
                                        <TableCell className="text-center">
                                            <p className="text-sm font-bold text-foreground">Nível {student.level || 1}</p>
                                            <p className="text-xs font-semibold text-primary">{formatXP(student.xp_points || 0)} XP</p>
                                        </TableCell>
                                        <TableCell className="text-right pr-5" onClick={(e) => e.stopPropagation()}>
                                            <DropdownMenu>
                                                <DropdownMenuTrigger asChild>
                                                    <Button variant="ghost" className="h-8 w-8 p-0 text-muted-foreground hover:text-foreground">
                                                        <MoreHorizontal className="h-4 w-4" />
                                                    </Button>
                                                </DropdownMenuTrigger>
                                                <DropdownMenuContent align="end">
                                                    <DropdownMenuLabel>Ações</DropdownMenuLabel>
                                                    <DropdownMenuItem onClick={() => router.push(`/dashboard/students/${student.id}`)}>
                                                        <UserIcon className="mr-2 h-4 w-4" /> Ver Perfil
                                                    </DropdownMenuItem>
                                                    {student.invite_status === "PENDING" && student.invite_link && (
                                                        <DropdownMenuItem
                                                            onClick={() => {
                                                                navigator.clipboard.writeText(student.invite_link!)
                                                                toast.success("Link de convite copiado!")
                                                            }}
                                                        >
                                                            <Copy className="mr-2 h-4 w-4" /> Copiar Link Convite
                                                        </DropdownMenuItem>
                                                    )}
                                                    <DropdownMenuSeparator />
                                                    <DropdownMenuItem
                                                        className="text-destructive focus:text-destructive focus:bg-destructive/10"
                                                        onClick={async () => {
                                                            try {
                                                                if (student.invite_status === "PENDING") {
                                                                    await ApiClient.deleteInvite(student.id)
                                                                    toast.success("Convite removido")
                                                                } else {
                                                                    toast.info("Use as configurações do aluno para desativar o acesso")
                                                                }
                                                                const data = await ApiClient.getStudents()
                                                                setStudents(data)
                                                                setFilteredStudents(data)
                                                            } catch {
                                                                toast.error("Erro ao executar ação")
                                                            }
                                                        }}
                                                    >
                                                        {student.invite_status === "PENDING" ? "Remover Convite" : "Desativar Acesso"}
                                                    </DropdownMenuItem>
                                                </DropdownMenuContent>
                                            </DropdownMenu>
                                        </TableCell>
                                    </TableRow>
                                ))
                            )}
                        </TableBody>
                    </Table>
                </div>
            </div>
        </div>
    )
}
