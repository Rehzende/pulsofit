"use client"

import { useEffect, useState } from "react"
import { useParams, useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { ApiClient } from "@/lib/api"
import Link from "next/link"
import { ArrowLeft, Calendar, Dumbbell, Pencil } from "lucide-react"

interface WorkoutItem {
    id: string
    exercise_id: string
    sets: number
    reps_min?: number | null
    reps_max?: number | null
    reps_per_set?: number[] | null
    rest_seconds: number
    notes?: string | null
    target_zone_min_bpm?: number | null
    target_zone_max_bpm?: number | null
    target_rpe?: number | null
}

interface Workout {
    id: string
    name: string
    user_id: string
    scheduled_for?: string | null
    items: WorkoutItem[]
}

export default function WorkoutDetailPage() {
    const params = useParams()
    const router = useRouter()
    const id = params.id as string
    const [workout, setWorkout] = useState<Workout | null>(null)
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

    if (isLoading) {
        return <div className="p-6">Carregando...</div>
    }

    if (!workout) {
        return <div className="p-6">Treino não encontrado</div>
    }

    return (
        <div className="flex flex-col gap-6">
            <div className="flex flex-wrap items-center gap-3">
                <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => router.back()}
                >
                    <ArrowLeft className="h-4 w-4" />
                </Button>
                <div className="flex-1 min-w-0">
                    <h1 className="text-xl sm:text-2xl md:text-3xl font-bold tracking-tight truncate">{workout.name}</h1>
                    {workout.scheduled_for && (
                        <p className="text-muted-foreground flex items-center gap-2 mt-1">
                            <Calendar className="h-4 w-4" />
                            {new Date(workout.scheduled_for).toLocaleDateString('pt-BR', {
                                weekday: 'long',
                                year: 'numeric',
                                month: 'long',
                                day: 'numeric'
                            })}
                        </p>
                    )}
                </div>
                <div className="flex items-center gap-2 flex-shrink-0">
                    <Badge variant={workout.scheduled_for && new Date(workout.scheduled_for) >= new Date() ? "default" : "secondary"}>
                        {workout.scheduled_for && new Date(workout.scheduled_for) >= new Date() ? "Ativo" : "Concluído"}
                    </Badge>
                    <Link href={`/dashboard/workouts/${id}/edit`}>
                        <Button variant="outline" size="icon">
                            <Pencil className="h-4 w-4" />
                        </Button>
                    </Link>
                    <Button size="sm" onClick={() => router.push(`/dashboard/workouts/${id}/run`)}>
                        Iniciar
                    </Button>
                </div>
            </div>

            <Card>
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <Dumbbell className="h-5 w-5" />
                        Exercícios ({workout.items.length})
                    </CardTitle>
                </CardHeader>
                <CardContent>
                    {workout.items.length === 0 ? (
                        <p className="text-muted-foreground text-center py-8">
                            Nenhum exercício neste treino.
                        </p>
                    ) : (
                        <div className="space-y-4">
                            {workout.items.map((item, index) => (
                                <div
                                    key={item.id}
                                    className="p-4 border rounded-lg"
                                >
                                    <div className="flex items-start justify-between mb-2">
                                        <div className="flex items-center gap-3">
                                            <div className="flex items-center justify-center w-8 h-8 rounded-full bg-primary text-primary-foreground font-semibold">
                                                {index + 1}
                                            </div>
                                            <div>
                                                <h3 className="font-semibold">Exercício {index + 1}</h3>
                                                <p className="text-sm text-muted-foreground">ID: {item.exercise_id}</p>
                                            </div>
                                        </div>
                                    </div>

                                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
                                        <div>
                                            <p className="text-sm text-muted-foreground">Séries</p>
                                            <p className="font-semibold">{item.sets}</p>
                                        </div>
                                        {item.reps_per_set && item.reps_per_set.length > 0 ? (
                                            <div>
                                                <p className="text-sm text-muted-foreground">Reps por série</p>
                                                <p className="font-semibold">{item.reps_per_set.join("/")}</p>
                                            </div>
                                        ) : item.reps_min !== undefined && (
                                            <div>
                                                <p className="text-sm text-muted-foreground">Repetições</p>
                                                <p className="font-semibold">
                                                    {item.reps_min}
                                                    {item.reps_max && item.reps_max !== item.reps_min ? `-${item.reps_max}` : ''}
                                                </p>
                                            </div>
                                        )}
                                        <div>
                                            <p className="text-sm text-muted-foreground">Descanso</p>
                                            <p className="font-semibold">{item.rest_seconds}s</p>
                                        </div>
                                        {item.target_rpe && (
                                            <div>
                                                <p className="text-sm text-muted-foreground">RPE Alvo</p>
                                                <p className="font-semibold">{item.target_rpe}</p>
                                            </div>
                                        )}
                                    </div>

                                    {(item.target_zone_min_bpm || item.target_zone_max_bpm) && (
                                        <div className="mt-3 p-3 bg-muted rounded-md">
                                            <p className="text-sm font-medium">Zona de Frequência Cardíaca</p>
                                            <p className="text-sm text-muted-foreground">
                                                {item.target_zone_min_bpm} - {item.target_zone_max_bpm} BPM
                                            </p>
                                        </div>
                                    )}

                                    {item.notes && (
                                        <div className="mt-3 p-3 bg-muted rounded-md">
                                            <p className="text-sm font-medium">Notas</p>
                                            <p className="text-sm text-muted-foreground">{item.notes}</p>
                                        </div>
                                    )}
                                </div>
                            ))}
                        </div>
                    )}
                </CardContent>
            </Card>
        </div>
    )
}
