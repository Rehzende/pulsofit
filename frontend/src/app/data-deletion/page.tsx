import React from 'react';
import Link from 'next/link';
import { ShieldAlert, Mail, ArrowLeft, Trash2, CheckCircle2 } from 'lucide-react';

export const metadata = {
  title: 'Exclusão de Dados | PULSO',
  description: 'Solicite a exclusão dos seus dados do aplicativo PULSO.',
};

export default function DataDeletion() {
  return (
    <div className="min-h-screen bg-black text-white selection:bg-purple-500/30">
      {/* Header */}
      <header className="border-b border-white/5 bg-black/60 backdrop-blur-md sticky top-0 z-50">
        <div className="container mx-auto px-4 h-16 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 group">
            <ArrowLeft className="w-5 h-5 text-gray-400 group-hover:text-white transition-colors" />
            <span className="font-bold tracking-tight text-xl text-white">
              PULSO
            </span>
          </Link>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-16 max-w-3xl">
        <div className="space-y-8">
          <div className="space-y-4">
            <div className="w-12 h-12 bg-red-500/10 rounded-2xl flex items-center justify-center mb-6">
              <ShieldAlert className="w-6 h-6 text-red-500" />
            </div>
            <h1 className="text-4xl md:text-5xl font-bold tracking-tight">
              Exclusão de Dados
            </h1>
            <p className="text-lg text-gray-400">
              Na PULSO, levamos sua privacidade a sério. Se você deseja excluir permanentemente sua conta e todos os dados associados a ela, siga as instruções abaixo.
            </p>
          </div>

          <div className="bg-white/[0.02] border border-white/5 rounded-3xl p-8 space-y-6">
            <h2 className="text-xl font-semibold flex items-center gap-3">
              <Trash2 className="w-5 h-5 text-purple-500" />
              Como solicitar a exclusão?
            </h2>
            
            <p className="text-gray-400 leading-relaxed">
              Atualmente, para garantir a segurança da solicitação, o processo de exclusão de dados requer autenticação via e-mail. Para excluir sua conta:
            </p>

            <div className="space-y-4 pt-4">
              <div className="flex gap-4 items-start">
                <div className="w-8 h-8 rounded-full bg-purple-500/10 flex items-center justify-center shrink-0 mt-1">
                  <span className="text-purple-500 font-bold">1</span>
                </div>
                <div className="space-y-1">
                  <h3 className="font-medium text-white">Envie um e-mail</h3>
                  <p className="text-gray-400 text-sm">Use o mesmo e-mail associado à sua conta na PULSO.</p>
                </div>
              </div>

              <div className="flex gap-4 items-start">
                <div className="w-8 h-8 rounded-full bg-purple-500/10 flex items-center justify-center shrink-0 mt-1">
                  <span className="text-purple-500 font-bold">2</span>
                </div>
                <div className="space-y-1">
                  <h3 className="font-medium text-white">Destinatário e Assunto</h3>
                  <div className="mt-2 p-4 bg-black rounded-xl border border-white/5 space-y-2">
                    <div className="flex items-center gap-2 text-sm">
                      <span className="text-gray-500">Para:</span>
                      <a href="mailto:suporte@pulsofit.app" className="text-purple-400 hover:text-purple-300 transition-colors font-medium flex items-center gap-2">
                        <Mail className="w-4 h-4" />
                        suporte@pulsofit.app
                      </a>
                    </div>
                    <div className="flex items-center gap-2 text-sm">
                      <span className="text-gray-500">Assunto:</span>
                      <span className="text-white font-medium">Solicitação de Exclusão de Conta - [Seu Nome]</span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="flex gap-4 items-start">
                <div className="w-8 h-8 rounded-full bg-purple-500/10 flex items-center justify-center shrink-0 mt-1">
                  <span className="text-purple-500 font-bold">3</span>
                </div>
                <div className="space-y-1">
                  <h3 className="font-medium text-white">Aguarde a confirmação</h3>
                  <p className="text-gray-400 text-sm">Nossa equipe processará a exclusão de todos os seus dados pessoais, métricas de saúde, fotos de perfil e históricos de treino em até 7 dias úteis.</p>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-purple-500/10 border border-purple-500/20 rounded-2xl p-6 flex items-start gap-4">
            <CheckCircle2 className="w-6 h-6 text-purple-400 shrink-0" />
            <div className="space-y-1">
              <h3 className="font-medium text-purple-300">O que acontece ao excluir a conta?</h3>
              <p className="text-purple-300/70 text-sm leading-relaxed">
                Todos os laços e permissões de dados (incluindo anamnese, treinos, frequência cardíaca e associação a treinadores) serão permanentemente removidos de nossos servidores sem possibilidade de recuperação, conforme previsto pela LGPD.
              </p>
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-white/5 py-8 mt-12">
        <div className="container mx-auto px-4 text-center text-sm text-gray-500">
          <p>© {new Date().getFullYear()} PULSO. Todos os direitos reservados.</p>
        </div>
      </footer>
    </div>
  );
}
