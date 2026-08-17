"use client"

import { useState, useEffect, Suspense } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import Link from "next/link"
import { ApiClient } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Zap, Loader2, PartyPopper } from "lucide-react"

function RegisterContent() {
    const router = useRouter()
    const searchParams = useSearchParams()
    const token = searchParams.get("token")
    const role = searchParams.get("role") as "STUDENT" | "TRAINER" | null
    const mode = searchParams.get("mode") as "solo" | "com_coach" | null

    const [loading, setLoading] = useState(true)
    const [trainerName, setTrainerName] = useState<string | null>(null)
    const [inviteEmail, setInviteEmail] = useState<string | null>(null)
    const [error, setError] = useState<string | null>(null)

    useEffect(() => {
        // Store role/mode in sessionStorage for use in login flow
        if (role) {
            sessionStorage.setItem("registration_role", role)
        }
        if (mode) {
            sessionStorage.setItem("registration_mode", mode)
        }

        // Check if user is already logged in
        const authToken = localStorage.getItem('token')
        if (authToken && !token) {
            // User is already logged in and not following an invite link
            // Redirect to dashboard
            router.replace('/dashboard')
            return
        }

        if (token) {
            const fetchInvite = async () => {
                try {
                    const data = await ApiClient.getInvite(token)
                    setInviteEmail(data.email)
                    setTrainerName(data.trainer_name ?? null)
                } catch {
                    setError("Convite inválido ou expirado.")
                } finally {
                    setLoading(false)
                }
            }
            fetchInvite()
        } else {
            setLoading(false)
        }
    }, [token, role, mode, router])

    if (loading) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-background">
                <Loader2 className="h-8 w-8 animate-spin text-primary" />
            </div>
        )
    }

    if (error) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-background p-4">
                <Card className="w-full max-w-md bg-card/70 border-border/50 backdrop-blur-xl">
                    <CardContent className="pt-8 pb-8 text-center">
                        <div className="mb-4 text-destructive font-bold text-xl">Convite Inválido</div>
                        <p className="text-muted-foreground mb-6">{error}</p>
                        <Link href="/login">
                            <Button className="w-full">Voltar para Login</Button>
                        </Link>
                    </CardContent>
                </Card>
            </div>
        )
    }

    return (
        <div className="min-h-screen flex items-center justify-center bg-background p-4 relative overflow-hidden">
            {/* Background Effects */}
            <div className="absolute inset-0 -z-10">
                <div className="absolute top-[-10%] right-[-10%] w-[500px] h-[500px] bg-primary/10 rounded-full blur-[100px]" />
                <div className="absolute bottom-[-10%] left-[-10%] w-[500px] h-[500px] bg-accent/8 rounded-full blur-[100px]" />
            </div>

            <Card className="w-full max-w-md bg-card/70 border-border/50 backdrop-blur-xl shadow-2xl relative z-10">
                <CardHeader className="space-y-1 text-center pt-10 pb-6">
                    <div className="flex justify-center mb-6">
                        <div className="relative">
                            <div className="absolute inset-0 bg-emerald-500/20 rounded-full blur-xl" />
                            <div className="relative w-16 h-16 bg-gradient-to-br from-emerald-500/30 to-emerald-500/10 border-2 border-emerald-500/40 rounded-full flex items-center justify-center">
                                <PartyPopper className="h-8 w-8 text-emerald-400" />
                            </div>
                        </div>
                    </div>
                    <CardTitle className="text-2xl font-bold tracking-tight text-foreground">
                        {token ? "Você foi convidado!" : "Comece no PULSO"}
                    </CardTitle>
                    <CardDescription className="text-muted-foreground">
                        {token && trainerName
                            ? `O treinador ${trainerName} te convidou para o PULSO.`
                            : role === "STUDENT" && mode === "solo"
                            ? "Treino Solo — entre com seu e-mail para começar"
                            : role === "STUDENT" && mode === "com_coach"
                            ? "Com Treinador — entre com seu e-mail para começar"
                            : role === "TRAINER"
                            ? "Seja um Treinador — entre com seu e-mail para começar"
                            : "Entre com seu e-mail para começar — sem senha necessária!"
                        }
                    </CardDescription>
                    {inviteEmail && (
                        <p className="text-sm text-primary font-semibold pt-2">
                            Faça login com: {inviteEmail}
                        </p>
                    )}
                </CardHeader>
                <CardContent className="px-8 pb-10">
                    <Link href={`/login${role ? `?role=${role}` : ''}${mode ? `${role ? '&' : '?'}mode=${mode}` : ''}`}>
                        <Button
                            className="w-full bg-primary hover:bg-primary/90 text-primary-foreground font-bold h-12 rounded-xl glow-primary-sm hover:glow-primary transition-all text-sm"
                        >
                            <Zap className="mr-2 h-4 w-4" />
                            Continuar para Login
                        </Button>
                    </Link>
                    <p className="text-center text-xs text-muted-foreground mt-4">
                        Você receberá um link mágico no seu e-mail para entrar.
                    </p>
                </CardContent>
            </Card>
        </div>
    )
}

export default function RegisterPage() {
    return (
        <Suspense fallback={<div className="min-h-screen flex items-center justify-center bg-background"><Loader2 className="h-8 w-8 animate-spin text-primary" /></div>}>
            <RegisterContent />
        </Suspense>
    )
}
