"use client"

import { useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { ApiClient, api } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Zap, Loader2, Link2, Mail, ArrowLeft, ClipboardPaste } from "lucide-react"
import { GoogleLogin, CredentialResponse } from "@react-oauth/google"

export function LoginContent() {
    const router = useRouter()
    const searchParams = useSearchParams()
    const [loading, setLoading] = useState(false)
    const [email, setEmail] = useState("")
    const [token, setToken] = useState("")
    const [error, setError] = useState<string | null>(null)
    const [step, setStep] = useState<"email" | "verify">("email")
    const [pendingEmail, setPendingEmail] = useState("")

    // Capture registration context (role/mode) and auto-verify if token in URL
    useEffect(() => {
        const role = searchParams.get("role")
        const mode = searchParams.get("mode")
        const urlToken = searchParams.get("token")

        if (role) sessionStorage.setItem("registration_role", role)
        if (mode) sessionStorage.setItem("registration_mode", mode)

        // Auto-verify if token present in URL (from email link)
        if (urlToken) {
            setToken(urlToken)
            setStep("verify")
            // Auto-submit after a brief delay to allow render
            const timer = setTimeout(() => handleVerifyToken(urlToken), 500)
            return () => clearTimeout(timer)
        }
    }, [searchParams])

    // Step 1: Request Magic Link
    const handleRequestMagicLink = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)
        setError(null)
        try {
            await ApiClient.requestMagicLink(email)
            setPendingEmail(email)
            setStep("verify")
        } catch (err: any) {
            console.error(err)
            if (err.response?.status === 422) {
                setError("Por favor, insira um e-mail válido.")
            } else {
                setError("Falha ao enviar o link mágico. Tente novamente.")
            }
        } finally {
            setLoading(false)
        }
    }

    // Step 2: Verify Token
    const handleVerifyToken = async (tokenParam?: string, e?: React.FormEvent) => {
        if (e) e.preventDefault()

        const verifyToken = tokenParam || token.trim()
        if (!verifyToken) return

        setLoading(true)
        setError(null)
        try {
            const data = await ApiClient.verifyMagicLink(verifyToken)
            localStorage.setItem("token", data.access_token)

            const user = await ApiClient.getMe()
            if (user.role === 'SUPER_ADMIN') {
                router.push("/admin")
            } else {
                router.push("/dashboard")
            }
        } catch (err: any) {
            console.error(err)
            const detail = err.response?.data?.detail || ""
            if (detail.includes("expired")) {
                setError("Link mágico expirado. Solicite um novo.")
            } else if (detail.includes("already been used")) {
                setError("Este link já foi utilizado. Solicite um novo.")
            } else {
                setError("Token inválido. Verifique e tente novamente.")
            }
        } finally {
            setLoading(false)
        }
    }

    // Resend Magic Link
    const handleResend = async () => {
        setLoading(true)
        setError(null)
        try {
            await ApiClient.requestMagicLink(pendingEmail)
            setError(null)
        } catch {
            setError("Falha ao reenviar. Tente novamente.")
        } finally {
            setLoading(false)
        }
    }

    // Google Sign-In
    const handleGoogleSuccess = async (credentialResponse: CredentialResponse) => {
        if (!credentialResponse.credential) return
        setLoading(true)
        setError(null)
        try {
            const response = await api.post("/auth/google", { id_token: credentialResponse.credential })
            const data = response.data
            localStorage.setItem("token", data.access_token)
            const user = await ApiClient.getMe()
            if (user.role === 'SUPER_ADMIN') {
                router.push("/admin")
            } else {
                router.push("/dashboard")
            }
        } catch {
            setError("Falha ao autenticar com Google. Tente novamente.")
        } finally {
            setLoading(false)
        }
    }

    // Paste from clipboard
    const handlePaste = async () => {
        try {
            const text = await navigator.clipboard.readText()
            if (text) setToken(text)
        } catch {
            // Clipboard permission denied — user can paste manually
        }
    }

    return (
        <div className="min-h-screen flex items-center justify-center bg-background p-4 relative overflow-hidden">

            {/* Ambient Background */}
            <div className="absolute inset-0 -z-10">
                <div className="absolute top-[-20%] left-[20%] w-[500px] h-[500px] bg-primary/10 rounded-full blur-[120px]" />
                <div className="absolute bottom-[-10%] right-[15%] w-[400px] h-[400px] bg-accent/8 rounded-full blur-[100px]" />
            </div>

            {/* Subtle Grid */}
            <div
                className="absolute inset-0 -z-10 opacity-[0.015]"
                style={{
                    backgroundImage: `linear-gradient(hsl(266 70% 55% / 0.5) 1px, transparent 1px), linear-gradient(90deg, hsl(266 70% 55% / 0.5) 1px, transparent 1px)`,
                    backgroundSize: '50px 50px'
                }}
            />

            <Card className="w-full max-w-md bg-card/70 border-border/50 backdrop-blur-xl shadow-2xl relative z-10">
                {step === "email" ? (
                    <>
                        {/* ═══════════════ STEP 1: Email Input ═══════════════ */}
                        <CardHeader className="space-y-1 text-center pt-10 pb-8">
                            <div className="flex justify-center mb-8">
                                <div className="relative">
                                    <div className="absolute inset-0 bg-primary/30 rounded-2xl blur-xl" />
                                    <div className="relative w-16 h-16 bg-gradient-to-br from-primary to-purple-400 rounded-2xl flex items-center justify-center shadow-xl shadow-primary/30">
                                        <Zap className="h-8 w-8 text-white" />
                                    </div>
                                </div>
                            </div>
                            <CardTitle className="text-2xl font-bold text-foreground">Bem-vindo ao PULSO</CardTitle>
                            <CardDescription className="text-muted-foreground">
                                Sem senha! Enviaremos um link mágico para o seu e-mail.
                            </CardDescription>
                        </CardHeader>

                        <CardContent className="px-8 pb-10">
                            <form onSubmit={handleRequestMagicLink} className="space-y-5">
                                {error && (
                                    <div className="bg-destructive/10 border border-destructive/25 text-destructive text-sm p-3 rounded-xl">
                                        {error}
                                    </div>
                                )}
                                <div className="space-y-2">
                                    <Label htmlFor="email" className="text-foreground/80 text-sm font-medium">Email</Label>
                                    <Input
                                        id="email"
                                        type="email"
                                        placeholder="seu@email.com"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        required
                                        className="bg-background/50 border-border/60 text-foreground placeholder:text-muted-foreground/50 focus:border-primary/60 focus:ring-primary/20 h-12 rounded-xl"
                                    />
                                </div>
                                <Button
                                    type="submit"
                                    className="w-full bg-primary hover:bg-primary/90 text-primary-foreground font-bold h-12 rounded-xl glow-primary-sm hover:glow-primary transition-all text-sm"
                                    disabled={loading}
                                >
                                    {loading ? (
                                        <>
                                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                            Enviando...
                                        </>
                                    ) : (
                                        <>
                                            <Link2 className="mr-2 h-4 w-4" />
                                            Enviar Link Mágico
                                        </>
                                    )}
                                </Button>
                            </form>

                            {/* Divider */}
                            <div className="flex items-center gap-3 my-5">
                                <div className="flex-1 h-px bg-border/50" />
                                <span className="text-xs text-muted-foreground">ou</span>
                                <div className="flex-1 h-px bg-border/50" />
                            </div>

                            {/* Google Sign-In */}
                            <div className="flex justify-center">
                                <GoogleLogin
                                    onSuccess={handleGoogleSuccess}
                                    onError={() => setError("Falha ao autenticar com Google.")}
                                    theme="filled_black"
                                    shape="rectangular"
                                    size="large"
                                    text="signin_with"
                                />
                            </div>
                        </CardContent>
                    </>
                ) : (
                    <>
                        {/* ═══════════════ STEP 2: Verify Token ═══════════════ */}
                        <CardHeader className="space-y-1 text-center pt-10 pb-6">
                            <div className="flex justify-center mb-6">
                                <div className="relative">
                                    <div className="absolute inset-0 bg-emerald-500/20 rounded-full blur-xl" />
                                    <div className="relative w-16 h-16 bg-gradient-to-br from-emerald-500/30 to-emerald-500/10 border-2 border-emerald-500/40 rounded-full flex items-center justify-center">
                                        <Mail className="h-8 w-8 text-emerald-400" />
                                    </div>
                                </div>
                            </div>
                            <CardTitle className="text-2xl font-bold text-foreground">Verifique seu e-mail</CardTitle>
                            <CardDescription className="text-muted-foreground">
                                <span className="block mb-2">
                                    Enviamos um link mágico para{" "}
                                    <span className="text-primary font-semibold">{pendingEmail}</span>
                                </span>
                                <span className="text-xs text-primary/80">
                                    💡 Dica: Clique no link do e-mail para entrar automaticamente, ou cole o token abaixo
                                </span>
                            </CardDescription>
                        </CardHeader>

                        <CardContent className="px-8 pb-10">
                            <form onSubmit={(e) => handleVerifyToken(undefined, e)} className="space-y-5">
                                {error && (
                                    <div className="bg-destructive/10 border border-destructive/25 text-destructive text-sm p-3 rounded-xl">
                                        {error}
                                    </div>
                                )}

                                <div className="space-y-2">
                                    <Label htmlFor="token" className="text-foreground/80 text-sm font-medium">
                                        Cole o token do e-mail aqui:
                                    </Label>
                                    <div className="relative">
                                        <Input
                                            id="token"
                                            type="text"
                                            placeholder="Cole o token aqui..."
                                            value={token}
                                            onChange={(e) => setToken(e.target.value)}
                                            className="bg-background/50 border-border/60 text-foreground font-mono placeholder:text-muted-foreground/50 focus:border-primary/60 focus:ring-primary/20 h-12 rounded-xl pr-12"
                                        />
                                        <button
                                            type="button"
                                            onClick={handlePaste}
                                            className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-primary transition-colors"
                                            title="Colar"
                                        >
                                            <ClipboardPaste className="h-4 w-4" />
                                        </button>
                                    </div>
                                </div>

                                <Button
                                    type="submit"
                                    className="w-full bg-primary hover:bg-primary/90 text-primary-foreground font-bold h-12 rounded-xl glow-primary-sm hover:glow-primary transition-all text-sm"
                                    disabled={loading}
                                >
                                    {loading ? (
                                        <>
                                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                            Verificando...
                                        </>
                                    ) : (
                                        "Verificar e Entrar"
                                    )}
                                </Button>

                                <div className="flex flex-col items-center gap-2 pt-2">
                                    <button
                                        type="button"
                                        onClick={handleResend}
                                        disabled={loading}
                                        className="text-sm text-primary hover:text-primary/80 font-semibold transition-colors disabled:opacity-50"
                                    >
                                        Reenviar link mágico
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => { setStep("email"); setError(null); setToken("") }}
                                        className="text-sm text-muted-foreground hover:text-foreground transition-colors flex items-center gap-1"
                                    >
                                        <ArrowLeft className="h-3 w-3" />
                                        Usar outro e-mail
                                    </button>
                                </div>
                            </form>
                        </CardContent>
                    </>
                )}
            </Card>
        </div>
    )
}
