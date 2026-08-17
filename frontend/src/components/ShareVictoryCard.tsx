"use client"

import { useState } from "react"
import { Card, CardContent } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { WorkoutSessionFinishResponse } from "@/lib/api"
import { Download, Copy, Trophy, Flame, Clock, Zap } from "lucide-react"
import { useRouter } from "next/navigation"

interface ShareVictoryCardProps {
    response: WorkoutSessionFinishResponse
    workoutName: string
}

export function ShareVictoryCard({ response, workoutName }: ShareVictoryCardProps) {
    const router = useRouter()
    const [isCopied, setIsCopied] = useState(false)
    const [isDownloading, setIsDownloading] = useState(false)

    const brandColor = response.share_context.brand_primary_color || "#000000"
    const stats = response.share_context.stats

    const shareText = `🔥 Treino Concluído! 🔥

${workoutName}
⏱️ Duração: ${stats.duration_minutes} min
🔥 Calorias: ${stats.calories} kcal
💪 Zona: ${stats.zone_minutes} min

+${response.xp_earned} XP | Total: ${response.new_total_xp} XP

#FitnessJourney #WorkoutComplete`

    const handleCopyText = async () => {
        try {
            await navigator.clipboard.writeText(shareText)
            setIsCopied(true)
            setTimeout(() => setIsCopied(false), 2000)
        } catch (error) {
            console.error("Failed to copy text", error)
        }
    }

    const handleDownloadImage = async () => {
        setIsDownloading(true)
        try {
            // Dynamically import html2canvas
            const html2canvas = (await import('html2canvas')).default
            const element = document.getElementById('victory-card')
            if (!element) return

            const canvas = await html2canvas(element, {
                backgroundColor: null,
                scale: 2,
            })

            const link = document.createElement('a')
            link.download = `workout-${Date.now()}.png`
            link.href = canvas.toDataURL()
            link.click()
        } catch (error) {
            console.error("Failed to download image", error)
        } finally {
            setIsDownloading(false)
        }
    }

    return (
        <div className="flex flex-col gap-6 max-w-2xl mx-auto">
            <div className="text-center">
                <div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-gradient-to-br from-yellow-400 to-orange-500 mb-4">
                    <Trophy className="h-10 w-10 text-white" />
                </div>
                <h1 className="text-4xl font-bold mb-2">Parabéns! 🎉</h1>
                <p className="text-muted-foreground text-lg">Você concluiu seu treino com sucesso!</p>
            </div>

            <Card
                id="victory-card"
                className="overflow-hidden"
                style={{
                    background: `linear-gradient(135deg, ${brandColor}15 0%, ${brandColor}05 100%)`,
                    borderColor: brandColor,
                }}
            >
                <CardContent className="p-8 space-y-6">
                    <div className="text-center">
                        {response.share_context.brand_logo_url && (
                            <img
                                src={response.share_context.brand_logo_url}
                                alt="Logo"
                                className="h-16 mx-auto mb-4 object-contain"
                            />
                        )}
                        <h2 className="text-3xl font-bold mb-2" style={{ color: brandColor }}>
                            Training Done! 🔥
                        </h2>
                        <p className="text-xl font-semibold text-muted-foreground">
                            {workoutName}
                        </p>
                    </div>

                    <div className="grid grid-cols-3 gap-4">
                        <div className="text-center p-4 rounded-lg bg-background/50">
                            <Clock className="h-6 w-6 mx-auto mb-2" style={{ color: brandColor }} />
                            <p className="text-2xl font-bold">{stats.duration_minutes}</p>
                            <p className="text-sm text-muted-foreground">minutos</p>
                        </div>
                        <div className="text-center p-4 rounded-lg bg-background/50">
                            <Flame className="h-6 w-6 mx-auto mb-2" style={{ color: brandColor }} />
                            <p className="text-2xl font-bold">{stats.calories}</p>
                            <p className="text-sm text-muted-foreground">kcal</p>
                        </div>
                        <div className="text-center p-4 rounded-lg bg-background/50">
                            <Zap className="h-6 w-6 mx-auto mb-2" style={{ color: brandColor }} />
                            <p className="text-2xl font-bold">{stats.zone_minutes}</p>
                            <p className="text-sm text-muted-foreground">min zona</p>
                        </div>
                    </div>

                    <div className="text-center p-4 rounded-lg" style={{ backgroundColor: `${brandColor}20` }}>
                        <p className="text-sm text-muted-foreground mb-1">XP Ganho</p>
                        <p className="text-3xl font-bold" style={{ color: brandColor }}>
                            +{response.xp_earned} XP
                        </p>
                        <p className="text-sm text-muted-foreground mt-1">
                            Total: {response.new_total_xp} XP
                        </p>
                    </div>
                </CardContent>
            </Card>

            <div className="flex gap-4">
                <Button
                    variant="outline"
                    onClick={handleCopyText}
                    className="flex-1 gap-2"
                >
                    <Copy className="h-4 w-4" />
                    {isCopied ? "Copiado!" : "Copiar Texto"}
                </Button>
                <Button
                    onClick={handleDownloadImage}
                    disabled={isDownloading}
                    className="flex-1 gap-2"
                    style={{ backgroundColor: brandColor }}
                >
                    <Download className="h-4 w-4" />
                    {isDownloading ? "Baixando..." : "Baixar Imagem"}
                </Button>
            </div>

            <Button
                variant="ghost"
                onClick={() => router.push('/dashboard')}
                className="w-full"
            >
                Voltar ao Dashboard
            </Button>
        </div>
    )
}
