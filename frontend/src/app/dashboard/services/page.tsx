"use client"

import { useState, useEffect, useRef } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { ApiClient, User } from "@/lib/api"
import { ArrowLeft, Save, Loader2, Plus, X, Download, QrCode } from "lucide-react"
import Link from "next/link"
import { QRCodeCanvas } from "qrcode.react"

export default function ServiceRegistrationPage() {
    const router = useRouter()
    const [loading, setLoading] = useState(true)
    const [saving, setSaving] = useState(false)
    const [user, setUser] = useState<User | null>(null)
    const qrRef = useRef<HTMLCanvasElement>(null)

    // Form State
    const [bio, setBio] = useState("")
    const [hourlyRate, setHourlyRate] = useState("")
    const [whatsapp, setWhatsapp] = useState("")
    const [specialties, setSpecialties] = useState<string[]>([])
    const [newSpecialty, setNewSpecialty] = useState("")

    useEffect(() => {
        const fetchData = async () => {
            try {
                const userData = await ApiClient.getMe()
                setUser(userData)

                // Pre-fill form if data exists
                if (userData.trainer_profile) {
                    setBio(userData.trainer_profile.bio || "")
                    setHourlyRate(userData.trainer_profile.hourly_rate?.toString() || "")
                    setWhatsapp(userData.trainer_profile.whatsapp_number || "")
                    if (userData.trainer_profile.specialties) {
                        // Handle if it comes as string or array depending on backend implementation
                        // Assuming backend sends array or comma-separated string
                        const specs = userData.trainer_profile.specialties
                        if (Array.isArray(specs)) {
                            setSpecialties(specs)
                        } else if (typeof specs === 'string') {
                            setSpecialties((specs as string).split(',').filter(s => s.trim()))
                        }
                    }
                }
            } catch (error) {
                console.error(error)
            } finally {
                setLoading(false)
            }
        }
        fetchData()
    }, [])

    const handleAddSpecialty = (e: React.FormEvent) => {
        e.preventDefault()
        if (newSpecialty.trim() && !specialties.includes(newSpecialty.trim())) {
            setSpecialties([...specialties, newSpecialty.trim()])
            setNewSpecialty("")
        }
    }

    const handleRemoveSpecialty = (specialty: string) => {
        setSpecialties(specialties.filter(s => s !== specialty))
    }

    const handleDownloadQR = () => {
        const canvas = document.getElementById('trainer-qr-canvas') as HTMLCanvasElement
        if (!canvas) return
        const url = canvas.toDataURL('image/png')
        const a = document.createElement('a')
        a.href = url
        a.download = 'qrcode-pulso.png'
        a.click()
    }

    const handleSave = async () => {
        setSaving(true)
        try {
            await ApiClient.trainer.updateProfile({
                bio,
                hourly_rate: parseFloat(hourlyRate),
                whatsapp_number: whatsapp,
                specialties
            })
            router.push('/dashboard')
        } catch (error) {
            console.error(error)
            // Show error toast (if available)
        } finally {
            setSaving(false)
        }
    }

    if (loading) {
        return <div className="flex items-center justify-center min-h-screen">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div>
    }

    return (
        <div className="container mx-auto max-w-3xl py-8 px-4 animate-in fade-in duration-500">
            <div className="flex items-center gap-4 mb-8">
                <Link href="/dashboard">
                    <Button variant="ghost" size="icon" className="rounded-full hover:bg-zinc-800">
                        <ArrowLeft className="h-5 w-5" />
                    </Button>
                </Link>
                <div>
                    <h1 className="text-3xl font-bold text-white">Registrar Serviços</h1>
                    <p className="text-zinc-400">Configure como seu perfil aparecerá para novos alunos</p>
                </div>
            </div>

            {/* QR Code Section */}
            {user && (
                <Card className="bg-zinc-900/50 border-zinc-800">
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <QrCode className="h-5 w-5 text-primary" />
                            Seu QR Code
                        </CardTitle>
                        <p className="text-sm text-zinc-400">Compartilhe para que alunos encontrem seu perfil no marketplace</p>
                    </CardHeader>
                    <CardContent className="flex flex-col items-center gap-4">
                        <div className="p-4 bg-white rounded-2xl">
                            <QRCodeCanvas
                                id="trainer-qr-canvas"
                                value={`${typeof window !== 'undefined' ? window.location.origin : ''}/marketplace/${user.id}`}
                                size={200}
                                level="H"
                            />
                        </div>
                        <p className="text-xs text-zinc-500 text-center">
                            {typeof window !== 'undefined' ? window.location.origin : ''}/marketplace/{user.id}
                        </p>
                        <Button
                            onClick={handleDownloadQR}
                            variant="outline"
                            className="border-zinc-700 hover:bg-zinc-800 text-white gap-2"
                        >
                            <Download className="h-4 w-4" />
                            Baixar QR
                        </Button>
                    </CardContent>
                </Card>
            )}

            <Card className="bg-zinc-900/50 border-zinc-800">
                <CardHeader>
                    <CardTitle>Informações Profissionais</CardTitle>
                </CardHeader>
                <CardContent className="space-y-6">
                    {/* Bio */}
                    <div className="space-y-2">
                        <Label htmlFor="bio">Biografia</Label>
                        <Textarea
                            id="bio"
                            className="min-h-[120px] bg-zinc-950 border-zinc-800 text-white"
                            placeholder="Conte um pouco sobre sua experiência, formação e metodologia..."
                            value={bio}
                            onChange={(e) => setBio(e.target.value)}
                        />
                    </div>

                    {/* Specialties */}
                    <div className="space-y-2">
                        <Label>Especialidades</Label>
                        <div className="flex gap-2">
                            <Input
                                placeholder="Ex: Hipertrofia, Yoga, Funcional..."
                                value={newSpecialty}
                                onChange={(e) => setNewSpecialty(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter') {
                                        e.preventDefault()
                                        handleAddSpecialty(e)
                                    }
                                }}
                            />
                            <Button onClick={handleAddSpecialty} size="icon" variant="secondary">
                                <Plus className="h-4 w-4" />
                            </Button>
                        </div>
                        <div className="flex flex-wrap gap-2 mt-2">
                            {specialties.map((spec) => (
                                <div key={spec} className="flex items-center gap-1 bg-primary/10 text-primary px-3 py-1 rounded-full text-sm border border-primary/20">
                                    {spec}
                                    <button onClick={() => handleRemoveSpecialty(spec)} className="hover:text-white transition-colors">
                                        <X className="h-3 w-3" />
                                    </button>
                                </div>
                            ))}
                        </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        {/* Hourly Rate */}
                        <div className="space-y-2">
                            <Label htmlFor="hourlyRate">Valor Hora (R$)</Label>
                            <Input
                                id="hourlyRate"
                                type="number"
                                placeholder="0.00"
                                value={hourlyRate}
                                onChange={(e) => setHourlyRate(e.target.value)}
                            />
                        </div>

                        {/* WhatsApp */}
                        <div className="space-y-2">
                            <Label htmlFor="whatsapp">WhatsApp para Contato</Label>
                            <Input
                                id="whatsapp"
                                placeholder="5511999999999"
                                value={whatsapp}
                                onChange={(e) => setWhatsapp(e.target.value)}
                            />
                        </div>
                    </div>

                    <div className="pt-6 flex justify-end">
                        <Button
                            onClick={handleSave}
                            disabled={saving}
                            className="bg-primary text-black hover:bg-primary/90 font-bold min-w-[150px]"
                        >
                            {saving ? (
                                <>
                                    <Loader2 className="mr-2 h-4 w-4 animate-spin" /> Salvando...
                                </>
                            ) : (
                                <>
                                    <Save className="mr-2 h-4 w-4" /> Salvar Alterações
                                </>
                            )}
                        </Button>
                    </div>
                </CardContent>
            </Card>
        </div>
    )
}
