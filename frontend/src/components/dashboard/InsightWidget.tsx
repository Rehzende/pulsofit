import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { LucideIcon } from "lucide-react"

interface InsightWidgetProps {
    title: string
    value: string | number
    icon: LucideIcon
    description?: string
    trend?: {
        value: number
        isPositive: boolean
    }
}

export function InsightWidget({ title, value, icon: Icon, description, trend }: InsightWidgetProps) {
    return (
        <Card className="bg-zinc-900 border-zinc-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium text-zinc-400">
                    {title}
                </CardTitle>
                <Icon className="h-4 w-4 text-primary" />
            </CardHeader>
            <CardContent>
                <div className="text-2xl font-bold text-white">{value}</div>
                <p className="text-xs text-zinc-500">
                    {description}
                </p>
                {trend && (
                    <div className={`text-xs mt-2 ${trend.isPositive ? 'text-primary' : 'text-red-500'}`}>
                        {trend.isPositive ? '↑' : '↓'} {Math.abs(trend.value)}% vs last month
                    </div>
                )}
            </CardContent>
        </Card>
    )
}
