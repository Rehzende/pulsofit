"use client"

import { useState, useEffect, useRef } from "react"
import { useRouter } from "next/navigation"
import { ApiClient, AgentSession, AgentMessage, AgentActionStatus } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle, CardFooter } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Sparkles, Send, Loader2, Bot, User as UserIcon, CheckCircle, XCircle } from "lucide-react"
import { toast } from "sonner"
import { Badge } from "@/components/ui/badge"
import { ScrollArea } from "@/components/ui/scroll-area"

export default function AiAgentPage() {
    const [session, setSession] = useState<AgentSession | null>(null)
    const [messages, setMessages] = useState<AgentMessage[]>([])
    const [prompt, setPrompt] = useState("")
    const [isLoading, setIsLoading] = useState(true)
    const [isSending, setIsSending] = useState(false)
    const scrollRef = useRef<HTMLDivElement>(null)

    useEffect(() => {
        const initSession = async () => {
            try {
                const data = await ApiClient.aiAgent.createOrGetSession()
                setSession(data)
                setMessages(data.messages || [])
            } catch (err: any) {
                console.error("Failed to init agent session", err)
                toast.error(err.response?.data?.detail || "Erro ao conectar com Agente")
            } finally {
                setIsLoading(false)
            }
        }
        initSession()
    }, [])

    useEffect(() => {
        if (scrollRef.current) {
            scrollRef.current.scrollTop = scrollRef.current.scrollHeight
        }
    }, [messages, isSending])

    const handleSend = async () => {
        if (!prompt.trim() || !session || isSending) return
        
        const userMsg = prompt.trim()
        setPrompt("")
        
        // Optimistic UI
        const fakeMessage: AgentMessage = {
            id: Date.now().toString(),
            session_id: session.id,
            role: "user",
            content: userMsg,
            created_at: new Date().toISOString()
        }
        setMessages(prev => [...prev, fakeMessage])
        setIsSending(true)

        try {
            const responseMsg = await ApiClient.aiAgent.sendMessage(session.id, userMsg)
            setMessages(prev => {
                return [...prev, responseMsg]
            })
            
            // Reload full session just to be safe and ordered
            const updatedSession = await ApiClient.aiAgent.getSession(session.id)
            setMessages(updatedSession.messages || [])
        } catch (err: any) {
            console.error(err)
            toast.error(err.response?.data?.detail || "Erro ao conversar com a IA")
        } finally {
            setIsSending(false)
        }
    }

    const handleAction = async (messageId: string, action: 'approve' | 'reject') => {
        try {
            await ApiClient.aiAgent.executeAction(messageId, action)
            toast.success(action === 'approve' ? "Ação aprovada!" : "Ação rejeitada!")
            // Reload
            if (session) {
                const updatedSession = await ApiClient.aiAgent.getSession(session.id)
                setMessages(updatedSession.messages || [])
            }
        } catch (err: any) {
            console.error(err)
            toast.error(err.response?.data?.detail || "Erro ao processar ação")
        }
    }

    if (isLoading) {
        return (
            <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
                <Loader2 className="h-10 w-10 text-primary animate-spin" />
                <p className="text-zinc-500 font-medium">Conectando ao Agente Pulso...</p>
            </div>
        )
    }

    return (
        <div className="flex flex-col h-[calc(100dvh-8rem)] max-w-4xl mx-auto px-4 sm:px-0">
            {/* Header */}
            <div className="mb-6 flex-none">
                <h1 className="text-2xl sm:text-3xl font-black tracking-tight text-white flex items-center gap-2">
                    <Sparkles className="h-6 sm:h-8 w-6 sm:w-8 text-primary" />
                    Agente Pulso
                </h1>
                <p className="text-zinc-400">Seu assistente virtual para montar treinos e gerenciar alunos.</p>
            </div>

            {/* Chat Box */}
            <Card className="flex flex-col flex-1 bg-zinc-950/50 border-zinc-800 overflow-hidden shadow-xl">
                <ScrollArea className="flex-1 p-4" ref={scrollRef}>
                    <div className="space-y-6 flex flex-col justify-end">
                        {messages.length === 0 ? (
                            <div className="flex flex-col items-center justify-center text-center p-4 sm:p-8 mt-8 sm:mt-10">
                                <div className="bg-zinc-900 p-3 sm:p-4 rounded-full mb-4 ring-1 ring-white/10">
                                    <Bot className="h-8 sm:h-12 w-8 sm:w-12 text-primary" />
                                </div>
                                <h3 className="text-lg sm:text-xl font-bold text-zinc-300">Olá, Treinador!</h3>
                                <p className="text-zinc-500 max-w-xs sm:max-w-sm mt-2 text-xs sm:text-sm px-2">
                                    Me diga o que precisa criar. Exemplo: "Crie uma pasta para o aluno Marcos com treino de inferiores."
                                </p>
                            </div>
                        ) : (
                            messages.map((msg, i) => (
                                <div key={msg.id || i} className={`flex gap-3 max-w-[85%] ${msg.role === 'user' ? 'self-end flex-row-reverse' : 'self-start'}`}>
                                    <div className="flex-shrink-0 mt-1">
                                        {msg.role === 'user' ? (
                                            <div className="h-8 w-8 rounded-full bg-zinc-800 flex items-center justify-center ring-1 ring-white/10">
                                                <UserIcon className="h-4 w-4 text-zinc-400" />
                                            </div>
                                        ) : (
                                            <div className="h-8 w-8 rounded-full bg-primary/20 flex items-center justify-center ring-1 ring-primary/30">
                                                <Bot className="h-4 w-4 text-primary" />
                                            </div>
                                        )}
                                    </div>
                                    <div className={`space-y-2 ${msg.role === 'user' ? 'items-end' : 'items-start'}`}>
                                        {msg.content && (
                                            <div className={`p-3 rounded-2xl text-sm ${msg.role === 'user' ? 'bg-primary text-primary-foreground rounded-tr-sm' : 'bg-zinc-900 border border-zinc-800 text-zinc-200 rounded-tl-sm'}`}>
                                                {msg.content}
                                            </div>
                                        )}
                                        
                                        {/* Tool Call Pending Box */}
                                        {msg.action_status && msg.action_data && (
                                            <Card className={`border ${msg.action_status === AgentActionStatus.PENDING ? 'border-amber-500/50 bg-amber-500/5' : msg.action_status === AgentActionStatus.EXECUTED ? 'border-primary/50 bg-primary/5' : 'border-red-500/50 bg-red-500/5'} w-80 shadow-none`}>
                                                <CardHeader className="p-3 pb-2 flex flex-row items-center justify-between space-y-0">
                                                    <CardTitle className="text-sm font-bold flex items-center gap-2">
                                                        {msg.action_status === AgentActionStatus.PENDING && <span className="text-amber-500 flex items-center"><Loader2 className="h-4 w-4 mr-1 animate-spin"/> Pendente</span>}
                                                        {msg.action_status === AgentActionStatus.EXECUTED && <span className="text-primary flex items-center"><CheckCircle className="h-4 w-4 mr-1"/> Executado</span>}
                                                        {msg.action_status === AgentActionStatus.REJECTED && <span className="text-red-500 flex items-center"><XCircle className="h-4 w-4 mr-1"/> Rejeitado</span>}
                                                    </CardTitle>
                                                </CardHeader>
                                                <CardContent className="p-3 pt-0">
                                                    <div className="space-y-2 flex flex-col text-xs text-zinc-400">
                                                        {(msg.action_data.type === 'batch' ? (msg.action_data.actions ?? []) : [msg.action_data]).map((action: any, aIdx: number) => (
                                                            <div key={aIdx} className="bg-zinc-950 p-2 rounded border border-zinc-800">
                                                                <span className="font-bold text-zinc-300">Ação:</span> {action.type}
                                                                {action.payload?.workout_name && <div>• Treino: {action.payload.workout_name}</div>}
                                                                {action.payload?.folder_name && <div>• Pasta: {action.payload.folder_name}</div>}
                                                            </div>
                                                        ))}
                                                    </div>
                                                </CardContent>
                                                {msg.action_status === AgentActionStatus.PENDING && (
                                                    <CardFooter className="p-3 pt-0 flex gap-2">
                                                        <Button variant="outline" size="sm" className="flex-1 text-red-400 border-red-900/50 hover:bg-red-950/30" onClick={() => handleAction(msg.id, 'reject')}>Rejeitar</Button>
                                                        <Button size="sm" className="flex-1 bg-amber-500 hover:bg-amber-600 text-amber-950 font-bold" onClick={() => handleAction(msg.id, 'approve')}>Permitir</Button>
                                                    </CardFooter>
                                                )}
                                            </Card>
                                        )}
                                    </div>
                                </div>
                            ))
                        )}
                        {isSending && (
                             <div className={`flex gap-3 max-w-[85%] self-start`}>
                                <div className="flex-shrink-0 mt-1">
                                    <div className="h-8 w-8 rounded-full bg-primary/20 flex items-center justify-center ring-1 ring-primary/30">
                                        <Bot className="h-4 w-4 text-primary animate-pulse" />
                                    </div>
                                </div>
                                <div className="bg-zinc-900 border border-zinc-800 p-3 rounded-2xl rounded-tl-sm text-sm text-zinc-400">
                                    <span className="animate-pulse">Digitando...</span>
                                </div>
                            </div>
                        )}
                    </div>
                </ScrollArea>
                <div className="p-4 bg-zinc-900 border-t border-zinc-800 flex items-center gap-2">
                    <Input
                        placeholder="Ex: Crie um treino de Costas..."
                        className="flex-1 bg-zinc-950 border-zinc-800 h-10 sm:h-12"
                        value={prompt}
                        onChange={(e) => setPrompt(e.target.value)}
                        onKeyDown={(e) => {
                            if (e.key === 'Enter' && !e.shiftKey) {
                                e.preventDefault();
                                handleSend();
                            }
                        }}
                        disabled={isSending}
                    />
                    <Button
                        size="icon"
                        className="h-10 sm:h-12 w-10 sm:w-12 rounded-xl bg-primary text-primary-foreground shrink-0"
                        onClick={handleSend}
                        disabled={isSending || !prompt.trim()}
                    >
                        <Send className="h-4 sm:h-5 w-4 sm:w-5" />
                    </Button>
                </div>
            </Card>
        </div>
    )
}
