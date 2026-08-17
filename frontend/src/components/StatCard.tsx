"use client"

import { Card, CardContent } from "@/components/ui/card"
import { LucideIcon } from "lucide-react"

interface StatCardProps {
    icon: LucideIcon
    value: string | number
    label: string
    trend?: {
        value: number
        isPositive: boolean
    }
    gradient?: string
    className?: string
}

export function StatCard({ icon: Icon, value, label, trend, className }: StatCardProps) {
    return (
        <Card className={`bg-zinc-900 border-zinc-800 ${className}`}>
            <CardContent className="p-4 sm:p-6">
                <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0 flex-1">
                        <p className="text-xs sm:text-sm font-medium text-zinc-400 leading-tight">{label}</p>
                        <h3 className="text-xl sm:text-2xl font-bold text-white mt-1 truncate">{value}</h3>
                    </div>
                    <div className="p-2 sm:p-3 bg-zinc-950 rounded-full border border-zinc-800 shrink-0">
                        <Icon className="w-4 h-4 sm:w-6 sm:h-6 text-primary" />
                    </div>
                </div>
                {trend && (
                    <div className="mt-3 flex items-center text-xs sm:text-sm flex-wrap gap-1">
                        <span className={trend.isPositive ? "text-primary font-semibold" : "text-red-500 font-semibold"}>
                            {trend.isPositive ? "+" : "-"}{trend.value}%
                        </span>
                        <span className="text-zinc-500">vs mês ant.</span>
                    </div>
                )}
            </CardContent>
        </Card>
    )
}
