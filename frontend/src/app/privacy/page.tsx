"use client"

import Link from "next/link"
import { Button } from "@/components/ui/button"
import { ArrowLeft } from "lucide-react"

export default function PolicyPage() {
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
            Política de Privacidade
          </h1>
          <p className="text-zinc-400">
            Última atualização: {new Date().toLocaleDateString('pt-BR')}
          </p>
        </div>

        {/* Content */}
        <div className="space-y-16">
          <section className="space-y-6">
            <h2 className="text-2xl font-bold text-white border-b border-zinc-800 pb-4">
              Política de Privacidade (Privacy Policy)
            </h2>
            
            <div className="space-y-4 text-zinc-300 leading-relaxed">
              <p>
                Sua privacidade é fundamental para nós. Esta política descreve como coletamos, usamos e protegemos seus dados, em conformidade com a LGPD (Lei Geral de Proteção de Dados) e com as diretrizes do Google Play.
              </p>

              <h3 className="text-lg font-semibold text-white mt-6">1. Dados Coletados</h3>
              <ul className="list-disc pl-6 space-y-2">
                <li><strong>Dados de Identificação:</strong> Nome completo, endereço de e-mail e número de telefone (usado para criação de conta e login).</li>
                <li><strong>Dados de Saúde e Performance:</strong> Frequência cardíaca (coletada em tempo real caso opte por conectar sensores Bluetooth), peso, altura, histórico de treinos e mapa de recuperação muscular.</li>
                <li><strong>Dados de Dispositivo:</strong> Modelo do aparelho celular e versão do sistema operacional para otimização de performance do App.</li>
              </ul>

              <h3 className="text-lg font-semibold text-white mt-6">2. Finalidade do Uso dos Dados</h3>
              <p>
                Utilizamos seus dados exclusivamente para fornecer a experiência de alta performance do Pulso Fit:
              </p>
              <ul className="list-disc pl-6 space-y-2">
                <li>Processar seu monitoramento cardíaco em tempo real e fornecer métricas fisiológicas avançadas.</li>
                <li>Alimentar o algoritmo de Inteligência Artificial para gerar seu Body Map (Mapa de Recuperação).</li>
                <li>Permitir que o Treinador de Elite (caso você o contrate no Marketplace) visualize seu histórico, adapte seus treinos e interaja via chat.</li>
                <li>Garantir a segurança da conta.</li>
              </ul>

              <h3 className="text-lg font-semibold text-white mt-6">3. Compartilhamento de Dados</h3>
              <p>
                <strong>Nós não vendemos seus dados para terceiros, sob nenhuma hipótese.</strong>
                <br /><br />
                As informações detalhadas do seu treino e sua métrica fisiológica são compartilhadas única e estritamente com o Treinador que <strong>você escolheu vincular</strong> à sua conta.
              </p>

              <h3 className="text-lg font-semibold text-white mt-6">4. Política de Exclusão de Dados</h3>
              <p>
                O usuário tem o controle total de sua conta. Você pode, a qualquer momento, revogar acessos ou solicitar a exclusão de todos os seus dados.
              </p>
              <p className="mt-2">
                <strong>No Aplicativo:</strong> Acesse Configurações &gt; Perfil &gt; Excluir Conta.
                <br />
                <strong>Na Web:</strong> Solicite a deleção diretamente pelo nosso suporte ou páginas de Gerenciamento da Conta. Toda a base de dados do usuário (histórico, credenciais e métricas corporais) será removida permanentemente.
              </p>

              <h3 className="text-lg font-semibold text-white mt-6">5. Contato</h3>
              <p>
                Caso tenha dúvidas sobre como manipulamos seus dados para manter sua experiência Dark Premium segura e eficiente, entre em contato conosco pelos canais oficiais de suporte do aplicativo.
              </p>
            </div>
          </section>
        </div>
        
        {/* Footer */}
        <div className="mt-24 pt-8 border-t border-zinc-900 text-center text-zinc-500 text-sm">
          &copy; {new Date().getFullYear()} PULSO Fit. Todos os direitos reservados.
        </div>
      </div>
    </div>
  )
}
