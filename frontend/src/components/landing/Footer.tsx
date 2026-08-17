"use client"

import Link from "next/link"
import { Zap } from "lucide-react"

export function Footer() {
    return (
        <footer className="bg-card/30 border-t border-border/40 py-16">
            <div className="container mx-auto px-4">
                <div className="flex flex-col md:flex-row justify-between items-center gap-8">

                    {/* Brand */}
                    <div className="flex items-center gap-2.5">
                        <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-primary to-purple-400 flex items-center justify-center">
                            <Zap className="w-3.5 h-3.5 text-white" />
                        </div>
                        <span className="text-lg font-bold tracking-tight text-foreground">
                            PULSO<span className="text-primary">.</span>
                        </span>
                    </div>

                    <p className="text-muted-foreground text-sm text-center">
                        © 2025 PULSO Tecnologia. Todos os direitos reservados.
                        <br className="md:hidden" />
                        {" "}Feito com 🖤 no Brasil.
                    </p>

                    <div className="flex gap-6">
                        <a href="#" className="text-muted-foreground hover:text-foreground transition-colors text-sm">Termos</a>
                        <a href="#" className="text-muted-foreground hover:text-foreground transition-colors text-sm">Privacidade</a>
                        <a href="#" className="text-muted-foreground hover:text-foreground transition-colors text-sm">Contato</a>
                    </div>
                </div>
            </div>
        </footer>
    )
}
