"use client"

import { useState, useEffect } from "react"
import Link from "next/link"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Plus, Users, Dumbbell, TrendingUp, Calendar, Flame, MessageCircle, Play, Clock, Zap, Activity, AlertTriangle } from "lucide-react"
import { ApiClient, User, StudentEngagement, ReviewStats } from "@/lib/api"
import { IncompleteWorkoutsNotification } from "@/components/IncompleteWorkoutsNotification"
import { WeeklyCalendar } from "@/components/WeeklyCalendar"
import { StatCard } from "@/components/StatCard"
import { ExerciseCard } from "@/components/ExerciseCard"
import { InsightWidget } from "@/components/dashboard/InsightWidget"
import { StudentCard } from "@/components/dashboard/StudentCard"
import { ReviewModal } from "@/components/ReviewModal"
import { ChallengeCard } from "@/components/ChallengeCard"
import { WorkoutModeOnboarding } from "@/components/WorkoutModeOnboarding"
import { Star } from "lucide-react"

// Student Dashboard Component
function StudentDashboard({ user }: { user: User }) {
    const [workouts, setWorkouts] = useState<any[]>([])
    const [stats, setStats] = useState<any>(null)
    const [bestStreak, setBestStreak] = useState<number>(0)
    const [loading, setLoading] = useState(true)
    const [reviewModalOpen, setReviewModalOpen] = useState(false)
    const [showModeOnboarding, setShowModeOnboarding] = useState(false)

    useEffect(() => {
        const fetchData = async () => {
            try {
                const [workoutsData, weeklyStatusData, studentStats] = await Promise.all([
                    ApiClient.getWorkouts(),
                    ApiClient.getWeeklyStatus(),
                    ApiClient.getStudentStats()
                ])
                setWorkouts(workoutsData)
                setBestStreak(studentStats.best_streak ?? 0)

                // Calculate basic stats from workouts
                const now = new Date()
                const completedCount = workoutsData.filter((w: any) => w.scheduled_for && new Date(w.scheduled_for) < now).length
                setStats({
                    current_streak: studentStats.current_streak,
                    attendance_rate: completedCount > 0 ? Math.round((completedCount / workoutsData.length) * 100) : 0,
                    weeklyStatus: weeklyStatusData
                })

                // Show workout mode onboarding if student has no trainer and hasn't chosen yet
                const hasTrainer = user?.trainer_profile?.id
                const modeChosen = localStorage.getItem("workout_mode_chosen")
                if (!hasTrainer && !modeChosen) {
                    setShowModeOnboarding(true)
                }
            } catch (error) {
                console.error(error)
            } finally {
                setLoading(false)
            }
        }
        fetchData()
    }, [user])

    const now = new Date()
    const upcomingWorkouts = workouts.filter(w => w.scheduled_for && new Date(w.scheduled_for) >= now)
    const completedWorkouts = workouts.filter(w => w.scheduled_for && new Date(w.scheduled_for) < now)

    // Use next_workout from API if available, otherwise fallback to local logic
    const nextWorkout = stats?.weeklyStatus?.next_workout || upcomingWorkouts[0]
    const isTodayCompleted = stats?.weeklyStatus?.today_completed
    const isToday = nextWorkout && new Date(nextWorkout.scheduled_for).toDateString() === new Date().toDateString()

    const trainerWhatsApp = user.trainer_whatsapp_number ? `https://wa.me/${user.trainer_whatsapp_number.replace(/\D/g, '')}` : null

    // Mock completed days (replace with real data)
    const completedDays = stats?.weeklyStatus?.completed_days || []

    const handleWorkoutModeSelected = (mode: "solo" | "com_coach") => {
        localStorage.setItem("workout_mode_chosen", mode)
        setShowModeOnboarding(false)

        if (mode === "com_coach") {
            // Redirect to marketplace if user chooses to find a trainer
            // window.location.href = "/dashboard/marketplace"
        }
    }

    return (
        <div className="grid grid-cols-1 md:grid-cols-12 gap-4 md:gap-8 animate-in fade-in duration-500">
            {/* Incomplete Workouts Notification */}
            <div className="col-span-1 md:col-span-12">
                <IncompleteWorkoutsNotification />
            </div>

            {/* Hero Section */}
            <div className="col-span-1 md:col-span-12 card-glow relative overflow-hidden rounded-2xl p-5 md:p-10 text-foreground shadow-2xl">
                {/* Background Decoration */}
                <div className="absolute inset-0 bg-gradient-to-br from-card via-secondary to-background z-0"></div>
                <div className="absolute top-0 right-0 w-96 h-96 bg-primary/20 rounded-full blur-[100px] -translate-y-1/2 translate-x-1/3"></div>

                <div className="relative z-10 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                    <div>
                        <h1 className="text-2xl sm:text-4xl md:text-5xl font-black mb-1 sm:mb-2 tracking-tight">
                            Olá, <span className="gradient-text">{user.full_name?.split(' ')[0] || 'Atleta'}</span>
                        </h1>
                        <p className="text-sm sm:text-base text-muted-foreground max-w-lg">
                            {isToday
                                ? "Seu corpo está pronto para evoluir. O treino de hoje já está preparado."
                                : "O descanso é parte do processo. Recupere-se bem para o próximo desafio."}
                        </p>
                    </div>

                    {isTodayCompleted ? (
                        <div className="flex flex-col items-start md:items-end w-full md:w-auto mt-6 md:mt-0">
                            <div className="text-left md:text-right mb-4">
                                <span className="block text-sm font-semibold text-accent uppercase tracking-widest">Status do Dia</span>
                                <span className="text-3xl font-bold">Tudo Feito! ✅</span>
                            </div>
                            {nextWorkout && (
                                <Link href={`/dashboard/workouts/${nextWorkout.id}`} className="w-full md:w-auto">
                                    <Button variant="outline" size="lg" className="w-full md:w-auto rounded-2xl border-border hover:bg-secondary hover:text-foreground backdrop-blur-sm bg-card/20">
                                        Ver Próximo Treino ({new Date(nextWorkout.scheduled_for).toLocaleDateString()})
                                    </Button>
                                </Link>
                            )}
                        </div>
                    ) : isToday ? (
                        <div className="flex flex-col items-start md:items-end w-full md:w-auto mt-6 md:mt-0">
                            <div className="text-left md:text-right mb-4">
                                <span className="block text-sm font-semibold text-primary uppercase tracking-widest">Foco de Hoje</span>
                                <span className="text-3xl font-bold">{nextWorkout.name}</span>
                            </div>
                            <Link href={`/dashboard/workouts/${nextWorkout.id}/run`} className="w-full md:w-auto">
                                <Button size="lg" className="w-full md:w-auto h-16 px-10 rounded-2xl text-lg font-bold bg-primary text-black hover:bg-primary/90 hover:scale-105 transition-all duration-300 neon-glow">
                                    <Play className="mr-3 h-6 w-6 fill-black" /> START WORKOUT
                                </Button>
                            </Link>
                        </div>
                    ) : (
                        <div className="flex flex-col items-start md:items-end w-full md:w-auto mt-6 md:mt-0">
                            <div className="text-left md:text-right mb-4">
                                <span className="block text-sm font-semibold text-zinc-500 uppercase tracking-widest">Próximo Desafio</span>
                                <span className="text-3xl font-bold">{nextWorkout ? nextWorkout.name : "Sem treinos agendados"}</span>
                            </div>
                            {nextWorkout ? (
                                <Link href={`/dashboard/workouts/${nextWorkout.id}`} className="w-full md:w-auto">
                                    <Button variant="outline" size="lg" className="w-full md:w-auto rounded-2xl border-border hover:bg-secondary hover:text-foreground backdrop-blur-sm bg-card/20">
                                        <Calendar className="mr-2 h-5 w-5" /> Ver Detalhes ({new Date(nextWorkout.scheduled_for).toLocaleDateString()})
                                    </Button>
                                </Link>
                            ) : (
                                <Link href="/dashboard/workouts" className="w-full md:w-auto">
                                    <Button variant="outline" size="lg" className="w-full md:w-auto rounded-2xl border-border hover:bg-secondary hover:text-foreground backdrop-blur-sm bg-card/20">
                                        <Dumbbell className="mr-2 h-5 w-5" /> Ver Biblioteca
                                    </Button>
                                </Link>
                            )}
                        </div>
                    )}
                </div>
            </div>

            {/* Stats Grid */}
            <div className="col-span-1 md:col-span-12 grid grid-cols-2 md:grid-cols-4 gap-3 sm:gap-4">
                <StatCard
                    icon={Zap}
                    value={user.xp_points || 0}
                    label="XP Total"
                    trend={{ value: 12, isPositive: true }}
                    className="bg-zinc-900/50 backdrop-blur-sm border-zinc-800/50 hover:border-primary/30 transition-colors"
                />
                <StatCard
                    icon={Flame}
                    value={stats?.current_streak ?? user.current_streak ?? 0}
                    label="Dias Seguidos"
                    className="bg-zinc-900/50 backdrop-blur-sm border-zinc-800/50 hover:border-orange-500/30 transition-colors"
                />
                <StatCard
                    icon={TrendingUp}
                    value={bestStreak}
                    label="Recorde"
                    className="bg-zinc-900/50 backdrop-blur-sm border-zinc-800/50 hover:border-yellow-500/30 transition-colors"
                />
                <StatCard
                    icon={TrendingUp}
                    value={user.level || 1}
                    label="Seu Nível"
                    className="bg-zinc-900/50 backdrop-blur-sm border-zinc-800/50 hover:border-blue-500/30 transition-colors"
                />
                <Link href="/dashboard/history" className="block h-full">
                    <div className="cursor-pointer h-full transition-transform hover:scale-[1.02]">
                        <StatCard
                            icon={Dumbbell}
                            value={completedWorkouts.length}
                            label="Treinos Feitos"
                            className="bg-zinc-900/50 backdrop-blur-sm border-zinc-800/50 h-full"
                        />
                    </div>
                </Link>
            </div>

            {/* Main Content Area */}
            <div className="col-span-1 md:col-span-8 space-y-6">
                {/* Next Workout Card (If not today) */}
                {nextWorkout && !isToday && (
                    <Card className="overflow-hidden bg-zinc-900/40 backdrop-blur-md border-zinc-800 hover:border-zinc-700 transition-colors group">
                        <CardHeader>
                            <CardTitle className="flex items-center gap-2 text-zinc-100">
                                <div className="p-2 rounded-lg bg-primary/10 text-primary group-hover:bg-primary group-hover:text-black transition-colors">
                                    <Calendar className="w-5 h-5" />
                                </div>
                                Próximo Treino
                            </CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-6">
                            <div className="flex items-center justify-between">
                                <div>
                                    <h3 className="text-xl sm:text-2xl md:text-3xl font-bold text-white group-hover:text-primary transition-colors">{nextWorkout.name}</h3>
                                    <p className="text-sm text-zinc-400 mt-1 flex items-center gap-2">
                                        <Clock className="w-4 h-4" /> Agendado para {new Date(nextWorkout.scheduled_for).toLocaleDateString()}
                                    </p>
                                </div>
                            </div>

                            <div className="grid grid-cols-2 gap-4">
                                <div className="p-4 rounded-xl bg-black/20 border border-white/5">
                                    <p className="text-xs text-zinc-500 uppercase tracking-wider font-semibold">Exercícios</p>
                                    <p className="text-xl font-bold text-white">{nextWorkout.items?.length || 0}</p>
                                </div>
                                <div className="p-4 rounded-xl bg-black/20 border border-white/5">
                                    <p className="text-xs text-zinc-500 uppercase tracking-wider font-semibold">Est. Duração</p>
                                    <p className="text-xl font-bold text-white">~45 min</p>
                                </div>
                            </div>

                            <Link href={`/dashboard/workouts/${nextWorkout.id}/run`}>
                                <Button
                                    size="lg"
                                    className="w-full h-14 text-lg font-bold bg-zinc-800 hover:bg-primary hover:text-black text-white transition-all duration-300"
                                >
                                    Visualizar Treino <Dumbbell className="ml-2 w-5 h-5" />
                                </Button>
                            </Link>
                        </CardContent>
                    </Card>
                )}

                {/* 7-Day Challenge */}
                <ChallengeCard />
            </div>

            {/* Sidebar Content Area */}
            <div className="col-span-1 md:col-span-4 space-y-6">
                {/* Weekly Calendar */}
                <Card className="card-glow">
                    <CardHeader>
                        <CardTitle className="text-foreground text-sm font-semibold uppercase tracking-wider">
                            Sua Semana
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        <WeeklyCalendar completedDays={completedDays} />
                    </CardContent>
                </Card>

                {/* Upcoming List */}
                {upcomingWorkouts.length > 1 && (
                    <div className="space-y-4">
                        <div className="flex items-center justify-between px-2">
                            <h2 className="text-lg font-bold text-foreground">Em Breve</h2>
                            <Link href="/dashboard/workouts" className="text-xs font-semibold text-primary hover:underline">
                                VER TODOS
                            </Link>
                        </div>
                        <div className="grid gap-3">
                            {upcomingWorkouts.slice(1, 4).map((workout: any) => (
                                <Link key={workout.id} href={`/dashboard/workouts/${workout.id}`}>
                                    <div className="group flex items-center justify-between p-4 rounded-xl bg-secondary/40 border border-border hover:border-primary/30 hover:bg-secondary/60 transition-all cursor-pointer">
                                        <div>
                                            <h4 className="font-semibold text-secondary-foreground group-hover:text-foreground">{workout.name}</h4>
                                            <p className="text-xs text-muted-foreground mt-1">
                                                {workout.scheduled_for ? new Date(workout.scheduled_for).toLocaleDateString() : 'Sem data'}
                                            </p>
                                        </div>
                                        <div className="h-8 w-8 rounded-full bg-zinc-800 flex items-center justify-center group-hover:bg-primary group-hover:text-black transition-colors">
                                            <Dumbbell className="w-4 h-4" />
                                        </div>
                                    </div>
                                </Link>
                            ))}
                        </div>
                    </div>
                )}

                {/* Trainer Contact */}
                {user.trainer_profile && (
                    <Card className="card-glow">
                        <CardContent className="p-6 space-y-4">
                            <div className="flex items-center gap-4">
                                <div className="h-12 w-12 rounded-full bg-green-500/10 flex items-center justify-center text-green-500">
                                    <MessageCircle className="h-6 w-6" />
                                </div>
                                <div>
                                    <h3 className="font-bold text-white">Precisa de ajuda?</h3>
                                    <p className="text-xs text-zinc-400">Fale com seu treinador</p>
                                </div>
                            </div>
                            
                            <div className="flex flex-col gap-2">
                                <Link href="/dashboard/chat" className="w-full">
                                    <Button className="w-full bg-primary hover:bg-primary/90 text-black font-semibold">
                                        <MessageCircle className="mr-2 h-4 w-4" /> Chat com Treinador
                                    </Button>
                                </Link>

                                <Button
                                    variant="outline"
                                    className="w-full border-border hover:bg-secondary text-foreground"
                                    onClick={() => setReviewModalOpen(true)}
                                >
                                    <Star className="mr-2 h-4 w-4 text-yellow-500" /> Avaliar Treinador
                                </Button>
                            </div>

                            <ReviewModal 
                                open={reviewModalOpen} 
                                onOpenChange={setReviewModalOpen}
                                trainerId={user.trainer_profile.user_id}
                                trainerName={user.trainer_brand_name || "Seu Treinador"}
                            />
                        </CardContent>
                    </Card>
                )}
            </div>

            {/* Workout Mode Onboarding Modal */}
            <WorkoutModeOnboarding
                open={showModeOnboarding}
                onClose={handleWorkoutModeSelected}
            />
        </div>
    )
}

// Trainer Dashboard Component
function TrainerDashboard({ user }: { user: User }) {
    const [stats, setStats] = useState<any>(null)
    const [engagement, setEngagement] = useState<StudentEngagement[]>([])
    const [recentWorkouts, setRecentWorkouts] = useState<any[]>([])
    const [reviews, setReviews] = useState<ReviewStats | null>(null)
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        const fetchData = async () => {
            try {
                const [statsData, engagementData, workoutsData, reviewsData] = await Promise.all([
                    ApiClient.trainer.getStats(),
                    ApiClient.trainer.getEngagement(),
                    ApiClient.getWorkouts(),
                    ApiClient.getTrainerReviews(user.id)
                ])
                setStats(statsData)
                setEngagement(engagementData)
                setRecentWorkouts(workoutsData.slice(0, 4))
                setReviews(reviewsData)
            } catch (error) {
                console.error(error)
            } finally {
                setLoading(false)
            }
        }
        fetchData()
    }, [user.id])

    const atRiskStudents = engagement.filter(s => s.risk_level === 'AT_RISK')
    const irregularStudents = engagement.filter(s => s.risk_level === 'IRREGULAR')
    const onTrackStudents = engagement.filter(s => s.risk_level === 'ON_TRACK')

    const riskConfig: Record<'AT_RISK' | 'IRREGULAR' | 'ON_TRACK', {
        label: string; badge: string; dot: string; bar: string; icon: string;
    }> = {
        AT_RISK: {
            label: 'Em Risco',
            badge: 'bg-red-500/15 text-red-400 border-red-500/30',
            dot: 'bg-red-500',
            bar: 'bg-red-500',
            icon: '🔴',
        },
        IRREGULAR: {
            label: 'Irregular',
            badge: 'bg-amber-500/15 text-amber-400 border-amber-500/30',
            dot: 'bg-amber-400',
            bar: 'bg-amber-400',
            icon: '🟡',
        },
        ON_TRACK: {
            label: 'Em Dia',
            badge: 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30',
            dot: 'bg-emerald-400',
            bar: 'bg-emerald-400',
            icon: '🟢',
        },
    }

    return (
        <div className="flex flex-col gap-4 md:gap-8 animate-in fade-in duration-500">
            {/* Hero Header */}
            <div className="card-glow relative overflow-hidden rounded-3xl p-5 sm:p-8 md:p-10 text-foreground shadow-2xl">
                <div className="absolute inset-0 bg-gradient-to-br from-card via-secondary to-background z-0" />
                <div className="absolute top-0 right-0 w-96 h-96 bg-primary/20 rounded-full blur-[100px] -translate-y-1/2 translate-x-1/3" />
                <div className="absolute bottom-0 left-0 w-64 h-64 bg-accent/10 rounded-full blur-[80px] translate-y-1/2 -translate-x-1/3" />
                <div className="relative z-10 flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
                    <div>
                        <h1 className="text-2xl sm:text-4xl md:text-5xl font-black mb-2 tracking-tight">
                            Olá, <span className="gradient-text">{user.full_name?.split(' ')[0] || 'Treinador'}</span>
                        </h1>
                        <p className="text-lg text-muted-foreground max-w-xl">
                            Você tem <span className="text-white font-bold">{engagement.length}</span> alunos ativos.
                            {atRiskStudents.length > 0 && (
                                <span className="text-red-400 font-semibold"> {atRiskStudents.length} precisam de atenção urgente.</span>
                            )}
                        </p>
                    </div>
                    <div className="flex flex-col sm:flex-row gap-3 w-full md:w-auto mt-6 md:mt-0">
                        <Link href="/dashboard/students/new" className="w-full sm:w-auto">
                            <Button className="w-full sm:w-auto bg-primary hover:bg-primary/90 text-primary-foreground font-bold h-11 px-5 rounded-xl">
                                <Plus className="mr-2 h-4 w-4" /> Novo Aluno
                            </Button>
                        </Link>
                        <Link href="/dashboard/workouts/new" className="w-full sm:w-auto">
                            <Button variant="outline" className="w-full sm:w-auto border-border hover:bg-secondary text-foreground h-11 px-5 rounded-xl">
                                <Dumbbell className="mr-2 h-4 w-4" /> Criar Treino
                            </Button>
                        </Link>
                    </div>
                </div>
            </div>

            {/* ─── Alert Banner: At-Risk Students ─────────────────────── */}
            {!loading && atRiskStudents.length > 0 && (
                <div className="rounded-2xl border border-red-500/20 bg-red-500/5 p-4">
                    <div className="flex items-start gap-3">
                        <div className="h-8 w-8 rounded-full bg-red-500/20 flex items-center justify-center flex-shrink-0 mt-0.5">
                            <AlertTriangle className="h-4 w-4 text-red-500" />
                        </div>
                        <div className="flex-1 min-w-0">
                            <p className="text-sm font-semibold text-red-400">
                                {atRiskStudents.length} {atRiskStudents.length === 1 ? 'aluno' : 'alunos'} sem treinar há 5+ dias
                            </p>
                            <div className="flex flex-col gap-2 mt-2">
                                {atRiskStudents.slice(0, 5).map(s => (
                                    <div key={s.student_id} className="flex items-center justify-between gap-3 bg-red-500/10 border border-red-500/20 rounded-xl px-3 py-2">
                                        <span className="text-xs text-red-300 font-medium truncate">
                                            {s.student_name}
                                            {s.days_since_last_session !== null ? ` · ${s.days_since_last_session}d sem treinar` : ' · nunca treinou'}
                                        </span>
                                        <Link href={`/dashboard/students/${s.student_id}`}>
                                            <span className="text-xs text-red-400 font-semibold hover:text-red-300 whitespace-nowrap">
                                                Ver aluno →
                                            </span>
                                        </Link>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* ─── Alert Banner: No Upcoming Workouts ──────────────────── */}
            {!loading && (() => {
                const noUpcoming = engagement.filter(s => s.upcoming_workouts_count === 0)
                return noUpcoming.length > 0 ? (
                    <div className="rounded-2xl border border-amber-500/20 bg-amber-500/5 p-4">
                        <div className="flex items-start gap-3">
                            <div className="h-8 w-8 rounded-full bg-amber-500/20 flex items-center justify-center flex-shrink-0 mt-0.5">
                                <Calendar className="h-4 w-4 text-amber-500" />
                            </div>
                            <div className="flex-1 min-w-0">
                                <p className="text-sm font-semibold text-amber-400">
                                    {noUpcoming.length} {noUpcoming.length === 1 ? 'aluno' : 'alunos'} sem treinos agendados — programe novos treinos
                                </p>
                                <div className="flex flex-wrap gap-2 mt-2">
                                    {noUpcoming.slice(0, 5).map(s => (
                                        <Link key={s.student_id} href={`/dashboard/students/${s.student_id}`}>
                                            <span className="text-xs bg-amber-500/10 text-amber-300 border border-amber-500/20 px-2.5 py-1 rounded-full hover:bg-amber-500/20 transition-colors cursor-pointer">
                                                {s.student_name}
                                            </span>
                                        </Link>
                                    ))}
                                </div>
                            </div>
                        </div>
                    </div>
                ) : null
            })()}

            {/* ─── Metrics Row ─────────────────────────────────────────── */}
            <div className="grid grid-cols-2 gap-3 sm:gap-4 md:grid-cols-2 lg:grid-cols-4">
                {[
                    {
                        label: 'Alunos Ativos',
                        value: loading ? '—' : (stats?.active_students ?? 0),
                        sub: `${onTrackStudents.length} em dia`,
                        icon: Users,
                        color: 'primary',
                        border: 'hover:border-primary/30',
                    },
                    {
                        label: 'Sessões este Mês',
                        value: loading ? '—' : (stats?.monthly_workouts ?? 0),
                        sub: 'concluídas pelos alunos',
                        icon: Dumbbell,
                        color: 'cyan-400',
                        border: 'hover:border-cyan-500/30',
                    },
                    {
                        label: 'Retenção',
                        value: loading ? '—' : `${stats?.retention_rate ?? 0}%`,
                        sub: 'alunos que continuam',
                        icon: TrendingUp,
                        color: 'emerald-400',
                        border: 'hover:border-emerald-500/30',
                    },
                    {
                        label: 'Streaks Ativos',
                        value: loading ? '—' : (stats?.active_streaks ?? 0),
                        sub: 'alunos em sequência',
                        icon: Flame,
                        color: 'orange-400',
                        border: 'hover:border-orange-500/30',
                    },
                ].map((m, i) => (
                    <div key={i} className={`bg-zinc-900/50 backdrop-blur-md border border-zinc-800/50 rounded-2xl p-5 ${m.border} transition-colors duration-300 group`}>
                        <div className="flex items-start justify-between mb-3">
                            <p className="text-xs text-zinc-500 uppercase tracking-wider font-semibold">{m.label}</p>
                            <m.icon className={`h-4 w-4 text-${m.color} opacity-70`} />
                        </div>
                        <div className={`text-4xl font-black text-white mb-1 ${loading ? 'animate-pulse' : ''}`}>{m.value}</div>
                        <p className="text-xs text-zinc-500">{m.sub}</p>
                    </div>
                ))}
            </div>

            {/* ─── Main Content: Engagement Board + Workouts ───────────── */}
            <div className="grid grid-cols-1 lg:grid-cols-5 gap-8">

                {/* Engagement Board */}
                <div className="lg:col-span-3 flex flex-col gap-4">
                    <div className="flex items-center justify-between px-1">
                        <h2 className="text-xl font-bold text-white flex items-center gap-2">
                            <Activity className="w-5 h-5 text-primary" />
                            Engagement Board
                        </h2>
                        <Link href="/dashboard/students">
                            <Button variant="ghost" size="sm" className="text-primary hover:text-primary/80 hover:bg-primary/10 text-xs">
                                Ver Todos →
                            </Button>
                        </Link>
                    </div>

                    {loading ? (
                        <div className="space-y-3">
                            {[1, 2, 3, 4, 5].map(i => (
                                <div key={i} className="h-16 rounded-xl bg-zinc-900/50 animate-pulse" />
                            ))}
                        </div>
                    ) : engagement.length === 0 ? (
                        <div className="rounded-2xl border border-dashed border-zinc-800 bg-zinc-900/30 flex flex-col items-center justify-center py-16 text-center">
                            <Users className="h-12 w-12 text-zinc-600 mb-4" />
                            <h3 className="text-lg font-semibold text-zinc-400">Nenhum aluno ainda</h3>
                            <Link href="/dashboard/students/new">
                                <Button variant="link" className="text-primary mt-2">Cadastrar primeiro aluno</Button>
                            </Link>
                        </div>
                    ) : (
                        <div className="space-y-2">
                            {engagement.map((s, idx) => {
                                const cfg = riskConfig[s.risk_level]
                                return (
                                    <Link key={s.student_id} href={`/dashboard/students/${s.student_id}`}>
                                        <div className="group flex items-center gap-4 p-4 rounded-xl border border-zinc-800/50 bg-zinc-900/40 hover:bg-zinc-900/70 hover:border-zinc-700 transition-all duration-200 cursor-pointer">
                                            {/* Rank */}
                                            <span className="text-xs font-bold text-zinc-600 w-5 text-center flex-shrink-0">
                                                {idx + 1}
                                            </span>

                                            {/* Avatar */}
                                            <div className="h-10 w-10 rounded-full bg-zinc-800 flex items-center justify-center text-sm font-bold text-white flex-shrink-0 relative">
                                                {s.student_name.charAt(0).toUpperCase()}
                                                <span className={`absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full border-2 border-zinc-900 ${cfg.dot}`} />
                                            </div>

                                            {/* Name & info */}
                                            <div className="flex-1 min-w-0">
                                                <div className="flex items-center gap-2 mb-1">
                                                    <span className="font-semibold text-white text-sm truncate group-hover:text-primary transition-colors">
                                                        {s.student_name}
                                                    </span>
                                                    <span className={`text-xs border px-2 py-0.5 rounded-full flex-shrink-0 ${cfg.badge}`}>
                                                        {cfg.icon} {cfg.label}
                                                    </span>
                                                </div>
                                                {/* Engagement bar */}
                                                <div className="flex items-center gap-2">
                                                    <div className="flex-1 h-1.5 bg-zinc-800 rounded-full overflow-hidden">
                                                        <div
                                                            className={`h-full rounded-full transition-all duration-500 ${cfg.bar}`}
                                                            style={{ width: `${s.engagement_score}%` }}
                                                        />
                                                    </div>
                                                    <span className="text-xs text-zinc-500 flex-shrink-0">{s.engagement_score}%</span>
                                                </div>
                                            </div>

                                            {/* Stats */}
                                            <div className="flex-shrink-0 text-right hidden sm:block">
                                                <div className="text-sm font-bold text-white">
                                                    {s.sessions_last_7_days}x
                                                </div>
                                                <div className="text-xs text-zinc-500">esta semana</div>
                                            </div>

                                            {/* Streak */}
                                            <div className="flex-shrink-0 text-right hidden md:block">
                                                {s.current_streak > 0 ? (
                                                    <div className="flex items-center gap-1 text-orange-400">
                                                        <Flame className="h-3.5 w-3.5" />
                                                        <span className="text-sm font-bold">{s.current_streak}</span>
                                                    </div>
                                                ) : (
                                                    <div className="text-zinc-600 text-xs">—</div>
                                                )}
                                                <div className="text-xs text-zinc-500">streak</div>
                                            </div>
                                        </div>
                                    </Link>
                                )
                            })}
                        </div>
                    )}
                </div>

                {/* Right Column: Summary + Recent Workouts */}
                <div className="lg:col-span-2 flex flex-col gap-6">

                    {/* Engagement Summary */}
                    <div className="rounded-2xl border border-zinc-800/50 bg-zinc-900/40 p-5">
                        <h3 className="text-sm font-bold text-white mb-4 uppercase tracking-wider">Resumo de Engajamento</h3>
                        <div className="space-y-3">
                            {[
                                { label: `Em Dia`, count: onTrackStudents.length, total: engagement.length, color: 'bg-emerald-400', textColor: 'text-emerald-400' },
                                { label: `Irregular`, count: irregularStudents.length, total: engagement.length, color: 'bg-amber-400', textColor: 'text-amber-400' },
                                { label: `Em Risco`, count: atRiskStudents.length, total: engagement.length, color: 'bg-red-500', textColor: 'text-red-400' },
                            ].map(item => (
                                <div key={item.label} className="flex items-center gap-3">
                                    <div className="w-24 text-xs text-zinc-400 font-medium flex-shrink-0">{item.label}</div>
                                    <div className="flex-1 h-2 bg-zinc-800 rounded-full overflow-hidden">
                                        <div
                                            className={`h-full rounded-full ${item.color} transition-all duration-700`}
                                            style={{ width: item.total > 0 ? `${(item.count / item.total) * 100}%` : '0%' }}
                                        />
                                    </div>
                                    <span className={`text-sm font-bold flex-shrink-0 ${item.textColor}`}>{item.count}</span>
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* Recent Workouts */}
                    <div>
                        <div className="flex items-center justify-between mb-3 px-1">
                            <h3 className="text-sm font-bold text-white uppercase tracking-wider flex items-center gap-2">
                                <Dumbbell className="h-4 w-4 text-primary" />
                                Treinos Recentes
                            </h3>
                            <Link href="/dashboard/workouts">
                                <Button variant="ghost" size="sm" className="text-primary hover:bg-primary/10 text-xs">Ver Todos →</Button>
                            </Link>
                        </div>
                        <div className="space-y-2">
                            {loading ? (
                                [1, 2, 3].map(i => <div key={i} className="h-14 rounded-xl bg-zinc-900/50 animate-pulse" />)
                            ) : recentWorkouts.length === 0 ? (
                                <Link href="/dashboard/workouts/new">
                                    <div className="flex items-center justify-center py-8 rounded-xl border border-dashed border-zinc-800 text-zinc-500 text-sm hover:border-primary/30 transition-colors cursor-pointer">
                                        + Criar primeiro treino
                                    </div>
                                </Link>
                            ) : (
                                recentWorkouts.map((workout: any) => (
                                    <Link key={workout.id} href={`/dashboard/workouts/${workout.id}`}>
                                        <div className="group flex items-center gap-3 p-3.5 rounded-xl bg-zinc-900/40 border border-zinc-800/50 hover:border-primary/30 hover:bg-zinc-900/60 transition-all cursor-pointer">
                                            <div className="h-8 w-8 rounded-lg bg-primary/10 flex items-center justify-center text-primary flex-shrink-0 group-hover:bg-primary group-hover:text-black transition-colors">
                                                <Dumbbell className="h-4 w-4" />
                                            </div>
                                            <div className="flex-1 min-w-0">
                                                <p className="text-sm font-semibold text-white truncate group-hover:text-primary transition-colors">{workout.name}</p>
                                                <p className="text-xs text-zinc-500">
                                                    {workout.items?.length || 0} exercícios
                                                    {workout.scheduled_for ? ` · ${new Date(workout.scheduled_for).toLocaleDateString('pt-BR')}` : ''}
                                                </p>
                                            </div>
                                        </div>
                                    </Link>
                                ))
                            )}
                        </div>
                    </div>

                    {/* Quick Actions */}
                    <div className="grid grid-cols-1 gap-2">
                        <Link href="/dashboard/services">
                            <div className="group flex items-center gap-3 p-4 rounded-xl border border-zinc-800/50 bg-zinc-900/30 hover:border-primary/30 hover:bg-zinc-900/50 transition-all cursor-pointer">
                                <div className="h-8 w-8 rounded-lg bg-primary/10 flex items-center justify-center text-primary flex-shrink-0 group-hover:bg-primary group-hover:text-black transition-colors">
                                    <TrendingUp className="h-4 w-4" />
                                </div>
                                <div>
                                    <p className="text-sm font-semibold text-white">Meu Perfil Público</p>
                                    <p className="text-xs text-zinc-500">Bio, especialidades e serviços</p>
                                </div>
                            </div>
                        </Link>
                    </div>

                    {/* Reviews Summary Card */}
                    {reviews && (
                        <Card className="bg-zinc-900/40 border-zinc-800">
                            <CardHeader className="pb-2">
                                <CardTitle className="text-sm font-bold text-white uppercase tracking-wider flex items-center justify-between">
                                    <span>Depoimentos de Alunos</span>
                                    <div className="flex items-center gap-1 text-yellow-500">
                                        <Star className="h-4 w-4 fill-yellow-500" />
                                        <span>{reviews.average_rating}</span>
                                    </div>
                                </CardTitle>
                            </CardHeader>
                            <CardContent className="space-y-4">
                                {reviews.reviews.length === 0 ? (
                                    <p className="text-xs text-zinc-500 italic text-center py-4">Nenhum depoimento ainda.</p>
                                ) : (
                                    <div className="space-y-3">
                                        {reviews.reviews.slice(0, 2).map(r => (
                                            <div key={r.id} className="p-3 rounded-lg bg-black/20 border border-white/5 space-y-1">
                                                <div className="flex justify-between items-center">
                                                    <span className="text-[10px] font-bold text-white">{r.student_name}</span>
                                                    <div className="flex items-center gap-0.5">
                                                        {[...Array(5)].map((_, i) => (
                                                            <Star key={i} className={`h-2.5 w-2.5 ${i < r.rating ? "fill-yellow-500 text-yellow-500" : "text-zinc-700"}`} />
                                                        ))}
                                                    </div>
                                                </div>
                                                <p className="text-[10px] text-zinc-400 line-clamp-2 italic">"{r.text}"</p>
                                            </div>
                                        ))}
                                        <Link href="/dashboard/services">
                                            <Button variant="ghost" size="sm" className="w-full text-[10px] text-zinc-500 hover:text-white">
                                                Ver todos os {reviews.total_reviews} depoimentos
                                            </Button>
                                        </Link>
                                    </div>
                                )}
                            </CardContent>
                        </Card>
                    )}
                </div>
            </div>
        </div>
    )
}

// Main Dashboard Component
export default function DashboardPage() {
    const [user, setUser] = useState<User | null>(null)
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        const fetchUser = async () => {
            try {
                const userData = await ApiClient.getMe()
                setUser(userData)
            } catch (error) {
                console.error(error)
            } finally {
                setLoading(false)
            }
        }
        fetchUser()
    }, [])

    if (loading) {
        return <div className="flex items-center justify-center min-h-dvh">
            <div className="text-center">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
                <p className="text-muted-foreground">Carregando...</p>
            </div>
        </div>
    }

    if (!user) {
        return <div className="p-6">Error loading user data</div>
    }

    return user.role === 'TRAINER' ? <TrainerDashboard user={user} /> : <StudentDashboard user={user} />
}

// Helper to get week number
declare global {
    interface Date {
        getWeek(): number
    }
}

Date.prototype.getWeek = function () {
    const onejan = new Date(this.getFullYear(), 0, 1)
    return Math.ceil((((this.getTime() - onejan.getTime()) / 86400000) + onejan.getDay() + 1) / 7)
}
