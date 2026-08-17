"use client"

import { useState } from "react"
import Link from "next/link"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { getImageUrl } from "@/lib/utils"
import { TrainerMarketplaceItem } from "@/lib/api"
import {
    ShieldCheck,
    Star,
    MessageCircle,
    ArrowRight,
    CheckCircle2,
    Dumbbell,
    MapPin,
    Video,
} from "lucide-react"

interface Props {
    trainer: TrainerMarketplaceItem | null
    trainerId: string
}

export default function PublicTrainerClient({ trainer, trainerId }: Props) {
    const [whatsappClicked, setWhatsappClicked] = useState(false)

    if (!trainer) {
        return (
            <div className="min-h-screen bg-zinc-950 flex flex-col items-center justify-center px-4 text-center">
                <div className="bg-zinc-900 border border-zinc-800 rounded-3xl p-12 max-w-md w-full">
                    <ShieldCheck className="w-16 h-16 text-zinc-600 mx-auto mb-4" />
                    <h1 className="text-2xl font-black text-white mb-2">Perfil não encontrado</h1>
                    <p className="text-zinc-400 mb-6">Este treinador pode ter removido o perfil público ou o link está incorreto.</p>
                    <Link href="/">
                        <Button className="bg-primary text-black font-bold">Conhecer o PULSO</Button>
                    </Link>
                </div>
            </div>
        )
    }

    const displayName = trainer.brand_name || trainer.full_name
    const initials = trainer.full_name.substring(0, 2).toUpperCase()

    function openWhatsApp() {
        if (trainer?.whatsapp_number) {
            setWhatsappClicked(true)
            window.open(`https://wa.me/${trainer.whatsapp_number.replace(/\D/g, '')}`, "_blank")
        }
    }

    return (
        <div className="min-h-screen bg-zinc-950 text-white">

            {/* Top bar */}
            <header className="fixed top-0 left-0 right-0 z-50 bg-zinc-950/80 backdrop-blur-md border-b border-zinc-800/60">
                <div className="max-w-4xl mx-auto px-4 h-14 flex items-center justify-between">
                    <Link href="/" className="text-primary font-black text-lg tracking-tight">
                        PULSO
                    </Link>
                    <Link href={`/register`}>
                        <Button size="sm" className="bg-primary text-black font-bold text-xs h-8 px-4 rounded-full">
                            Criar conta grátis
                        </Button>
                    </Link>
                </div>
            </header>

            <main className="pt-14 pb-24">
                {/* Hero Banner */}
                <div className="relative h-48 sm:h-64 md:h-80 bg-zinc-900 overflow-hidden">
                    {trainer.logo_url ? (
                        <>
                            <img
                                src={getImageUrl(trainer.logo_url)}
                                alt={`${displayName} cover`}
                                className="w-full h-full object-cover"
                            />
                            <div className="absolute inset-0 bg-gradient-to-t from-zinc-950 via-zinc-950/50 to-zinc-950/20" />
                        </>
                    ) : (
                        <div className="w-full h-full bg-gradient-to-br from-zinc-800 via-zinc-900 to-zinc-950" />
                    )}
                </div>

                {/* Avatar floating over banner */}
                <div className="max-w-4xl mx-auto px-4 md:px-8">
                    <div className="relative -mt-12 mb-4 flex items-end justify-between">
                        {/* Avatar */}
                        <div className="h-24 w-24 sm:h-28 sm:w-28 rounded-2xl border-4 border-zinc-950 shadow-2xl bg-zinc-800 overflow-hidden flex-shrink-0">
                            {trainer.photo_url ? (
                                <img
                                    src={getImageUrl(trainer.photo_url)}
                                    alt={trainer.full_name}
                                    className="w-full h-full object-cover"
                                />
                            ) : (
                                <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-primary/30 to-primary/10">
                                    <span className="text-3xl font-black text-white">{initials}</span>
                                </div>
                            )}
                        </div>

                        {/* Rating badge */}
                        <div className="flex items-center gap-1.5 bg-zinc-900 border border-zinc-800 rounded-xl px-3 py-2 mb-1">
                            <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                            <span className="text-sm font-bold text-white">5.0</span>
                        </div>
                    </div>

                    {/* Name & Bio */}
                    <div className="mb-6">
                        <h1 className="text-2xl sm:text-3xl md:text-4xl font-black text-white tracking-tight leading-tight">
                            {displayName}
                        </h1>
                        {trainer.brand_name && (
                            <p className="text-zinc-400 text-sm sm:text-base mt-1">{trainer.full_name}</p>
                        )}
                    </div>

                    {trainer.bio && (
                        <p className="text-zinc-300 leading-relaxed mb-6 text-sm sm:text-base">
                            {trainer.bio}
                        </p>
                    )}

                    {/* Modality */}
                    {trainer.modality && (
                        <div className="mb-6">
                            <p className="text-xs font-bold text-zinc-500 uppercase tracking-wider mb-3">Modalidade</p>
                            <div className="inline-flex items-center gap-2 bg-zinc-900 border border-zinc-800 rounded-xl px-3 py-2">
                                {trainer.modality === 'presencial' && <MapPin className="w-4 h-4 text-blue-400" />}
                                {trainer.modality === 'online' && <Video className="w-4 h-4 text-purple-400" />}
                                {trainer.modality === 'hibrido' && <MapPin className="w-4 h-4 text-orange-400" />}
                                <span className="text-sm font-semibold text-white">
                                    {trainer.modality === 'presencial' && 'Presencial'}
                                    {trainer.modality === 'online' && 'Online'}
                                    {trainer.modality === 'hibrido' && 'Híbrido'}
                                </span>
                            </div>
                        </div>
                    )}

                    {/* Gyms */}
                    {trainer.gyms && trainer.gyms.length > 0 && (
                        <div className="mb-6">
                            <p className="text-xs font-bold text-zinc-500 uppercase tracking-wider mb-3">Locais de Atendimento</p>
                            <div className="flex flex-wrap gap-2">
                                {trainer.gyms.map(gym => (
                                    <Badge key={gym} className="bg-zinc-800 text-zinc-200 border-zinc-700 hover:bg-zinc-700 px-3 py-1.5 text-xs sm:text-sm font-medium flex items-center gap-1.5">
                                        <MapPin className="w-3 h-3" />
                                        {gym}
                                    </Badge>
                                ))}
                            </div>
                        </div>
                    )}

                    {/* Info cards row */}
                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 mb-6">
                        {trainer.hourly_rate && (
                            <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
                                <p className="text-zinc-500 text-xs font-bold uppercase tracking-wider mb-1">Valor / hora</p>
                                <p className="text-xl sm:text-2xl font-black text-primary">
                                    R$ {Number(trainer.hourly_rate).toFixed(0)}
                                </p>
                            </div>
                        )}
                        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 flex items-center gap-2">
                            <CheckCircle2 className="w-4 h-4 text-blue-400 shrink-0" />
                            <p className="text-xs text-white font-semibold leading-tight">Coach PULSO Certificado</p>
                        </div>
                        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 flex items-center gap-2">
                            <Dumbbell className="w-4 h-4 text-primary shrink-0" />
                            <p className="text-xs text-white font-semibold leading-tight">Treinos via App</p>
                        </div>
                    </div>

                    {/* Specialties */}
                    {trainer.specialties && trainer.specialties.length > 0 && (
                        <div className="mb-6">
                            <p className="text-xs font-bold text-zinc-500 uppercase tracking-wider mb-3">Especialidades</p>
                            <div className="flex flex-wrap gap-2">
                                {trainer.specialties.map((s) => (
                                    <Badge key={s} className="bg-zinc-800 text-zinc-200 border-zinc-700 hover:bg-zinc-700 px-3 py-1.5 text-xs sm:text-sm font-medium">
                                        {s}
                                    </Badge>
                                ))}
                            </div>
                        </div>
                    )}

                    {/* CTA Section */}
                    <div className="border-t border-zinc-800 pt-6 space-y-4">
                        <p className="text-zinc-400 text-sm">
                            Quer treinar com <span className="text-white font-semibold">{displayName}</span>? Crie sua conta no PULSO e envie uma solicitação de vaga.
                        </p>

                        <div className="flex flex-col sm:flex-row gap-3">
                            <Link href={`/register?ref=trainer&trainer_id=${trainerId}`} className="flex-1 hidden md:block">
                                <Button className="w-full bg-primary hover:bg-primary/90 text-black font-bold h-12 rounded-xl text-base shadow-lg shadow-primary/20">
                                    Quero treinar com {trainer.brand_name ? trainer.brand_name.split(' ')[0] : trainer.full_name.split(' ')[0]}
                                    <ArrowRight className="ml-2 h-4 w-4" />
                                </Button>
                            </Link>

                            {trainer.whatsapp_number && (
                                <Button
                                    onClick={openWhatsApp}
                                    variant="outline"
                                    className="sm:w-auto bg-[#25D366]/10 border-[#25D366]/30 text-[#25D366] hover:bg-[#25D366]/20 hover:border-[#25D366]/50 font-bold h-12 rounded-xl"
                                >
                                    <MessageCircle className="mr-2 h-4 w-4" />
                                    WhatsApp
                                </Button>
                            )}
                        </div>

                        {whatsappClicked && (
                            <p className="text-xs text-zinc-500">
                                Já falou pelo WhatsApp? Crie sua conta no PULSO para acompanhar seus treinos de forma profissional.
                            </p>
                        )}
                    </div>
                </div>
            </main>

            {/* Fixed bottom CTA — mobile only */}
            <div className="fixed bottom-0 left-0 right-0 bg-zinc-900/95 backdrop-blur-md border-t border-zinc-800 p-4 md:hidden">
                <Link href={`/register?ref=trainer&trainer_id=${trainerId}`}>
                    <Button className="w-full bg-primary text-black font-bold h-12 rounded-xl text-base">
                        Treinar com {trainer.brand_name ? trainer.brand_name.split(' ')[0] : trainer.full_name.split(' ')[0]} no PULSO
                        <ArrowRight className="ml-2 h-4 w-4" />
                    </Button>
                </Link>
            </div>
        </div>
    )
}
