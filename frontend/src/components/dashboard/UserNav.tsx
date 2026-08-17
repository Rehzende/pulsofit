"use client"

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuGroup,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { User } from "@/lib/api"
import { LogOut, User as UserIcon } from "lucide-react"
import { useRouter } from "next/navigation"

interface UserNavProps {
    user?: User | null
}

export function UserNav({ user }: UserNavProps) {
    const router = useRouter()

    const handleLogout = () => {
        localStorage.removeItem("token")
        router.push("/login")
    }

    return (
        <DropdownMenu>
            <DropdownMenuTrigger asChild>
                <Button variant="ghost" className="relative h-10 w-10 rounded-full">
                    <Avatar className="h-10 w-10 border border-zinc-800">
                        <AvatarImage src={user?.photo_url} alt={user?.full_name || "User"} />
                        <AvatarFallback className="bg-zinc-900 text-zinc-400">
                            {user?.full_name?.substring(0, 2).toUpperCase() || "U"}
                        </AvatarFallback>
                    </Avatar>
                </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent className="w-56 bg-zinc-900 border-zinc-800 text-zinc-100" align="end" forceMount>
                <DropdownMenuLabel className="font-normal">
                    <div className="flex flex-col space-y-1">
                        <p className="text-sm font-medium leading-none text-white">{user?.full_name}</p>
                        <p className="text-xs leading-none text-zinc-400">
                            {user?.email}
                        </p>
                    </div>
                </DropdownMenuLabel>
                <DropdownMenuSeparator className="bg-zinc-800" />
                <DropdownMenuGroup>
                    <DropdownMenuItem className="focus:bg-zinc-800 focus:text-white cursor-pointer" onClick={() => router.push("/dashboard/settings")}>
                        <UserIcon className="mr-2 h-4 w-4" />
                        <span>Profile</span>
                    </DropdownMenuItem>
                </DropdownMenuGroup>
                <DropdownMenuSeparator className="bg-zinc-800" />
                <DropdownMenuItem className="text-red-500 focus:bg-red-500/10 focus:text-red-500 cursor-pointer" onClick={handleLogout}>
                    <LogOut className="mr-2 h-4 w-4" />
                    <span>Log out</span>
                </DropdownMenuItem>
            </DropdownMenuContent>
        </DropdownMenu>
    )
}
