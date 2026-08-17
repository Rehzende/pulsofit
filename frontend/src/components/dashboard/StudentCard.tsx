import { User } from "@/lib/api"
import { Card, CardContent } from "@/components/ui/card"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Activity, Calendar, Trophy } from "lucide-react"
import Link from "next/link"
import { getImageUrl } from "@/lib/utils"

interface StudentCardProps {
    student: User
}

export function StudentCard({ student }: StudentCardProps) {
    return (
        <Link href={`/dashboard/students/${student.id}`}>
            <Card className="bg-zinc-900/40 backdrop-blur-md border-zinc-800 hover:border-primary/50 hover:bg-zinc-900/60 transition-all cursor-pointer group">
                <CardContent className="p-4 flex items-center gap-4">
                    <Avatar className="h-12 w-12 border border-zinc-700 group-hover:border-primary transition-colors">
                        <AvatarImage src={getImageUrl(student.photo_url)} />
                        <AvatarFallback className="bg-zinc-800 text-zinc-400 font-bold">
                            {student.full_name?.substring(0, 2).toUpperCase()}
                        </AvatarFallback>
                    </Avatar>
                    <div className="flex-1 min-w-0">
                        <h3 className="font-semibold text-white truncate group-hover:text-primary transition-colors">
                            {student.full_name}
                        </h3>
                        <div className="flex items-center gap-2 text-xs text-zinc-500 mt-1">
                            <span className={`flex items-center gap-1.5 ${student.is_active ? 'text-green-500' : 'text-zinc-500'}`}>
                                <span className={`w-1.5 h-1.5 rounded-full ${student.is_active ? 'bg-green-500' : 'bg-zinc-500'}`} />
                                {student.is_active ? 'Ativo' : 'Inativo'}
                            </span>
                            <span>•</span>
                            <span>Lvl {student.level || 1}</span>
                        </div>
                    </div>
                </CardContent>
            </Card>
        </Link>
    )
}
