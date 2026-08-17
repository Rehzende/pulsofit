"use client"

import { useEffect, useState } from "react"
import { useParams, useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Progress } from "@/components/ui/progress"
import { ApiClient, Workout, WorkoutItem } from "@/lib/api"
import { ArrowLeft, Check, ChevronRight, Timer, Dumbbell } from "lucide-react"

export default function WorkoutSessionPage() {
    const params = useParams()
    const router = useRouter()
    const id = params.id as string

    const [workout, setWorkout] = useState<Workout | null>(null)
    const [currentExerciseIndex, setCurrentExerciseIndex] = useState(0)
    const [currentSet, setCurrentSet] = useState(1)
    const [isResting, setIsResting] = useState(false)
    const [restTimeLeft, setRestTimeLeft] = useState(0)
    const [completedSets, setCompletedSets] = useState<Set<string>>(new Set())
    const [isLoading, setIsLoading] = useState(true)

    useEffect(() => {
        const fetchWorkout = async () => {
            try {
                const data = await ApiClient.getWorkout(id)
                setWorkout(data)
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

    // Rest timer
    useEffect(() => {
        if (isResting && restTimeLeft > 0) {
            const timer = setTimeout(() => {
                setRestTimeLeft(restTimeLeft - 1)
            }, 1000)
            return () => clearTimeout(timer)
        } else if (isResting && restTimeLeft === 0) {
            setIsResting(false)
        }
    }, [isResting, restTimeLeft])

    if (isLoading) {
        return <div className="p-6">Carregando...</div>
    }

    if (!workout) {
        return <div className="p-6">Treino não encontrado</div>
    }

    const currentExercise = workout.items[currentExerciseIndex]
    const totalExercises = workout.items.length
    const progress = ((currentExerciseIndex + (currentSet / currentExercise.sets)) / totalExercises) * 100

    const handleCompleteSet = () => {
        const setKey = `${currentExerciseIndex}-${currentSet}`
        setCompletedSets(new Set(completedSets).add(setKey))

        if (currentSet < currentExercise.sets) {
            // Start rest period
            setIsResting(true)
            setRestTimeLeft(currentExercise.rest_seconds)
            setCurrentSet(currentSet + 1)
        } else {
            // Move to next exercise
            if (currentExerciseIndex < totalExercises - 1) {
                setCurrentExerciseIndex(currentExerciseIndex + 1)
                setCurrentSet(1)
            } else {
                // Workout complete!
                alert("Parabéns! Treino concluído! 🎉")
                router.push("/dashboard")
            }
        }
    }

    const handleSkipRest = () => {
        setIsResting(false)
        setRestTimeLeft(0)
    }

    return (
        <div className="flex flex-col gap-6 max-w-2xl mx-auto">
            {/* Header */}
            <div className="flex items-center gap-4">
                <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => router.back()}
                >
                    <ArrowLeft className="h-4 w-4" />
                </Button>
                <div className="flex-1">
                    <h1 className="text-2xl font-bold">{workout.name}</h1>
                    <p className="text-sm text-muted-foreground">
                        Exercício {currentExerciseIndex + 1} de {totalExercises}
                    </p>
                </div>
            </div>

            {/* Progress Bar */}
            <div className="space-y-2">
                <Progress value={progress} className="h-2" />
                <p className="text-xs text-muted-foreground text-right">{Math.round(progress)}% completo</p>
            </div>

            {/* Rest Timer */}
            {isResting && (
                <Card className="bg-gradient-to-br from-orange-500 to-red-500 text-white border-none">
                    <CardContent className="p-5 sm:p-8 text-center">
                        <Timer className="h-16 w-16 mx-auto mb-4" />
                        <h2 className="text-3xl sm:text-4xl font-bold mb-2">{restTimeLeft}s</h2>
                        <p className="text-lg mb-4">Descansando...</p>
                        <Button
                            variant="secondary"
                            onClick={handleSkipRest}
                        >
                            Pular Descanso
                        </Button>
                    </CardContent>
                </Card>
            )}

            {/* Current Exercise */}
            {!isResting && (
                <Card className="border-2 border-primary">
                    <CardHeader className="bg-gradient-to-r from-blue-500 to-cyan-500 text-white">
                        <CardTitle className="flex items-center gap-2 text-2xl">
                            <Dumbbell className="h-6 w-6" />
                            Exercício {currentExerciseIndex + 1}
                        </CardTitle>
                        <p className="text-sm opacity-90">ID: {currentExercise.exercise_id}</p>
                    </CardHeader>
                    <CardContent className="p-5 sm:p-8">
                        <div className="space-y-6">
                            {/* Set Info */}
                            <div className="text-center">
                                <p className="text-sm text-muted-foreground mb-2">Série Atual</p>
                                <p className="text-4xl sm:text-5xl font-bold text-primary">{currentSet}/{currentExercise.sets}</p>
                            </div>

                            {/* Exercise Details */}
                            <div className="grid grid-cols-2 gap-4">
                                {currentExercise.reps_min !== undefined && (
                                    <div className="text-center p-4 bg-muted rounded-lg">
                                        <p className="text-sm text-muted-foreground">Repetições</p>
                                        <p className="text-2xl font-bold">
                                            {currentExercise.reps_min}
                                            {currentExercise.reps_max && currentExercise.reps_max !== currentExercise.reps_min ? `-${currentExercise.reps_max}` : ''}
                                        </p>
                                    </div>
                                )}
                                <div className="text-center p-4 bg-muted rounded-lg">
                                    <p className="text-sm text-muted-foreground">Descanso</p>
                                    <p className="text-2xl font-bold">{currentExercise.rest_seconds}s</p>
                                </div>
                                {currentExercise.target_rpe && (
                                    <div className="text-center p-4 bg-muted rounded-lg">
                                        <p className="text-sm text-muted-foreground">RPE Alvo</p>
                                        <p className="text-2xl font-bold">{currentExercise.target_rpe}</p>
                                    </div>
                                )}
                            </div>

                            {/* Heart Rate Zone */}
                            {(currentExercise.target_zone_min_bpm || currentExercise.target_zone_max_bpm) && (
                                <div className="p-4 bg-red-50 dark:bg-red-950/20 rounded-lg border border-red-200 dark:border-red-800">
                                    <p className="text-sm font-medium text-red-900 dark:text-red-100 mb-1">
                                        Zona de Frequência Cardíaca
                                    </p>
                                    <p className="text-xl font-bold text-red-600 dark:text-red-400">
                                        {currentExercise.target_zone_min_bpm} - {currentExercise.target_zone_max_bpm} BPM
                                    </p>
                                </div>
                            )}

                            {/* Notes */}
                            {currentExercise.notes && (
                                <div className="p-4 bg-blue-50 dark:bg-blue-950/20 rounded-lg border border-blue-200 dark:border-blue-800">
                                    <p className="text-sm font-medium text-blue-900 dark:text-blue-100 mb-1">Notas</p>
                                    <p className="text-sm text-blue-700 dark:text-blue-300">{currentExercise.notes}</p>
                                </div>
                            )}

                            {/* Complete Set Button */}
                            <Button
                                onClick={handleCompleteSet}
                                className="w-full h-16 text-lg bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700"
                            >
                                <Check className="mr-2 h-6 w-6" />
                                Completar Série
                            </Button>
                        </div>
                    </CardContent>
                </Card>
            )}

            {/* Exercise List */}
            <Card>
                <CardHeader>
                    <CardTitle className="text-sm">Todos os Exercícios</CardTitle>
                </CardHeader>
                <CardContent>
                    <div className="space-y-2">
                        {workout.items.map((item, index) => (
                            <div
                                key={item.id}
                                className={`flex items-center gap-3 p-3 rounded-lg ${index === currentExerciseIndex
                                    ? 'bg-primary/10 border-2 border-primary'
                                    : index < currentExerciseIndex
                                        ? 'bg-green-50 dark:bg-green-950/20'
                                        : 'bg-muted'
                                    }`}
                            >
                                <div className={`flex items-center justify-center w-8 h-8 rounded-full ${index < currentExerciseIndex
                                    ? 'bg-green-500 text-white'
                                    : index === currentExerciseIndex
                                        ? 'bg-primary text-primary-foreground'
                                        : 'bg-gray-300 dark:bg-gray-700'
                                    }`}>
                                    {index < currentExerciseIndex ? (
                                        <Check className="h-4 w-4" />
                                    ) : (
                                        <span className="text-sm font-bold">{index + 1}</span>
                                    )}
                                </div>
                                <div className="flex-1">
                                    <p className="text-sm font-medium">Exercício {index + 1}</p>
                                    <p className="text-xs text-muted-foreground">{item.sets} séries</p>
                                </div>
                                {index === currentExerciseIndex && (
                                    <ChevronRight className="h-5 w-5 text-primary" />
                                )}
                            </div>
                        ))}
                    </div>
                </CardContent>
            </Card>
        </div>
    )
}
