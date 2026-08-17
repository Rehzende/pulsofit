"use client"

import { Card, CardContent } from "@/components/ui/card"
import { Dumbbell } from "lucide-react"
import Image from "next/image"

interface ExerciseCardProps {
    image?: string
    name: string
    sets: number
    reps?: string
    weight?: string
    muscleGroup?: string
    onClick?: () => void
}

export function ExerciseCard({
    image,
    name,
    sets,
    reps,
    weight,
    muscleGroup,
    onClick
}: ExerciseCardProps) {
    return (
        <Card
            className="overflow-hidden bg-card hover:bg-accent/50 transition-all cursor-pointer group border-border/50"
            onClick={onClick}
        >
            <div className="relative h-48 bg-gradient-to-br from-purple-900/20 to-pink-900/20">
                {image ? (
                    <Image
                        src={image}
                        alt={name}
                        fill
                        className="object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                ) : (
                    <div className="w-full h-full flex items-center justify-center">
                        <Dumbbell className="w-16 h-16 text-muted-foreground/30" />
                    </div>
                )}
                {muscleGroup && (
                    <div className="absolute top-2 left-2 px-3 py-1 rounded-full bg-black/60 backdrop-blur-sm">
                        <span className="text-xs font-medium text-white">{muscleGroup}</span>
                    </div>
                )}
            </div>
            <CardContent className="p-4">
                <h3 className="font-bold text-lg mb-2 line-clamp-1">{name}</h3>
                <div className="flex items-center gap-3 text-sm text-muted-foreground">
                    <span className="font-medium">{sets} séries</span>
                    {reps && (
                        <>
                            <span>•</span>
                            <span>{reps} reps</span>
                        </>
                    )}
                    {weight && (
                        <>
                            <span>•</span>
                            <span className="font-semibold text-purple-400">{weight}</span>
                        </>
                    )}
                </div>
            </CardContent>
        </Card>
    )
}
