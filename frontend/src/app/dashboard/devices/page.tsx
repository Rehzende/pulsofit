"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Bluetooth, Heart, RefreshCw, Trash2, Zap } from "lucide-react"

interface PairedDevice {
    id: string
    name: string
    connected: boolean
    lastBPM?: number
    pairedAt: string
}

export default function DevicesPage() {
    const [pairedDevices, setPairedDevices] = useState<PairedDevice[]>([])
    const [scanning, setScanning] = useState(false)
    const [connecting, setConnecting] = useState(false)
    const [error, setError] = useState<string | null>(null)
    const [supportsBluetooth, setSupportsBluetooth] = useState(false)
    const [activeBPM, setActiveBPM] = useState<number | null>(null)
    const [listeningDevice, setListeningDevice] = useState<string | null>(null)

    // Check if browser supports Web Bluetooth API
    useEffect(() => {
        const supported = !!(navigator.bluetooth && typeof (navigator.bluetooth as any).getDevices === 'function')
        setSupportsBluetooth(supported)
        if (supported) {
            loadPairedDevices()
        }
    }, [])

    const loadPairedDevices = async () => {
        try {
            if (!navigator.bluetooth) return
            const devices = await (navigator.bluetooth as any).getDevices()
            const stored = localStorage.getItem("pairedBLEDevices")
            const storedDevices: PairedDevice[] = stored ? JSON.parse(stored) : []
            setPairedDevices(storedDevices)
        } catch (err) {
            console.error("Erro ao carregar dispositivos:", err)
        }
    }

    const scanForDevices = async () => {
        if (!navigator.bluetooth) {
            setError("Bluetooth não suportado no seu navegador")
            return
        }

        setScanning(true)
        setError(null)

        try {
            const device = await navigator.bluetooth.requestDevice({
                filters: [
                    { namePrefix: "Polar" },
                    { namePrefix: "MI Band" },
                    { namePrefix: "GarminFit" },
                    { services: ['heart_rate'] }
                ],
                optionalServices: ['device_information', 'battery_service']
            })

            if (device) {
                const newDevice: PairedDevice = {
                    id: device.id || `device-${Date.now()}`,
                    name: device.name || "Dispositivo Desconhecido",
                    connected: device.gatt?.connected || false,
                    pairedAt: new Date().toISOString()
                }

                setPairedDevices(prev => {
                    const updated = [...prev.filter(d => d.id !== newDevice.id), newDevice]
                    localStorage.setItem("pairedBLEDevices", JSON.stringify(updated))
                    return updated
                })
            }
        } catch (err: any) {
            if (err.name !== "NotFoundError") {
                setError(`Erro ao escanear: ${err.message}`)
            }
        } finally {
            setScanning(false)
        }
    }

    const connectToDevice = async (device: PairedDevice) => {
        setConnecting(true)
        setError(null)

        try {
            if (!navigator.bluetooth) {
                setError("Bluetooth não suportado")
                return
            }

            // Try to reconnect to the device
            const bluetoothDevice = await (navigator.bluetooth as any).getDevices()
                .then((devices: any) => devices.find((d: any) => d.id === device.id || d.name === device.name))

            if (!bluetoothDevice) {
                setError("Dispositivo não encontrado. Escaneie novamente.")
                return
            }

            // Simulate connection (real implementation would connect to GATT server)
            const updated = pairedDevices.map(d =>
                d.id === device.id ? { ...d, connected: true } : d
            )
            setPairedDevices(updated)
            localStorage.setItem("pairedBLEDevices", JSON.stringify(updated))

            // Simulate BPM reading
            setListeningDevice(device.id)
            const interval = setInterval(() => {
                setActiveBPM(Math.floor(60 + Math.random() * 40))
            }, 1000)

            setTimeout(() => {
                clearInterval(interval)
                setListeningDevice(null)
                setActiveBPM(null)
            }, 10000)

        } catch (err: any) {
            setError(`Erro ao conectar: ${err.message}`)
            setConnecting(false)
        }
    }

    const disconnectDevice = (id: string) => {
        const updated = pairedDevices.map(d =>
            d.id === id ? { ...d, connected: false } : d
        )
        setPairedDevices(updated)
        localStorage.setItem("pairedBLEDevices", JSON.stringify(updated))

        if (listeningDevice === id) {
            setListeningDevice(null)
            setActiveBPM(null)
        }
    }

    const removePairedDevice = (id: string) => {
        const updated = pairedDevices.filter(d => d.id !== id)
        setPairedDevices(updated)
        localStorage.setItem("pairedBLEDevices", JSON.stringify(updated))
    }

    if (!supportsBluetooth) {
        return (
            <div className="flex flex-col gap-6">
                <div>
                    <h1 className="text-3xl font-bold">Dispositivos</h1>
                    <p className="text-muted-foreground mt-2">Pareie sensores e dispositivos wearables</p>
                </div>

                <Card className="card-glow">
                    <CardContent className="pt-8 pb-8">
                        <div className="text-center py-12">
                            <div className="mx-auto w-16 h-16 bg-secondary rounded-full flex items-center justify-center mb-4">
                                <Bluetooth className="h-8 w-8 text-muted-foreground" />
                            </div>
                            <h3 className="text-lg font-semibold text-foreground mb-2">
                                Bluetooth não suportado
                            </h3>
                            <p className="text-muted-foreground max-w-sm mx-auto mb-6">
                                Seu navegador não suporta a API Web Bluetooth. Use Chrome, Edge ou Firefox em versões recentes para parear dispositivos.
                            </p>
                            <p className="text-sm text-muted-foreground">
                                💡 Dica: Teste em um navegador suportado em um dispositivo mobile ou desktop com Bluetooth.
                            </p>
                        </div>
                    </CardContent>
                </Card>
            </div>
        )
    }

    return (
        <div className="flex flex-col gap-6">
            <div>
                <h1 className="text-3xl font-bold">Dispositivos</h1>
                <p className="text-muted-foreground mt-2">Pareie sensores de frequência cardíaca e wearables</p>
            </div>

            {error && (
                <Card className="bg-destructive/10 border-destructive/25">
                    <CardContent className="pt-6 pb-6">
                        <p className="text-destructive text-sm">{error}</p>
                    </CardContent>
                </Card>
            )}

            {/* Scan Button */}
            <Card className="card-glow">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <Bluetooth className="h-5 w-5 text-primary" />
                        Escanear Novos Dispositivos
                    </CardTitle>
                    <CardDescription>
                        Clique para buscar dispositivos Bluetooth próximos (Polar, Garmin, Mi Band, etc.)
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <Button
                        onClick={scanForDevices}
                        disabled={scanning}
                        className="w-full bg-primary hover:bg-primary/90 h-12 rounded-xl font-semibold"
                    >
                        {scanning ? (
                            <>
                                <RefreshCw className="mr-2 h-4 w-4 animate-spin" />
                                Escaneando...
                            </>
                        ) : (
                            <>
                                <Bluetooth className="mr-2 h-4 w-4" />
                                Escanear Dispositivos
                            </>
                        )}
                    </Button>
                </CardContent>
            </Card>

            {/* Paired Devices List */}
            <div className="space-y-4">
                <h2 className="text-xl font-semibold">Dispositivos Pareados</h2>

                {pairedDevices.length === 0 ? (
                    <Card className="bg-secondary/30 border-border">
                        <CardContent className="pt-8 pb-8">
                            <div className="text-center py-8">
                                <Heart className="h-8 w-8 mx-auto text-muted-foreground mb-3" />
                                <p className="text-muted-foreground">
                                    Nenhum dispositivo pareado ainda. Clique no botão acima para começar.
                                </p>
                            </div>
                        </CardContent>
                    </Card>
                ) : (
                    <div className="grid gap-4">
                        {pairedDevices.map(device => (
                            <Card key={device.id} className={`card-glow transition-all ${device.connected ? 'border-primary/50' : ''}`}>
                                <CardContent className="pt-6 pb-6">
                                    <div className="flex items-center justify-between gap-4">
                                        <div className="flex-1">
                                            <div className="flex items-center gap-3 mb-2">
                                                <Heart className={`h-5 w-5 ${device.connected ? 'text-primary animate-pulse fill-primary' : 'text-muted-foreground'}`} />
                                                <h3 className="font-semibold text-foreground">{device.name}</h3>
                                                <Badge variant={device.connected ? "default" : "secondary"}>
                                                    {device.connected ? "Conectado" : "Desconectado"}
                                                </Badge>
                                            </div>
                                            {listeningDevice === device.id && activeBPM && (
                                                <div className="flex items-center gap-2 text-primary mt-2">
                                                    <Zap className="h-4 w-4" />
                                                    <span className="text-sm font-bold">{activeBPM} BPM</span>
                                                </div>
                                            )}
                                            <p className="text-xs text-muted-foreground mt-1">
                                                Pareado em {new Date(device.pairedAt).toLocaleDateString('pt-BR')}
                                            </p>
                                        </div>

                                        <div className="flex items-center gap-2">
                                            {!device.connected ? (
                                                <Button
                                                    onClick={() => connectToDevice(device)}
                                                    disabled={connecting || listeningDevice === device.id}
                                                    size="sm"
                                                    className="bg-primary hover:bg-primary/90"
                                                >
                                                    {listeningDevice === device.id ? (
                                                        <>
                                                            <RefreshCw className="mr-1 h-3 w-3 animate-spin" />
                                                            Testando...
                                                        </>
                                                    ) : (
                                                        "Conectar"
                                                    )}
                                                </Button>
                                            ) : (
                                                <Button
                                                    onClick={() => disconnectDevice(device.id)}
                                                    size="sm"
                                                    variant="outline"
                                                >
                                                    Desconectar
                                                </Button>
                                            )}

                                            <Button
                                                onClick={() => removePairedDevice(device.id)}
                                                size="sm"
                                                variant="ghost"
                                                className="text-destructive hover:text-destructive hover:bg-destructive/10"
                                            >
                                                <Trash2 className="h-4 w-4" />
                                            </Button>
                                        </div>
                                    </div>
                                </CardContent>
                            </Card>
                        ))}
                    </div>
                )}
            </div>

            {/* Info Card */}
            <Card className="bg-primary/5 border-primary/20">
                <CardHeader>
                    <CardTitle className="text-base">💡 Como usar</CardTitle>
                </CardHeader>
                <CardContent className="space-y-2 text-sm text-muted-foreground">
                    <p>1. Ative Bluetooth no seu dispositivo (smartwatch, HR monitor, etc.)</p>
                    <p>2. Clique em "Escanear Dispositivos" acima</p>
                    <p>3. Selecione seu dispositivo na lista de opções</p>
                    <p>4. Clique em "Conectar" para sincronizar dados de batimento cardíaco</p>
                    <p>5. Durante treinos, seus dados serão coletados automaticamente</p>
                </CardContent>
            </Card>
        </div>
    )
}
