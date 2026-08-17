"use client"

import { useEffect, useState } from "react"
import { ApiClient, SubscriptionPlan } from "@/lib/api"
import { Button }   from "@/components/ui/button"
import { Input }    from "@/components/ui/input"
import { Label }    from "@/components/ui/label"
import { Switch }   from "@/components/ui/switch"
import { Badge }    from "@/components/ui/badge"
import { toast }    from "sonner"
import {
    Dialog, DialogContent, DialogHeader,
    DialogTitle, DialogFooter,
} from "@/components/ui/dialog"
import { Plus, Pencil, Sparkles, Wifi, Users, CreditCard, ArrowUpRight } from "lucide-react"

function SkeletonCard() {
    return (
        <div className="bg-card/50 border border-border/40 rounded-xl p-5 animate-pulse">
            <div className="h-3 w-16 rounded bg-muted mb-4" />
            <div className="h-8 w-20 rounded bg-muted mb-2" />
            <div className="h-3 w-28 rounded bg-muted mb-4" />
            <div className="flex gap-2">
                <div className="h-5 w-16 rounded-full bg-muted" />
                <div className="h-5 w-10 rounded-full bg-muted" />
            </div>
        </div>
    )
}

const EMPTY_FORM = {
    name: "",
    price: "",
    max_students: "",
    features: { ai_workouts: false, iot_enabled: false },
}

export default function PlansPage() {
    const [plans, setPlans]           = useState<SubscriptionPlan[]>([])
    const [isLoading, setIsLoading]   = useState(true)
    const [isDialogOpen, setIsDialogOpen] = useState(false)
    const [isSaving, setIsSaving]     = useState(false)
    const [editingPlan, setEditingPlan] = useState<SubscriptionPlan | null>(null)
    const [formData, setFormData]     = useState(EMPTY_FORM)

    const fetchPlans = async () => {
        try {
            const data = await ApiClient.admin.getPlans()
            setPlans(data)
        } catch {
            toast.error("Erro ao carregar planos")
        } finally {
            setIsLoading(false)
        }
    }

    useEffect(() => { fetchPlans() }, [])

    const openDialog = (plan?: SubscriptionPlan) => {
        if (plan) {
            setEditingPlan(plan)
            setFormData({
                name: plan.name,
                price: plan.price.toString(),
                max_students: plan.max_students.toString(),
                features: {
                    ai_workouts: plan.features?.ai_workouts ?? false,
                    iot_enabled: plan.features?.iot_enabled ?? false,
                },
            })
        } else {
            setEditingPlan(null)
            setFormData(EMPTY_FORM)
        }
        setIsDialogOpen(true)
    }

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setIsSaving(true)
        try {
            const payload = {
                name: formData.name,
                price: parseFloat(formData.price),
                max_students: parseInt(formData.max_students),
                features: formData.features,
            }
            if (editingPlan) {
                await ApiClient.admin.updatePlan(editingPlan.id, payload)
                toast.success(`Plano "${formData.name}" atualizado`)
            } else {
                await ApiClient.admin.createPlan(payload)
                toast.success(`Plano "${formData.name}" criado`)
            }
            setIsDialogOpen(false)
            fetchPlans()
        } catch {
            toast.error("Erro ao salvar plano. Tente novamente.")
        } finally {
            setIsSaving(false)
        }
    }

    const setFeature = (key: keyof typeof formData.features, val: boolean) =>
        setFormData((prev) => ({ ...prev, features: { ...prev.features, [key]: val } }))

    return (
        <div className="flex flex-col gap-8 animate-in fade-in duration-500">

            {/* Header */}
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div>
                    <h1 className="text-3xl font-black tracking-tight text-foreground">Planos</h1>
                    <p className="text-muted-foreground text-sm mt-1">
                        Defina features por plano. Ao atribuir um plano a um trainer, as features são sincronizadas automaticamente.
                    </p>
                </div>
                <Button
                    onClick={() => openDialog()}
                    className="bg-primary text-primary-foreground hover:bg-primary/90 font-bold shadow-lg shadow-primary/20"
                >
                    <Plus className="mr-2 h-4 w-4" /> Criar Plano
                </Button>
            </div>

            {/* Plan cards */}
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {isLoading ? (
                    Array.from({ length: 3 }).map((_, i) => <SkeletonCard key={i} />)
                ) : plans.length === 0 ? (
                    <div className="sm:col-span-2 lg:col-span-3 flex flex-col items-center justify-center py-20 gap-3 text-muted-foreground">
                        <div className="h-14 w-14 rounded-full bg-muted flex items-center justify-center">
                            <CreditCard className="h-6 w-6" />
                        </div>
                        <p className="font-bold text-foreground">Nenhum plano criado</p>
                        <p className="text-sm">Crie o primeiro plano usando o botão acima.</p>
                    </div>
                ) : (
                    plans.map((plan) => (
                        <div
                            key={plan.id}
                            className="group bg-card/50 border border-border/40 rounded-xl p-5 hover:bg-card/80 hover:border-border/60 transition-all duration-200"
                        >
                            <div className="flex items-start justify-between mb-4">
                                <div>
                                    <p className="text-xs font-bold text-muted-foreground uppercase tracking-widest mb-1">Plano</p>
                                    <p className="text-xl font-black text-foreground">{plan.name}</p>
                                </div>
                                <Button
                                    variant="ghost" size="icon"
                                    className="h-8 w-8 opacity-0 group-hover:opacity-100 transition-opacity text-muted-foreground hover:text-foreground"
                                    onClick={() => openDialog(plan)}
                                >
                                    <Pencil className="h-3.5 w-3.5" />
                                </Button>
                            </div>

                            <p className="text-3xl font-black text-foreground mb-1">
                                R$ {Number(plan.price).toFixed(2)}
                                <span className="text-sm font-normal text-muted-foreground">/mês</span>
                            </p>

                            <div className="flex items-center gap-1.5 text-sm text-muted-foreground mb-4">
                                <Users className="h-3.5 w-3.5" />
                                <span>Até {plan.max_students} alunos</span>
                            </div>

                            <div className="flex flex-wrap gap-2 pt-4 border-t border-border/40">
                                {plan.features?.ai_workouts && (
                                    <Badge className="bg-primary/10 text-primary border-primary/20 font-bold text-xs gap-1">
                                        <Sparkles className="h-3 w-3" /> IA Treinos
                                    </Badge>
                                )}
                                {plan.features?.iot_enabled && (
                                    <Badge className="bg-cyan-500/10 text-cyan-400 border-cyan-500/20 font-bold text-xs gap-1">
                                        <Wifi className="h-3 w-3" /> IoT
                                    </Badge>
                                )}
                                {!plan.features?.ai_workouts && !plan.features?.iot_enabled && (
                                    <span className="text-xs text-muted-foreground">Funcionalidades básicas</span>
                                )}
                            </div>
                        </div>
                    ))
                )}
            </div>

            {/* Dialog create/edit */}
            <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
                <DialogContent className="sm:max-w-[440px]">
                    <DialogHeader>
                        <DialogTitle>{editingPlan ? "Editar Plano" : "Criar Plano"}</DialogTitle>
                    </DialogHeader>
                    <form onSubmit={handleSubmit} className="flex flex-col gap-5 py-2">
                        <div className="flex flex-col gap-1.5">
                            <Label htmlFor="plan-name">Nome do plano</Label>
                            <Input
                                id="plan-name"
                                placeholder="Ex: Pro, Premium, Free"
                                value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                required
                            />
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                            <div className="flex flex-col gap-1.5">
                                <Label htmlFor="plan-price">Preço (R$)</Label>
                                <Input
                                    id="plan-price"
                                    type="number" step="0.01" min="0"
                                    placeholder="0.00"
                                    value={formData.price}
                                    onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                                    required
                                />
                            </div>
                            <div className="flex flex-col gap-1.5">
                                <Label htmlFor="plan-max">Máx. alunos</Label>
                                <Input
                                    id="plan-max"
                                    type="number" min="1"
                                    placeholder="50"
                                    value={formData.max_students}
                                    onChange={(e) => setFormData({ ...formData, max_students: e.target.value })}
                                    required
                                />
                            </div>
                        </div>

                        {/* Features */}
                        <div className="flex flex-col gap-3 border border-border/40 rounded-xl p-4 bg-card/30">
                            <p className="text-sm font-bold text-foreground">Features do plano</p>

                            <div className="flex items-center justify-between">
                                <div className="flex items-center gap-3">
                                    <div className="h-8 w-8 rounded-lg bg-primary/15 flex items-center justify-center">
                                        <Sparkles className="h-4 w-4 text-primary" />
                                    </div>
                                    <div>
                                        <p className="text-sm font-semibold text-foreground">IA Treinos</p>
                                        <p className="text-xs text-muted-foreground">Geração com Claude AI</p>
                                    </div>
                                </div>
                                <Switch
                                    checked={formData.features.ai_workouts}
                                    onCheckedChange={(v) => setFeature("ai_workouts", v)}
                                    className="data-[state=checked]:bg-primary"
                                />
                            </div>

                            <div className="flex items-center justify-between">
                                <div className="flex items-center gap-3">
                                    <div className="h-8 w-8 rounded-lg bg-cyan-500/15 flex items-center justify-center">
                                        <Wifi className="h-4 w-4 text-cyan-400" />
                                    </div>
                                    <div>
                                        <p className="text-sm font-semibold text-foreground">IoT / Frequência Cardíaca</p>
                                        <p className="text-xs text-muted-foreground">Integração BLE</p>
                                    </div>
                                </div>
                                <Switch
                                    checked={formData.features.iot_enabled}
                                    onCheckedChange={(v) => setFeature("iot_enabled", v)}
                                    className="data-[state=checked]:bg-cyan-500"
                                />
                            </div>
                        </div>

                        <DialogFooter>
                            <Button type="button" variant="outline" onClick={() => setIsDialogOpen(false)} disabled={isSaving}>
                                Cancelar
                            </Button>
                            <Button
                                type="submit"
                                disabled={isSaving}
                                className="bg-primary text-primary-foreground hover:bg-primary/90 font-bold"
                            >
                                {isSaving ? "Salvando..." : editingPlan ? "Salvar Alterações" : "Criar Plano"}
                            </Button>
                        </DialogFooter>
                    </form>
                </DialogContent>
            </Dialog>
        </div>
    )
}
