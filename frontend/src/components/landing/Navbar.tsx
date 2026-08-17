"use client"

import Link from "next/link"
import { Button } from "@/components/ui/button"
import { motion } from "framer-motion"
import { Menu, Zap } from "lucide-react"
import {
    Sheet,
    SheetContent,
    SheetHeader,
    SheetTitle,
    SheetTrigger,
} from "@/components/ui/sheet"

export function Navbar() {
    return (
        <motion.nav
            initial={{ y: -100, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ duration: 0.6, ease: "easeOut" }}
            className="fixed top-0 left-0 right-0 z-50 bg-background/70 backdrop-blur-xl border-b border-border/40"
        >
            <div className="container mx-auto px-4">
                <div className="flex items-center justify-between h-20">

                    {/* Logo */}
                    <Link href="/" className="flex items-center gap-2.5 group">
                        <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary to-purple-400 flex items-center justify-center shadow-lg shadow-primary/30 group-hover:shadow-primary/50 transition-all">
                            <Zap className="w-4 h-4 text-white" />
                        </div>
                        <span className="text-xl font-bold tracking-tight text-foreground">
                            PULSO
                            <span className="text-primary">.</span>
                        </span>
                    </Link>

                    {/* Nav Links */}
                    <div className="hidden md:flex items-center gap-8">
                        <Link href="#features" className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors">
                            Funcionalidades
                        </Link>
                        <Link href="#how-it-works" className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors">
                            Como Funciona
                        </Link>
                        <Link href="#about" className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors">
                            Sobre
                        </Link>
                    </div>

                    {/* CTA Buttons & Mobile Menu */}
                    <div className="flex items-center gap-3">
                        <Link href="/register?role=trainer" className="hidden sm:block">
                            <Button
                                variant="ghost"
                                className="text-muted-foreground hover:text-foreground hover:bg-card/60 font-medium text-sm"
                            >
                                Sou Personal
                            </Button>
                        </Link>
                        <Link href="/register?role=student">
                            <Button
                                className="bg-primary hover:bg-primary/90 text-primary-foreground font-bold rounded-full px-4 sm:px-6 shadow-lg shadow-primary/25 hover:shadow-primary/40 transition-all hover:scale-105 text-sm"
                            >
                                Começar Grátis
                            </Button>
                        </Link>
                        
                        {/* Mobile Menu */}
                        <div className="md:hidden">
                            <Sheet>
                                <SheetTrigger asChild>
                                    <Button variant="ghost" size="icon" className="text-muted-foreground">
                                        <Menu className="h-6 w-6" />
                                    </Button>
                                </SheetTrigger>
                                <SheetContent side="right" className="w-[300px] border-border/40">
                                    <SheetHeader>
                                        <SheetTitle className="text-left flex items-center gap-2 mb-4">
                                            <div className="w-6 h-6 rounded bg-gradient-to-br from-primary to-purple-400 flex items-center justify-center">
                                                <Zap className="w-3 h-3 text-white" />
                                            </div>
                                            PULSO
                                        </SheetTitle>
                                    </SheetHeader>
                                    <div className="flex flex-col gap-4 mt-6">
                                        <Link href="#features" className="text-sm font-medium hover:text-primary transition-colors">
                                            Funcionalidades
                                        </Link>
                                        <Link href="#how-it-works" className="text-sm font-medium hover:text-primary transition-colors">
                                            Como Funciona
                                        </Link>
                                        <Link href="#about" className="text-sm font-medium hover:text-primary transition-colors">
                                            Sobre
                                        </Link>
                                        <hr className="border-border/40 my-2" />
                                        <Link href="/login" className="text-sm font-medium hover:text-primary transition-colors">
                                            Entrar
                                        </Link>
                                        <Link href="/register?role=trainer" className="text-sm font-medium hover:text-primary transition-colors">
                                            Sou Personal
                                        </Link>
                                    </div>
                                </SheetContent>
                            </Sheet>
                        </div>
                    </div>
                </div>
            </div>
        </motion.nav>
    )
}
