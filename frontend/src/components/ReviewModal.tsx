"use client"

import { useState, useEffect } from "react"
import { ApiClient, Review } from "@/lib/api"
import { Button } from "@/components/ui/button"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog"
import { Textarea } from "@/components/ui/textarea"
import { Star } from "lucide-react"
import { toast } from "sonner"

interface ReviewModalProps {
    trainerId: string
    trainerName: string
    open: boolean
    onOpenChange: (open: boolean) => void
}

export function ReviewModal({ trainerId, trainerName, open, onOpenChange }: ReviewModalProps) {
    const [rating, setRating] = useState(0)
    const [hover, setHover] = useState(0)
    const [text, setText] = useState("")
    const [isLoading, setIsLoading] = useState(false)
    const [existingReview, setExistingReview] = useState<Review | null>(null)

    useEffect(() => {
        if (open && trainerId) {
            ApiClient.getMyReview(trainerId)
                .then(review => {
                    if (review) {
                        setExistingReview(review)
                        setRating(review.rating)
                        setText(review.text || "")
                    }
                })
                .catch(() => {})
        }
    }, [open, trainerId])

    const handleSubmit = async () => {
        if (rating === 0) {
            toast.error("Por favor, selecione uma nota.")
            return
        }

        setIsLoading(true)
        try {
            await ApiClient.createReview({
                trainer_id: trainerId,
                rating,
                text
            })
            toast.success("Depoimento enviado com sucesso!")
            onOpenChange(false)
        } catch (error: any) {
            toast.error(error.response?.data?.detail || "Erro ao enviar depoimento.")
        } finally {
            setIsLoading(false)
        }
    }

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="bg-zinc-900 border-zinc-800 sm:max-w-[425px]">
                <DialogHeader>
                    <DialogTitle className="text-white">Depoimento para {trainerName}</DialogTitle>
                    <DialogDescription className="text-zinc-500">
                        Compartilhe sua experiência e ajude outros alunos.
                    </DialogDescription>
                </DialogHeader>
                <div className="grid gap-6 py-4">
                    <div className="flex flex-col items-center gap-2">
                        <div className="flex items-center gap-1">
                            {[1, 2, 3, 4, 5].map((star) => (
                                <button
                                    key={star}
                                    type="button"
                                    className="p-1 transition-transform hover:scale-110 active:scale-95"
                                    onClick={() => setRating(star)}
                                    onMouseEnter={() => setHover(star)}
                                    onMouseLeave={() => setHover(0)}
                                >
                                    <Star
                                        className={`h-8 w-8 transition-colors ${
                                            (hover || rating) >= star
                                                ? "fill-yellow-500 text-yellow-500"
                                                : "text-zinc-700"
                                        }`}
                                    />
                                </button>
                            ))}
                        </div>
                        <p className="text-xs font-bold text-zinc-400 uppercase tracking-widest">
                            {rating === 1 && "Muito Ruim"}
                            {rating === 2 && "Regular"}
                            {rating === 3 && "Bom"}
                            {rating === 4 && "Muito Bom"}
                            {rating === 5 && "Excelente!"}
                            {rating === 0 && "Selecione uma nota"}
                        </p>
                    </div>
                    <div className="space-y-2">
                        <label className="text-sm font-medium text-zinc-300">Seu comentário (opcional)</label>
                        <Textarea
                            placeholder="Conte como o treinador tem te ajudado..."
                            className="bg-zinc-800 border-zinc-700 text-white min-h-[120px] resize-none"
                            value={text}
                            onChange={(e) => setText(e.target.value)}
                        />
                    </div>
                </div>
                <DialogFooter>
                    <Button
                        variant="ghost"
                        onClick={() => onOpenChange(false)}
                        className="text-zinc-400 hover:text-white hover:bg-zinc-800"
                    >
                        Cancelar
                    </Button>
                    <Button
                        onClick={handleSubmit}
                        disabled={isLoading || rating === 0}
                        className="bg-primary text-primary-foreground font-bold"
                    >
                        {isLoading ? "Enviando..." : "Enviar Depoimento"}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    )
}
