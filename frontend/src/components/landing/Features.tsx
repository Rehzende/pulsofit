"use client"

import { motion } from "framer-motion"
import { Activity, User, Award } from "lucide-react"

const features = [
    {
        icon: Activity,
        title: "Biofeedback em Tempo Real",
        description: "Conecte cintas cardíacas (Magene/Polar) e veja o esforço real do seu aluno à distância. Ajuste a intensidade na hora.",
        color: "text-red-500",
        bg: "bg-red-500/10",
        border: "border-red-500/20"
    },
    {
        icon: User,
        title: "Mapa de Recuperação",
        description: "Nossa IA analisa a fadiga muscular e gera um mapa de calor corporal automático. Saiba exatamente o que treinar.",
        color: "text-blue-500",
        bg: "bg-blue-500/10",
        border: "border-blue-500/20"
    },
    {
        icon: Award,
        title: "White Label",
        description: "Sua marca, suas cores. O aluno baixa o app e vê o SEU logo. Profissionalismo de alto nível para sua consultoria.",
        color: "text-yellow-500",
        bg: "bg-yellow-500/10",
        border: "border-yellow-500/20"
    }
]

export function Features() {
    return (
        <section id="features" className="py-24 bg-zinc-950 relative">
            <div className="container mx-auto px-4">
                <div className="text-center mb-16">
                    <h2 className="text-3xl lg:text-5xl font-black text-white mb-4">
                        Por que escolher o <span className="text-red-500">PULSO?</span>
                    </h2>
                    <p className="text-zinc-400 text-lg max-w-2xl mx-auto">
                        Ferramentas exclusivas que colocam sua consultoria anos à frente da concorrência.
                    </p>
                </div>

                <div className="grid md:grid-cols-3 gap-8">
                    {features.map((feature, i) => (
                        <motion.div
                            key={i}
                            initial={{ opacity: 0, y: 20 }}
                            whileInView={{ opacity: 1, y: 0 }}
                            viewport={{ once: true }}
                            transition={{ delay: i * 0.2 }}
                            className={`p-8 rounded-3xl bg-zinc-900/50 border ${feature.border} hover:bg-zinc-900 transition-colors group`}
                        >
                            <div className={`w-14 h-14 rounded-2xl ${feature.bg} flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300`}>
                                <feature.icon className={`w-7 h-7 ${feature.color}`} />
                            </div>
                            <h3 className="text-xl font-bold text-white mb-4">{feature.title}</h3>
                            <p className="text-zinc-400 leading-relaxed">
                                {feature.description}
                            </p>
                        </motion.div>
                    ))}
                </div>
            </div>
        </section>
    )
}
