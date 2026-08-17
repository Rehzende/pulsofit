"use client"

import { Check } from "lucide-react"

interface WeeklyCalendarProps {
    completedDays?: number[]
    currentDay?: number
}

export function WeeklyCalendar({ completedDays = [], currentDay }: WeeklyCalendarProps) {
    const days = [
        { short: 'Dom', number: 1 },
        { short: 'Seg', number: 2 },
        { short: 'Ter', number: 3 },
        { short: 'Qua', number: 4 },
        { short: 'Qui', number: 5 },
        { short: 'Sex', number: 6 },
        { short: 'Sáb', number: 7 }
    ]

    const today = currentDay ?? new Date().getDay()

    return (
        <div className="flex justify-between gap-2">
            {days.map((day, index) => {
                const isCompleted = completedDays.includes(index)
                const isToday = index === today

                return (
                    <div key={day.short} className="flex flex-col items-center gap-2">
                        <span className="text-xs text-muted-foreground font-medium">
                            {day.short}
                        </span>
                        <div
                            className={`
                                w-12 h-12 rounded-full flex items-center justify-center
                                transition-all duration-300
                                ${isCompleted
                                    ? 'bg-gradient-to-br from-purple-600 to-pink-600 shadow-lg shadow-purple-500/50'
                                    : isToday
                                        ? 'border-2 border-purple-600 bg-purple-600/10'
                                        : 'bg-muted/50'
                                }
                            `}
                        >
                            {isCompleted ? (
                                <Check className="w-6 h-6 text-white" strokeWidth={3} />
                            ) : (
                                <span className={`text-sm font-semibold ${isToday ? 'text-purple-600' : 'text-muted-foreground'}`}>
                                    {day.number}
                                </span>
                            )}
                        </div>
                        {isCompleted && (
                            <div className="w-1 h-1 rounded-full bg-purple-600 animate-pulse" />
                        )}
                    </div>
                )
            })}
        </div>
    )
}
