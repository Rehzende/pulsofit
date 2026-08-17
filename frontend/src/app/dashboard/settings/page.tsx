"use client"

// Feature flag: when true, trainers can switch plans themselves via the portal.
// Currently false — plan changes are made by admin only.
// Will be enabled when payment integration is implemented.
const PLAN_SELF_SERVICE_ENABLED = false

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { ApiClient, User, SubscriptionPlan } from "@/lib/api"
import { toast } from "sonner"
import { CreditCard, Globe, Copy, ExternalLink, Store, Upload, Check, Palette, Lock } from "lucide-react"

export default function SettingsPage() {
    const router = useRouter()
    const [user, setUser] = useState<User | null>(null)
    const [isLoading, setIsLoading] = useState(true)
    const [isSaving, setIsSaving] = useState(false)
    const [isUploading, setIsUploading] = useState(false)
    const [logoPreview, setLogoPreview] = useState<string | null>(null)
    const [plans, setPlans] = useState<SubscriptionPlan[]>([])
    const [isChangingPlan, setIsChangingPlan] = useState(false)
    const [plansLoading, setPlansLoading] = useState(false)
    const [activeTab, setActiveTab] = useState('branding')

    // Student fields
    const [studentData, setStudentData] = useState({
        full_name: "",
        birthday: "",
        whatsapp_number: "",
        photo_url: "",
    })

    // Trainer fields
    const [trainerData, setTrainerData] = useState({
        slug: "",
        brand_name: "",
        primary_color: "#3b82f6",
        logo_url: "",
        photo_url: "",
        whatsapp_number: "",
        is_available_for_hire: false,
        modality: "" as "" | "presencial" | "online" | "hibrido",
        specialties: [] as string[],
        gyms: [] as string[],
    })
    const [photoPreview, setPhotoPreview] = useState<string | null>(null)
    const [slugError, setSlugError] = useState("")

    useEffect(() => {
        const fetchProfile = async () => {
            try {
                const userData = await ApiClient.getMe()
                setUser(userData)

                if (userData.role === 'STUDENT') {
                    setStudentData({
                        full_name: userData.full_name || "",
                        birthday: userData.birthday ? new Date(userData.birthday).toISOString().split('T')[0] : "",
                        whatsapp_number: userData.whatsapp_number || "",
                        photo_url: userData.photo_url || "",
                    })
                    if (userData.photo_url) {
                        setLogoPreview(userData.photo_url.startsWith('http') ? userData.photo_url : `https://web-production-06662.up.railway.app/${userData.photo_url}`)
                    }
                } else if (userData.role === 'TRAINER') {
                    if (userData.trainer_profile) {
                        setTrainerData({
                            slug: userData.trainer_profile.slug || "",
                            brand_name: userData.trainer_profile.brand_name || "",
                            primary_color: userData.trainer_profile.primary_color || "#3b82f6",
                            logo_url: userData.trainer_profile.logo_url || "",
                            photo_url: userData.photo_url || "",
                            whatsapp_number: userData.trainer_profile.whatsapp_number || "",
                            is_available_for_hire: userData.trainer_profile.is_available_for_hire ?? false,
                            modality: (userData.trainer_profile.modality || "") as "" | "presencial" | "online" | "hibrido",
                            specialties: Array.isArray(userData.trainer_profile.specialties) ? userData.trainer_profile.specialties : [],
                            gyms: Array.isArray(userData.trainer_profile.gyms) ? userData.trainer_profile.gyms : [],
                        })
                        if (userData.trainer_profile.logo_url) {
                            const logoUrl = userData.trainer_profile.logo_url
                            setLogoPreview(logoUrl.startsWith('http') ? logoUrl : `https://web-production-06662.up.railway.app/${logoUrl}`)
                        }
                        if (userData.photo_url) {
                            const photoUrl = userData.photo_url
                            setPhotoPreview(photoUrl.startsWith('http') ? photoUrl : `https://web-production-06662.up.railway.app/${photoUrl}`)
                        }
                    }
                    // Fetch available plans for self-service plan switching
                    setPlansLoading(true)
                    try {
                        const plansData = await ApiClient.getPublicPlans()
                        setPlans(plansData)
                    } catch (_) {
                        // Plans may not be available yet — fail silently
                    } finally {
                        setPlansLoading(false)
                    }
                }
            } catch (error) {
                console.error("Failed to fetch profile", error)
            } finally {
                setIsLoading(false)
            }
        }

        fetchProfile()
    }, [router])

    const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>, imageType: 'avatar' | 'logo' = 'logo') => {
        const file = e.target.files?.[0]
        if (!file) return

        const reader = new FileReader()
        reader.onloadend = () => {
            if (imageType === 'avatar' || user?.role === 'STUDENT') {
                setPhotoPreview(reader.result as string)
            } else {
                setLogoPreview(reader.result as string)
            }
        }
        reader.readAsDataURL(file)

        setIsUploading(true)
        try {
            const uploadType = user?.role === 'STUDENT' ? 'avatar' : imageType
            const result = await ApiClient.trainer.uploadLogo(file, uploadType)

            if (user?.role === 'STUDENT') {
                setStudentData(prev => ({ ...prev, photo_url: result.logo_url }))
            } else if (imageType === 'avatar') {
                setTrainerData(prev => ({ ...prev, photo_url: result.logo_url }))
            } else {
                setTrainerData(prev => ({ ...prev, logo_url: result.logo_url }))
            }
            toast.success("Upload realizado com sucesso!")
        } catch (error) {
            toast.error("Erro ao enviar arquivo")
            if (imageType === 'avatar') {
                setPhotoPreview(null)
            } else {
                setLogoPreview(null)
            }
        } finally {
            setIsUploading(false)
        }
    }

    const handleChangePlan = async (planId: string) => {
        if (planId === user?.plan_id) return
        setIsChangingPlan(true)
        try {
            await ApiClient.requestPlanChange(planId)
            toast.success("Plano alterado com sucesso! 🎉")
            const updatedUser = await ApiClient.getMe()
            setUser(updatedUser)
        } catch (error) {
            toast.error("Erro ao trocar plano. Tente novamente.")
        } finally {
            setIsChangingPlan(false)
        }
    }

    const handleStudentSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setIsSaving(true)
        try {
            await ApiClient.updateMe({
                full_name: studentData.full_name,
                birthday: studentData.birthday ? new Date(studentData.birthday).toISOString() : undefined,
                whatsapp_number: studentData.whatsapp_number,
                photo_url: studentData.photo_url
            })

            toast.success("Configurações salvas com sucesso!")
            const updatedUser = await ApiClient.getMe()
            setUser(updatedUser)
            setStudentData({
                full_name: updatedUser.full_name || "",
                birthday: updatedUser.birthday ? new Date(updatedUser.birthday).toISOString().split('T')[0] : "",
                whatsapp_number: updatedUser.whatsapp_number || "",
                photo_url: updatedUser.photo_url || "",
            })
        } catch (error) {
            console.error("Failed to update profile", error)
            toast.error("Erro ao salvar configurações")
        } finally {
            setIsSaving(false)
        }
    }

    const handleTrainerSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        if (slugError) return
        setIsSaving(true)
        try {
            await ApiClient.trainer.updateProfile(trainerData)
            toast.success("Configurações salvas com sucesso!")
        } catch (error: any) {
            const detail = error?.response?.data?.detail
            const detailStr = typeof detail === 'string' ? detail : JSON.stringify(detail ?? '')
            if (detailStr.toLowerCase().includes('slug')) {
                setSlugError('Este slug já está em uso. Escolha outro.')
            } else {
                toast.error("Erro ao salvar configurações")
            }
        } finally {
            setIsSaving(false)
        }
    }

    if (isLoading) {
        return <div className="flex items-center justify-center h-dvh">Carregando...</div>
    }

    if (!user) {
        return <div>Erro ao carregar usuário</div>
    }

    // Student Settings
    if (user.role === 'STUDENT') {
        return (
            <div className="flex flex-col gap-4 px-0 sm:gap-6">
                {/* Hero Section */}
                <div className="relative overflow-hidden rounded-lg bg-gradient-to-br from-blue-600 via-purple-600 to-cyan-500 p-5 sm:p-8 text-white">
                    <div className="relative z-10">
                        <h1 className="text-2xl sm:text-4xl font-bold mb-1 sm:mb-2">Configurações ⚙️</h1>
                        <p className="text-sm sm:text-lg opacity-90">Personalize seu perfil</p>
                    </div>
                    <div className="absolute top-0 right-0 w-48 h-48 sm:w-64 sm:h-64 bg-white/10 rounded-full blur-3xl"></div>
                </div>

                <Card>
                    <CardHeader className="pb-3">
                        <CardTitle className="text-base sm:text-lg">Informações Pessoais</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <form onSubmit={handleStudentSubmit} className="space-y-4 sm:space-y-6">
                            <div className="space-y-2">
                                <Label htmlFor="full_name">Nome Completo</Label>
                                <Input
                                    id="full_name"
                                    value={studentData.full_name}
                                    onChange={(e) => setStudentData({ ...studentData, full_name: e.target.value })}
                                    placeholder="Seu nome completo"
                                />
                            </div>

                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                <div className="space-y-2">
                                    <Label htmlFor="birthday">Data de Nascimento</Label>
                                    <Input
                                        id="birthday"
                                        type="date"
                                        value={studentData.birthday}
                                        onChange={(e) => setStudentData({ ...studentData, birthday: e.target.value })}
                                    />
                                </div>
                                <div className="space-y-2">
                                    <Label htmlFor="whatsapp">WhatsApp</Label>
                                    <Input
                                        id="whatsapp"
                                        value={studentData.whatsapp_number}
                                        onChange={(e) => setStudentData({ ...studentData, whatsapp_number: e.target.value })}
                                        placeholder="+55..."
                                    />
                                </div>
                            </div>

                            <div className="space-y-2">
                                <Label htmlFor="photo">Foto de Perfil</Label>
                                {logoPreview && (
                                    <div className="mb-3">
                                        <img
                                            src={logoPreview}
                                            alt="Profile preview"
                                            className="w-20 h-20 sm:w-24 sm:h-24 rounded-full border object-cover"
                                        />
                                    </div>
                                )}
                                <Input
                                    id="photo"
                                    type="file"
                                    accept="image/*"
                                    onChange={handleFileChange}
                                    disabled={isUploading}
                                />
                                {isUploading && <p className="text-sm text-muted-foreground">Enviando...</p>}
                            </div>

                            <div className="space-y-2">
                                <Label htmlFor="email">Email</Label>
                                <Input
                                    id="email"
                                    value={user.email}
                                    disabled
                                    className="bg-muted"
                                />
                                <p className="text-xs text-muted-foreground">O email não pode ser alterado</p>
                            </div>

                            <Button type="submit" disabled={isSaving} className="w-full sm:w-auto bg-gradient-to-r from-blue-500 to-purple-600 hover:from-blue-600 hover:to-purple-700">
                                {isSaving ? "Salvando..." : "Salvar Alterações"}
                            </Button>
                        </form>
                    </CardContent>
                </Card>
            </div>
        )
    }

    // Trainer Settings
    return (
        <div className="flex flex-col gap-4 sm:gap-6">
            {/* Hero Section */}
            <div className="relative overflow-hidden rounded-xl bg-gradient-to-br from-zinc-900 via-black to-zinc-900 border border-zinc-800 p-5 sm:p-8 text-white">
                <div className="relative z-10">
                    <h1 className="text-2xl sm:text-4xl font-black mb-1 sm:mb-2 tracking-tight">Configurações <span className="text-primary">⚙️</span></h1>
                    <p className="text-sm sm:text-lg text-zinc-400">Gerencie sua marca, cobranças e vitrine pública.</p>
                </div>
                <div className="absolute top-0 right-0 w-48 h-48 sm:w-64 sm:h-64 bg-primary/10 rounded-full blur-[100px]"></div>
            </div>

            {/* Custom Tabs */}
            <div className="flex space-x-1 sm:space-x-2 border-b border-zinc-800 pb-px overflow-x-auto scrollbar-hide">
                {[
                    { id: 'branding', label: 'Marca & Perfil', icon: Palette },
                    { id: 'marketplace', label: 'Marketplace', icon: Store },
                    { id: 'subscription', label: 'Assinatura', icon: CreditCard }
                ].map((tab) => (
                    <button
                        key={tab.id}
                        onClick={() => setActiveTab(tab.id)}
                        className={`flex items-center gap-1 sm:gap-2 px-2 sm:px-4 py-3 text-xs sm:text-sm font-bold transition-all border-b-2 whitespace-nowrap ${activeTab === tab.id
                            ? 'border-primary text-primary'
                            : 'border-transparent text-zinc-500 hover:text-white hover:border-zinc-700'
                            }`}
                    >
                        <tab.icon className="w-4 h-4 flex-shrink-0" />
                        <span className="hidden sm:inline">{tab.label}</span>
                    </button>
                ))}
            </div>

            {/* Tab Contents */}
            <div className="mt-2">
                {activeTab === 'branding' && (
                    <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 sm:gap-6">
                        <div className="lg:col-span-2 space-y-4 sm:space-y-6">
                            <Card className="border-zinc-800 bg-zinc-900/40 backdrop-blur-md shadow-xl">
                                <CardHeader className="pb-3 border-b border-zinc-800/50">
                                    <CardTitle className="text-lg text-white font-bold">Identidade Visual</CardTitle>
                                </CardHeader>
                                <CardContent className="pt-4 sm:pt-6">
                                    <form onSubmit={handleTrainerSubmit} className="space-y-4 sm:space-y-6">
                                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 sm:gap-6">
                                            <div className="space-y-2">
                                                <Label htmlFor="brand_name" className="text-zinc-300">Nome da Marca</Label>
                                                <Input
                                                    id="brand_name"
                                                    value={trainerData.brand_name}
                                                    onChange={(e) => setTrainerData({ ...trainerData, brand_name: e.target.value })}
                                                    placeholder="Sua Consultoria"
                                                    className="bg-black/50 border-zinc-800 focus-visible:ring-primary"
                                                />
                                            </div>
                                            <div className="space-y-2">
                                                <Label htmlFor="whatsapp_number" className="text-zinc-300">WhatsApp</Label>
                                                <Input
                                                    id="whatsapp_number"
                                                    value={trainerData.whatsapp_number}
                                                    onChange={(e) => setTrainerData({ ...trainerData, whatsapp_number: e.target.value })}
                                                    placeholder="5511999999999"
                                                    className="bg-black/50 border-zinc-800 focus-visible:ring-primary"
                                                />
                                            </div>
                                        </div>

                                        <div className="space-y-2">
                                            <Label htmlFor="slug" className="text-zinc-300">Link Público (Slug)</Label>
                                            <div className="flex items-center rounded-lg border border-zinc-800 bg-black/50 overflow-hidden focus-within:ring-1 focus-within:ring-primary focus-within:border-primary transition-all">
                                                <span className="px-3 py-2 text-sm text-zinc-500 border-r border-zinc-800 select-none bg-zinc-900/50">
                                                    pulso.app/t/
                                                </span>
                                                <input
                                                    id="slug"
                                                    className="flex-1 px-3 py-2 text-sm bg-transparent outline-none placeholder:text-zinc-600 text-white min-w-0"
                                                    value={trainerData.slug}
                                                    placeholder="seu-nome"
                                                    onChange={(e) => {
                                                        const v = e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, '')
                                                        setTrainerData({ ...trainerData, slug: v })
                                                        if (v && !/^[a-z0-9][a-z0-9\-]{1,28}[a-z0-9]$/.test(v)) {
                                                            setSlugError('Use apenas letras minúsculas, números e hífens.')
                                                        } else {
                                                            setSlugError('')
                                                        }
                                                    }}
                                                />
                                            </div>
                                            {slugError && <p className="text-xs text-red-500 font-medium">{slugError}</p>}
                                        </div>

                                        <div className="space-y-3">
                                            <Label className="text-zinc-300">Cor Principal</Label>
                                            <div className="flex flex-wrap gap-3">
                                                {['#ef4444', '#f97316', '#f59e0b', '#84cc16', '#10b981', '#06b6d4', '#3b82f6', '#8b5cf6', '#d946ef', '#f43f5e'].map(color => (
                                                    <button
                                                        key={color}
                                                        type="button"
                                                        onClick={() => setTrainerData({ ...trainerData, primary_color: color })}
                                                        className={`w-10 h-10 rounded-full flex items-center justify-center transition-transform hover:scale-110 shadow-lg ${trainerData.primary_color === color ? 'ring-2 ring-white ring-offset-2 ring-offset-zinc-900' : 'ring-1 ring-zinc-800/50'}`}
                                                        style={{ backgroundColor: color }}
                                                    >
                                                        {trainerData.primary_color === color && <Check className="w-5 h-5 text-white drop-shadow-md" />}
                                                    </button>
                                                ))}
                                                <div className="relative group">
                                                    <Input
                                                        type="color"
                                                        value={trainerData.primary_color}
                                                        onChange={(e) => setTrainerData({ ...trainerData, primary_color: e.target.value })}
                                                        className="w-10 h-10 p-0 border-0 rounded-full overflow-hidden cursor-pointer opacity-0 absolute inset-0 z-10"
                                                    />
                                                    <div
                                                        className="w-10 h-10 rounded-full flex items-center justify-center ring-1 ring-zinc-700 bg-[conic-gradient(red,yellow,green,cyan,blue,magenta,red)]"
                                                    >
                                                        <div className="w-8 h-8 rounded-full bg-zinc-900 flex items-center justify-center">
                                                            <div className="w-6 h-6 rounded-full" style={{ backgroundColor: trainerData.primary_color }}></div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>

                                        <Button type="submit" disabled={isSaving || isUploading} className="w-full sm:w-auto bg-primary hover:bg-primary/90 text-primary-foreground font-bold shadow-[0_0_15px_rgba(132,204,22,0.3)]">
                                            {isSaving ? "Salvando..." : "Salvar Configurações"}
                                        </Button>
                                    </form>
                                </CardContent>
                            </Card>
                        </div>

                        <div className="space-y-6">
                            <Card className="border-zinc-800 bg-zinc-900/40 backdrop-blur-md shadow-xl">
                                <CardHeader className="pb-3 border-b border-zinc-800/50">
                                    <CardTitle className="text-base text-white font-bold">Logotipo</CardTitle>
                                </CardHeader>
                                <CardContent className="pt-6">
                                    <div className="flex flex-col items-center justify-center space-y-4">
                                        <div className="relative group w-24 h-24 sm:w-32 sm:h-32 rounded-3xl border-2 border-dashed border-zinc-700 overflow-hidden flex items-center justify-center bg-black/40 hover:bg-black/60 transition-colors shadow-inner">
                                            {logoPreview ? (
                                                <img src={logoPreview} alt="Logo" className="w-full h-full object-cover" />
                                            ) : (
                                                <Upload className="w-6 sm:w-8 h-6 sm:h-8 text-zinc-500 group-hover:text-primary transition-colors" />
                                            )}
                                            <input
                                                type="file"
                                                accept="image/*"
                                                onChange={handleFileChange}
                                                className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
                                                disabled={isUploading}
                                            />
                                            <div className="absolute inset-x-0 bottom-0 bg-black/70 py-1.5 opacity-0 group-hover:opacity-100 transition-opacity flex justify-center pointer-events-none">
                                                <span className="text-[10px] uppercase tracking-wider font-bold text-white">Alterar Logo</span>
                                            </div>
                                        </div>
                                        {isUploading && <p className="text-xs text-primary animate-pulse font-bold">Enviando...</p>}
                                        <p className="text-xs text-zinc-500 text-center px-2">
                                            Recomendado: 512x512px (PNG ou JPG transparente).
                                        </p>
                                    </div>
                                </CardContent>
                            </Card>

                            <Card className="border-zinc-800 bg-zinc-900/40 backdrop-blur-md shadow-xl">
                                <CardHeader className="pb-3 border-b border-zinc-800/50">
                                    <CardTitle className="text-base text-white font-bold">Foto de Perfil</CardTitle>
                                </CardHeader>
                                <CardContent className="pt-6">
                                    <div className="flex flex-col items-center justify-center space-y-4">
                                        <div className="relative group w-24 h-24 sm:w-32 sm:h-32 rounded-full border-2 border-dashed border-zinc-700 overflow-hidden flex items-center justify-center bg-black/40 hover:bg-black/60 transition-colors shadow-inner">
                                            {photoPreview ? (
                                                <img src={photoPreview} alt="Foto de Perfil" className="w-full h-full object-cover" />
                                            ) : (
                                                <Upload className="w-6 sm:w-8 h-6 sm:h-8 text-zinc-500 group-hover:text-primary transition-colors" />
                                            )}
                                            <input
                                                type="file"
                                                accept="image/*"
                                                onChange={(e) => handleFileChange(e, 'avatar')}
                                                className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
                                                disabled={isUploading}
                                            />
                                            <div className="absolute inset-x-0 bottom-0 bg-black/70 py-1.5 opacity-0 group-hover:opacity-100 transition-opacity flex justify-center pointer-events-none">
                                                <span className="text-[10px] uppercase tracking-wider font-bold text-white">Alterar Foto</span>
                                            </div>
                                        </div>
                                        {isUploading && <p className="text-xs text-primary animate-pulse font-bold">Enviando...</p>}
                                        <p className="text-xs text-zinc-500 text-center px-2">
                                            Recomendado: 400x400px (PNG ou JPG).
                                        </p>
                                    </div>
                                </CardContent>
                            </Card>

                            {user.id && (
                                <Card className="border-primary/20 bg-primary/5 shadow-xl shadow-primary/5">
                                    <CardHeader className="pb-3 border-b border-primary/10">
                                        <CardTitle className="flex items-center gap-2 text-base text-primary font-bold">
                                            <Globe className="h-4 w-4" /> Sua Página
                                        </CardTitle>
                                    </CardHeader>
                                    <CardContent className="pt-4">
                                        <p className="text-xs text-zinc-400 mb-3">
                                            Compartilhe este link em seu Instagram para atrair novos alunos.
                                        </p>
                                        {(() => {
                                            const handle = trainerData.slug || user.id
                                            const url = `${typeof window !== 'undefined' ? window.location.origin : ''}/t/${handle}`
                                            return (
                                                <div className="flex items-center gap-1 bg-black/60 rounded-lg border border-zinc-800 px-2 py-1.5">
                                                    <span className="text-xs text-zinc-300 truncate flex-1 font-mono">
                                                        .../t/{handle}
                                                    </span>
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        className="h-7 w-7 shrink-0 text-zinc-400 hover:text-white hover:bg-zinc-800"
                                                        onClick={() => { navigator.clipboard.writeText(url); toast.success("Copiado com sucesso!") }}
                                                    >
                                                        <Copy className="h-3.5 w-3.5" />
                                                    </Button>
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        className="h-7 w-7 shrink-0 text-zinc-400 hover:text-white hover:bg-zinc-800"
                                                        onClick={() => window.open(`/t/${handle}`, '_blank')}
                                                    >
                                                        <ExternalLink className="h-3.5 w-3.5" />
                                                    </Button>
                                                </div>
                                            )
                                        })()}
                                    </CardContent>
                                </Card>
                            )}
                        </div>
                    </div>
                )}

                {activeTab === 'marketplace' && (
                    <Card className="border-zinc-800 bg-zinc-900/40 backdrop-blur-md shadow-xl max-w-3xl">
                        <CardHeader className="pb-3 border-b border-zinc-800/50">
                            <CardTitle className="flex items-center gap-2 text-base sm:text-lg text-white font-bold">
                                <Store className="h-5 w-5 text-primary" /> Divulgação no Marketplace
                            </CardTitle>
                        </CardHeader>
                        <CardContent className="pt-6">
                            <div className={`flex flex-col sm:flex-row sm:items-center justify-between gap-6 p-5 rounded-2xl border transition-colors ${trainerData.is_available_for_hire ? 'border-primary/30 bg-primary/5' : 'border-zinc-800 bg-black/30'}`}>
                                <div>
                                    <h3 className="font-bold text-white text-lg mb-1">
                                        {trainerData.is_available_for_hire ? 'Visível no Marketplace' : 'Perfil Privado'}
                                    </h3>
                                    <p className="text-sm text-zinc-400 max-w-md">
                                        Quando ativado, seu perfil será recomendado para novos atletas da plataforma Pulso que buscam por um personal trainer.
                                    </p>
                                </div>
                                <button
                                    type="button"
                                    role="switch"
                                    aria-checked={trainerData.is_available_for_hire}
                                    onClick={async () => {
                                        const newValue = !trainerData.is_available_for_hire
                                        setTrainerData(prev => ({ ...prev, is_available_for_hire: newValue }))
                                        try {
                                            await ApiClient.trainer.updateProfile({ is_available_for_hire: newValue })
                                            toast.success(newValue ? "Você está visível no marketplace! 🚀" : "Seu perfil foi ocultado.")
                                        } catch {
                                            setTrainerData(prev => ({ ...prev, is_available_for_hire: !newValue }))
                                            toast.error("Erro ao atualizar status.")
                                        }
                                    }}
                                    className={`relative inline-flex h-8 w-14 sm:h-9 sm:w-16 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-300 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 focus:ring-offset-black shadow-inner ${trainerData.is_available_for_hire ? 'bg-primary' : 'bg-zinc-700'}`}
                                >
                                    <span
                                        className={`pointer-events-none inline-block h-7 w-7 sm:h-8 sm:w-8 transform rounded-full bg-white shadow-md ring-0 transition duration-300 ease-in-out ${trainerData.is_available_for_hire ? 'translate-x-6 sm:translate-x-7' : 'translate-x-0'}`}
                                    />
                                </button>
                            </div>

                            {trainerData.is_available_for_hire && (
                                <div className="mt-6 pt-6 border-t border-zinc-800 space-y-6">
                                    {/* Modality Section */}
                                    <div className="space-y-3">
                                        <Label htmlFor="modality" className="text-zinc-300 font-semibold">Modalidade de Atendimento</Label>
                                        <select
                                            id="modality"
                                            value={trainerData.modality}
                                            onChange={(e) => setTrainerData({ ...trainerData, modality: e.target.value as "" | "presencial" | "online" | "hibrido" })}
                                            className="w-full px-3 py-2 rounded-lg border border-zinc-800 bg-black/50 text-white focus-visible:ring-primary focus-visible:ring-1 focus-visible:border-primary transition-all"
                                        >
                                            <option value="">Selecione uma modalidade</option>
                                            <option value="presencial">Presencial</option>
                                            <option value="online">Online</option>
                                            <option value="hibrido">Híbrido (Presencial + Online)</option>
                                        </select>
                                        <p className="text-xs text-zinc-400">Informar sua modalidade ajuda os alunos a encontrarem você.</p>
                                    </div>

                                    {/* Gyms Section */}
                                    <div className="space-y-3">
                                        <Label className="text-zinc-300 font-semibold">Locais de Atendimento (Academias/Estúdios)</Label>
                                        <div className="space-y-2">
                                            {trainerData.gyms.map((gym, index) => (
                                                <div key={index} className="flex gap-2 items-center">
                                                    <Input
                                                        value={gym}
                                                        onChange={(e) => {
                                                            const newGyms = [...trainerData.gyms]
                                                            newGyms[index] = e.target.value
                                                            setTrainerData({ ...trainerData, gyms: newGyms })
                                                        }}
                                                        placeholder="Ex: Academia Gold, Studio Yoga..."
                                                        className="bg-black/50 border-zinc-800 focus-visible:ring-primary"
                                                    />
                                                    <button
                                                        type="button"
                                                        onClick={() => {
                                                            const newGyms = trainerData.gyms.filter((_, i) => i !== index)
                                                            setTrainerData({ ...trainerData, gyms: newGyms })
                                                        }}
                                                        className="px-3 py-2 rounded-lg bg-red-500/10 text-red-400 hover:bg-red-500/20 transition-colors text-sm font-medium"
                                                    >
                                                        Remover
                                                    </button>
                                                </div>
                                            ))}
                                            <button
                                                type="button"
                                                onClick={() => setTrainerData({ ...trainerData, gyms: [...trainerData.gyms, ""] })}
                                                className="w-full px-3 py-2 rounded-lg border border-dashed border-zinc-700 text-zinc-400 hover:text-zinc-200 hover:border-zinc-600 transition-colors text-sm font-medium"
                                            >
                                                + Adicionar Local
                                            </button>
                                        </div>
                                        <p className="text-xs text-zinc-400">Liste as academias ou estúdios onde você atende.</p>
                                    </div>
                                </div>
                            )}
                        </CardContent>
                    </Card>
                )}

                {activeTab === 'subscription' && (
                    <Card className="border-border/50">
                        <CardHeader className="pb-3">
                            <div className="flex items-start sm:items-center justify-between gap-3 flex-wrap">
                                <div>
                                    <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
                                        <CreditCard className="h-5 w-5 text-primary" />
                                        Meu Plano
                                    </CardTitle>
                                    <p className="text-xs sm:text-sm text-muted-foreground mt-1">
                                        Gerencie sua assinatura e recursos disponíveis
                                    </p>
                                </div>
                                {user.subscription_status && (
                                    <span className={`text-xs font-semibold px-3 py-1.5 rounded-full border ${user.subscription_status === 'ACTIVE'
                                        ? 'text-emerald-400 bg-emerald-400/10 border-emerald-400/30'
                                        : user.subscription_status === 'TRIAL'
                                            ? 'text-amber-400 bg-amber-400/10 border-amber-400/30'
                                            : 'text-red-400 bg-red-400/10 border-red-400/30'
                                        }`}>
                                        {user.subscription_status === 'ACTIVE' ? '✅ Ativo'
                                            : user.subscription_status === 'TRIAL' ? '⏳ Trial'
                                                : '❌ Inativo'}
                                    </span>
                                )}
                            </div>
                        </CardHeader>
                        <CardContent>
                            {!PLAN_SELF_SERVICE_ENABLED && (
                                <div className="flex items-start gap-3 rounded-lg border border-amber-400/20 bg-amber-400/5 px-4 py-3 mb-5">
                                    <Lock className="h-4 w-4 text-amber-400 mt-0.5 flex-shrink-0" />
                                    <p className="text-xs text-amber-300/90 leading-relaxed">
                                        Seu plano é gerenciado pela equipe Pulso. Em breve você poderá alterar seu plano diretamente aqui após a integração com meios de pagamento.
                                    </p>
                                </div>
                            )}
                            {plansLoading ? (
                                <div className="flex items-center gap-3 py-8 justify-center text-muted-foreground">
                                    <div className="h-5 w-5 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
                                    Carregando planos...
                                </div>
                            ) : plans.length === 0 ? (
                                <p className="text-sm text-muted-foreground py-4 text-center">
                                    Nenhum plano disponível no momento.
                                </p>
                            ) : (
                                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                                    {plans.map((plan) => {
                                        const isCurrentPlan = plan.id === user.plan_id
                                        const price = Number(plan.price)
                                        return (
                                            <div
                                                key={plan.id}
                                                className={`relative rounded-xl border-2 p-4 sm:p-5 transition-all duration-200 ${isCurrentPlan
                                                    ? 'border-primary bg-primary/5 shadow-lg shadow-primary/10'
                                                    : 'border-border/30 bg-card hover:border-border'
                                                    }`}
                                            >
                                                {isCurrentPlan && (
                                                    <div className="absolute -top-2.5 left-4">
                                                        <span className="text-xs font-bold bg-primary text-primary-foreground px-2.5 py-1 rounded-full">
                                                            Plano Atual
                                                        </span>
                                                    </div>
                                                )}
                                                <div className="mt-1">
                                                    <h3 className={`font-bold text-base sm:text-lg ${isCurrentPlan ? 'text-primary' : 'text-foreground'}`}>
                                                        {plan.name}
                                                    </h3>
                                                    <div className="flex items-end gap-1 mt-2">
                                                        <span className="text-2xl sm:text-3xl font-black text-foreground">
                                                            {price === 0 ? 'Grátis' : `R$ ${price.toFixed(2)}`}
                                                        </span>
                                                        {price > 0 && <span className="text-muted-foreground text-sm mb-1">/mês</span>}
                                                    </div>
                                                    <p className="text-sm text-muted-foreground mt-1">
                                                        Até {plan.max_students} alunos
                                                    </p>

                                                    {plan.features && Object.keys(plan.features).length > 0 && (
                                                        <div className="mt-4 space-y-2">
                                                            {Object.entries(plan.features).map(([key, val]) => (
                                                                <div key={key} className="flex items-center gap-2">
                                                                    <div className={`h-4 w-4 rounded-full flex items-center justify-center flex-shrink-0 ${val ? 'bg-primary/20 text-primary' : 'bg-muted text-muted-foreground'
                                                                        }`}>
                                                                        {val ? '✓' : '✗'}
                                                                    </div>
                                                                    <span className="text-xs text-muted-foreground capitalize">
                                                                        {String(key).replace(/_/g, ' ')}
                                                                    </span>
                                                                </div>
                                                            ))}
                                                        </div>
                                                    )}

                                                    {PLAN_SELF_SERVICE_ENABLED ? (
                                                        <Button
                                                            onClick={() => handleChangePlan(plan.id)}
                                                            disabled={isCurrentPlan || isChangingPlan}
                                                            size="sm"
                                                            className={`w-full mt-4 sm:mt-5 ${isCurrentPlan
                                                                ? 'bg-primary/20 text-primary border border-primary/30 cursor-default'
                                                                : 'bg-primary hover:bg-primary/90 text-primary-foreground shadow-sm shadow-primary/20'
                                                                }`}
                                                        >
                                                            {isCurrentPlan ? 'Plano Ativo' : isChangingPlan ? 'Alterando...' : 'Selecionar Plano'}
                                                        </Button>
                                                    ) : (
                                                        <div className={`w-full mt-4 sm:mt-5 text-center text-xs px-3 py-2 rounded-lg ${isCurrentPlan
                                                            ? 'bg-primary/10 text-primary border border-primary/20'
                                                            : 'bg-muted/30 text-muted-foreground'
                                                            }`}>
                                                            {isCurrentPlan ? 'Plano Atual' : ''}
                                                        </div>
                                                    )}
                                                </div>
                                            </div>
                                        )
                                    })}
                                </div>
                            )}
                        </CardContent>
                    </Card>
                )}
            </div>
        </div>
    )
}
