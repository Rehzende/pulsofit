"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { ApiClient, User } from "@/lib/api"
import { StudentLayout } from "@/components/layouts/StudentLayout"
import { TrainerLayout } from "@/components/layouts/TrainerLayout"

export default function DashboardLayout({
    children,
}: {
    children: React.ReactNode
}) {
    const router = useRouter()
    const [isLoading, setIsLoading] = useState(true)
    const [user, setUser] = useState<User | null>(null)

    useEffect(() => {
        const token = localStorage.getItem("token")
        if (!token) {
            router.push("/login")
        } else {
            // Fetch user data to get trainer branding
            ApiClient.getMe()
                .then(userData => {
                    if (!userData.accepted_ai_terms_at) {
                        router.push("/ai-terms")
                    } else {
                        setUser(userData)
                        setIsLoading(false)
                    }
                })
                .catch(() => {
                    localStorage.removeItem("token")
                    router.push("/login")
                })
        }
    }, [router])

    if (isLoading) {
        return (
            <div className="flex h-dvh w-full items-center justify-center bg-background">
                <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
            </div>
        )
    }

    const brandName = user?.trainer_brand_name || "PULSO"
    const logoUrl = user?.trainer_logo_url ? `https://web-production-06662.up.railway.app/${user.trainer_logo_url}` : null
    const primaryColor = user?.trainer_primary_color

    if (user?.role === 'STUDENT') {
        return <StudentLayout user={user}>{children}</StudentLayout>
    }

    return (
        <TrainerLayout
            brandName={brandName}
            logoUrl={logoUrl}
            primaryColor={primaryColor}
        >
            {children}
        </TrainerLayout>
    )
}
