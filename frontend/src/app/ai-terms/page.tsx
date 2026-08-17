"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { ApiClient, User } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { ShieldCheck, AlertTriangle, Info } from "lucide-react"

export default function AiTermsPage() {
    const router = useRouter()
    const [isLoading, setIsLoading] = useState(true)
    const [isAccepting, setIsAccepting] = useState(false)
    const [accepted, setAccepted] = useState(false)
    const [user, setUser] = useState<User | null>(null)

    useEffect(() => {
        const token = localStorage.getItem("token")
        if (!token) {
            router.push("/login")
            return
        }

        ApiClient.getMe()
            .then(userData => {
                if (userData.accepted_ai_terms_at) {
                    router.push("/dashboard")
                } else {
                    setUser(userData)
                    setIsLoading(false)
                }
            })
            .catch(() => {
                localStorage.removeItem("token")
                router.push("/login")
            })
    }, [router])

    const handleAccept = async () => {
        if (!accepted) return

        setIsAccepting(true)
        try {
            await ApiClient.acceptAiTerms()
            router.push("/dashboard")
        } catch (error) {
            console.error("Failed to accept AI terms:", error)
            alert("Erro ao aceitar os termos. Tente novamente.")
        } finally {
            setIsAccepting(false)
        }
    }

    if (isLoading) {
        return (
            <div className="flex h-screen w-full items-center justify-center bg-background">
                <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
            </div>
        )
    }

    return (
        <div className="flex min-h-screen items-center justify-center bg-muted/30 p-4">
            <Card className="max-w-2xl shadow-xl">
                <CardHeader className="text-center">
                    <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-primary/10 text-primary">
                        <ShieldCheck className="h-10 w-10" />
                    </div>
                    <CardTitle className="text-2xl font-bold">Termos de Uso de Inteligência Artificial</CardTitle>
                    <CardDescription>
                        Para continuar utilizando o Pulso, você precisa aceitar os termos de responsabilidade da IA.
                    </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4 text-sm leading-relaxed">
                    <div className="rounded-lg border border-blue-100 bg-blue-50 p-4 text-blue-800">
                        <div className="flex gap-3">
                            <Info className="h-5 w-5 shrink-0" />
                            <p>
                                O Pulso utiliza modelos avançados de IA para auxiliar na criação de treinos e análise de dados.
                                Estes modelos são ferramentas de assistência e não substituem o julgamento profissional.
                            </p>
                        </div>
                    </div>

                    <div className="space-y-3 px-1">
                        <h3 className="font-semibold text-foreground">1. Natureza da Assistência</h3>
                        <p className="text-muted-foreground">
                            As sugestões geradas pela IA são baseadas em padrões estatísticos e dados fornecidos. 
                            Elas devem ser revisadas por você antes de serem aplicadas ou enviadas a alunos.
                        </p>

                        <h3 className="font-semibold text-foreground">2. Responsabilidade Profissional</h3>
                        <p className="text-muted-foreground">
                            Você reconhece que, como profissional de educação física ou usuário final, a responsabilidade final pela 
                            segurança e eficácia dos exercícios é inteiramente sua.
                        </p>

                        <h3 className="font-semibold text-foreground">3. Limitações da Tecnologia</h3>
                        <p className="text-muted-foreground">
                            A IA pode ocasionalmente gerar informações incorretas ou incompletas. Verifique sempre 
                            as contraindicações e limites físicos informados na anamnese.
                        </p>

                        <div className="rounded-lg border border-amber-100 bg-amber-50 p-4 text-amber-800">
                            <div className="flex gap-3">
                                <AlertTriangle className="h-5 w-5 shrink-0" />
                                <p className="font-medium">
                                    Ao utilizar ferramentas de IA, você concorda que o Pulso Fit não se responsabiliza por 
                                    lesões ou danos decorrentes do uso direto de sugestões não revisadas.
                                </p>
                            </div>
                        </div>
                    </div>
                </CardContent>
                <CardFooter className="flex flex-col gap-4 border-t pt-6">
                    <div className="flex items-center space-x-2 self-start">
                        <input
                            type="checkbox"
                            id="terms"
                            checked={accepted}
                            onChange={(e) => setAccepted(e.target.checked)}
                            className="h-4 w-4 rounded border-zinc-300 text-primary focus:ring-primary"
                        />
                        <label
                            htmlFor="terms"
                            className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
                        >
                            Eu li e aceito os Termos de Responsabilidade de IA
                        </label>
                    </div>
                    <Button 
                        className="w-full" 
                        disabled={!accepted || isAccepting}
                        onClick={handleAccept}
                    >
                        {isAccepting ? "Processando..." : "Aceitar e Continuar"}
                    </Button>
                </CardFooter>
            </Card>
        </div>
    )
}
