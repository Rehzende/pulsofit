"use client"

import { Navbar } from "@/components/landing/Navbar"
import { Footer } from "@/components/landing/Footer"
import { Button } from "@/components/ui/button"
import { motion } from "framer-motion"
import { ArrowRight, Star, Activity, CheckCircle2, Zap, Shield, TrendingUp, Heart, Users, Zap as ZapIcon, ChevronDown, MapPin, Video, Users2 } from "lucide-react"
import Link from "next/link"
import { useState } from "react"

// --- Animation Helpers ---
const fadeUp = {
  hidden: { opacity: 0, y: 30 },
  show: { opacity: 1, y: 0, transition: { duration: 0.7, ease: "easeOut" as const } },
}

const stagger = {
  hidden: {},
  show: { transition: { staggerChildren: 0.1 } },
}

export default function LandingPage() {
  const [expandedFaq, setExpandedFaq] = useState<number | null>(null)

  return (
    <div className="min-h-screen bg-background text-foreground selection:bg-primary/30 overflow-x-hidden">
      <Navbar />

      <main>
        {/* ==========================================
         * HERO SECTION — ROLE SELECTION
         * ========================================== */}
        <section className="relative pt-28 pb-20 overflow-hidden">

          {/* Ambient Background */}
          <div className="absolute inset-0 -z-10">
            <div className="absolute top-[-20%] left-[10%] w-[600px] h-[600px] bg-primary/10 rounded-full blur-[120px]" />
            <div className="absolute bottom-[-10%] right-[5%] w-[400px] h-[400px] bg-accent/8 rounded-full blur-[100px]" />
            <div className="absolute top-[30%] right-[25%] w-[300px] h-[300px] bg-purple-500/5 rounded-full blur-[80px]" />
          </div>

          <div
            className="absolute inset-0 -z-10 opacity-[0.02]"
            style={{
              backgroundImage: `linear-gradient(hsl(266 70% 55% / 0.5) 1px, transparent 1px), linear-gradient(90deg, hsl(266 70% 55% / 0.5) 1px, transparent 1px)`,
              backgroundSize: '60px 60px'
            }}
          />

          <div className="container mx-auto px-4">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              className="text-center mb-16"
            >
              <div className="inline-flex items-center gap-2.5 px-4 py-2 rounded-full bg-primary/10 border border-primary/25 mb-6 backdrop-blur-sm">
                <span className="relative flex h-2 w-2">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-2 w-2 bg-primary"></span>
                </span>
                <span className="text-xs font-bold text-primary tracking-widest uppercase">IA + IoT + Sensores em Tempo Real</span>
              </div>

              <h1 className="text-5xl lg:text-7xl font-bold leading-[1.05] tracking-tight mb-6">
                Seu Corpo.{" "}
                <span className="gradient-text">
                  Seus Dados.
                </span>
                <br />
                <span className="text-foreground/90">
                  Seu Ritmo.
                </span>
              </h1>

              <p className="text-lg text-muted-foreground mb-12 leading-relaxed max-w-2xl mx-auto">
                A plataforma definitiva de performance. Escolha seu caminho: conecte-se com um treinador ou treine gratuitamente usando sensores. Monitore seus dados em tempo real.
              </p>

              {/* Role Selection CTAs */}
              <motion.div
                variants={stagger}
                initial="hidden"
                animate="show"
                className="grid md:grid-cols-2 gap-6 max-w-3xl mx-auto"
              >
                {/* Aluno com Treinador */}
                <motion.div variants={fadeUp} className="relative group">
                  <div className="absolute inset-0 bg-gradient-to-r from-primary/20 to-purple-500/10 rounded-2xl blur-xl group-hover:blur-2xl transition-all" />
                  <Link href="/register?role=student" className="relative block">
                    <div className="rounded-2xl border border-primary/30 bg-card/50 backdrop-blur-xl p-8 hover:border-primary/50 hover:bg-card/80 transition-all duration-300">
                      <div className="w-14 h-14 rounded-2xl bg-primary/20 flex items-center justify-center mb-4 mx-auto">
                        <Users2 className="w-7 h-7 text-primary" />
                      </div>
                      <h3 className="text-xl font-bold text-foreground mb-2">Com Treinador</h3>
                      <p className="text-sm text-muted-foreground mb-6">Conecte-se com um profissional. Ele acompanha seu progresso em tempo real via app</p>
                      <Button className="w-full bg-primary hover:bg-primary/90 h-12 rounded-lg font-semibold group-hover:scale-105 transition-transform">
                        Começar Grátis <ArrowRight className="ml-2 h-4 w-4" />
                      </Button>
                      <div className="mt-4 pt-4 border-t border-border/50">
                        <p className="text-xs text-muted-foreground text-center">
                          ✓ Acesso grátis ao app • 🔐 Google Sign-In
                        </p>
                      </div>
                    </div>
                  </Link>
                </motion.div>

                {/* Solo Mode */}
                <motion.div variants={fadeUp} className="relative group">
                  <div className="absolute inset-0 bg-gradient-to-r from-accent/20 to-green-500/10 rounded-2xl blur-xl group-hover:blur-2xl transition-all" />
                  <Link href="/register?role=student&mode=solo" className="relative block">
                    <div className="rounded-2xl border border-accent/30 bg-card/50 backdrop-blur-xl p-8 hover:border-accent/50 hover:bg-card/80 transition-all duration-300">
                      <div className="w-14 h-14 rounded-2xl bg-accent/20 flex items-center justify-center mb-4 mx-auto">
                        <Activity className="w-7 h-7 text-accent" />
                      </div>
                      <h3 className="text-xl font-bold text-foreground mb-2">100% Gratuito</h3>
                      <p className="text-sm text-muted-foreground mb-6">Treine sozinho. Conecte sensores e monitore frequência cardíaca em tempo real</p>
                      <Button className="w-full bg-accent hover:bg-accent/90 h-12 rounded-lg font-semibold text-accent-foreground group-hover:scale-105 transition-transform">
                        Começar Grátis <ArrowRight className="ml-2 h-4 w-4" />
                      </Button>
                      <div className="mt-4 pt-4 border-t border-border/50">
                        <p className="text-xs text-muted-foreground text-center">
                          ✓ Acesso completo • Sem limites
                        </p>
                      </div>
                    </div>
                  </Link>
                </motion.div>
              </motion.div>

              {/* Trainer CTA */}
              <motion.div variants={fadeUp} className="mt-8">
                <p className="text-muted-foreground mb-4">Você é treinador?</p>
                <Link href="/register?role=trainer">
                  <Button
                    variant="outline"
                    size="lg"
                    className="border-border/60 bg-card/40 text-foreground/80 hover:bg-card hover:text-foreground hover:border-primary/30 font-semibold h-12 px-8 rounded-full backdrop-blur-sm"
                  >
                    Criar Perfil de Treinador
                  </Button>
                </Link>
              </motion.div>
            </motion.div>
          </div>
        </section>

        {/* ==========================================
         * COMO FUNCIONA
         * ========================================== */}
        <section className="py-28 relative">
          <div className="absolute inset-0 -z-10">
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[80%] h-[60%] bg-primary/5 rounded-full blur-[100px]" />
          </div>

          <div className="container mx-auto px-4">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              viewport={{ once: true }}
              className="text-center mb-20"
            >
              <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-primary/10 border border-primary/25 text-primary text-xs font-bold tracking-widest uppercase mb-6">
                <ZapIcon className="w-3 h-3" /> Como Funciona
              </div>
              <h2 className="text-4xl lg:text-6xl font-bold text-foreground mb-5">
                Seu caminho,{" "}
                <span className="gradient-text">em 3 passos.</span>
              </h2>
            </motion.div>

            <motion.div
              variants={stagger}
              initial="hidden"
              whileInView="show"
              viewport={{ once: true }}
              className="grid md:grid-cols-3 gap-8"
            >
              {/* Aluno + Treinador */}
              <motion.div variants={fadeUp} className="card-glow rounded-2xl p-8 relative overflow-hidden">
                <div className="absolute top-0 right-0 w-20 h-20 bg-primary/10 rounded-full blur-2xl" />
                <div className="relative">
                  <div className="w-12 h-12 rounded-2xl bg-primary/15 flex items-center justify-center mb-6">
                    <Users2 className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="text-xl font-bold text-foreground mb-4">Com Treinador</h3>
                  <ol className="space-y-3 text-sm text-muted-foreground">
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-primary flex-shrink-0">1.</span>
                      <span>Crie sua conta grátis no app</span>
                    </li>
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-primary flex-shrink-0">2.</span>
                      <span>Procure um treinador no marketplace (presencial/online)</span>
                    </li>
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-primary flex-shrink-0">3.</span>
                      <span>Contrate e conecte-se ao seu treinador</span>
                    </li>
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-primary flex-shrink-0">4.</span>
                      <span>Conecte sensor (Polar/Magene) e comece os treinos</span>
                    </li>
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-primary flex-shrink-0">5.</span>
                      <span>Seu treinador acompanha seus dados em tempo real</span>
                    </li>
                  </ol>
                </div>
              </motion.div>

              {/* Solo */}
              <motion.div variants={fadeUp} className="card-glow rounded-2xl p-8 relative overflow-hidden">
                <div className="absolute top-0 right-0 w-20 h-20 bg-accent/10 rounded-full blur-2xl" />
                <div className="relative">
                  <div className="w-12 h-12 rounded-2xl bg-accent/15 flex items-center justify-center mb-6">
                    <Activity className="w-6 h-6 text-accent" />
                  </div>
                  <h3 className="text-xl font-bold text-foreground mb-4">Treino Solo</h3>
                  <ol className="space-y-3 text-sm text-muted-foreground">
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-accent flex-shrink-0">1.</span>
                      <span>Escolha "Treino Solo" e crie sua conta</span>
                    </li>
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-accent flex-shrink-0">2.</span>
                      <span>Conecte seu sensor HR (Bluetooth)</span>
                    </li>
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-accent flex-shrink-0">3.</span>
                      <span>Comece seu treino — dados em tempo real</span>
                    </li>
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-accent flex-shrink-0">4.</span>
                      <span>Receba análise IA após o treino</span>
                    </li>
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-accent flex-shrink-0">5.</span>
                      <span>Acompanhe evolução em dashboard</span>
                    </li>
                  </ol>
                </div>
              </motion.div>

              {/* Treinador */}
              <motion.div variants={fadeUp} className="card-glow rounded-2xl p-8 relative overflow-hidden">
                <div className="absolute top-0 right-0 w-20 h-20 bg-purple-500/10 rounded-full blur-2xl" />
                <div className="relative">
                  <div className="w-12 h-12 rounded-2xl bg-purple-500/15 flex items-center justify-center mb-6">
                    <Star className="w-6 h-6 text-purple-400" />
                  </div>
                  <h3 className="text-xl font-bold text-foreground mb-4">Sou Personal Trainer</h3>
                  <ol className="space-y-3 text-sm text-muted-foreground">
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-purple-400 flex-shrink-0">1.</span>
                      <span>Crie perfil de treinador</span>
                    </li>
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-purple-400 flex-shrink-0">2.</span>
                      <span>Configure marca, especialidades, modalidade e preço</span>
                    </li>
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-purple-400 flex-shrink-0">3.</span>
                      <span>Apareça no marketplace (presencial/online/híbrido)</span>
                    </li>
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-purple-400 flex-shrink-0">4.</span>
                      <span>Alunos encontram e contratam você (negocie o preço)</span>
                    </li>
                    <li className="flex items-start gap-3">
                      <span className="font-bold text-purple-400 flex-shrink-0">5.</span>
                      <span>Use IA e dados em tempo real para treinar melhor</span>
                    </li>
                  </ol>
                </div>
              </motion.div>
            </motion.div>
          </div>
        </section>

        {/* ==========================================
         * STATS BAR
         * ========================================== */}
        <section className="py-12 border-y border-border/40 bg-card/30 backdrop-blur-sm">
          <div className="container mx-auto px-4">
            <motion.div
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              transition={{ duration: 0.6 }}
              viewport={{ once: true }}
              className="grid grid-cols-2 lg:grid-cols-4 gap-8 text-center"
            >
              {[
                { icon: Users, value: "Milhares", label: "de Atletas Ativos" },
                { icon: Star, value: "200+", label: "Treinadores Verificados" },
                { icon: Heart, value: "98%", label: "Retenção" },
                { icon: TrendingUp, value: "4.9★", label: "App Store" },
              ].map((stat, i) => (
                <div key={i} className="group">
                  <div className="flex justify-center mb-2">
                    <stat.icon className="w-6 h-6 text-primary/60" />
                  </div>
                  <div className="text-3xl lg:text-4xl font-bold gradient-text-primary mb-1">{stat.value}</div>
                  <div className="text-sm text-muted-foreground font-medium">{stat.label}</div>
                </div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ==========================================
         * MARKETPLACE SECTION COM MODALIDADES
         * ========================================== */}
        <section className="py-28 overflow-hidden relative">
          <div className="absolute inset-0 -z-10">
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[80%] h-[60%] bg-primary/5 rounded-full blur-[100px]" />
          </div>

          <div className="container mx-auto px-4 mb-16 text-center">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              viewport={{ once: true }}
            >
              <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-accent/10 border border-accent/25 text-accent text-xs font-bold tracking-widest uppercase mb-6">
                <Zap className="w-3 h-3" /> Marketplace
              </div>
              <h2 className="text-4xl lg:text-6xl font-bold text-foreground mb-5">
                Encontre seu{" "}
                <span className="gradient-text">Mentor Perfeito.</span>
              </h2>
              <p className="text-muted-foreground text-lg max-w-2xl mx-auto">
                Conecte-se com treinadores especializados. Filtre por objetivo, modalidade (presencial, online, híbrido) e avaliações.
              </p>

              {/* Modalidade Filter */}
              <motion.div initial={{ opacity: 0, y: 10 }} whileInView={{ opacity: 1, y: 10 }} transition={{ delay: 0.3 }} viewport={{ once: true }} className="mt-8 flex gap-3 justify-center flex-wrap">
                {[
                  { icon: MapPin, label: "Presencial", color: "from-primary" },
                  { icon: Video, label: "Online", color: "from-accent" },
                  { icon: Users2, label: "Híbrido", color: "from-purple-500" },
                ].map((mode) => (
                  <button key={mode.label} className={`flex items-center gap-2 px-5 py-2.5 rounded-full border border-border/50 hover:border-primary/50 bg-card/50 hover:bg-card transition-all text-sm font-semibold`}>
                    <mode.icon className="w-4 h-4" />
                    {mode.label}
                  </button>
                ))}
              </motion.div>
            </motion.div>
          </div>

          {/* Marquee */}
          <div className="relative w-full overflow-hidden">
            <div className="absolute left-0 top-0 bottom-0 w-24 lg:w-48 bg-gradient-to-r from-background to-transparent z-10 pointer-events-none" />
            <div className="absolute right-0 top-0 bottom-0 w-24 lg:w-48 bg-gradient-to-l from-background to-transparent z-10 pointer-events-none" />
            <div className="flex gap-5 animate-marquee" style={{ width: 'max-content' }}>
              {[
                { initial: 'R', name: 'Rafael Costa', tags: ['Hipertrofia', 'Força'], rating: '5.0', specialty: 'Performance', modality: '🏢 Presencial' },
                { initial: 'M', name: 'Marina Lima', tags: ['Funcional', 'HIIT'], rating: '4.9', specialty: 'Condicionamento', modality: '💻 Online' },
                { initial: 'A', name: 'André Souza', tags: ['Corrida', 'Resistência'], rating: '5.0', specialty: 'Endurance', modality: '🔄 Híbrido' },
                { initial: 'J', name: 'Juliana Neves', tags: ['Yoga', 'Pilates'], rating: '4.8', specialty: 'Bem-estar', modality: '🏢 Presencial' },
                { initial: 'L', name: 'Lucas Mendes', tags: ['Crossfit', 'Potência'], rating: '5.0', specialty: 'Força', modality: '💻 Online' },
                { initial: 'B', name: 'Bianca Torres', tags: ['Spinning', 'Aeróbico'], rating: '4.9', specialty: 'Cardio', modality: '🔄 Híbrido' },
                { initial: 'R', name: 'Rafael Costa', tags: ['Hipertrofia', 'Força'], rating: '5.0', specialty: 'Performance', modality: '🏢 Presencial' },
                { initial: 'M', name: 'Marina Lima', tags: ['Funcional', 'HIIT'], rating: '4.9', specialty: 'Condicionamento', modality: '💻 Online' },
              ].map((trainer, i) => (
                <div
                  key={i}
                  className="w-[280px] card-glow rounded-2xl p-5 flex-shrink-0 hover:border-primary/40 hover:shadow-[0_0_40px_hsla(266,70%,55%,0.12)] transition-all duration-300 cursor-pointer group"
                >
                  <div className="flex items-center gap-4 mb-4">
                    <div
                      className="w-12 h-12 rounded-xl flex items-center justify-center text-base font-bold text-white shadow-lg"
                      style={{ background: `linear-gradient(135deg, hsl(${246 + (i % 5) * 20}, 70%, 55%) 0%, hsl(${270 + (i % 5) * 15}, 65%, 65%) 100%)` }}
                    >
                      {trainer.initial}
                    </div>
                    <div>
                      <h3 className="font-bold text-foreground text-sm group-hover:text-primary transition-colors">{trainer.name}</h3>
                      <div className="flex items-center gap-1 text-yellow-400 text-xs mt-0.5">
                        <Star className="w-3 h-3 fill-current" />
                        <span className="font-semibold">{trainer.rating}</span>
                        <span className="text-muted-foreground ml-1">• {trainer.specialty}</span>
                      </div>
                    </div>
                  </div>
                  <div className="mb-3 px-2 py-1.5 rounded-lg bg-primary/5 border border-primary/10">
                    <p className="text-xs font-medium text-foreground">{trainer.modality}</p>
                  </div>
                  <div className="flex gap-2 mb-4 flex-wrap">
                    {trainer.tags.map((tag) => (
                      <span key={tag} className="text-[10px] font-bold px-2.5 py-1 rounded-full bg-primary/10 text-primary border border-primary/15">
                        {tag}
                      </span>
                    ))}
                  </div>
                  <Button size="sm" className="w-full bg-primary/10 hover:bg-primary text-primary hover:text-primary-foreground border border-primary/20 rounded-xl transition-all duration-200 text-xs font-bold">
                    Ver Perfil
                  </Button>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* ==========================================
         * TESTIMONIALS
         * ========================================== */}
        <section className="py-28 relative">
          <div className="absolute inset-0 -z-10">
            <div className="absolute bottom-0 right-0 w-[500px] h-[500px] bg-primary/5 rounded-full blur-[100px]" />
          </div>

          <div className="container mx-auto px-4">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              viewport={{ once: true }}
              className="text-center mb-16"
            >
              <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-primary/10 border border-primary/25 text-primary text-xs font-bold tracking-widest uppercase mb-6">
                <Users className="w-3 h-3" /> Depoimentos
              </div>
              <h2 className="text-4xl lg:text-6xl font-bold text-foreground mb-5">
                O que os atletas{" "}
                <span className="gradient-text">dizem sobre nós.</span>
              </h2>
            </motion.div>

            <motion.div
              variants={stagger}
              initial="hidden"
              whileInView="show"
              viewport={{ once: true }}
              className="grid md:grid-cols-3 gap-6"
            >
              {[
                {
                  name: "João Silva",
                  role: "Aluno • 3 meses no PULSO",
                  avatar: "J",
                  rating: 5,
                  text: "Meu treinador acompanha meus dados no app em tempo real. Recebo feedback imediato e mudanças no treino conforme necessário. Já ganhei 5kg de massa magra!",
                },
                {
                  name: "Ana Costa",
                  role: "Aluna • Treino Solo",
                  avatar: "A",
                  rating: 5,
                  text: "Não tenho tempo para treinador, mas o PULSO me dá exatamente o que preciso. O app é intuitivo e os dados são incríveis.",
                },
                {
                  name: "Carlos Mendes",
                  role: "Treinador • 50+ alunos",
                  avatar: "C",
                  rating: 5,
                  text: "O marketplace me trouxe mais alunos. Agora posso oferecer aulas online E presenciais. Faturei 2x desde que entrei.",
                },
              ].map((testimonial, i) => (
                <motion.div key={i} variants={fadeUp} className="card-glow rounded-2xl p-7">
                  <div className="flex items-start justify-between mb-5">
                    <div className="flex items-center gap-3">
                      <div className="w-12 h-12 rounded-full bg-gradient-to-br from-primary to-purple-400 flex items-center justify-center text-sm font-bold text-white">
                        {testimonial.avatar}
                      </div>
                      <div>
                        <h4 className="font-bold text-foreground text-sm">{testimonial.name}</h4>
                        <p className="text-xs text-muted-foreground">{testimonial.role}</p>
                      </div>
                    </div>
                  </div>
                  <div className="flex gap-1 mb-4">
                    {Array.from({ length: testimonial.rating }).map((_, i) => (
                      <Star key={i} className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                    ))}
                  </div>
                  <p className="text-muted-foreground text-sm leading-relaxed italic">"{testimonial.text}"</p>
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ==========================================
         * PRICING
         * ========================================== */}
        <section className="py-28 relative">
          <div className="absolute inset-0 -z-10">
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-accent/10 rounded-full blur-[120px]" />
          </div>

          <div className="container mx-auto px-4">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              viewport={{ once: true }}
              className="text-center mb-16"
            >
              <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-accent/10 border border-accent/25 text-accent text-xs font-bold tracking-widest uppercase mb-6">
                <Zap className="w-3 h-3" /> Planos
              </div>
              <h2 className="text-4xl lg:text-6xl font-bold text-foreground mb-5">
                Planos para{" "}
                <span className="gradient-text">Personal Trainers.</span>
              </h2>
              <p className="text-muted-foreground text-lg max-w-2xl mx-auto">
                <strong className="text-foreground">Alunos:</strong> Use o app completamente grátis. Você negocia o preço direto com seu personal. <strong className="text-foreground">Personais:</strong> Estes planos são para gerenciar seus alunos no PULSO.
              </p>
            </motion.div>

            <motion.div
              variants={stagger}
              initial="hidden"
              whileInView="show"
              viewport={{ once: true }}
              className="grid md:grid-cols-3 gap-6 max-w-5xl mx-auto"
            >
              {[
                {
                  name: "Aluno (Grátis)",
                  price: "R$ 0",
                  desc: "Para todos os alunos (com ou sem treinador)",
                  features: [
                    "Conexão com sensores HR (Polar, Magene)",
                    "Diário de treinos completo",
                    "Histórico ilimitado",
                    "Análise após treino (em breve)",
                    "Acesso ao marketplace de treinadores",
                  ],
                  cta: "Começar Grátis",
                  ctaHref: "/register",
                  highlight: false,
                },
                {
                  name: "Personal Pro",
                  price: "R$ 29",
                  period: "/mês",
                  desc: "Para treinar 1-10 alunos • Você define o preço com cada aluno",
                  features: [
                    "Acompanhe até 10 alunos",
                    "Dashboard em tempo real por aluno",
                    "Histórico ilimitado de treinos",
                    "Criação de treino com IA (linguagem natural)",
                    "Alertas de alunos treinando/inativos",
                    "Acesso aos dados biométricos dos alunos",
                    "Vitrine no marketplace de treinadores",
                  ],
                  cta: "Começar Pro",
                  ctaHref: "/register?role=trainer",
                  highlight: true,
                },
                {
                  name: "Personal Elite",
                  price: "R$ 79",
                  period: "/mês",
                  desc: "Para treinar 11+ alunos • Você define o preço com cada aluno",
                  features: [
                    "Alunos ilimitados",
                    "Dashboard avançado com gráficos de performance",
                    "Criação de treinos avançada com IA (linguagem natural)",
                    "Alertas inteligentes de alunos treinando/inativos",
                    "Acesso completo aos dados biométricos dos alunos",
                    "Vitrine destacada no marketplace",
                    "Integração com calendários e API customizada",
                    "Consultor dedicado",
                  ],
                  cta: "Começar Elite",
                  ctaHref: "/register?role=trainer",
                  highlight: false,
                },
              ].map((plan, i) => (
                <motion.div
                  key={i}
                  variants={fadeUp}
                  className={`rounded-2xl p-8 transition-all duration-300 ${
                    plan.highlight
                      ? "card-glow border border-primary/40 relative scale-105"
                      : "card-glow border border-border/50"
                  }`}
                >
                  {plan.highlight && (
                    <div className="absolute -top-4 left-1/2 -translate-x-1/2 px-4 py-1 rounded-full bg-primary text-primary-foreground text-xs font-bold">
                      RECOMENDADO
                    </div>
                  )}
                  <div className="mb-6">
                    <h3 className="text-2xl font-bold text-foreground mb-2">{plan.name}</h3>
                    <p className="text-sm text-muted-foreground">{plan.desc}</p>
                  </div>
                  <div className="mb-8">
                    <span className="text-4xl font-bold text-foreground">{plan.price}</span>
                    {plan.period && <span className="text-muted-foreground text-sm">{plan.period}</span>}
                  </div>
                  <ul className="space-y-3 mb-8">
                    {plan.features.map((feature, j) => (
                      <li key={j} className="flex items-center gap-3 text-sm text-muted-foreground">
                        <CheckCircle2 className="w-4 h-4 text-primary flex-shrink-0" />
                        {feature}
                      </li>
                    ))}
                  </ul>
                  <Link href={plan.ctaHref}>
                    <Button
                      className={`w-full h-12 rounded-lg font-semibold ${
                        plan.highlight
                          ? "bg-primary hover:bg-primary/90 text-primary-foreground"
                          : "bg-primary/10 hover:bg-primary/20 text-primary"
                      }`}
                    >
                      {plan.cta}
                    </Button>
                  </Link>
                </motion.div>
              ))}
            </motion.div>

            <motion.p
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              transition={{ delay: 0.6 }}
              viewport={{ once: true }}
              className="text-center mt-12 text-muted-foreground text-sm"
            >
              ✓ Sem cartão de crédito &nbsp;·&nbsp; ✓ Cancele quando quiser &nbsp;·&nbsp; ✓ 100% seguro
            </motion.p>
          </div>
        </section>

        {/* ==========================================
         * BENEFÍCIOS PARA PERSONALS
         * ========================================== */}
        <section className="py-28 relative overflow-hidden">
          <div className="absolute inset-0 -z-10">
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[80%] h-[60%] bg-primary/5 rounded-full blur-[100px]" />
          </div>

          <div className="container mx-auto px-4">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              viewport={{ once: true }}
              className="text-center mb-16"
            >
              <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-primary/10 border border-primary/25 text-primary text-xs font-bold tracking-widest uppercase mb-6">
                <Star className="w-3 h-3" /> Benefícios
              </div>
              <h2 className="text-4xl lg:text-6xl font-bold text-foreground mb-5">
                Por que usar PULSO como{" "}
                <span className="gradient-text">Personal Trainer.</span>
              </h2>
            </motion.div>

            <motion.div
              variants={stagger}
              initial="hidden"
              whileInView="show"
              viewport={{ once: true }}
              className="grid md:grid-cols-2 lg:grid-cols-4 gap-5"
            >
              {[
                {
                  icon: MapPin,
                  title: "Vitrine no Marketplace",
                  desc: "Apareça para milhares de alunos buscando treinador. Presencial, online ou híbrido.",
                  color: "primary",
                },
                {
                  icon: Zap,
                  title: "IA para Criar Treinos",
                  desc: "Crie treinos em linguagem natural. Ex: 'Treino para hipertrofia de perna com foco em quadríceps'",
                  color: "accent",
                },
                {
                  icon: Activity,
                  title: "Alertas de Alunos",
                  desc: "Receba notificações quando alunos estão treinando ou quando ficar sem treinar por dias.",
                  color: "primary",
                },
                {
                  icon: TrendingUp,
                  title: "Dados em Tempo Real",
                  desc: "Acompanhe frequência cardíaca, performance e recuperação de cada aluno em um dashboard.",
                  color: "accent",
                },
              ].map((benefit, i) => (
                <motion.div
                  key={i}
                  variants={fadeUp}
                  className="card-glow rounded-2xl p-6 group hover:border-primary/30 transition-all duration-300"
                >
                  <div
                    className={`w-10 h-10 rounded-lg mb-4 flex items-center justify-center ${
                      benefit.color === "primary"
                        ? "bg-primary/15 border border-primary/25"
                        : "bg-accent/15 border border-accent/25"
                    }`}
                  >
                    <benefit.icon
                      className={`w-5 h-5 ${benefit.color === "primary" ? "text-primary" : "text-accent"}`}
                    />
                  </div>
                  <h3 className="text-lg font-bold text-foreground mb-2">{benefit.title}</h3>
                  <p className="text-sm text-muted-foreground leading-relaxed">{benefit.desc}</p>
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ==========================================
         * FAQ
         * ========================================== */}
        <section className="py-28 relative">
          <div className="container mx-auto px-4 max-w-2xl">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              viewport={{ once: true }}
              className="text-center mb-16"
            >
              <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-primary/10 border border-primary/25 text-primary text-xs font-bold tracking-widest uppercase mb-6">
                <HelpCircle className="w-3 h-3" /> FAQ
              </div>
              <h2 className="text-4xl lg:text-5xl font-bold text-foreground mb-5">
                Perguntas{" "}
                <span className="gradient-text">Frequentes.</span>
              </h2>
            </motion.div>

            <motion.div
              variants={stagger}
              initial="hidden"
              whileInView="show"
              viewport={{ once: true }}
              className="space-y-4"
            >
              {[
                {
                  q: "Qual sensor de frequência cardíaca devo comprar?",
                  a: "Recomendamos Polar H10 ou Magene H64 (ambas compatíveis via Bluetooth BLE). Qualquer sensor ANT+ também funciona. Começar com um sensor básico é ótimo!",
                },
                {
                  q: "Como funciona a IA no PULSO?",
                  a: "Após cada treino, nossa IA analisa seus dados biométricos e performance para gerar insights personalizados. Análise é apresentada APÓS o treino, não em tempo real.",
                },
                {
                  q: "Posso treinar com treinador E usar o modo solo?",
                  a: "Sim! Você pode ter múltiplos treinos. Alguns com seu treinador (que acompanha em tempo real) e outros solo. Tudo é grátis para alunos.",
                },
                {
                  q: "Qual é o custo para alunos?",
                  a: "Alunos têm acesso completamente grátis ao app! Sensor, diário de treinos, análise — tudo gratuito. Os planos de pagamento são para personais trainers gerenciarem seus alunos.",
                },
                {
                  q: "Como os personals ganham dinheiro?",
                  a: "Você define seu próprio preço com cada aluno (a plataforma não tira nada). Além disso, use Planos Pro/Elite (R$29-79/mês) para gerenciar múltiplos alunos com dashboard, alertas e IA.",
                },
                {
                  q: "Quem define o preço que cobro dos alunos?",
                  a: "Você! Negocie livremente o preço direto com cada aluno. A plataforma PULSO não participa da cobrança — você gerencia isso fora do app.",
                },
                {
                  q: "Meus dados são privados?",
                  a: "100%. Seus dados biométricos são criptografados e nunca compartilhados. Você controla o que seu treinador vê.",
                },
                {
                  q: "Posso usar o app offline?",
                  a: "Sim, o sensor conecta via Bluetooth local. Dados sincronizam quando reconectar à internet.",
                },
              ].map((faq, i) => (
                <motion.div
                  key={i}
                  variants={fadeUp}
                  className="card-glow rounded-2xl overflow-hidden"
                >
                  <button
                    onClick={() => setExpandedFaq(expandedFaq === i ? null : i)}
                    className="w-full p-6 flex items-center justify-between hover:bg-card/60 transition-colors"
                  >
                    <h3 className="text-left font-bold text-foreground">{faq.q}</h3>
                    <ChevronDown
                      className={`w-5 h-5 text-primary transition-transform ${expandedFaq === i ? "rotate-180" : ""}`}
                    />
                  </button>
                  {expandedFaq === i && (
                    <div className="px-6 pb-6 text-muted-foreground text-sm leading-relaxed border-t border-border/50">
                      {faq.a}
                    </div>
                  )}
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        {/* ==========================================
         * CTA FINAL
         * ========================================== */}
        <section className="py-28 relative overflow-hidden">
          <div className="absolute inset-0 -z-10">
            <div className="absolute inset-0 bg-gradient-to-br from-primary/15 via-background to-accent/10" />
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-primary/15 rounded-full blur-[120px]" />
          </div>

          <div className="container mx-auto px-4 text-center relative z-10">
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7 }}
              viewport={{ once: true }}
            >
              <h2 className="text-5xl lg:text-7xl font-bold text-foreground mb-6 leading-tight">
                Sua evolução{" "}
                <span className="gradient-text">começa agora.</span>
              </h2>
              <p className="text-xl text-muted-foreground mb-12 max-w-2xl mx-auto">
                Junte-se a milhares de atletas que já transformaram seu treino com PULSO.
              </p>
              <div className="flex flex-col sm:flex-row justify-center gap-5">
                <Link href="/register?role=student">
                  <Button
                    size="lg"
                    className="bg-primary hover:bg-primary/90 text-primary-foreground font-bold h-16 px-12 rounded-full text-lg glow-primary hover:scale-105 transition-all shadow-2xl"
                  >
                    Sou Aluno — Começar Grátis
                    <ArrowRight className="ml-2 h-5 w-5" />
                  </Button>
                </Link>
                <Link href="/register?role=student&mode=solo">
                  <Button
                    size="lg"
                    variant="outline"
                    className="border-primary/30 text-foreground hover:bg-primary/10 hover:border-primary/50 font-bold h-16 px-12 rounded-full text-lg backdrop-blur-sm"
                  >
                    Treinar Solo
                  </Button>
                </Link>
                <Link href="/register?role=trainer">
                  <Button
                    size="lg"
                    variant="outline"
                    className="border-border/30 text-foreground hover:bg-card hover:border-primary/50 font-bold h-16 px-12 rounded-full text-lg backdrop-blur-sm"
                  >
                    Sou Treinador
                  </Button>
                </Link>
              </div>
              <p className="mt-8 text-sm text-muted-foreground">
                ✓ Alunos grátis &nbsp;·&nbsp; ✓ Personais pagam apenas se gerenciarem muitos alunos &nbsp;·&nbsp; ✓ Sem surpresas
              </p>
            </motion.div>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  )
}

// Import HelpCircle icon
import { HelpCircle } from "lucide-react"
