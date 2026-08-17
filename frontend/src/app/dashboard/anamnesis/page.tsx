"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { ApiClient, User } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Label } from "@/components/ui/label"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Loader2, CheckCircle2 } from "lucide-react"

export default function AnamnesisPage() {
    const router = useRouter()
    const [isLoading, setIsLoading] = useState(false)
    const [user, setUser] = useState<User | null>(null)

    // Form State
    const [goal, setGoal] = useState("Hipertrofia")
    const [activityLevel, setActivityLevel] = useState("Sedentário")
    const [injuries, setInjuries] = useState("")
    const [gender, setGender] = useState("MALE")
    const [weight, setWeight] = useState("")

    useEffect(() => {
        ApiClient.getMe().then(setUser).catch(console.error)
    }, [])

    const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault()
        setIsLoading(true)

        try {
            const medicalHistory = {
                goal,
                activity_level: activityLevel,
                injuries,
                updated_at: new Date().toISOString()
            }

            // Update profile via API (we need to ensure this endpoint exists/works for students)
            // The mobile app uses updateProfile. Let's check api.ts for equivalent.
            // api.ts has trainer.updateProfile but maybe we need a generic user update or specific student one.
            // The mobile app calls `_apiService.updateProfile`.
            // In api.ts we have `updateUserMe` (PUT /users/me). Let's use that.

            // Wait, api.ts doesn't have updateUserMe exposed in ApiClient object explicitly?
            // Let's check api.ts again.
            // It has `getMe`. It doesn't seem to have `updateMe`.
            // I might need to add `updateMe` to ApiClient in api.ts first.
            // But for now let's assume I can add it or use axios directly if needed, 
            // but better to add to ApiClient.

            // Actually, let's check api.ts content I read earlier.
            // It has `registerStudent`, `getMe`, `login`.
            // It DOES NOT have `updateMe`.
            // I need to add `updateMe` to ApiClient.

            // For now, I will write this file assuming ApiClient.updateMe exists, 
            // and then I will go update api.ts.

            await ApiClient.updateMe({
                medical_history: medicalHistory,
                anamnesis_completed: true,
                gender,
                weight_kg: parseFloat(weight)
            })

            alert("Anamnese salva com sucesso! Seu treinador já tem acesso às suas informações.")

            router.push("/dashboard")
            router.refresh()
        } catch (error) {
            console.error(error)
            alert("Erro ao salvar. Tente novamente mais tarde.")
        } finally {
            setIsLoading(false)
        }
    }

    if (!user) {
        return <div className="flex justify-center p-8"><Loader2 className="animate-spin text-white" /></div>
    }

    return (
        <div className="max-w-2xl mx-auto space-y-5 sm:space-y-8">
            <div>
                <h1 className="text-2xl sm:text-3xl font-black tracking-tight text-white mb-2">Anamnese</h1>
                <p className="text-zinc-400">
                    Responda algumas perguntas para que seu treinador possa montar o melhor treino para você.
                </p>
            </div>

            <Card className="bg-zinc-900/50 border-zinc-800">
                <CardHeader>
                    <CardTitle className="text-white">Informações Iniciais</CardTitle>
                    <CardDescription className="text-zinc-400">
                        Esses dados são essenciais para sua segurança e resultados.
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <form onSubmit={handleSubmit} className="space-y-4 sm:space-y-6">
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 sm:gap-6">
                            <div className="space-y-2">
                                <Label className="text-zinc-200">Gênero</Label>
                                <Select value={gender} onValueChange={setGender}>
                                    <SelectTrigger className="bg-zinc-950 border-zinc-800 text-white">
                                        <SelectValue placeholder="Selecione" />
                                    </SelectTrigger>
                                    <SelectContent className="bg-zinc-900 border-zinc-800 text-white">
                                        <SelectItem value="MALE">Masculino</SelectItem>
                                        <SelectItem value="FEMALE">Feminino</SelectItem>
                                        <SelectItem value="OTHER">Outro</SelectItem>
                                    </SelectContent>
                                </Select>
                            </div>

                            <div className="space-y-2">
                                <Label className="text-zinc-200">Peso (kg)</Label>
                                <Input
                                    type="number"
                                    step="0.1"
                                    placeholder="Ex: 75.5"
                                    className="bg-zinc-950 border-zinc-800 text-white"
                                    value={weight}
                                    onChange={(e) => setWeight(e.target.value)}
                                    required
                                />
                            </div>
                        </div>

                        <div className="space-y-2">
                            <Label className="text-zinc-200">Objetivo Principal</Label>
                            <Select value={goal} onValueChange={setGoal}>
                                <SelectTrigger className="bg-zinc-950 border-zinc-800 text-white">
                                    <SelectValue placeholder="Selecione seu objetivo" />
                                </SelectTrigger>
                                <SelectContent className="bg-zinc-900 border-zinc-800 text-white">
                                    <SelectItem value="Hipertrofia">Hipertrofia (Ganho de Massa)</SelectItem>
                                    <SelectItem value="Emagrecimento">Emagrecimento</SelectItem>
                                    <SelectItem value="Condicionamento">Condicionamento Físico</SelectItem>
                                    <SelectItem value="Força">Ganho de Força</SelectItem>
                                </SelectContent>
                            </Select>
                        </div>

                        <div className="space-y-2">
                            <Label className="text-zinc-200">Nível de Atividade</Label>
                            <Select value={activityLevel} onValueChange={setActivityLevel}>
                                <SelectTrigger className="bg-zinc-950 border-zinc-800 text-white">
                                    <SelectValue placeholder="Selecione seu nível" />
                                </SelectTrigger>
                                <SelectContent className="bg-zinc-900 border-zinc-800 text-white">
                                    <SelectItem value="Sedentário">Sedentário</SelectItem>
                                    <SelectItem value="Levemente Ativo">Levemente Ativo (1-2x semana)</SelectItem>
                                    <SelectItem value="Moderadamente Ativo">Moderadamente Ativo (3-4x semana)</SelectItem>
                                    <SelectItem value="Muito Ativo">Muito Ativo (5-6x semana)</SelectItem>
                                    <SelectItem value="Extremamente Ativo">Extremamente Ativo (Todo dia)</SelectItem>
                                </SelectContent>
                            </Select>
                        </div>

                        <div className="space-y-2">
                            <Label className="text-zinc-200">Lesões ou Restrições</Label>
                            <textarea
                                placeholder="Descreva se possui alguma lesão, dor crônica ou restrição médica..."
                                className="flex min-h-[100px] w-full rounded-md border border-zinc-800 bg-zinc-950 px-3 py-2 text-sm ring-offset-background placeholder:text-zinc-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 text-white"
                                value={injuries}
                                onChange={(e) => setInjuries(e.target.value)}
                            />
                        </div>

                        <Button
                            type="submit"
                            className="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-bold"
                            disabled={isLoading}
                        >
                            {isLoading ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <CheckCircle2 className="mr-2 h-4 w-4" />}
                            Salvar Respostas
                        </Button>
                    </form>
                </CardContent>
            </Card>
        </div>
    )
}
