"use client"

import { useState, useEffect } from "react"
import { ApiClient } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Trophy, Flame, CheckCircle2, Circle, Loader2, Sparkles } from "lucide-react"
import { toast } from "sonner"
import { Progress } from "@/components/ui/progress"

export function ChallengeCard() {
    const [status, setStatus] = useState<{
        active: boolean;
        days_completed: number;
        completed: boolean;
        started_at: string | null;
        completed_at: string | null;
    } | null>(null)
    const [isLoading, setIsLoading] = useState(true)
    const [isStarting, setIsStarting] = useState(false)

    const fetchStatus = async () => {
        try {
            const data = await ApiClient.getChallengeStatus()
            setStatus(data)
        } catch (error) {
            console.error("Failed to fetch challenge status", error)
        } finally {
            setIsLoading(false)
        }
    }

    useEffect(() => {
        fetchStatus()
    }, [])

    const handleStart = async () => {
        setIsStarting(true)
        try {
            await ApiClient.startChallenge()
            toast.success("Desafio de 7 dias iniciado! 💪")
            fetchStatus()
        } catch (error: any) {
            toast.error(error.response?.data?.detail || "Erro ao iniciar desafio.")
        } finally {
            setIsStarting(false)
        }
    }

    if (isLoading) {
        return (
            <Card className="bg-zinc-900 border-zinc-800 h-[200px] flex items-center justify-center">
                <Loader2 className="h-6 w-6 animate-spin text-primary" />
            </Card>
        )
    }

    if (!status || (!status.active && !status.completed)) {
        return (
            <Card className="bg-gradient-to-br from-indigo-900/20 to-primary/10 border-primary/20 overflow-hidden relative group">
                <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
                    <Trophy className="h-24 w-24 text-primary" />
                </div>
                <CardHeader>
                    <CardTitle className="flex items-center gap-2 text-white">
                        <Flame className="h-5 w-5 text-orange-500 animate-pulse" />
                        Desafio de 7 Dias
                    </CardTitle>
                    <CardDescription>
                        Treine por 7 dias seguidos e ganhe um badge exclusivo e XP extra!
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <Button 
                        onClick={handleStart} 
                        disabled={isStarting}
                        className="w-full bg-primary text-primary-foreground font-bold h-11"
                    >
                        {isStarting ? "Iniciando..." : "ACEITAR DESAFIO"}
                    </Button>
                </CardContent>
            </Card>
        )
    }

    const progress = (status.days_completed / 7) * 100

    return (
        <Card className="bg-zinc-900 border-primary/30 overflow-hidden relative">
            {status.completed && (
                <div className="absolute inset-0 bg-primary/5 backdrop-blur-[2px] z-10 flex flex-col items-center justify-center text-center p-6 animate-in fade-in duration-500">
                    <div className="bg-primary text-black p-3 rounded-full mb-3 shadow-[0_0_20px_rgba(132,204,22,0.5)]">
                        <Trophy className="h-8 w-8" />
                    </div>
                    <h3 className="text-xl font-black text-white">DESAFIO CONCLUÍDO!</h3>
                    <p className="text-zinc-400 text-sm mt-1">Você é uma máquina de treinar!</p>
                    <Button variant="outline" size="sm" className="mt-4 border-primary text-primary hover:bg-primary hover:text-black" onClick={handleStart}>
                        Começar Novo Desafio
                    </Button>
                </div>
            )}

            <CardHeader className="pb-2">
                <div className="flex justify-between items-center">
                    <CardTitle className="text-sm font-bold text-zinc-400 uppercase tracking-widest flex items-center gap-2">
                        <Sparkles className="h-4 w-4 text-primary" />
                        Seu Progresso
                    </CardTitle>
                    <span className="text-xs font-bold text-primary">{status.days_completed}/7 DIAS</span>
                </div>
            </CardHeader>
            <CardContent className="space-y-6">
                <div className="space-y-2">
                    <Progress value={progress} className="h-2 bg-zinc-800" />
                </div>

                <div className="flex justify-between items-center px-1">
                    {[1, 2, 3, 4, 5, 6, 7].map((day) => (
                        <div key={day} className="flex flex-col items-center gap-1.5">
                            {day <= status.days_completed ? (
                                <div className="bg-primary/20 p-1 rounded-full">
                                    <CheckCircle2 className="h-5 w-5 text-primary" />
                                </div>
                            ) : (
                                <div className="p-1">
                                    <Circle className="h-5 w-5 text-zinc-800" />
                                </div>
                            )}
                            <span className={`text-[10px] font-bold ${day <= status.days_completed ? "text-primary" : "text-zinc-600"}`}>
                                D{day}
                            </span>
                        </div>
                    ))}
                </div>

                {!status.completed && (
                    <p className="text-[11px] text-center text-zinc-500 italic">
                        Mantenha o foco! Faltam {7 - status.days_completed} treinos para completar.
                    </p>
                )}
            </CardContent>
        </Card>
    )
}
