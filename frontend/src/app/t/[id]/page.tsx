import { Metadata } from "next"
import PublicTrainerClient from "./client"

const API_BASE = (process.env.NEXT_PUBLIC_API_URL || "https://web-production-06662.up.railway.app").replace(/\/+$/, '')

async function fetchTrainer(id: string) {
    try {
        const res = await fetch(`${API_BASE}/api/v1/public/trainers/${id}`, {
            next: { revalidate: 60 },
        })
        if (!res.ok) return null
        return res.json()
    } catch {
        return null
    }
}

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
    const { id } = await params
    const trainer = await fetchTrainer(id)
    if (!trainer) {
        return { title: "Treinador não encontrado | PULSO" }
    }
    const name = trainer.brand_name || trainer.full_name
    const description = trainer.bio
        ? trainer.bio.slice(0, 160)
        : `Conheça ${name} no PULSO e comece sua transformação fitness hoje.`

    return {
        title: `${name} | PULSO`,
        description,
        openGraph: {
            title: `${name} | PULSO`,
            description,
            images: trainer.logo_url ? [trainer.logo_url] : [],
            type: "profile",
        },
        twitter: {
            card: "summary_large_image",
            title: `${name} | PULSO`,
            description,
            images: trainer.logo_url ? [trainer.logo_url] : [],
        },
    }
}

export default async function PublicTrainerPage({ params }: { params: Promise<{ id: string }> }) {
    const { id } = await params
    const trainer = await fetchTrainer(id)
    return <PublicTrainerClient trainer={trainer} trainerId={id} />
}
