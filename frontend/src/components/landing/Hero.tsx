"use client"

import Link from "next/link"
import { Button } from "@/components/ui/button"
import { motion } from "framer-motion"
import { ArrowRight, Activity, Zap } from "lucide-react"

export function Hero() {
    return (
        <section className="relative pt-32 pb-20 lg:pt-48 lg:pb-32 overflow-hidden">
            {/* Background Effects */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-[500px] bg-red-600/20 blur-[120px] rounded-full opacity-20 pointer-events-none" />

            <div className="container mx-auto px-4 relative z-10">
                <div className="flex flex-col lg:flex-row items-center gap-12 lg:gap-20">

                    {/* Text Content */}
                    <motion.div
                        initial={{ opacity: 0, x: -20 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ duration: 0.5 }}
                        className="flex-1 text-center lg:text-left"
                    >
                        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/5 border border-white/10 mb-8">
                            <span className="relative flex h-2 w-2">
                                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
                                <span className="relative inline-flex rounded-full h-2 w-2 bg-red-500"></span>
                            </span>
                            <span className="text-xs font-medium text-zinc-300 tracking-wide uppercase">Novo: Análise de Fadiga com IA</span>
                        </div>

                        <h1 className="text-5xl lg:text-7xl font-black text-white leading-[1.1] tracking-tight mb-6">
                            A Inteligência Artificial que escala sua <span className="text-transparent bg-clip-text bg-gradient-to-r from-red-500 to-orange-600">Consultoria.</span>
                        </h1>

                        <p className="text-lg text-zinc-400 mb-8 leading-relaxed max-w-2xl mx-auto lg:mx-0">
                            Monitore seus alunos em tempo real, gerencie cargas e previna lesões com o primeiro ecossistema de IoT Fitness do Brasil.
                        </p>

                        <div className="flex flex-col sm:flex-row items-center gap-4 justify-center lg:justify-start">
                            <Link href="/register" className="w-full sm:w-auto">
                                <Button size="lg" className="w-full sm:w-auto bg-red-600 hover:bg-red-700 text-white font-bold h-14 px-8 rounded-full text-lg shadow-lg shadow-red-600/20 transition-all hover:scale-105">
                                    Começar Grátis
                                    <ArrowRight className="ml-2 h-5 w-5" />
                                </Button>
                            </Link>
                            <Link href="#how-it-works" className="w-full sm:w-auto">
                                <Button size="lg" variant="outline" className="w-full sm:w-auto border-zinc-800 bg-zinc-900/50 text-white hover:bg-zinc-900 hover:text-white font-semibold h-14 px-8 rounded-full">
                                    Ver Demonstração
                                </Button>
                            </Link>
                        </div>

                        <div className="mt-10 flex items-center justify-center lg:justify-start gap-6 text-zinc-500 text-sm font-medium">
                            <div className="flex items-center gap-2">
                                <Zap className="w-4 h-4 text-zinc-400" />
                                <span>Setup em 2 min</span>
                            </div>
                            <div className="flex items-center gap-2">
                                <Activity className="w-4 h-4 text-zinc-400" />
                                <span>Dados em Tempo Real</span>
                            </div>
                        </div>
                    </motion.div>

                    {/* Visual Mockup */}
                    <motion.div
                        initial={{ opacity: 0, x: 20 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ duration: 0.5, delay: 0.2 }}
                        className="flex-1 relative w-full max-w-[500px] lg:max-w-none"
                    >
                        <div className="relative z-10 bg-zinc-900 border border-zinc-800 rounded-[2.5rem] p-4 shadow-2xl shadow-black/50 rotate-[-6deg] hover:rotate-0 transition-transform duration-500">
                            {/* Mockup Screen */}
                            <div className="bg-black rounded-[2rem] overflow-hidden aspect-[9/19] relative border border-zinc-800">
                                {/* Status Bar */}
                                <div className="h-8 flex justify-between items-center px-6 pt-2">
                                    <span className="text-[10px] font-bold text-white">9:41</span>
                                    <div className="flex gap-1">
                                        <div className="w-4 h-2.5 bg-white rounded-[1px]" />
                                        <div className="w-0.5 h-2.5 bg-white/30 rounded-[1px]" />
                                    </div>
                                </div>

                                {/* App Content */}
                                <div className="p-6 space-y-6">
                                    {/* Header */}
                                    <div className="flex justify-between items-center">
                                        <div>
                                            <h3 className="text-white font-bold text-xl">Olá, Ricardo</h3>
                                            <p className="text-zinc-500 text-xs">Treino de Peito • Em andamento</p>
                                        </div>
                                        <div className="h-10 w-10 rounded-full bg-zinc-800 border border-zinc-700" />
                                    </div>

                                    {/* Heart Rate Card */}
                                    <div className="bg-zinc-900 rounded-2xl p-5 border border-zinc-800 relative overflow-hidden">
                                        <div className="absolute top-0 right-0 p-3 opacity-20">
                                            <Activity className="w-24 h-24 text-red-500" />
                                        </div>
                                        <div className="relative z-10">
                                            <div className="flex items-center gap-2 mb-2">
                                                <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
                                                <span className="text-red-500 text-xs font-bold uppercase tracking-wider">Ao Vivo</span>
                                            </div>
                                            <div className="flex items-baseline gap-2">
                                                <span className="text-5xl font-black text-white">142</span>
                                                <span className="text-zinc-400 font-medium">BPM</span>
                                            </div>
                                            <p className="text-zinc-500 text-xs mt-2">Zona 3 • Aeróbico</p>
                                        </div>
                                    </div>

                                    {/* Body Map Preview */}
                                    <div className="bg-zinc-900 rounded-2xl p-5 border border-zinc-800">
                                        <div className="flex justify-between items-center mb-4">
                                            <span className="text-white font-bold text-sm">Fadiga Muscular</span>
                                            <span className="text-xs text-zinc-500">Hoje</span>
                                        </div>
                                        <div className="flex gap-2">
                                            <div className="flex-1 bg-zinc-950 rounded-xl h-32 relative flex items-center justify-center border border-zinc-800/50">
                                                {/* Abstract Body Shape */}
                                                <div className="w-16 h-24 bg-zinc-800/50 rounded-lg relative">
                                                    <div className="absolute top-2 left-1 right-1 h-6 bg-red-500/40 blur-md rounded-full" />
                                                </div>
                                            </div>
                                            <div className="w-1/3 space-y-2">
                                                <div className="bg-zinc-950 p-2 rounded-lg border border-zinc-800/50">
                                                    <div className="text-[10px] text-zinc-500">Peitoral</div>
                                                    <div className="text-red-400 font-bold text-sm">85%</div>
                                                </div>
                                                <div className="bg-zinc-950 p-2 rounded-lg border border-zinc-800/50">
                                                    <div className="text-[10px] text-zinc-500">Ombros</div>
                                                    <div className="text-orange-400 font-bold text-sm">62%</div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                {/* Bottom Nav */}
                                <div className="absolute bottom-0 left-0 right-0 h-20 bg-zinc-900/90 backdrop-blur border-t border-zinc-800 flex justify-around items-center px-6 pb-4">
                                    <div className="w-6 h-6 rounded-full bg-white/20" />
                                    <div className="w-6 h-6 rounded-full bg-red-500 shadow-[0_0_15px_rgba(239,68,68,0.5)]" />
                                    <div className="w-6 h-6 rounded-full bg-white/20" />
                                </div>
                            </div>
                        </div>

                        {/* Floating Elements */}
                        <motion.div
                            animate={{ y: [0, -10, 0] }}
                            transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
                            className="absolute -top-10 -right-10 bg-zinc-900 p-4 rounded-2xl border border-zinc-800 shadow-xl z-20 hidden lg:block"
                        >
                            <div className="flex items-center gap-3">
                                <div className="h-10 w-10 rounded-full bg-green-500/20 flex items-center justify-center">
                                    <Zap className="w-5 h-5 text-green-500" />
                                </div>
                                <div>
                                    <p className="text-white font-bold text-sm">Novo Recorde!</p>
                                    <p className="text-zinc-500 text-xs">Supino Reto • 100kg</p>
                                </div>
                            </div>
                        </motion.div>
                    </motion.div>
                </div>
            </div>
        </section>
    )
}
