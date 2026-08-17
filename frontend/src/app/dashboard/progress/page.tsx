"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { ApiClient } from "@/lib/api"
import { TrendingUp, Calendar, Dumbbell, Award, Target, Zap } from "lucide-react"
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';

export default function ProgressPage() {
    const [workouts, setWorkouts] = useState<any[]>([])
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        const fetchData = async () => {
            try {
                const workoutsData = await ApiClient.getWorkouts()
                setWorkouts(workoutsData)
            } catch (error) {
                console.error(error)
            } finally {
                setLoading(false)
            }
        }
        fetchData()
    }, [])

    if (loading) return (
        <div className="flex items-center justify-center h-64">
            <div className="flex items-center gap-3 text-muted-foreground">
                <div className="h-5 w-5 rounded-full border-2 border-primary border-t-transparent animate-spin" />
                Carregando progresso...
            </div>
        </div>
    )

    const now = new Date()
    const completedWorkouts = workouts.filter(w => w.scheduled_for && new Date(w.scheduled_for) < now)
    const upcomingWorkouts = workouts.filter(w => w.scheduled_for && new Date(w.scheduled_for) >= now)

    const totalWorkouts = workouts.length
    const completedCount = completedWorkouts.length
    const completionRate = totalWorkouts > 0 ? Math.round((completedCount / totalWorkouts) * 100) : 0

    const thisMonth = new Date().getMonth()
    const thisYear = new Date().getFullYear()
    const thisMonthWorkouts = completedWorkouts.filter(w => {
        const date = new Date(w.scheduled_for)
        return date.getMonth() === thisMonth && date.getFullYear() === thisYear
    })

    const monthNames = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
    
    // Generate data for the last 6 months
    const chartData = Array.from({ length: 6 }).map((_, i) => {
        const d = new Date()
        d.setMonth(d.getMonth() - (5 - i))
        return {
            name: monthNames[d.getMonth()],
            month: d.getMonth(),
            year: d.getFullYear(),
            treinos: 0
        }
    })

    completedWorkouts.forEach(w => {
        const date = new Date(w.scheduled_for)
        const point = chartData.find(d => d.month === date.getMonth() && d.year === date.getFullYear())
        if (point) point.treinos++
    })

    return (
        <div className="flex flex-col gap-6">
            {/* ===========================
                Header Banner — Design System Violet/Cyan
            =========================== */}
            <div className="relative overflow-hidden rounded-2xl p-5 sm:p-8 text-primary-foreground bg-gradient-to-br from-primary via-purple-600 to-purple-800">
                {/* Ambient blobs */}
                <div className="absolute top-0 right-0 w-72 h-72 rounded-full blur-3xl pointer-events-none"
                    style={{ background: 'radial-gradient(circle, rgba(167,139,250,0.2) 0%, transparent 70%)' }}
                />
                <div className="absolute bottom-0 left-20 w-48 h-48 rounded-full blur-3xl pointer-events-none"
                    style={{ background: 'radial-gradient(circle, rgba(6,182,212,0.15) 0%, transparent 70%)' }}
                />

                <div className="relative z-10 flex items-center gap-4">
                    <div className="bg-white/15 backdrop-blur-sm p-3 rounded-xl">
                        <TrendingUp className="h-8 w-8 text-white" />
                    </div>
                    <div>
                        <h1 className="text-xl sm:text-3xl font-bold tracking-tight">Seu Progresso</h1>
                        <p className="text-white/70 mt-1">Acompanhe sua evolução e conquistas</p>
                    </div>
                </div>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-2 gap-3 sm:gap-4 md:grid-cols-2 lg:grid-cols-4">
                {/* Total de Treinos */}
                <Card className="relative overflow-hidden border-border/50 group hover:border-primary/40 transition-colors duration-300">
                    <div className="absolute inset-0 bg-gradient-to-br from-primary/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium text-muted-foreground">Total de Treinos</CardTitle>
                        <div className="h-8 w-8 rounded-lg bg-primary/15 flex items-center justify-center">
                            <Dumbbell className="h-4 w-4 text-primary" />
                        </div>
                    </CardHeader>
                    <CardContent>
                        <div className="text-3xl font-bold text-foreground">{totalWorkouts}</div>
                        <p className="text-xs text-muted-foreground mt-1">Treinos criados</p>
                        <div className="mt-3 h-1 rounded-full bg-border/50">
                            <div className="h-1 rounded-full bg-primary" style={{ width: '100%' }} />
                        </div>
                    </CardContent>
                </Card>

                {/* Concluídos */}
                <Card className="relative overflow-hidden border-border/50 group hover:border-primary/40 transition-colors duration-300">
                    <div className="absolute inset-0 bg-gradient-to-br from-primary/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium text-muted-foreground">Concluídos</CardTitle>
                        <div className="h-8 w-8 rounded-lg bg-primary/15 flex items-center justify-center">
                            <Award className="h-4 w-4 text-primary" />
                        </div>
                    </CardHeader>
                    <CardContent>
                        <div className="text-3xl font-bold text-foreground">{completedCount}</div>
                        <p className="text-xs text-muted-foreground mt-1">Treinos finalizados</p>
                        <div className="mt-3 h-1 rounded-full bg-border/50">
                            <div className="h-1 rounded-full bg-primary"
                                style={{ width: `${totalWorkouts > 0 ? (completedCount / totalWorkouts) * 100 : 0}%` }}
                            />
                        </div>
                    </CardContent>
                </Card>

                {/* Taxa de Conclusão */}
                <Card className="relative overflow-hidden border-border/50 group hover:border-accent/40 transition-colors duration-300">
                    <div className="absolute inset-0 bg-gradient-to-br from-accent/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium text-muted-foreground">Taxa de Conclusão</CardTitle>
                        <div className="h-8 w-8 rounded-lg bg-accent/15 flex items-center justify-center">
                            <Target className="h-4 w-4 text-accent" />
                        </div>
                    </CardHeader>
                    <CardContent>
                        <div className="text-3xl font-bold text-foreground">{completionRate}%</div>
                        <p className="text-xs text-muted-foreground mt-1">De todos os treinos</p>
                        <div className="mt-3 h-1 rounded-full bg-border/50">
                            <div className="h-1 rounded-full bg-accent" style={{ width: `${completionRate}%` }} />
                        </div>
                    </CardContent>
                </Card>

                {/* Este Mês */}
                <Card className="relative overflow-hidden border-border/50 group hover:border-primary/40 transition-colors duration-300">
                    <div className="absolute inset-0 bg-gradient-to-br from-primary/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                        <CardTitle className="text-sm font-medium text-muted-foreground">Este Mês</CardTitle>
                        <div className="h-8 w-8 rounded-lg bg-primary/15 flex items-center justify-center">
                            <Calendar className="h-4 w-4 text-primary" />
                        </div>
                    </CardHeader>
                    <CardContent>
                        <div className="text-3xl font-bold text-foreground">{thisMonthWorkouts.length}</div>
                        <p className="text-xs text-muted-foreground mt-1">Treinos completados</p>
                        <div className="mt-3 h-1 rounded-full bg-border/50">
                            <div className="h-1 rounded-full bg-gradient-to-r from-primary to-purple-400"
                                style={{ width: `${thisMonthWorkouts.length > 0 ? Math.min(thisMonthWorkouts.length * 10, 100) : 0}%` }}
                            />
                        </div>
                    </CardContent>
                </Card>
            </div>

            {/* Progress Chart Placeholder */}
            <Card className="border-border/50">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2 text-foreground">
                        <div className="h-8 w-8 rounded-lg bg-primary/15 flex items-center justify-center">
                            <TrendingUp className="h-4 w-4 text-primary" />
                        </div>
                        Evolução Mensal
                    </CardTitle>
                </CardHeader>
                <CardContent>
                    <div className="h-64 w-full">
                        <ResponsiveContainer width="100%" height="100%">
                            <LineChart data={chartData} margin={{ top: 5, right: 20, bottom: 5, left: 0 }}>
                                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="rgba(255,255,255,0.1)" />
                                <XAxis dataKey="name" stroke="hsl(220, 12%, 45%)" fontSize={12} tickLine={false} axisLine={false} />
                                <YAxis stroke="hsl(220, 12%, 45%)" fontSize={12} tickLine={false} axisLine={false} />
                                <Tooltip
                                    contentStyle={{ backgroundColor: 'hsl(246, 14%, 7%)', borderColor: 'hsl(248, 12%, 13%)', borderRadius: '8px', color: 'hsl(220, 20%, 96%)' }}
                                    itemStyle={{ color: 'hsl(220, 20%, 96%)' }}
                                />
                                <Line type="monotone" dataKey="treinos" name="Treinos" stroke="hsl(266, 70%, 55%)" strokeWidth={3} dot={{ fill: 'hsl(266, 70%, 55%)', strokeWidth: 2, r: 4 }} activeDot={{ r: 6, strokeWidth: 0 }} />
                            </LineChart>
                        </ResponsiveContainer>
                    </div>
                </CardContent>
            </Card>

            {/* Recent Activity */}
            <Card className="border-border/50">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2 text-foreground">
                        <div className="h-8 w-8 rounded-lg bg-primary/15 flex items-center justify-center">
                            <Zap className="h-4 w-4 text-primary" />
                        </div>
                        Atividade Recente
                    </CardTitle>
                </CardHeader>
                <CardContent>
                    {completedWorkouts.length === 0 ? (
                        <div className="flex flex-col items-center gap-3 py-10 text-center">
                            <div className="h-12 w-12 rounded-xl bg-border/30 flex items-center justify-center">
                                <Dumbbell className="h-6 w-6 text-muted-foreground/50" />
                            </div>
                            <p className="text-muted-foreground text-sm">
                                Nenhum treino concluído ainda. Continue treinando!
                            </p>
                        </div>
                    ) : (
                        <div className="space-y-3">
                            {completedWorkouts.slice(0, 10).reverse().map((workout) => (
                                <div key={workout.id}
                                    className="flex items-center justify-between p-3 rounded-xl border border-border/50 hover:border-primary/30 hover:bg-primary/5 transition-all duration-200"
                                >
                                    <div className="flex items-center gap-3">
                                        <div className="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
                                            <Dumbbell className="h-5 w-5 text-primary" />
                                        </div>
                                        <div>
                                            <p className="font-medium text-foreground text-sm">{workout.name}</p>
                                            <p className="text-xs text-muted-foreground">
                                                {new Date(workout.scheduled_for).toLocaleDateString('pt-BR', {
                                                    day: 'numeric',
                                                    month: 'long',
                                                    year: 'numeric'
                                                })}
                                            </p>
                                        </div>
                                    </div>
                                    <div className="px-3 py-1 rounded-full text-xs font-semibold flex-shrink-0 bg-primary/15 text-primary border border-primary/25">
                                        Concluído
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </CardContent>
            </Card>
        </div>
    )
}
