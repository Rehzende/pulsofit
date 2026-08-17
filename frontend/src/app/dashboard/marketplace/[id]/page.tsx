"use client"

import { useEffect, useState } from "react"
import { useParams, useRouter } from "next/navigation"
import { ApiClient, TrainerMarketplaceItem } from "@/lib/api"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { getImageUrl } from "@/lib/utils"
import { ArrowLeft, Clock, ShieldCheck, Mail, CheckCircle2, Star, Check, Phone, MapPin, Video, MessageCircle } from "lucide-react"
import Link from "next/link"

const getModalityInfo = (modality?: string) => {
    switch (modality) {
        case 'presencial':
            return { label: 'Presencial', icon: MapPin, color: 'text-blue-400', bgColor: 'bg-blue-500/10', borderColor: 'border-blue-500/30' }
        case 'online':
            return { label: 'Online', icon: Video, color: 'text-purple-400', bgColor: 'bg-purple-500/10', borderColor: 'border-purple-500/30' }
        case 'hibrido':
            return { label: 'Híbrido', icon: MapPin, color: 'text-orange-400', bgColor: 'bg-orange-500/10', borderColor: 'border-orange-500/30' }
        default:
            return { label: null, icon: null, color: '', bgColor: '', borderColor: '' }
    }
}

export default function TrainerProfilePage() {
    const params = useParams()
    const router = useRouter()
    const trainerId = params.id as string

    const [trainer, setTrainer] = useState<TrainerMarketplaceItem | null>(null)
    const [isLoading, setIsLoading] = useState(true)
    const [isRequesting, setIsRequesting] = useState(false)
    const [status, setStatus] = useState<string>("NONE")
    const [dataConsent, setDataConsent] = useState(false)

    useEffect(() => {
        if (trainerId) loadTrainer()
    }, [trainerId])

    async function loadTrainer() {
        try {
            const data = await ApiClient.getTrainerProfile(trainerId)
            setTrainer(data)
            setStatus(data.request_status || "NONE")
        } catch (error) {
            console.error("Failed to load trainer profile", error)
        } finally {
            setIsLoading(false)
        }
    }

    async function handleRequest() {
        try {
            setIsRequesting(true)
            await ApiClient.requestTrainer(trainerId)
            setStatus("PENDING")
            setTrainer(prev => prev ? { ...prev, request_status: "PENDING" } : null)
        } catch (error) {
            console.error("Erro ao solicitar vaga", error)
            alert("Erro ao solicitar vaga. Verifique sua conexão ou tente novamente.")
        } finally {
            setIsRequesting(false)
        }
    }

    function openWhatsApp() {
        if (trainer?.whatsapp_number) {
            window.open(`https://wa.me/${trainer.whatsapp_number.replace(/\D/g, '')}`, '_blank')
        }
    }

    if (isLoading) {
        return (
            <div className="max-w-4xl mx-auto space-y-6 animate-pulse">
                <div className="h-48 bg-zinc-900 rounded-3xl" />
                <div className="px-8 space-y-4">
                    <div className="h-24 w-24 bg-zinc-800 rounded-full -mt-16" />
                    <div className="h-8 bg-zinc-800 w-1/3 rounded" />
                    <div className="h-4 bg-zinc-800 w-full rounded" />
                    <div className="h-4 bg-zinc-800 w-2/3 rounded" />
                </div>
            </div>
        )
    }

    if (!trainer) {
        return (
            <div className="text-center py-20 flex flex-col items-center">
                <ShieldCheck className="w-16 h-16 text-zinc-600 mb-4" />
                <h2 className="text-2xl font-bold text-white mb-2">Treinador não encontrado</h2>
                <p className="text-zinc-400 mb-6">Este perfil pode ter sido removido ou não estar mais disponível.</p>
                <Button onClick={() => router.push('/dashboard/marketplace')} variant="outline">
                    Voltar para a Vitrine
                </Button>
            </div>
        )
    }

    const isPending = status === "PENDING"
    const isAccepted = status === "ACCEPTED"
    const isRejected = status === "REJECTED"

    return (
        <div className="max-w-4xl mx-auto pb-20 w-full">
            {/* Header / Nav */}
            <button
                onClick={() => router.push('/dashboard/marketplace')}
                className="flex items-center gap-2 text-zinc-400 hover:text-white transition-colors mb-6 group"
            >
                <ArrowLeft className="w-4 h-4 group-hover:-translate-x-1 transition-transform" />
                <span>Voltar à vitrine</span>
            </button>

            {/* Profile Card */}
            <div className="bg-zinc-900/40 border border-zinc-800/60 rounded-[2rem] overflow-hidden relative shadow-2xl w-full">

                {/* Banner */}
                <div className="h-48 md:h-64 relative bg-zinc-800 border-b border-zinc-800 w-full">
                    {trainer.logo_url ? (
                        <>
                            <img src={getImageUrl(trainer.logo_url)} alt="Cover" className="w-full h-full object-cover opacity-50" />
                            <div className="absolute inset-0 bg-gradient-to-t from-zinc-900 via-zinc-900/20 to-transparent" />
                        </>
                    ) : (
                        <div className="w-full h-full bg-gradient-to-br from-zinc-800 to-zinc-900" />
                    )}

                    {/* Request Status Badge */}
                    {isPending && (
                        <div className="absolute top-6 right-6 bg-orange-500/10 text-orange-400 border border-orange-500/20 px-4 py-2 rounded-2xl flex items-center gap-2 font-bold backdrop-blur-md shadow-lg">
                            <Clock className="w-4 h-4" /> Solicitação Pendente
                        </div>
                    )}
                    {isAccepted && (
                        <div className="absolute top-6 right-6 bg-green-500/10 text-green-400 border border-green-500/20 px-4 py-2 rounded-2xl flex items-center gap-2 font-bold backdrop-blur-md shadow-lg">
                            <ShieldCheck className="w-4 h-4" /> Seu Treinador
                        </div>
                    )}
                    {isRejected && (
                        <div className="absolute top-6 right-6 bg-red-500/10 text-red-400 border border-red-500/20 px-4 py-2 rounded-2xl flex items-center gap-2 font-bold backdrop-blur-md shadow-lg">
                            Vaga Indisponível
                        </div>
                    )}
                </div>

                <div className="px-4 md:px-10 pb-6 md:pb-10 flex flex-col md:flex-row gap-6 md:gap-8 w-full min-w-0">

                    {/* Left Column (Avatar & Quick Info) */}
                    <div className="flex flex-col items-start w-full md:w-1/3 -mt-20 relative z-10">
                        <Avatar className="h-32 w-32 md:h-40 md:w-40 border-8 border-zinc-950 shadow-2xl bg-zinc-900 mb-4">
                            <AvatarImage src={getImageUrl(trainer.photo_url)} className="object-cover" />
                            <AvatarFallback className="bg-zinc-800 text-3xl font-black text-white">
                                {trainer.full_name.substring(0, 2).toUpperCase()}
                            </AvatarFallback>
                        </Avatar>

                        <div className="w-full space-y-4">
                            {trainer.hourly_rate && (
                                <div className="bg-zinc-950/50 p-4 rounded-2xl border border-zinc-800">
                                    <p className="text-zinc-500 text-xs uppercase font-bold tracking-wider mb-1">Investimento Mensal</p>
                                    <h3 className="text-2xl font-black text-green-400">R$ {trainer.hourly_rate}</h3>
                                    <p className="text-zinc-500 text-sm">/ hora</p>
                                </div>
                            )}

                            <div className="bg-zinc-950/50 p-4 rounded-2xl border border-zinc-800 space-y-3">
                                <div className="flex items-center gap-3">
                                    <div className="w-8 h-8 rounded-full bg-zinc-900 flex items-center justify-center">
                                        <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                                    </div>
                                    <div>
                                        <p className="text-white font-bold leading-none">5.0 <span className="text-zinc-500 font-normal text-sm">(12 avaliações)</span></p>
                                    </div>
                                </div>
                                <div className="flex items-center gap-3">
                                    <div className="w-8 h-8 rounded-full bg-zinc-900 flex items-center justify-center">
                                        <CheckCircle2 className="w-4 h-4 text-blue-400" />
                                    </div>
                                    <p className="text-white font-medium text-sm">Coach Certificado PULSO</p>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Right Column (Bio, Core & CTA) */}
                    <div className="w-full md:flex-1 pt-4 md:pt-8 flex flex-col md:min-w-0">

                        <div className="mb-6">
                            <h1 className="text-2xl sm:text-3xl md:text-4xl font-black text-white tracking-tight mb-2">
                                {trainer.brand_name || trainer.full_name}
                            </h1>
                            <p className="text-zinc-400 text-lg">
                                {trainer.brand_name ? trainer.full_name : "Personal Trainer"}
                            </p>
                        </div>

                        <div className="prose prose-invert max-w-none text-zinc-300 leading-relaxed mb-8 w-full break-words overflow-hidden">
                            {trainer.bio ? (
                                <p className="break-words">{trainer.bio}</p>
                            ) : (
                                <p className="text-zinc-500 italic">Este treinador ainda não adicionou uma descrição detalhada em seu perfil.</p>
                            )}
                        </div>

                        {/* Modality Section */}
                        {trainer.modality && (() => {
                            const modalityInfo = getModalityInfo(trainer.modality)
                            const Icon = modalityInfo.icon
                            return (
                                <div className="mb-8">
                                    <h3 className="text-sm font-bold text-zinc-500 uppercase tracking-wider mb-3">Modalidade de Atendimento</h3>
                                    <div className={`inline-flex items-center gap-3 px-4 py-3 rounded-xl border ${modalityInfo.bgColor} ${modalityInfo.borderColor}`}>
                                        {Icon && <Icon className={`w-5 h-5 ${modalityInfo.color}`} />}
                                        <span className={`font-bold text-sm ${modalityInfo.color}`}>{modalityInfo.label}</span>
                                    </div>
                                </div>
                            )
                        })()}

                        {/* Gyms Section */}
                        {trainer.gyms && trainer.gyms.length > 0 && (
                            <div className="mb-8">
                                <h3 className="text-sm font-bold text-zinc-500 uppercase tracking-wider mb-3">Locais de Atendimento</h3>
                                <div className="flex flex-wrap gap-2">
                                    {trainer.gyms.map(gym => (
                                        <div key={gym} className="flex items-center gap-2 bg-zinc-800/60 px-3 py-1.5 rounded-lg border border-zinc-700">
                                            <MapPin className="w-4 h-4 text-blue-400" />
                                            <span className="text-sm text-zinc-200 font-medium">{gym}</span>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}

                        {trainer.specialties && trainer.specialties.length > 0 && (
                            <div className="mb-8">
                                <h3 className="text-sm font-bold text-zinc-500 uppercase tracking-wider mb-3">Especialidades</h3>
                                <div className="flex flex-wrap gap-2">
                                    {trainer.specialties.map(s => (
                                        <Badge key={s} className="bg-zinc-800 text-zinc-200 hover:bg-zinc-700 px-3 py-1.5 text-sm font-medium">
                                            {s}
                                        </Badge>
                                    ))}
                                </div>
                            </div>
                        )}

                        {/* Actions Section */}
                        <div className="mt-auto pt-6 border-t border-zinc-800">

                            {status === "NONE" && (
                                <div className="flex flex-col gap-4">
                                    <label className="flex items-start gap-3 cursor-pointer group">
                                        <input
                                            type="checkbox"
                                            checked={dataConsent}
                                            onChange={(e) => setDataConsent(e.target.checked)}
                                            className="mt-0.5 h-4 w-4 rounded border-zinc-600 bg-zinc-800 accent-red-500 cursor-pointer"
                                        />
                                        <span className="text-xs text-zinc-400 group-hover:text-zinc-300 transition-colors">
                                            Autorizo o compartilhamento dos meus dados cadastrais (nome, e-mail e telefone) com este treinador para fins de contato e avaliação do meu perfil.
                                        </span>
                                    </label>
                                    <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center w-full">
                                        <Button
                                            onClick={handleRequest}
                                            disabled={isRequesting || !dataConsent}
                                            className="w-full sm:w-auto bg-red-500 hover:bg-red-600 disabled:opacity-40 text-white font-bold h-12 sm:h-14 px-4 sm:px-8 rounded-xl shadow-lg shadow-red-500/20 text-sm sm:text-lg whitespace-nowrap"
                                        >
                                            {isRequesting ? "Enviando..." : "Solicitar Vaga"}
                                        </Button>
                                        <p className="text-xs text-zinc-500 break-words">
                                            O treinador avaliará o seu perfil antes do aceite final.
                                        </p>
                                    </div>
                                </div>
                            )}

                            {isPending && (
                                <div className="bg-orange-500/10 border border-orange-500/20 rounded-2xl p-6 flex items-start gap-4">
                                    <Mail className="w-8 h-8 text-orange-400 shrink-0" />
                                    <div>
                                        <h4 className="text-orange-400 font-bold mb-1">Solicitação enviada com sucesso!</h4>
                                        <p className="text-orange-500/70 text-sm">O treinador foi notificado no painel PULSO e entrará em contato em breve para realizar a sua entrevista de anamnese.</p>
                                    </div>
                                </div>
                            )}

                            {isAccepted && (
                                <div className="bg-green-500/10 border border-green-500/20 rounded-2xl p-6 space-y-4">
                                    <div className="flex items-start gap-4">
                                        <ShieldCheck className="w-8 h-8 text-green-400 shrink-0" />
                                        <div>
                                            <h4 className="text-green-400 font-bold mb-1">Ele(a) é seu Treinador Oficial!</h4>
                                            <p className="text-green-500/70 text-sm">Vocês já estão conectados no PULSO. Use os contatos abaixo para falar diretamente.</p>
                                        </div>
                                    </div>

                                    <div className="space-y-2 w-full">
                                        <Link href="/dashboard/chat" className="w-full block">
                                            <button className="w-full flex items-center gap-2 sm:gap-3 bg-primary/10 hover:bg-primary/20 border border-primary/30 text-primary font-bold h-12 px-3 sm:px-4 rounded-xl transition-colors">
                                                <MessageCircle className="w-4 h-4 shrink-0" />
                                                <span className="text-sm truncate">Chat</span>
                                                <span className="ml-auto text-xs opacity-70">→</span>
                                            </button>
                                        </Link>

                                        {trainer?.whatsapp_number && (
                                            <button
                                                onClick={openWhatsApp}
                                                className="w-full flex items-center gap-2 sm:gap-3 bg-[#25D366]/10 hover:bg-[#25D366]/20 border border-[#25D366]/30 text-[#25D366] font-bold h-12 px-3 sm:px-4 rounded-xl transition-colors"
                                            >
                                                <Phone className="w-4 h-4 shrink-0" />
                                                <span className="text-sm truncate">{trainer.whatsapp_number}</span>
                                                <span className="ml-auto text-xs opacity-70 shrink-0">WA</span>
                                            </button>
                                        )}
                                        {trainer?.email && (
                                            <a
                                                href={`mailto:${trainer.email}`}
                                                className="w-full flex items-center gap-2 sm:gap-3 bg-zinc-800/60 hover:bg-zinc-700/60 border border-zinc-700 text-zinc-200 font-medium h-12 px-3 sm:px-4 rounded-xl transition-colors"
                                            >
                                                <Mail className="w-4 h-4 shrink-0 text-zinc-400" />
                                                <span className="text-sm truncate">{trainer.email}</span>
                                                <span className="ml-auto text-xs text-zinc-500 shrink-0">E-mail</span>
                                            </a>
                                        )}
                                    </div>
                                </div>
                            )}

                        </div>

                    </div>
                </div>
            </div>
        </div>
    )
}
