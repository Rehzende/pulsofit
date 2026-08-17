"use client"

import { useEffect, useState, useCallback } from "react"
import { useParams, useRouter } from "next/navigation"
import { Card, CardContent } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { ApiClient, Workout, WorkoutItem, WorkoutSession, WorkoutSessionFinishResponse } from "@/lib/api"
import { ArrowLeft, Play, CheckCircle2, Timer, Dumbbell, Circle, CheckCircle, Clock, Flame, X, Heart, Weight, Youtube } from "lucide-react"
import { FeedbackModal } from "@/components/FeedbackModal"
import { ShareVictoryCard } from "@/components/ShareVictoryCard"
import { ExerciseCard } from "@/components/ExerciseCard"
import { useWebBluetooth } from "@/hooks/useWebBluetooth"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"

interface ExerciseProgress {
    exerciseId: string
    completedSets: number
    totalSets: number
    isComplete: boolean
}

// Backward-compat normalizer for persisted loads.
// Old format stored ONE load per exercise (number); new format stores an
// array indexed by set number. Convert legacy numbers to a single-element array.
function normalizeLoads(raw: unknown): Record<string, number[]> {
    if (!raw || typeof raw !== 'object') return {}
    const result: Record<string, number[]> = {}
    for (const [exerciseId, value] of Object.entries(raw as Record<string, unknown>)) {
        if (typeof value === 'number') {
            result[exerciseId] = [value]
        } else if (Array.isArray(value)) {
            result[exerciseId] = value.map(v => (typeof v === 'number' ? v : 0))
        }
    }
    return result
}

export default function WorkoutRunPage() {
    const params = useParams()
    const router = useRouter()
    const id = params.id as string

    const [workout, setWorkout] = useState<Workout | null>(null)
    const [session, setSession] = useState<WorkoutSession | null>(null)
    const [exerciseProgress, setExerciseProgress] = useState<ExerciseProgress[]>([])
    const [selectedExerciseId, setSelectedExerciseId] = useState<string | null>(null)
    // Per-set loads: array indexed by set number (index 0 = set 1).
    const [exerciseLoads, setExerciseLoads] = useState<Record<string, number[]>>({})
    const [isLoading, setIsLoading] = useState(true)
    const [sessionStarted, setSessionStarted] = useState(false)
    const [elapsedTime, setElapsedTime] = useState(0)
    const [showFeedbackModal, setShowFeedbackModal] = useState(false)
    const [finishResponse, setFinishResponse] = useState<WorkoutSessionFinishResponse | null>(null)
    const [isSubmitting, setIsSubmitting] = useState(false)
    const [restTimer, setRestTimer] = useState(0)
    const [isResting, setIsResting] = useState(false)
    const { heartRate, isConnected, connectToDevice } = useWebBluetooth()
    const [alertMessage, setAlertMessage] = useState<{ show: false, title: '', desc: '', isError: false } | { show: true, title: string, desc: string, isError: boolean, onOk?: () => void }>({ show: false, title: '', desc: '', isError: false })
    const [showExitConfirm, setShowExitConfirm] = useState(false)

    // Load workout and restore progress from localStorage
    useEffect(() => {
        const fetchWorkout = async () => {
            try {
                const data = await ApiClient.getWorkout(id)
                setWorkout(data)

                const initialProgress: ExerciseProgress[] = data.items.map(item => ({
                    exerciseId: item.id,
                    completedSets: 0,
                    totalSets: item.sets,
                    isComplete: false
                }))

                const savedProgress = localStorage.getItem(`workout_progress_${id}`)
                if (savedProgress) {
                    const parsed = JSON.parse(savedProgress)
                    setExerciseProgress(parsed.progress || initialProgress)
                    setElapsedTime(parsed.elapsedTime || 0)
                    setExerciseLoads(normalizeLoads(parsed.loads))
                } else {
                    setExerciseProgress(initialProgress)
                }

                const firstIncomplete = initialProgress.find(p => !p.isComplete)
                if (firstIncomplete) {
                    setSelectedExerciseId(firstIncomplete.exerciseId)
                }
            } catch (error) {
                console.error("Failed to fetch workout", error)
            } finally {
                setIsLoading(false)
            }
        }

        if (id) {
            fetchWorkout()
        }
    }, [id])

    useEffect(() => {
        if (!sessionStarted) return
        const interval = setInterval(() => setElapsedTime(prev => prev + 1), 1000)
        return () => clearInterval(interval)
    }, [sessionStarted])

    useEffect(() => {
        if (!isResting || restTimer === 0) return
        const interval = setInterval(() => {
            setRestTimer(prev => {
                if (prev <= 1) {
                    setIsResting(false)
                    // Finalize the set completion after rest
                    if (selectedExerciseId) {
                        finalizeSetCompletion(selectedExerciseId)
                    }
                    return 0
                }
                return prev - 1
            })
        }, 1000)
        return () => clearInterval(interval)
    }, [isResting, restTimer, selectedExerciseId])

    const saveProgress = useCallback(async () => {
        if (!workout || !session) return
        const progressData = { progress: exerciseProgress, elapsedTime, loads: exerciseLoads }
        localStorage.setItem(`workout_progress_${id}`, JSON.stringify(progressData))
        try {
            const response = await ApiClient.updateSessionProgress(session.id, progressData)
            if (response.should_save_as_draft) {
                setAlertMessage({ show: true, title: 'Rascunho Salvo', desc: 'Treino salvo como rascunho. Você pode continuar depois!', isError: false, onOk: () => router.push('/dashboard') })
            }
        } catch (error) {
            console.error("Failed to save progress", error)
        }
    }, [workout, session, exerciseProgress, exerciseLoads, elapsedTime, id, router])

    useEffect(() => {
        if (!sessionStarted) return
        const interval = setInterval(saveProgress, 30000)
        return () => clearInterval(interval)
    }, [sessionStarted, saveProgress])

    useEffect(() => {
        if (!sessionStarted || finishResponse) return
        const handleBeforeUnload = (e: BeforeUnloadEvent) => {
            e.preventDefault()
            e.returnValue = ''
        }
        window.addEventListener('beforeunload', handleBeforeUnload)
        return () => window.removeEventListener('beforeunload', handleBeforeUnload)
    }, [sessionStarted, finishResponse])

    const handleStartWorkout = async () => {
        if (!workout) return
        try {
            const newSession = await ApiClient.startWorkoutSession(workout.id)
            setSession(newSession)
            setSessionStarted(true)
        } catch (error) {
            console.error("Failed to start workout session", error)
        }
    }

    const handleSetComplete = (exerciseId: string) => {
        const currentExercise = workout?.items.find(item => item.id === exerciseId)
        const currentProgress = exerciseProgress.find(p => p.exerciseId === exerciseId)

        if (!currentExercise || !currentProgress) return

        // Check if already at max sets
        if (currentProgress.completedSets >= currentProgress.totalSets) {
            // Already complete, move to next exercise
            const currentIndex = exerciseProgress.findIndex(p => p.exerciseId === exerciseId)
            const nextIncomplete = exerciseProgress.slice(currentIndex + 1).find(p => !p.isComplete)
            if (nextIncomplete) {
                setSelectedExerciseId(nextIncomplete.exerciseId)
            }
            return
        }

        // Check if rest is needed
        if (currentExercise.rest_seconds > 0) {
            setRestTimer(currentExercise.rest_seconds)
            setIsResting(true)
        } else {
            // No rest needed, complete set immediately
            finalizeSetCompletion(exerciseId)
        }
    }

    const finalizeSetCompletion = (exerciseId: string) => {
        setExerciseProgress(prev => {
            const justCompletedSetIndex = prev.find(p => p.exerciseId === exerciseId)?.completedSets ?? 0
            const updated = prev.map(p => {
                if (p.exerciseId === exerciseId && p.completedSets < p.totalSets) {
                    const newCompletedSets = p.completedSets + 1
                    return {
                        ...p,
                        completedSets: newCompletedSets,
                        isComplete: newCompletedSets >= p.totalSets
                    }
                }
                return p
            })

            // Pre-fill the next set's load with the value just used (common gym UX:
            // most people keep the same weight set-to-set). The user can still edit it.
            const completed = updated.find(p => p.exerciseId === exerciseId)
            if (completed && !completed.isComplete) {
                const nextSetIndex = completed.completedSets
                setExerciseLoads(loadsPrev => {
                    const current = loadsPrev[exerciseId] ?? []
                    if (current[nextSetIndex] !== undefined && current[nextSetIndex] !== 0) return loadsPrev
                    const prevValue = current[justCompletedSetIndex] ?? 0
                    if (prevValue === 0) return loadsPrev
                    const next = [...current]
                    while (next.length <= nextSetIndex) next.push(0)
                    next[nextSetIndex] = prevValue
                    return { ...loadsPrev, [exerciseId]: next }
                })
            }

            // Auto-advance to next exercise if current is complete
            const currentProgress = updated.find(p => p.exerciseId === exerciseId)
            if (currentProgress?.isComplete) {
                const currentIndex = updated.findIndex(p => p.exerciseId === exerciseId)
                const nextIncomplete = updated.slice(currentIndex + 1).find(p => !p.isComplete)
                if (nextIncomplete) {
                    setSelectedExerciseId(nextIncomplete.exerciseId)
                }
            }

            return updated
        })
    }

    const handleStartRest = () => {
        const currentExercise = workout?.items.find(item => item.id === selectedExerciseId)
        if (currentExercise) {
            setRestTimer(currentExercise.rest_seconds)
            setIsResting(true)
        }
    }

    const handleFinishWorkout = () => {
        setShowFeedbackModal(true)
    }

    const handleFeedbackSubmit = async (rpe: number, feedback: string) => {
        if (!session) return
        setIsSubmitting(true)
        try {
            const response = await ApiClient.finishWorkoutSession(session.id, {
                end_time: new Date().toISOString(),
                status: 'FINISHED'
            })
            setFinishResponse(response)
            setShowFeedbackModal(false)
            localStorage.removeItem(`workout_progress_${id}`)
        } catch (error) {
            console.error("Failed to finish workout session", error)
            setAlertMessage({ show: true, title: 'Erro', desc: 'Erro ao finalizar treino. Verifique o console para mais detalhes.', isError: true })
        } finally {
            setIsSubmitting(false)
        }
    }

    const formatTime = (seconds: number) => {
        const mins = Math.floor(seconds / 60)
        const secs = seconds % 60
        return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
    }

    const getProgressIcon = (progress: ExerciseProgress) => {
        if (progress.isComplete) {
            return <CheckCircle className="h-5 w-5 text-primary" />
        } else if (progress.completedSets > 0) {
            return <Clock className="h-5 w-5 text-accent" />
        }
        return <Circle className="h-5 w-5 text-muted-foreground" />
    }

    if (isLoading) {
        return (
            <div className="flex items-center justify-center min-h-dvh bg-zinc-950">
                <div className="text-center">
                    <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
                    <p className="text-zinc-400">Carregando treino...</p>
                </div>
            </div>
        )
    }

    if (!workout) {
        return <div className="p-6">Treino não encontrado</div>
    }

    if (finishResponse) {
        return <ShareVictoryCard response={finishResponse} workoutName={workout.name} />
    }

    const selectedExercise = workout.items.find(item => item.id === selectedExerciseId)
    const selectedProgress = exerciseProgress.find(p => p.exerciseId === selectedExerciseId)
    const allComplete = exerciseProgress.every(p => p.isComplete)
    const totalExercises = workout.items.length
    const completedExercises = exerciseProgress.filter(p => p.isComplete).length
    const estMinutes = Math.round(
        workout.items.reduce((acc, item) => acc + item.sets * (item.rest_seconds + 40), 0) / 60
    )
    const progressPct = totalExercises > 0 ? Math.round((completedExercises / totalExercises) * 100) : 0

    return (
        <div className="min-h-dvh bg-zinc-950 pb-[calc(5rem+env(safe-area-inset-bottom))]">
            <div className="max-w-7xl mx-auto p-4 md:p-6 space-y-6">
                {!sessionStarted ? (
                    // Pre-workout Screen
                    <div className="space-y-6">
                        {/* Header */}
                        <div className="flex items-center justify-between">
                            <Button
                                variant="ghost"
                                size="icon"
                                onClick={() => router.back()}
                                className="rounded-full"
                            >
                                <ArrowLeft className="h-5 w-5" />
                            </Button>
                            <h1 className="text-2xl font-bold">{workout.name}</h1>
                            <div className="w-10" />
                        </div>

                        {/* Workout Summary Card */}
                        <Card className="bg-zinc-900 border-zinc-800 text-white overflow-hidden">
                            <CardContent className="p-5 sm:p-8">
                                <div className="flex items-center justify-between mb-6">
                                    <div className="flex-1 min-w-0 pr-4">
                                        <p className="text-sm text-zinc-400 mb-1">Pronto para começar?</p>
                                        <h2 className="text-xl sm:text-3xl font-bold truncate">{workout.name}</h2>
                                    </div>
                                    <Dumbbell className="h-12 w-12 sm:h-16 sm:w-16 text-zinc-800 flex-shrink-0" />
                                </div>
                                <div className="grid grid-cols-2 gap-3 sm:gap-4">
                                    <div className="text-center">
                                        <div className="text-2xl sm:text-3xl font-bold">{totalExercises}</div>
                                        <div className="text-xs text-zinc-400">Exercícios</div>
                                    </div>
                                    <div className="text-center">
                                        <div className="text-2xl sm:text-3xl font-bold">~{estMinutes}</div>
                                        <div className="text-xs text-zinc-400">Minutos</div>
                                    </div>
                                </div>
                            </CardContent>
                        </Card>

                        {/* Exercise List */}
                        <div className="space-y-4">
                            <h3 className="text-lg font-semibold text-white">Exercícios</h3>
                            <div className="grid gap-4 md:grid-cols-2">
                                {workout.items.map((item, index) => (
                                    <ExerciseCard
                                        key={item.id}
                                        name={`${index + 1}. ${item.exercise_name || "Exercício Desconhecido"}`}
                                        sets={item.sets}
                                        reps={item.reps_per_set && item.reps_per_set.length > 0 ? item.reps_per_set.join("/") : item.reps_min && item.reps_max ? `${item.reps_min}-${item.reps_max}` : undefined}
                                        muscleGroup={`${item.rest_seconds}s descanso`}
                                    />
                                ))}
                            </div>
                        </div>

                        {/* Start Button */}
                        <Button
                            size="lg"
                            onClick={handleStartWorkout}
                            className="w-full h-16 text-xl font-bold bg-primary text-primary-foreground hover:bg-primary/90 shadow-lg shadow-primary/20"
                        >
                            <Play className="mr-2 h-6 w-6" />
                            Iniciar Treino
                        </Button>
                    </div>
                ) : (
                    // During Workout Screen
                    <div className="space-y-6">
                        {/* Header with Timer */}
                        <div className="flex items-center justify-between bg-zinc-900 rounded-2xl p-4 border border-zinc-800">
                            <div className="flex items-center gap-2">
                                <Button
                                    variant="ghost"
                                    size="icon"
                                    onClick={() => setShowExitConfirm(true)}
                                    className="rounded-full"
                                >
                                    <X className="h-5 w-5" />
                                </Button>
                                <Button
                                    variant="ghost"
                                    size="icon"
                                    onClick={connectToDevice}
                                    className="rounded-full"
                                >
                                    <Heart className={`h-5 w-5 ${isConnected ? 'text-red-500 fill-red-500 animate-pulse' : 'text-zinc-400'}`} />
                                </Button>
                            </div>
                            <div className="flex items-center gap-4">
                                <div className="flex items-center gap-2">
                                    <Timer className="h-5 w-5 text-primary" />
                                    <span className="text-2xl font-bold font-mono">{formatTime(elapsedTime)}</span>
                                </div>
                                {isConnected && heartRate && (
                                    <div className="flex items-center gap-2 px-3 py-1 bg-red-500/10 border border-red-500/30 rounded-full">
                                        <Heart className="h-4 w-4 text-red-500 fill-red-500 animate-pulse" />
                                        <span className="text-lg font-bold text-red-500">{heartRate}</span>
                                        <span className="text-xs text-red-400">BPM</span>
                                    </div>
                                )}
                            </div>
                            <div className="text-sm text-muted-foreground">
                                {completedExercises}/{totalExercises}
                            </div>
                        </div>

                        {/* Progress Bar */}
                        <div className="space-y-2">
                            <div className="flex justify-between text-sm">
                                <span className="text-zinc-400">Progresso</span>
                                <span className="font-semibold">{progressPct}%</span>
                            </div>
                            <div className="h-2 bg-muted rounded-full overflow-hidden">
                                <div
                                    className="h-full bg-primary transition-all duration-500"
                                    style={{ width: `${progressPct}%` }}
                                />
                            </div>
                        </div>

                        {/* Exercise List - Compact */}
                        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2">
                            {workout.items.map((item, index) => {
                                const progress = exerciseProgress.find(p => p.exerciseId === item.id)
                                const isSelected = selectedExerciseId === item.id

                                return (
                                    <button
                                        key={item.id}
                                        onClick={() => setSelectedExerciseId(item.id)}
                                        className={`p-3 rounded-xl border-2 transition-all ${isSelected
                                            ? 'border-primary bg-primary/10'
                                            : 'border-zinc-800 bg-zinc-900 hover:border-zinc-700'
                                            }`}
                                    >
                                        <div className="flex items-center justify-between mb-1">
                                            <span className="text-xs font-semibold">Ex {index + 1}</span>
                                            {progress && getProgressIcon(progress)}
                                        </div>
                                        {progress && (
                                            <div className="text-xs text-muted-foreground">
                                                {progress.completedSets}/{progress.totalSets} sets
                                            </div>
                                        )}
                                    </button>
                                )
                            })}
                        </div>

                        {/* Current Exercise Card */}
                        {selectedExercise && selectedProgress && (
                            <Card className="bg-zinc-900 border-zinc-800">
                                <CardContent className="p-6 space-y-6">
                                    {/* Exercise Header */}
                                    <div className="text-center">
                                        <p className="text-sm text-zinc-400 mb-1">Exercício Atual</p>
                                        <h2 className="text-2xl font-bold text-white">
                                            {selectedExercise.exercise_name || "Exercício Desconhecido"}
                                        </h2>
                                        {selectedExercise.video_url && (
                                            <a
                                                href={selectedExercise.video_url}
                                                target="_blank"
                                                rel="noopener noreferrer"
                                                className="inline-flex items-center gap-1.5 mt-2 px-3 py-1.5 rounded-full text-xs font-semibold bg-red-600/15 text-red-400 hover:bg-red-600/25 transition-colors"
                                            >
                                                <Youtube className="h-3.5 w-3.5" />
                                                Ver vídeo
                                            </a>
                                        )}
                                    </div>

                                    {/* Set Counter - BIG */}
                                    <div className="text-center p-8 bg-zinc-950 rounded-2xl border border-zinc-800">
                                        <div className="text-sm text-zinc-400 mb-2">Série</div>
                                        <div className="text-7xl font-bold text-white">
                                            {selectedProgress.completedSets + 1} / {selectedProgress.totalSets}
                                        </div>
                                    </div>

                                    {/* Exercise Details */}
                                    <div className="grid grid-cols-2 gap-4">
                                        {selectedExercise.reps_per_set && selectedExercise.reps_per_set.length > 0 ? (
                                            <div className="text-center p-4 bg-muted/50 rounded-xl">
                                                <p className="text-xs text-muted-foreground mb-1">Reps por série</p>
                                                <p className="text-2xl font-bold">{selectedExercise.reps_per_set.join("/")}</p>
                                            </div>
                                        ) : selectedExercise.reps_min !== undefined && selectedExercise.reps_min !== null && (
                                            <div className="text-center p-4 bg-muted/50 rounded-xl">
                                                <p className="text-xs text-muted-foreground mb-1">Reps</p>
                                                <p className="text-2xl font-bold">
                                                    {selectedExercise.reps_min}
                                                    {selectedExercise.reps_max && selectedExercise.reps_max !== selectedExercise.reps_min
                                                        ? `-${selectedExercise.reps_max}`
                                                        : ''}
                                                </p>
                                            </div>
                                        )}
                                        <div className="text-center p-4 bg-zinc-950 rounded-xl border border-zinc-800">
                                            <p className="text-xs text-zinc-400 mb-1">Descanso</p>
                                            <p className="text-2xl font-bold text-white">{selectedExercise.rest_seconds}s</p>
                                        </div>
                                    </div>

                                    {/* Rest Timer */}
                                    {isResting && (
                                        <div className="text-center p-6 rounded-2xl border animate-pulse"
                                            style={{ background: 'rgba(6,182,212,0.08)', borderColor: 'rgba(6,182,212,0.25)' }}
                                        >
                                            <div className="flex items-center justify-center gap-2 mb-2">
                                                <Clock className="h-5 w-5" style={{ color: '#06B6D4' }} />
                                                <div className="text-sm font-semibold" style={{ color: '#06B6D4' }}>Descansando</div>
                                            </div>
                                            <div className="text-4xl sm:text-5xl font-bold font-mono" style={{ color: '#06B6D4' }}>
                                                {formatTime(restTimer)}
                                            </div>
                                            <button
                                                onClick={() => setIsResting(false)}
                                                className="mt-3 text-xs text-muted-foreground hover:text-foreground transition-colors"
                                            >
                                                Pular descanso
                                            </button>
                                        </div>
                                    )}

                                    {/* Load Tracker */}
                                    {!selectedProgress.isComplete && (
                                        <div className="flex items-center gap-3 p-4 rounded-xl border border-border/50"
                                            style={{ background: 'rgba(124,58,237,0.05)' }}
                                        >
                                            <div className="h-8 w-8 rounded-lg bg-primary/15 flex items-center justify-center flex-shrink-0">
                                                <Weight className="h-4 w-4 text-primary" />
                                            </div>
                                            <div className="flex-1">
                                                <p className="text-xs text-muted-foreground mb-1">
                                                    Carga usada (kg) — Série {selectedProgress.completedSets + 1}
                                                </p>
                                                <input
                                                    type="number"
                                                    inputMode="decimal"
                                                    placeholder="Ex: 80"
                                                    value={exerciseLoads[selectedExerciseId!]?.[selectedProgress.completedSets] || ''}
                                                    onChange={(e) => {
                                                        const val = parseFloat(e.target.value) || 0
                                                        const setIndex = selectedProgress.completedSets
                                                        setExerciseLoads(prev => {
                                                            const current = prev[selectedExerciseId!] ?? []
                                                            // Clone and extend the array up to the current set, filling gaps with 0.
                                                            const next = [...current]
                                                            while (next.length <= setIndex) next.push(0)
                                                            next[setIndex] = val
                                                            return { ...prev, [selectedExerciseId!]: next }
                                                        })
                                                    }}
                                                    className="w-full bg-transparent text-foreground font-bold text-lg outline-none border-b border-border/50 focus:border-primary pb-1 transition-colors"
                                                    style={{ colorScheme: 'dark' }}
                                                />
                                                {/* Per-set history hint for completed sets of this exercise */}
                                                {(exerciseLoads[selectedExerciseId!]?.slice(0, selectedProgress.completedSets).some(v => v > 0)) && (
                                                    <p className="text-xs text-muted-foreground mt-1">
                                                        Séries: {exerciseLoads[selectedExerciseId!]!.slice(0, selectedProgress.completedSets).map(v => `${v}`).join(', ')}kg
                                                    </p>
                                                )}
                                            </div>
                                        </div>
                                    )}

                                    {/* Action Buttons */}
                                    {!selectedProgress.isComplete && (
                                        <div className="grid grid-cols-2 gap-3">
                                            <Button
                                                onClick={() => handleSetComplete(selectedExercise.id)}
                                                size="lg"
                                                disabled={isResting}
                                                className="h-14 bg-primary hover:bg-primary/90 text-primary-foreground shadow-md shadow-primary/20"
                                            >
                                                <CheckCircle2 className="mr-2 h-5 w-5" />
                                                Concluir Série
                                            </Button>
                                            <Button
                                                onClick={handleStartRest}
                                                variant="outline"
                                                size="lg"
                                                disabled={isResting}
                                                className="h-14 border-border/50 text-muted-foreground hover:bg-secondary hover:text-foreground"
                                            >
                                                <Clock className="mr-2 h-5 w-5" />
                                                Descansar
                                            </Button>
                                        </div>
                                    )}

                                    {/* Finish Button */}
                                    {allComplete && (
                                        <Button
                                            onClick={handleFinishWorkout}
                                            className="w-full h-16 text-lg font-bold bg-primary hover:bg-primary/90 text-primary-foreground shadow-lg shadow-primary/25"
                                        >
                                            <CheckCircle2 className="mr-2 h-6 w-6" />
                                            Finalizar Treino 🏆
                                        </Button>
                                    )}
                                </CardContent>
                            </Card>
                        )}
                    </div>
                )}
            </div>

            <FeedbackModal
                open={showFeedbackModal}
                onClose={() => setShowFeedbackModal(false)}
                onSubmit={handleFeedbackSubmit}
                isSubmitting={isSubmitting}
            />

            <AlertDialog open={showExitConfirm} onOpenChange={setShowExitConfirm}>
                <AlertDialogContent>
                    <AlertDialogHeader>
                        <AlertDialogTitle>Sair do treino?</AlertDialogTitle>
                        <AlertDialogDescription>
                            Tem certeza que deseja sair? Seu progresso será salvo e você poderá continuar depois.
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogCancel>Cancelar</AlertDialogCancel>
                        <AlertDialogAction onClick={() => { saveProgress(); router.back() }}>
                            Sair
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>

            <AlertDialog open={alertMessage.show} onOpenChange={(open) => !open && setAlertMessage({ show: false, title: '', desc: '', isError: false })}>
                <AlertDialogContent>
                    <AlertDialogHeader>
                        <AlertDialogTitle>{alertMessage.title}</AlertDialogTitle>
                        <AlertDialogDescription>
                            {alertMessage.desc}
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogAction onClick={() => alertMessage.show && alertMessage.onOk?.()}>
                            OK
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>
        </div>
    )
}
