"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { ApiClient, WorkoutSession } from "@/lib/api"
import { AlertCircle } from "lucide-react"

export function IncompleteWorkoutsNotification() {
    const [draftSessions, setDraftSessions] = useState<WorkoutSession[]>([])
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        const fetchDrafts = async () => {
            try {
                const sessions = await ApiClient.getDraftSessions()
                setDraftSessions(sessions)
            } catch (error) {
                console.error("Failed to fetch draft sessions", error)
            } finally {
                setLoading(false)
            }
        }

        fetchDrafts()
    }, [])

    if (loading || draftSessions.length === 0) {
        return null
    }

    return (
        <Card className="border-orange-500 bg-orange-50 dark:bg-orange-950/20">
            <CardHeader className="pb-3">
                <CardTitle className="flex items-center gap-2 text-orange-900 dark:text-orange-100">
                    <AlertCircle className="h-5 w-5 text-orange-600" />
                    Treinos Não Finalizados
                </CardTitle>
            </CardHeader>
            <CardContent>
                <p className="text-sm text-orange-800 dark:text-orange-200">
                    Você tem {draftSessions.length} treino(s) não finalizado(s).{" "}
                    <Link href="/dashboard/workouts" className="underline font-medium hover:text-orange-900 dark:hover:text-orange-100">
                        Ver treinos
                    </Link>
                </p>
            </CardContent>
        </Card>
    )
}
