"use client"

import { useEffect, useState } from "react"
import { ApiClient, WorkoutSession } from "@/lib/api"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Calendar, Clock, Flame, Trophy } from "lucide-react"
import { format } from "date-fns"

export default function HistoryPage() {
    const [history, setHistory] = useState<WorkoutSession[]>([])
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        const fetchHistory = async () => {
            try {
                const data = await ApiClient.getHistory()
                setHistory(data)
            } catch (error) {
                console.error("Failed to fetch history", error)
            } finally {
                setLoading(false)
            }
        }
        fetchHistory()
    }, [])

    if (loading) {
        return (
            <div className="flex items-center justify-center min-h-[50vh]">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
            </div>
        )
    }

    return (
        <div className="space-y-6">
            <h1 className="text-3xl font-bold text-white">Histórico de Treinos</h1>

            {history.length === 0 ? (
                <Card className="bg-zinc-900 border-zinc-800">
                    <CardContent className="flex flex-col items-center justify-center py-12 text-center">
                        <Trophy className="h-12 w-12 text-zinc-600 mb-4" />
                        <h3 className="text-lg font-semibold text-white">Nenhum treino ainda</h3>
                        <p className="text-zinc-400">Complete seu primeiro treino para vê-lo aqui!</p>
                    </CardContent>
                </Card>
            ) : (
                <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                    {history.map((session) => (
                        <Card key={session.id} className="bg-zinc-900 border-zinc-800 hover:border-zinc-700 transition-colors">
                            <CardHeader className="pb-2">
                                <div className="flex justify-between items-start">
                                    <CardTitle className="text-lg text-white">
                                        Sessão de Treino
                                    </CardTitle>
                                    <span className="text-xs font-mono text-zinc-500 bg-zinc-950 px-2 py-1 rounded">
                                        {session.status === 'FINISHED' ? 'CONCLUÍDO' : session.status === 'STARTED' ? 'EM ANDAMENTO' : session.status}
                                    </span>
                                </div>
                            </CardHeader>
                            <CardContent>
                                <div className="space-y-3 text-sm text-zinc-400">
                                    <div className="flex items-center gap-2">
                                        <Calendar className="w-4 h-4 text-primary" />
                                        <span>{format(new Date(session.start_time), "dd/MM/yyyy")}</span>
                                    </div>
                                    <div className="flex items-center gap-2">
                                        <Clock className="w-4 h-4 text-primary" />
                                        <span>
                                            {session.end_time
                                                ? `${Math.round((new Date(session.end_time).getTime() - new Date(session.start_time).getTime()) / 60000)} min`
                                                : "Em andamento"}
                                        </span>
                                    </div>
                                    {session.progress_data && (
                                        <div className="flex items-center gap-2">
                                            <Flame className="w-4 h-4 text-primary" />
                                            <span>~{Math.round((new Date(session.end_time || new Date()).getTime() - new Date(session.start_time).getTime()) / 60000) * 5} Kcal</span>
                                        </div>
                                    )}
                                </div>
                            </CardContent>
                        </Card>
                    ))}
                </div>
            )}
        </div>
    )
}
