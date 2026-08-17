"use client"

interface GaugeChartProps {
    value: number
    label: string
    maxValue?: number
    size?: "sm" | "md" | "lg"
}

export function GaugeChart({ value, label, maxValue = 100, size = "md" }: GaugeChartProps) {
    const percentage = Math.min((value / maxValue) * 100, 100)
    const circumference = 2 * Math.PI * 70
    const strokeDashoffset = circumference - (percentage / 100) * circumference

    const sizes = {
        sm: "w-32 h-32",
        md: "w-48 h-48",
        lg: "w-64 h-64"
    }

    const textSizes = {
        sm: "text-2xl",
        md: "text-4xl",
        lg: "text-5xl"
    }

    return (
        <div className={`relative ${sizes[size]} mx-auto`}>
            <svg className="w-full h-full transform -rotate-90" viewBox="0 0 200 200">
                {/* Background circle */}
                <circle
                    cx="100"
                    cy="100"
                    r="70"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="12"
                    className="text-muted opacity-20"
                />

                {/* Progress circle with gradient */}
                <circle
                    cx="100"
                    cy="100"
                    r="70"
                    fill="none"
                    stroke="url(#gaugeGradient)"
                    strokeWidth="12"
                    strokeLinecap="round"
                    strokeDasharray={circumference}
                    strokeDashoffset={strokeDashoffset}
                    className="transition-all duration-1000 ease-out"
                />

                <defs>
                    <linearGradient id="gaugeGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" stopColor="#667eea" />
                        <stop offset="100%" stopColor="#764ba2" />
                    </linearGradient>
                </defs>
            </svg>

            {/* Center text */}
            <div className="absolute inset-0 flex flex-col items-center justify-center">
                <span className={`${textSizes[size]} font-bold bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent`}>
                    {value}%
                </span>
                <span className="text-xs text-muted-foreground mt-1 uppercase tracking-wide">
                    {label}
                </span>
            </div>
        </div>
    )
}
