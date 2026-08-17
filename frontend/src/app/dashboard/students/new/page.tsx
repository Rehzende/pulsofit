"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { ApiClient } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Copy, Check, ArrowLeft } from "lucide-react"
import Link from "next/link"

export default function NewStudentPage() {
    const router = useRouter()
    const [loading, setLoading] = useState(false)
    const [email, setEmail] = useState("")
    const [inviteLink, setInviteLink] = useState("")
    const [copied, setCopied] = useState(false)

    const handleInvite = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)
        try {
            const response = await ApiClient.createInvite(email)
            setInviteLink(response.invite_link)
        } catch (err) {
            console.error(err)
            alert("Failed to create invite")
        } finally {
            setLoading(false)
        }
    }

    const copyToClipboard = () => {
        navigator.clipboard.writeText(inviteLink)
        setCopied(true)
        setTimeout(() => setCopied(false), 2000)
    }

    return (
        <div className="max-w-2xl mx-auto animate-in fade-in duration-500">
            <Link href="/dashboard/students" className="flex items-center text-zinc-400 hover:text-white mb-6 transition-colors">
                <ArrowLeft className="mr-2 h-4 w-4" /> Voltar para Alunos
            </Link>

            <h1 className="text-3xl font-black tracking-tight text-white mb-2">Novo Aluno</h1>
            <p className="text-zinc-400 mb-8">Convide um novo aluno para sua plataforma.</p>

            <Card className="bg-zinc-900/50 border-zinc-800 backdrop-blur-sm">
                <CardHeader>
                    <CardTitle className="text-white">Enviar Convite</CardTitle>
                    <CardDescription className="text-zinc-400">
                        O aluno receberá um link para completar o cadastro e preencher a anamnese.
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    {!inviteLink ? (
                        <form onSubmit={handleInvite} className="space-y-4">
                            <div className="space-y-2">
                                <Label htmlFor="email" className="text-zinc-300">Email do Aluno</Label>
                                <Input
                                    id="email"
                                    type="email"
                                    value={email}
                                    onChange={e => setEmail(e.target.value)}
                                    required
                                    className="bg-zinc-950/50 border-zinc-800 text-white focus:ring-primary focus:border-primary"
                                    placeholder="exemplo@email.com"
                                />
                            </div>
                            <Button
                                type="submit"
                                className="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-bold shadow-[0_0_15px_rgba(132,204,22,0.3)] transition-all"
                                disabled={loading}
                            >
                                {loading ? "Gerando Convite..." : "Gerar Link de Convite"}
                            </Button>
                        </form>
                    ) : (
                        <div className="space-y-6">
                            <div className="bg-green-500/10 border border-green-500/20 rounded-lg p-4 text-center">
                                <h3 className="text-green-500 font-bold mb-2">Convite Gerado com Sucesso!</h3>
                                <p className="text-sm text-zinc-400">Envie o link abaixo para seu aluno se cadastrar.</p>
                            </div>

                            <div className="space-y-2">
                                <Label className="text-zinc-300">Link de Convite</Label>
                                <div className="flex gap-2">
                                    <Input
                                        value={inviteLink}
                                        readOnly
                                        className="bg-zinc-950/50 border-zinc-800 text-zinc-400 font-mono text-sm"
                                    />
                                    <Button
                                        onClick={copyToClipboard}
                                        className="bg-zinc-800 hover:bg-zinc-700 text-white border border-zinc-700"
                                    >
                                        {copied ? <Check className="h-4 w-4 text-green-500" /> : <Copy className="h-4 w-4" />}
                                    </Button>
                                </div>
                            </div>

                            <Button
                                variant="outline"
                                className="w-full border-zinc-700 text-zinc-300 hover:bg-zinc-800 hover:text-white"
                                onClick={() => {
                                    setInviteLink("")
                                    setEmail("")
                                }}
                            >
                                Gerar Outro Convite
                            </Button>
                        </div>
                    )}
                </CardContent>
            </Card>
        </div>
    )
}
