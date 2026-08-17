"use client"

import { useState } from "react"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Label } from "@/components/ui/label"
import { Slider } from "@/components/ui/slider"

interface FeedbackModalProps {
    open: boolean
    onClose: () => void
    onSubmit: (rpe: number, feedback: string) => void
    isSubmitting: boolean
}

export function FeedbackModal({ open, onClose, onSubmit, isSubmitting }: FeedbackModalProps) {
    const [rpe, setRpe] = useState(5)
    const [feedback, setFeedback] = useState("")

    const handleSubmit = () => {
        onSubmit(rpe, feedback)
    }

    return (
        <Dialog open={open} onOpenChange={onClose}>
            <DialogContent className="sm:max-w-[500px]">
                <DialogHeader>
                    <DialogTitle>Como foi o treino?</DialogTitle>
                    <DialogDescription>
                        Compartilhe sua experiência para ajudar seu treinador a personalizar seus próximos treinos.
                    </DialogDescription>
                </DialogHeader>

                <div className="space-y-6 py-4">
                    <div className="space-y-3">
                        <Label htmlFor="rpe" className="text-base">
                            RPE - Esforço Percebido (1-10)
                        </Label>
                        <div className="flex items-center gap-4">
                            <Slider
                                id="rpe"
                                min={1}
                                max={10}
                                step={1}
                                value={[rpe]}
                                onValueChange={(value) => setRpe(value[0])}
                                className="flex-1"
                            />
                            <div className="w-12 text-center">
                                <span className="text-2xl font-bold">{rpe}</span>
                            </div>
                        </div>
                        <p className="text-sm text-muted-foreground">
                            1 = Muito fácil • 10 = Máximo esforço
                        </p>
                    </div>

                    <div className="space-y-3">
                        <Label htmlFor="feedback" className="text-base">
                            Feedback (Opcional)
                        </Label>
                        <textarea
                            id="feedback"
                            placeholder="Como você se sentiu durante o treino? Algum exercício foi particularmente desafiador?"
                            value={feedback}
                            onChange={(e) => setFeedback(e.target.value)}
                            className="w-full min-h-[100px] px-3 py-2 text-sm rounded-md border border-input bg-background ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 resize-none"
                        />
                    </div>
                </div>

                <DialogFooter>
                    <Button
                        variant="outline"
                        onClick={onClose}
                        disabled={isSubmitting}
                    >
                        Cancelar
                    </Button>
                    <Button
                        onClick={handleSubmit}
                        disabled={isSubmitting}
                    >
                        {isSubmitting ? "Enviando..." : "Enviar Feedback"}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    )
}
