"use client"

import Link from "next/link"
import { Button } from "@/components/ui/button"
import { ArrowLeft } from "lucide-react"

export default function LegalPage() {
  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-50 selection:bg-red-500/30">
      <div className="container mx-auto px-4 py-12 max-w-3xl">
        {/* Header */}
        <div className="mb-12">
          <Link href="/">
            <Button variant="ghost" className="text-zinc-400 hover:text-white pl-0 mb-8 hover:bg-transparent">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Voltar para a Home
            </Button>
          </Link>
          <h1 className="text-4xl font-black tracking-tight text-white mb-4">
            Legal & Privacidade
          </h1>
          <p className="text-zinc-400">
            Última atualização: {new Date().toLocaleDateString('pt-BR')}
          </p>
        </div>

        {/* Content */}
        <div className="space-y-16">
          
          {/* Termos de Uso */}
          <section className="space-y-6">
            <h2 className="text-2xl font-bold text-white border-b border-zinc-800 pb-4">
              1. Termos de Uso (Terms of Service)
            </h2>
            
            <div className="space-y-4 text-zinc-300 leading-relaxed">
              <p>
                Bem-vindo ao <strong>PULSO</strong>. Ao utilizar nossa plataforma (aplicativo móvel e painel web), você concorda com os termos descritos abaixo.
              </p>
              
              <h3 className="text-lg font-semibold text-white mt-6">Natureza do Serviço</h3>
              <p>
                O PULSO é uma ferramenta tecnológica de auxílio ao treinamento e monitoramento de performance. <strong>O serviço não substitui, em hipótese alguma, a orientação médica ou de um profissional de educação física presencial.</strong>
              </p>

              <h3 className="text-lg font-semibold text-white mt-6">Responsabilidade do Usuário</h3>
              <p>
                O usuário declara estar apto fisicamente para a prática de exercícios. O usuário é inteiramente responsável pela execução correta dos movimentos e pelo respeito aos seus próprios limites fisiológicos.
              </p>

              <h3 className="text-lg font-semibold text-white mt-6">Isenção de Responsabilidade</h3>
              <p>
                A equipe do PULSO não se responsabiliza por lesões, danos físicos ou problemas de saúde decorrentes do uso da plataforma. Recomendamos fortemente que você consulte um médico antes de iniciar qualquer programa de exercícios.
              </p>
            </div>
          </section>

          {/* Política de Privacidade */}
          <section className="space-y-6">
            <h2 className="text-2xl font-bold text-white border-b border-zinc-800 pb-4">
              2. Política de Privacidade (Privacy Policy)
            </h2>
            
            <div className="space-y-4 text-zinc-300 leading-relaxed">
              <p>
                Sua privacidade é fundamental para nós. Esta política descreve como coletamos, usamos e protegemos seus dados, em conformidade com a LGPD (Lei Geral de Proteção de Dados).
              </p>

              <h3 className="text-lg font-semibold text-white mt-6">Dados Coletados</h3>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Dados de Identificação:</strong> Nome completo, endereço de e-mail e número de telefone (WhatsApp).</li>
                <li><strong>Dados de Saúde e Performance:</strong> Frequência cardíaca (via dispositivos Bluetooth), peso, altura, idade e histórico de treinos.</li>
              </ul>

              <h3 className="text-lg font-semibold text-white mt-6">Finalidade do Uso</h3>
              <p>
                Utilizamos seus dados exclusivamente para:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Monitorar sua performance em tempo real durante os treinos.</li>
                <li>Calcular métricas fisiológicas como gasto calórico e carga de treinamento.</li>
                <li>Permitir que seu treinador (caso vinculado) acompanhe seu progresso.</li>
              </ul>

              <h3 className="text-lg font-semibold text-white mt-6">Compartilhamento de Dados</h3>
              <p>
                <strong>Seus dados não são vendidos a terceiros.</strong> Compartilhamos suas informações de treino apenas com o Treinador que você escolheu vincular à sua conta.
              </p>

              <h3 className="text-lg font-semibold text-white mt-6">Seus Direitos</h3>
              <p>
                Você pode solicitar a exportação ou a exclusão completa da sua conta e de todos os seus dados a qualquer momento através das configurações do aplicativo ou entrando em contato com nosso suporte.
              </p>
            </div>
          </section>

        </div>
        
        {/* Footer */}
        <div className="mt-24 pt-8 border-t border-zinc-900 text-center text-zinc-500 text-sm">
          &copy; {new Date().getFullYear()} PULSO Performance. Todos os direitos reservados.
        </div>
      </div>
    </div>
  )
}
