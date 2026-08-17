"use client"

import { useState, useEffect, use } from "react"
import { useRouter } from "next/navigation"
import { ApiClient, User, WorkoutSession } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { 
    ArrowLeft, 
    History, 
    Calendar, 
    Clock, 
    Activity, 
    Zap, 
    ChevronRight,
    Trophy,
    Flame
} from "lucide-react"
import { Badge } from "@/components/ui/badge"
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from "@/components/ui/table"

export default function StudentSessionsPage({ params }: { params: Promise<{ id: string }> }) {
    const { id } = use(params)
    const router = useRouter()
    const [student, setStudent] = useState<User | null>(null)
    const [sessions, setSessions] = useState<WorkoutSession[]>([])
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        const fetchData = async () => {
            try {
                const [studentData, sessionsData] = await Promise.all([
                    ApiClient.getStudent(id),
                    ApiClient.getStudentHistory(id)
                ])
                setStudent(studentData)
                setSessions(sessionsData)
            } catch (err) {
                console.error("Failed to fetch student data or history", err)
            } finally {
                setLoading(false)
            }
        }
        fetchData()
    }, [id])

    const formatDate = (dateString: string) => {
        return new Date(dateString).toLocaleDateString('pt-BR', {
            day: '2-digit',
            month: 'long',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        })
    }

    const formatDuration = (start: string, end?: string | null) => {
        if (!end) return "N/A"
        const startTime = new Date(start).getTime()
        const endTime = new Date(end).getTime()
        const diffMs = endTime - startTime
        const diffMins = Math.round(diffMs / 60000)
        return `${diffMins} min`
    }

    if (loading) {
        return (
            <div className="flex h-screen w-full items-center justify-center bg-background">
                <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
            </div>
        )
    }

    if (!student) {
        return (
            <div className="p-8 text-center">
                <p className="text-zinc-500">Aluno não encontrado.</p>
                <Button variant="ghost" className="mt-4" onClick={() => router.back()}>
                    <ArrowLeft className="mr-2 h-4 w-4" /> Voltar
                </Button>
            </div>
        )
    }

    return (
        <div className="flex flex-col gap-8 max-w-6xl mx-auto">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-4">
                    <Button variant="ghost" size="icon" onClick={() => router.back()} className="rounded-full border border-zinc-800">
                        <ArrowLeft className="h-4 w-4" />
                    </Button>
                    <div>
                        <h1 className="text-3xl font-black tracking-tight text-white">Histórico de Sessões</h1>
                        <p className="text-zinc-400">Atleta: {student.full_name || student.email}</p>
                    </div>
                </div>
                <div className="hidden md:flex items-center gap-4">
                    <div className="bg-zinc-900 border border-zinc-800 p-3 rounded-xl flex items-center gap-3">
                        <Flame className="h-5 w-5 text-orange-500" />
                        <div>
                            <p className="text-[10px] font-bold text-zinc-500 uppercase">Streak Atual</p>
                            <p className="text-lg font-black text-white">{student.current_streak} dias</p>
                        </div>
                    </div>
                    <div className="bg-zinc-900 border border-zinc-800 p-3 rounded-xl flex items-center gap-3">
                        <Trophy className="h-5 w-5 text-yellow-500" />
                        <div>
                            <p className="text-[10px] font-bold text-zinc-500 uppercase">Nível</p>
                            <p className="text-lg font-black text-white">{student.level}</p>
                        </div>
                    </div>
                </div>
            </div>

            {/* Quick Stats Cards */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <Card className="bg-zinc-900 border-zinc-800">
                    <CardHeader className="pb-2">
                        <CardTitle className="text-sm font-medium text-zinc-500 flex items-center gap-2">
                            <Activity className="h-4 w-4 text-primary" /> Total de Treinos
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        <p className="text-2xl font-black text-white">{sessions.length}</p>
                    </CardContent>
                </Card>
                <Card className="bg-zinc-900 border-zinc-800">
                    <CardHeader className="pb-2">
                        <CardTitle className="text-sm font-medium text-zinc-500 flex items-center gap-2">
                            <Clock className="h-4 w-4 text-blue-400" /> Tempo em Atividade
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        <p className="text-2xl font-black text-white">
                            {sessions.reduce((acc, s) => {
                                if (!s.end_time) return acc
                                return acc + (new Date(s.end_time).getTime() - new Date(s.start_time).getTime())
                            }, 0) / (1000 * 60 * 60) | 0}h {Math.round((sessions.reduce((acc, s) => {
                                if (!s.end_time) return acc
                                return acc + (new Date(s.end_time).getTime() - new Date(s.start_time).getTime())
                            }, 0) / (1000 * 60)) % 60)}min
                        </p>
                    </CardContent>
                </Card>
                <Card className="bg-zinc-900 border-zinc-800">
                    <CardHeader className="pb-2">
                        <CardTitle className="text-sm font-medium text-zinc-500 flex items-center gap-2">
                            <Zap className="h-4 w-4 text-yellow-400" /> Total de XP
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        <p className="text-2xl font-black text-white">{student.xp_points} XP</p>
                    </CardContent>
                </Card>
            </div>

            {/* History Table */}
            <Card className="bg-zinc-900 border-zinc-800 overflow-hidden shadow-2xl">
                <CardHeader className="bg-zinc-900/50 border-b border-zinc-800">
                    <CardTitle className="flex items-center gap-2">
                        <History className="h-5 w-5 text-primary" /> Lista de Sessões Concluídas
                    </CardTitle>
                </CardHeader>
                <CardContent className="p-0">
                    <div className="overflow-x-auto">
                        <Table>
                            <TableHeader>
                                <TableRow className="border-zinc-800 hover:bg-transparent bg-zinc-900/80">
                                    <TableHead className="text-zinc-500 font-bold uppercase text-[10px] pl-6">Data</TableHead>
                                    <TableHead className="text-zinc-500 font-bold uppercase text-[10px]">Treino</TableHead>
                                    <TableHead className="text-zinc-500 font-bold uppercase text-[10px]">Duração</TableHead>
                                    <TableHead className="text-zinc-500 font-bold uppercase text-[10px]">Frequência Cardíaca</TableHead>
                                    <TableHead className="text-zinc-500 font-bold uppercase text-[10px]">XP Ganho</TableHead>
                                    <TableHead className="text-zinc-500 font-bold uppercase text-[10px] text-right pr-6">Status</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {sessions.length === 0 ? (
                                    <TableRow className="border-zinc-800 hover:bg-transparent">
                                        <TableCell colSpan={6} className="h-40 text-center">
                                            <p className="text-zinc-500 italic">Nenhum treino concluído ainda.</p>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    sessions.map((session) => (
                                        <TableRow key={session.id} className="border-zinc-800 hover:bg-zinc-800/30 transition-colors group">
                                            <TableCell className="pl-6 font-medium text-zinc-300">
                                                <div className="flex flex-col">
                                                    <span>{formatDate(session.start_time)}</span>
                                                </div>
                                            </TableCell>
                                            <TableCell className="text-white font-bold">
                                                {session.workout?.name || "Treino Direto"}
                                            </TableCell>
                                            <TableCell className="text-zinc-400">
                                                <div className="flex items-center gap-1.5">
                                                    <Clock className="h-3 w-3 text-zinc-600" />
                                                    {formatDuration(session.start_time, session.end_time)}
                                                </div>
                                            </TableCell>
                                            <TableCell>
                                                {session.average_heart_rate ? (
                                                    <div className="flex items-center gap-2">
                                                        <Activity className="h-3 w-3 text-red-500" />
                                                        <span className="text-zinc-300 font-bold">{session.average_heart_rate} <span className="text-[10px] font-normal text-zinc-500">BPM</span></span>
                                                    </div>
                                                ) : (
                                                    <span className="text-zinc-600 text-xs">—</span>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                <Badge className="bg-primary/10 text-primary border-primary/20">
                                                    +{session.xp_earned || 0} XP
                                                </Badge>
                                            </TableCell>
                                            <TableCell className="text-right pr-6">
                                                <Badge className="bg-green-500/10 text-green-500 border-green-500/20 font-bold">
                                                    CONCLUÍDO
                                                </Badge>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </div>
                </CardContent>
            </Card>
        </div>
    )
}
