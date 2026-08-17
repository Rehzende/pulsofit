import { useState, useEffect, useCallback } from 'react'

// Web Bluetooth API type declarations
declare global {
    interface Navigator {
        bluetooth: {
            requestDevice(options: RequestDeviceOptions): Promise<BluetoothDevice>
        }
    }

    interface RequestDeviceOptions {
        filters?: BluetoothLEScanFilter[]
        optionalServices?: BluetoothServiceUUID[]
    }

    interface BluetoothLEScanFilter {
        services?: BluetoothServiceUUID[]
        name?: string
        namePrefix?: string
    }

    type BluetoothServiceUUID = string | number

    interface BluetoothDevice extends EventTarget {
        id: string
        name?: string
        gatt?: BluetoothRemoteGATTServer
        addEventListener(type: 'gattserverdisconnected', listener: () => void): void
    }

    interface BluetoothRemoteGATTServer {
        device: BluetoothDevice
        connected: boolean
        connect(): Promise<BluetoothRemoteGATTServer>
        disconnect(): void
        getPrimaryService(service: BluetoothServiceUUID): Promise<BluetoothRemoteGATTService>
    }

    interface BluetoothRemoteGATTService {
        device: BluetoothDevice
        uuid: string
        getCharacteristic(characteristic: BluetoothServiceUUID): Promise<BluetoothRemoteGATTCharacteristic>
    }

    interface BluetoothRemoteGATTCharacteristic extends EventTarget {
        service: BluetoothRemoteGATTService
        uuid: string
        value?: DataView
        startNotifications(): Promise<BluetoothRemoteGATTCharacteristic>
        stopNotifications(): Promise<BluetoothRemoteGATTCharacteristic>
        addEventListener(type: 'characteristicvaluechanged', listener: (event: Event) => void): void
    }
}


interface WebBluetoothHook {
    heartRate: number | null
    isConnected: boolean
    connectToDevice: () => Promise<void>
    disconnect: () => void
}

export function useWebBluetooth(): WebBluetoothHook {
    const [heartRate, setHeartRate] = useState<number | null>(null)
    const [isConnected, setIsConnected] = useState(false)
    const [device, setDevice] = useState<BluetoothDevice | null>(null)

    const disconnect = useCallback(() => {
        if (device?.gatt?.connected) {
            device.gatt.disconnect()
        }
        setDevice(null)
        setIsConnected(false)
        setHeartRate(null)
    }, [device])

    const connectToDevice = useCallback(async () => {
        try {
            // Check if Web Bluetooth is available
            if (!navigator.bluetooth) {
                alert('Web Bluetooth não está disponível neste navegador. Use Chrome ou Edge.')
                return
            }

            // Request device with heart rate service
            const device = await navigator.bluetooth.requestDevice({
                filters: [{ services: ['heart_rate'] }],
                optionalServices: ['heart_rate']
            })

            setDevice(device)

            // Connect to GATT server
            const server = await device.gatt!.connect()

            // Get heart rate service
            const service = await server.getPrimaryService('heart_rate')

            // Get heart rate measurement characteristic
            const characteristic = await service.getCharacteristic('heart_rate_measurement')

            // Start notifications
            await characteristic.startNotifications()

            // Listen for heart rate updates
            characteristic.addEventListener('characteristicvaluechanged', (event: any) => {
                const value = event.target.value as DataView
                // Parse heart rate value (standard Bluetooth HR format)
                // First byte contains flags
                const flags = value.getUint8(0)
                const rate16Bits = flags & 0x1
                let heartRateValue: number

                if (rate16Bits) {
                    heartRateValue = value.getUint16(1, true)
                } else {
                    heartRateValue = value.getUint8(1)
                }

                setHeartRate(heartRateValue)
            })

            setIsConnected(true)

            // Handle disconnection
            device.addEventListener('gattserverdisconnected', () => {
                setIsConnected(false)
                setHeartRate(null)
            })

        } catch (error) {
            console.error('Erro ao conectar ao dispositivo Bluetooth:', error)
            alert('Falha ao conectar ao dispositivo. Verifique se está ligado e próximo.')
        }
    }, [])

    useEffect(() => {
        return () => {
            disconnect()
        }
    }, [disconnect])

    return {
        heartRate,
        isConnected,
        connectToDevice,
        disconnect
    }
}
