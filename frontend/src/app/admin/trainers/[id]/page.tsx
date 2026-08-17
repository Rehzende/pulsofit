"use client"

import { useEffect, useState } from "react"
import { useRouter, useParams } from "next/navigation"
import { ApiClient, User, SubscriptionPlan } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import {
    ArrowLeft, Save, User2, Mail, CreditCard, Calendar,
    CheckCircle2, Sparkles, Users, Zap, Shield, Clock
} from "lucide-react"
import Link from "next/link"
import { toast } from "sonner"

const SUBSCRIPTION_STATUS_MAP: Record<string, { label: string; color: string }> = {
    ACTIVE: { label: "Ativo", color: "text-emerald-400 bg-emerald-400/10 border-emerald-400/30" },
    TRIAL: { label: "Trial", color: "text-amber-400 bg-amber-400/10 border-amber-400/30" },
    INACTIVE: { label: "Inativo", color: "text-red-400 bg-red-400/10 border-red-400/30" },
}

export default function TrainerDetailPage() {
    const router = useRouter()
    const params = useParams()
    const id = params.id as string

    const [trainer, setTrainer] = useState<User | null>(null)
    const [plans, setPlans] = useState<SubscriptionPlan[]>([])
    const [isLoading, setIsLoading] = useState(true)
    const [isSaving, setIsSaving] = useState(false)
    const [formData, setFormData] = useState({
        full_name: "",
        subscription_status: "TRIAL",
        subscription_end_date: "",
        plan_id: "",
    })

    useEffect(() => {
        const fetchData = async () => {
            try {
                const [trainerData, plansData] = await Promise.all([
                    ApiClient.admin.getTrainer(id),
                    ApiClient.admin.getPlans(),
                ])
                setTrainer(trainerData)
                setPlans(plansData)
                setFormData({
                    full_name: trainerData.full_name || "",
                    subscription_status: trainerData.subscription_status || "TRIAL",
                    subscription_end_date: trainerData.subscription_end_date
                        ? new Date(trainerData.subscription_end_date).toISOString().split("T")[0]
                        : "",
                    plan_id: trainerData.plan_id || "",
                })
            } catch (error) {
                console.error("Failed to fetch data", error)
            } finally {
                setIsLoading(false)
            }
        }
        fetchData()
    }, [id])

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setIsSaving(true)
        try {
            // Update basic info and subscription status/date
            await ApiClient.admin.updateTrainer(id, {
                full_name: formData.full_name,
                subscription_status: formData.subscription_status,
                subscription_end_date: formData.subscription_end_date
                    ? new Date(formData.subscription_end_date).toISOString()
                    : null,
            })

            // If plan changed, use the dedicated endpoint that syncs features
            if (formData.plan_id && formData.plan_id !== trainer?.plan_id) {
                await ApiClient.admin.assignTrainerPlan(id, formData.plan_id)
            } else if (!formData.plan_id && trainer?.plan_id) {
                // Plan was cleared — update plan_id to null directly
                await ApiClient.admin.updateTrainer(id, { plan_id: null })
            }

            toast.success("Dados do trainer atualizados com sucesso!")
            // Refresh trainer data to reflect new state
            const updated = await ApiClient.admin.getTrainer(id)
            setTrainer(updated)
            setFormData(prev => ({ ...prev, plan_id: updated.plan_id || "" }))
        } catch (error) {
            toast.error("Erro ao salvar. Tente novamente.")
        } finally {
            setIsSaving(false)
        }
    }

    const handlePlanSelect = (planId: string) => {
        setFormData(prev => ({ ...prev, plan_id: planId }))
    }

    if (isLoading) {
        return (
            <div className="min-h-screen flex items-center justify-center">
                <div className="flex flex-col items-center gap-4">
                    <div className="h-10 w-10 rounded-full border-2 border-primary border-t-transparent animate-spin" />
                    <p className="text-muted-foreground text-sm">Carregando trainer...</p>
                </div>
            </div>
        )
    }

    if (!trainer) {
        return (
            <div className="flex flex-col items-center justify-center gap-4 py-20">
                <p className="text-muted-foreground">Trainer não encontrado.</p>
                <Link href="/admin/trainers"><Button variant="outline">Voltar</Button></Link>
            </div>
        )
    }

    const currentPlan = plans.find(p => p.id === formData.plan_id)
    const statusInfo = SUBSCRIPTION_STATUS_MAP[formData.subscription_status] ?? SUBSCRIPTION_STATUS_MAP["TRIAL"]

    const getPlanIcon = (plan: SubscriptionPlan) => {
        const price = Number(plan.price)
        if (price === 0) return <Sparkles className="h-5 w-5" />
        if (price < 100) return <Zap className="h-5 w-5" />
        return <Shield className="h-5 w-5" />
    }

    return (
        <div className="flex flex-col gap-6">
            {/* Header */}
            <div className="flex items-center gap-4">
                <Link href="/admin/trainers">
                    <Button variant="ghost" size="icon" className="rounded-full hover:bg-primary/10">
                        <ArrowLeft className="h-4 w-4" />
                    </Button>
                </Link>
                <div>
                    <h1 className="text-2xl font-bold tracking-tight">Perfil do Trainer</h1>
                    <p className="text-sm text-muted-foreground">{trainer.email}</p>
                </div>
            </div>

            {/* Trainer Identity Card */}
            <div className="relative overflow-hidden rounded-2xl border border-primary/20 bg-gradient-to-br from-primary/10 via-background to-background p-6">
                <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_left,_var(--tw-gradient-stops))] from-primary/15 to-transparent pointer-events-none" />
                <div className="relative z-10 flex items-start gap-4">
                    <div className="h-16 w-16 rounded-2xl bg-primary/20 flex items-center justify-center text-2xl font-bold text-primary flex-shrink-0">
                        {(trainer.full_name || trainer.email).charAt(0).toUpperCase()}
                    </div>
                    <div className="flex-1 min-w-0">
                        <h2 className="text-xl font-bold text-foreground truncate">
                            {trainer.full_name || trainer.email.split("@")[0]}
                        </h2>
                        <p className="text-sm text-muted-foreground">{trainer.email}</p>
                        <div className="flex items-center gap-3 mt-3 flex-wrap">
                            <Badge className={`text-xs border ${statusInfo.color}`}>
                                {statusInfo.label}
                            </Badge>
                            {currentPlan && (
                                <Badge variant="outline" className="text-xs border-primary/30 text-primary bg-primary/5">
                                    {currentPlan.name}
                                </Badge>
                            )}
                            <span className="text-xs text-muted-foreground flex items-center gap-1">
                                <Users className="h-3 w-3" />
                                {currentPlan ? `${currentPlan.max_students} alunos máx.` : "Sem plano"}
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            <form onSubmit={handleSubmit} className="grid gap-6 lg:grid-cols-5">
                {/* Left: Info & Subscription */}
                <div className="lg:col-span-2 flex flex-col gap-6">
                    <Card className="bg-card border-border/50">
                        <CardHeader>
                            <CardTitle className="text-base flex items-center gap-2">
                                <User2 className="h-4 w-4 text-primary" />
                                Informações Pessoais
                            </CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            <div className="space-y-2">
                                <Label htmlFor="email" className="text-xs text-muted-foreground uppercase tracking-wide">Email</Label>
                                <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-muted/50 border border-border/30">
                                    <Mail className="h-4 w-4 text-muted-foreground flex-shrink-0" />
                                    <span className="text-sm truncate">{trainer.email}</span>
                                </div>
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="full_name" className="text-xs text-muted-foreground uppercase tracking-wide">Nome Completo</Label>
                                <Input
                                    id="full_name"
                                    value={formData.full_name}
                                    onChange={(e) => setFormData({ ...formData, full_name: e.target.value })}
                                    placeholder="Nome do trainer"
                                />
                            </div>
                        </CardContent>
                    </Card>

                    <Card className="bg-card border-border/50">
                        <CardHeader>
                            <CardTitle className="text-base flex items-center gap-2">
                                <CreditCard className="h-4 w-4 text-primary" />
                                Assinatura
                            </CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            <div className="space-y-2">
                                <Label className="text-xs text-muted-foreground uppercase tracking-wide">Status</Label>
                                <Select
                                    value={formData.subscription_status}
                                    onValueChange={(v) => setFormData({ ...formData, subscription_status: v })}
                                >
                                    <SelectTrigger>
                                        <SelectValue />
                                    </SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="ACTIVE">✅ Ativo</SelectItem>
                                        <SelectItem value="TRIAL">⏳ Trial</SelectItem>
                                        <SelectItem value="INACTIVE">❌ Inativo</SelectItem>
                                    </SelectContent>
                                </Select>
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="end_date" className="text-xs text-muted-foreground uppercase tracking-wide flex items-center gap-1">
                                    <Calendar className="h-3 w-3" />
                                    Validade
                                </Label>
                                <Input
                                    id="end_date"
                                    type="date"
                                    value={formData.subscription_end_date}
                                    onChange={(e) => setFormData({ ...formData, subscription_end_date: e.target.value })}
                                />
                            </div>
                        </CardContent>
                    </Card>

                    <Button type="submit" disabled={isSaving} className="h-12 bg-primary hover:bg-primary/90 text-primary-foreground shadow-md shadow-primary/20 w-full">
                        {isSaving ? (
                            <><div className="h-4 w-4 border-2 border-primary-foreground/30 border-t-primary-foreground rounded-full animate-spin mr-2" />Salvando...</>
                        ) : (
                            <><Save className="mr-2 h-4 w-4" />Salvar Alterações</>
                        )}
                    </Button>
                </div>

                {/* Right: Plan Selection */}
                <div className="lg:col-span-3">
                    <Card className="bg-card border-border/50 h-full">
                        <CardHeader>
                            <CardTitle className="text-base flex items-center gap-2">
                                <Sparkles className="h-4 w-4 text-primary" />
                                Selecionar Plano
                            </CardTitle>
                            <CardDescription>
                                Escolha o plano de assinatura para este trainer.
                            </CardDescription>
                        </CardHeader>
                        <CardContent>
                            <div className="grid gap-3 sm:grid-cols-2">
                                {/* No Plan Option */}
                                <button
                                    type="button"
                                    onClick={() => handlePlanSelect("")}
                                    className={`p-4 rounded-xl border-2 text-left transition-all duration-200 ${!formData.plan_id
                                            ? "border-primary bg-primary/5"
                                            : "border-border/30 bg-muted/30 hover:border-border"
                                        }`}
                                >
                                    <div className="flex items-center justify-between mb-2">
                                        <div className={`h-8 w-8 rounded-lg flex items-center justify-center ${!formData.plan_id ? "bg-primary/20 text-primary" : "bg-muted text-muted-foreground"}`}>
                                            <Clock className="h-4 w-4" />
                                        </div>
                                        {!formData.plan_id && <CheckCircle2 className="h-4 w-4 text-primary" />}
                                    </div>
                                    <h3 className={`font-semibold text-sm ${!formData.plan_id ? "text-primary" : "text-foreground"}`}>
                                        Sem Plano
                                    </h3>
                                    <p className="text-xs text-muted-foreground mt-1">Acesso restrito</p>
                                </button>

                                {plans.map((plan) => {
                                    const isSelected = formData.plan_id === plan.id
                                    const price = Number(plan.price)
                                    return (
                                        <button
                                            key={plan.id}
                                            type="button"
                                            onClick={() => handlePlanSelect(plan.id)}
                                            className={`p-4 rounded-xl border-2 text-left transition-all duration-200 ${isSelected
                                                    ? "border-primary bg-primary/5"
                                                    : "border-border/30 bg-muted/30 hover:border-border"
                                                }`}
                                        >
                                            <div className="flex items-center justify-between mb-2">
                                                <div className={`h-8 w-8 rounded-lg flex items-center justify-center ${isSelected ? "bg-primary/20 text-primary" : "bg-muted text-muted-foreground"}`}>
                                                    {getPlanIcon(plan)}
                                                </div>
                                                {isSelected && <CheckCircle2 className="h-4 w-4 text-primary" />}
                                            </div>
                                            <h3 className={`font-bold text-sm ${isSelected ? "text-primary" : "text-foreground"}`}>
                                                {plan.name}
                                            </h3>
                                            <div className="flex items-center justify-between mt-2">
                                                <span className="text-lg font-black text-foreground">
                                                    {price === 0 ? "Grátis" : `R$ ${price.toFixed(2)}`}
                                                </span>
                                                <span className="text-xs text-muted-foreground bg-muted px-2 py-1 rounded-md">
                                                    {plan.max_students} alunos
                                                </span>
                                            </div>
                                            {plan.features && Object.keys(plan.features).length > 0 && (
                                                <div className="mt-3 space-y-1">
                                                    {Object.entries(plan.features).slice(0, 3).map(([key, val]) => (
                                                        <div key={key} className="flex items-center gap-1.5">
                                                            <div className={`h-1.5 w-1.5 rounded-full ${val ? "bg-primary" : "bg-muted-foreground"}`} />
                                                            <span className="text-xs text-muted-foreground capitalize">
                                                                {key.replace(/_/g, " ")}
                                                            </span>
                                                        </div>
                                                    ))}
                                                </div>
                                            )}
                                        </button>
                                    )
                                })}
                            </div>
                        </CardContent>
                    </Card>
                </div>
            </form>
        </div>
    )
}
