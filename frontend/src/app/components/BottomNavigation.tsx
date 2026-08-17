"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { LucideIcon } from "lucide-react"
import { motion } from "framer-motion"

interface BottomNavigationProps {
    items: {
        href: string
        icon: LucideIcon
        label: string
    }[]
}

export function BottomNavigation({ items }: BottomNavigationProps) {
    const pathname = usePathname()

    return (
        <div className="fixed bottom-0 left-0 right-0 z-50 md:hidden">
            <div
                className="border-t border-border/40 pb-[env(safe-area-inset-bottom)]"
                style={{ background: "hsl(248, 15%, 4%)" }}
            >
                <div className="flex justify-around items-center h-16">
                    {items.map((item) => {
                        const isActive = pathname === item.href
                        const Icon = item.icon

                        return (
                            <Link
                                key={item.href}
                                href={item.href}
                                className="relative flex flex-col items-center justify-center w-full h-full"
                            >
                                {isActive && (
                                    <motion.div
                                        layoutId="bottom-nav-indicator"
                                        className="absolute top-0 w-10 h-0.5 rounded-b-full bg-primary"
                                        initial={false}
                                        transition={{ type: "spring", stiffness: 500, damping: 30 }}
                                    />
                                )}
                                <div className={`
                                    flex flex-col items-center gap-1 transition-all duration-200
                                    ${isActive
                                        ? "text-primary scale-105"
                                        : "text-muted-foreground/60 hover:text-muted-foreground"}
                                `}>
                                    {isActive ? (
                                        <div className="relative">
                                            <div className="relative bg-primary/15 rounded-lg p-1.5">
                                                <Icon className="w-5 h-5" />
                                            </div>
                                        </div>
                                    ) : (
                                        <Icon className="w-5 h-5" />
                                    )}
                                    <span className={`text-[11px] font-bold tracking-wide ${isActive ? "text-primary" : ""}`}>
                                        {item.label}
                                    </span>
                                </div>
                            </Link>
                        )
                    })}
                </div>
            </div>
        </div>
    )
}
