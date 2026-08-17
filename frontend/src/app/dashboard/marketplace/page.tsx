"use client"

import { useEffect, useState } from "react"
import { ApiClient, TrainerMarketplaceItem } from "@/lib/api"
import { Card, CardContent, CardFooter, CardHeader } from "@/components/ui/card"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Search, ChevronRight, Star, ShieldCheck, MapPin } from "lucide-react"
import { Input } from "@/components/ui/input"
import { getImageUrl } from "@/lib/utils"
import { useRouter } from "next/navigation"

// Static specialties for fast filtering (could be fetched from an endpoint later)
const AVAILABLE_SPECIALTIES = [
    "Hipertrofia", "Emagrecimento", "Postura", "Força", "Crossfit", "Reabilitação", "Calistenia"
]

const AVAILABLE_MODALITIES = [
    { value: 'presencial' as const, label: 'Presencial' },
    { value: 'online' as const, label: 'Online' },
    { value: 'hibrido' as const, label: 'Híbrido' },
]

const getModalityInfo = (modality?: string) => {
    switch (modality) {
        case 'presencial':
            return { label: 'Presencial', color: 'text-primary', bgColor: 'bg-primary/10', borderColor: 'border-primary/30' }
        case 'online':
            return { label: 'Online', color: 'text-accent', bgColor: 'bg-accent/10', borderColor: 'border-accent/30' }
        case 'hibrido':
            return { label: 'Híbrido', color: 'text-purple-400', bgColor: 'bg-purple-500/10', borderColor: 'border-purple-500/30' }
        default:
            return { label: null, color: '', bgColor: '', borderColor: '' }
    }
}

export default function MarketplacePage() {
    const router = useRouter()
    const [trainers, setTrainers] = useState<TrainerMarketplaceItem[]>([])
    const [isLoading, setIsLoading] = useState(true)
    const [searchTerm, setSearchTerm] = useState("")
    const [activeSpecialty, setActiveSpecialty] = useState<string | null>(null)
    const [activeModality, setActiveModality] = useState<string | null>(null)

    useEffect(() => {
        loadTrainers()
    }, [])

    async function loadTrainers() {
        try {
            // We load all and filter in memory for snappy UI
            const data = await ApiClient.getMarketplaceTrainers()
            setTrainers(data)
        } catch (error) {
            console.error("Failed to load trainers", error)
        } finally {
            setIsLoading(false)
        }
    }

    const filteredTrainers = trainers.filter(t => {
        const matchesSearch = t.full_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
            t.brand_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
            t.specialties?.some(s => s.toLowerCase().includes(searchTerm.toLowerCase()))

        const matchesSpecialty = activeSpecialty ? t.specialties?.includes(activeSpecialty) : true

        const matchesModality = activeModality ? t.modality === activeModality : true

        return matchesSearch && matchesSpecialty && matchesModality
    })

    return (
        <div className="space-y-10 max-w-7xl mx-auto pb-12">

            {/* HEROS SECTION */}
            <div className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between bg-card/60 p-8 rounded-3xl border border-border relative overflow-hidden">
                <div className="absolute top-0 right-0 w-64 h-64 bg-primary/10 rounded-full blur-[100px] pointer-events-none" />
                <div className="absolute bottom-0 left-0 w-64 h-64 bg-accent/10 rounded-full blur-[100px] pointer-events-none" />

                <div className="relative z-10 max-w-2xl">
                    <Badge variant="outline" className="mb-4 text-primary border-primary/30 bg-primary/10 px-3 py-1">Vitrine Elite</Badge>
                    <h1 className="text-4xl md:text-5xl font-black text-foreground tracking-tight mb-4">
                        Marketplace de <br />
                        <span className="gradient-text">
                            Treinadores Premium
                        </span>
                    </h1>
                    <p className="text-muted-foreground text-lg">
                        Encontre o profissional exato para o seu objetivo. Avalie, solicite vaga e comece sua evolução hoje.
                    </p>
                </div>
                <div className="relative z-10 w-full md:w-[400px] space-y-4">
                    <div className="relative">
                        <Search className="absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-muted-foreground" />
                        <Input
                            placeholder="Buscar por nome ou nicho..."
                            className="h-14 pl-12 rounded-2xl bg-input border-border text-foreground placeholder:text-muted-foreground focus:ring-primary text-base"
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                        />
                    </div>
                </div>
            </div>

            {/* FILTERS TRAY */}
            <div className="flex flex-col space-y-6">
                {/* Specialty Filters */}
                <div className="flex flex-col space-y-3">
                    <div className="flex items-center gap-2">
                        <span className="text-sm font-semibold text-zinc-500 uppercase tracking-wider">Especialidades</span>
                    </div>
                    <div className="flex overflow-x-auto pb-2 gap-2 [&::-webkit-scrollbar]:hidden w-full" style={{ scrollbarWidth: 'none' }}>
                        <Badge
                            variant="secondary"
                            className={`cursor-pointer px-4 py-2 text-sm transition-all duration-300 ${!activeSpecialty ? 'bg-primary text-primary-foreground hover:bg-primary/80' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'}`}
                            onClick={() => setActiveSpecialty(null)}
                        >
                            Todos
                        </Badge>
                        {AVAILABLE_SPECIALTIES.map(s => (
                            <Badge
                                key={s}
                                variant="secondary"
                                className={`cursor-pointer px-4 py-2 text-sm transition-all duration-300 ${activeSpecialty === s ? 'bg-primary text-primary-foreground hover:bg-primary/80' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'}`}
                                onClick={() => setActiveSpecialty(s)}
                            >
                                {s}
                            </Badge>
                        ))}
                    </div>
                </div>

                {/* Modality Filters */}
                <div className="flex flex-col space-y-3">
                    <div className="flex items-center gap-2">
                        <span className="text-sm font-semibold text-zinc-500 uppercase tracking-wider">Modalidade</span>
                    </div>
                    <div className="flex overflow-x-auto pb-2 gap-2 [&::-webkit-scrollbar]:hidden w-full" style={{ scrollbarWidth: 'none' }}>
                        <Badge
                            variant="secondary"
                            className={`cursor-pointer px-4 py-2 text-sm transition-all duration-300 ${!activeModality ? 'bg-primary text-primary-foreground hover:bg-primary/80' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'}`}
                            onClick={() => setActiveModality(null)}
                        >
                            Todos
                        </Badge>
                        {AVAILABLE_MODALITIES.map(m => (
                            <Badge
                                key={m.value}
                                variant="secondary"
                                className={`cursor-pointer px-4 py-2 text-sm transition-all duration-300 ${activeModality === m.value ? 'bg-primary text-primary-foreground hover:bg-primary/80' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'}`}
                                onClick={() => setActiveModality(m.value)}
                            >
                                {m.label}
                            </Badge>
                        ))}
                    </div>
                </div>
            </div>

            {/* TRAINERS GRID */}
            {isLoading ? (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
                    {[1, 2, 3, 4, 5, 6].map(i => (
                        <div key={i} className="h-[420px] rounded-3xl card-glow animate-pulse relative overflow-hidden">
                            <div className="h-32 bg-secondary/50 w-full" />
                            <div className="absolute top-20 left-6 w-24 h-24 bg-secondary rounded-full border-4 border-background" />
                            <div className="mt-16 px-6 space-y-4">
                                <div className="h-6 bg-secondary w-3/4 rounded-md" />
                                <div className="h-4 bg-secondary w-1/2 rounded-md" />
                                <div className="space-y-2 pt-4">
                                    <div className="h-3 bg-secondary w-full rounded-sm" />
                                    <div className="h-3 bg-secondary w-5/6 rounded-sm" />
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            ) : filteredTrainers.length === 0 ? (
                <div className="text-center py-24 bg-secondary/20 rounded-3xl border border-border border-dashed">
                    <div className="mx-auto w-16 h-16 bg-secondary rounded-full flex items-center justify-center mb-4">
                        <Search className="h-8 w-8 text-muted-foreground" />
                    </div>
                    <h3 className="text-xl font-bold text-foreground mb-2">Nenhum treinador encontrado</h3>
                    <p className="text-muted-foreground max-w-md mx-auto">
                        Não encontramos ninguém {searchTerm && `com o termo "${searchTerm}"`} {activeSpecialty && `na especialidade ${activeSpecialty}`} {activeModality && `na modalidade ${AVAILABLE_MODALITIES.find(m => m.value === activeModality)?.label}`}. Tente ajustar seus filtros.
                    </p>
                    <button
                        onClick={() => { setSearchTerm(""); setActiveSpecialty(null); setActiveModality(null) }}
                        className="mt-6 text-primary font-medium hover:text-primary/80"
                    >
                        Limpar todos os filtros
                    </button>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-8">
                    {filteredTrainers.map(trainer => (
                        <div
                            key={trainer.user_id}
                            onClick={() => router.push(`/dashboard/marketplace/${trainer.user_id}`)}
                            className="card-glow overflow-hidden hover:border-primary/60 transition-all duration-300 hover:shadow-2xl hover:shadow-primary/10 cursor-pointer group flex flex-col h-full relative"
                        >
                            {/* Card Cover Banner */}
                            <div className="h-32 relative bg-secondary overflow-hidden">
                                {trainer.logo_url ? (
                                    <>
                                        <img src={getImageUrl(trainer.logo_url)} alt="Cover" className="w-full h-full object-cover opacity-40 group-hover:opacity-60 transition-opacity duration-500" />
                                        <div className="absolute inset-0 bg-gradient-to-t from-card via-transparent to-transparent" />
                                    </>
                                ) : (
                                    <div className="w-full h-full bg-gradient-to-br from-secondary to-card" />
                                )}

                                {trainer.request_status === 'PENDING' && (
                                    <div className="absolute top-4 right-4 bg-primary/20 text-primary border border-primary/30 px-3 py-1 rounded-full text-xs font-bold backdrop-blur-md flex items-center gap-1.5">
                                        <div className="w-2 h-2 rounded-full bg-primary animate-pulse" />
                                        Vaga Solicitada
                                    </div>
                                )}
                                {trainer.request_status === 'ACCEPTED' && (
                                    <div className="absolute top-4 right-4 bg-accent/20 text-accent border border-accent/30 px-3 py-1 rounded-full text-xs font-bold backdrop-blur-md flex items-center gap-1.5">
                                        <ShieldCheck className="w-3 h-3" />
                                        Seu Coach
                                    </div>
                                )}
                            </div>

                            {/* Avatar */}
                            <div className="px-6 -mt-12 relative z-10">
                                <Avatar className="h-24 w-24 border-4 border-background shadow-xl bg-card">
                                    <AvatarImage src={getImageUrl(trainer.photo_url)} className="object-cover" />
                                    <AvatarFallback className="bg-secondary text-2xl font-black text-foreground">
                                        {trainer.full_name.substring(0, 2).toUpperCase()}
                                    </AvatarFallback>
                                </Avatar>
                            </div>

                            {/* Content */}
                            <div className="px-6 pt-4 pb-6 flex flex-col flex-grow">
                                <div className="flex justify-between items-start mb-4">
                                    <div>
                                        <h3 className="text-xl font-bold text-foreground group-hover:text-primary transition-colors flex items-center gap-2">
                                            {trainer.brand_name || trainer.full_name}
                                        </h3>
                                        <p className="text-sm text-muted-foreground font-medium">
                                            {trainer.brand_name ? trainer.full_name : "Personal Trainer"}
                                        </p>
                                    </div>
                                    {trainer.average_rating ? (
                                        <div className="flex items-center gap-1 bg-secondary/50 px-2 py-1 rounded-lg">
                                            <Star className="w-3.5 h-3.5 text-accent fill-accent" />
                                            <span className="text-sm font-bold text-foreground">
                                                {trainer.average_rating.toFixed(1)}
                                            </span>
                                            {trainer.total_reviews && (
                                                <span className="text-xs text-muted-foreground">({trainer.total_reviews})</span>
                                            )}
                                        </div>
                                    ) : (
                                        <Badge className="bg-primary/15 text-primary border-primary/20 text-xs font-semibold">
                                            Novo
                                        </Badge>
                                    )}
                                </div>

                                {trainer.hourly_rate && (
                                    <div className="mb-4 inline-flex items-center gap-1.5 bg-accent/10 text-accent px-3 py-1.5 rounded-lg w-fit border border-accent/20">
                                        <span className="text-sm font-bold">R$ {trainer.hourly_rate}</span>
                                        <span className="text-xs text-accent/70 uppercase">/ hora</span>
                                    </div>
                                )}

                                <p className="text-sm text-muted-foreground line-clamp-3 mb-6 flex-grow leading-relaxed">
                                    {trainer.bio || "Especialista em transformação física e performance de alto nível."}
                                </p>

                                {/* Modality Badge */}
                                {trainer.modality && (() => {
                                    const modalityInfo = getModalityInfo(trainer.modality)
                                    return (
                                        <div className={`inline-block px-2.5 py-1 rounded-lg border ${modalityInfo.bgColor} ${modalityInfo.borderColor} mb-4`}>
                                            <span className={`text-xs font-bold ${modalityInfo.color}`}>
                                                {modalityInfo.label}
                                            </span>
                                        </div>
                                    )
                                })()}

                                {/* Gyms */}
                                {trainer.gyms && trainer.gyms.length > 0 && (
                                    <div className="mb-4 space-y-2">
                                        <p className="text-xs font-semibold text-muted-foreground uppercase">Locais de atendimento</p>
                                        <div className="flex flex-wrap gap-1.5">
                                            {trainer.gyms.slice(0, 2).map(gym => (
                                                <Badge key={gym} variant="secondary" className="bg-secondary/60 text-secondary-foreground border-none font-medium text-xs flex items-center gap-1">
                                                    <MapPin className="w-3 h-3" /> {gym}
                                                </Badge>
                                            ))}
                                            {trainer.gyms.length > 2 && (
                                                <Badge variant="secondary" className="bg-secondary/50 text-muted-foreground border-none text-xs">
                                                    +{trainer.gyms.length - 2}
                                                </Badge>
                                            )}
                                        </div>
                                    </div>
                                )}

                                {/* Specialties & CTA */}
                                <div className="mt-auto space-y-5">
                                    <div className="flex flex-wrap gap-2">
                                        {trainer.specialties?.slice(0, 3).map(s => (
                                            <Badge key={s} variant="secondary" className="bg-secondary text-secondary-foreground border-none font-medium text-xs">
                                                {s}
                                            </Badge>
                                        ))}
                                        {trainer.specialties && trainer.specialties.length > 3 && (
                                            <Badge variant="secondary" className="bg-secondary/50 text-muted-foreground border-none text-xs">
                                                +{trainer.specialties.length - 3}
                                            </Badge>
                                        )}
                                    </div>

                                    <div className="flex items-center justify-between pt-4 border-t border-border w-full group/btn">
                                        <span className="text-sm font-semibold text-foreground group-hover/btn:text-primary transition-colors">
                                            Ver Perfil Completo
                                        </span>
                                        <div className="w-8 h-8 rounded-full bg-secondary flex items-center justify-center group-hover/btn:bg-primary transition-colors">
                                            <ChevronRight className="w-4 h-4 text-muted-foreground group-hover/btn:text-primary-foreground transition-colors" />
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    )
}
