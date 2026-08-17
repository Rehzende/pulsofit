"use client"

import { useState } from "react"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { Dumbbell, Users, ArrowRight } from "lucide-react"

interface WorkoutModeOnboardingProps {
    open: boolean
    onClose: (mode: "solo" | "com_coach") => void
}

export function WorkoutModeOnboarding({ open, onClose }: WorkoutModeOnboardingProps) {
    const [selected, setSelected] = useState<"solo" | "com_coach" | null>(null)

    const handleConfirm = () => {
        if (selected) {
            onClose(selected)
        }
    }

    return (
        <Dialog open={open} onOpenChange={() => {}}>
            <DialogContent className="max-w-2xl">
                <DialogHeader className="text-center space-y-3">
                    <DialogTitle className="text-2xl">Como você quer treinar?</DialogTitle>
                    <DialogDescription className="text-base">
                        Escolha se prefere treinar sozinho ou com a orientação de um treinador profissional.
                        Você pode mudar de ideia depois.
                    </DialogDescription>
                </DialogHeader>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 my-6">
                    {/* Solo Mode */}
                    <Card
                        className={`p-6 cursor-pointer transition-all ${
                            selected === "solo"
                                ? "card-glow border-primary/60 ring-2 ring-primary/30"
                                : "card-glow hover:border-primary/40"
                        }`}
                        onClick={() => setSelected("solo")}
                    >
                        <div className="flex flex-col items-center text-center space-y-4">
                            <div className="w-12 h-12 rounded-full bg-primary/15 flex items-center justify-center">
                                <Dumbbell className="h-6 w-6 text-primary" />
                            </div>
                            <div>
                                <h3 className="font-bold text-lg text-foreground mb-1">Treino Solo</h3>
                                <p className="text-sm text-muted-foreground">
                                    Crie e gerencie seus próprios treinos. Use IA para gerar programas personalizados.
                                </p>
                            </div>
                            <ul className="text-xs text-muted-foreground space-y-1 w-full text-left">
                                <li>✓ Treinos personalizados com IA</li>
                                <li>✓ Biblioteca de exercícios</li>
                                <li>✓ Rastreamento de progresso</li>
                                <li>✓ Sensores HR opcionais</li>
                            </ul>
                            {selected === "solo" && (
                                <div className="mt-2">
                                    <span className="inline-block px-3 py-1 bg-primary/20 text-primary text-xs font-semibold rounded-full">
                                        Selecionado
                                    </span>
                                </div>
                            )}
                        </div>
                    </Card>

                    {/* Com Coach Mode */}
                    <Card
                        className={`p-6 cursor-pointer transition-all ${
                            selected === "com_coach"
                                ? "card-glow border-primary/60 ring-2 ring-primary/30"
                                : "card-glow hover:border-primary/40"
                        }`}
                        onClick={() => setSelected("com_coach")}
                    >
                        <div className="flex flex-col items-center text-center space-y-4">
                            <div className="w-12 h-12 rounded-full bg-primary/15 flex items-center justify-center">
                                <Users className="h-6 w-6 text-primary" />
                            </div>
                            <div>
                                <h3 className="font-bold text-lg text-foreground mb-1">Com Treinador</h3>
                                <p className="text-sm text-muted-foreground">
                                    Encontre um treinador profissional para orientação personalizada.
                                </p>
                            </div>
                            <ul className="text-xs text-muted-foreground space-y-1 w-full text-left">
                                <li>✓ Treinos sob medida</li>
                                <li>✓ Chat com o treinador</li>
                                <li>✓ Acompanhamento semanal</li>
                                <li>✓ Feedback personalizado</li>
                            </ul>
                            {selected === "com_coach" && (
                                <div className="mt-2">
                                    <span className="inline-block px-3 py-1 bg-primary/20 text-primary text-xs font-semibold rounded-full">
                                        Selecionado
                                    </span>
                                </div>
                            )}
                        </div>
                    </Card>
                </div>

                <div className="flex gap-3 justify-end">
                    <Button
                        onClick={handleConfirm}
                        disabled={!selected}
                        className="bg-primary hover:bg-primary/90 text-primary-foreground font-semibold gap-2"
                    >
                        Continuar
                        <ArrowRight className="h-4 w-4" />
                    </Button>
                </div>
            </DialogContent>
        </Dialog>
    )
}
