import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/bluetooth_controller.dart';

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Dispositivos',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Consumer<BluetoothController>(
          builder: (context, bluetooth, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.neonAccent).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(AppConstants.neonAccent).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(AppConstants.neonAccent),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Conecte um monitor cardíaco Bluetooth para rastrear seus batimentos e calcular o gasto calórico com precisão.',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Connected device card
                if (bluetooth.isConnected) ...[
                  _ConnectedCard(bluetooth: bluetooth),
                  const SizedBox(height: 24),
                ],

                // Scan section
                if (!bluetooth.isConnected)
                  _ScanSection(bluetooth: bluetooth),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  final BluetoothController bluetooth;
  const _ConnectedCard({required this.bluetooth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bluetooth.deviceName,
                  style: GoogleFonts.inter(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.favorite, color: Colors.red, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '${bluetooth.heartRate} BPM',
              style: GoogleFonts.inter(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => bluetooth.disconnect(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text('Desconectar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanSection extends StatelessWidget {
  final BluetoothController bluetooth;
  const _ScanSection({required this.bluetooth});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scan button / Stop button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: bluetooth.isConnecting
                ? null
                : bluetooth.isScanning
                    ? () => bluetooth.stopScan()
                    : () => bluetooth.startScan(),
            icon: bluetooth.isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.bluetooth_searching),
            label: Text(
              bluetooth.isScanning
                  ? 'Parar busca'
                  : 'Buscar dispositivos',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: bluetooth.isScanning
                  ? Colors.grey.shade700
                  : const Color(AppConstants.neonAccent),
              foregroundColor: Colors.white,
            ),
          ),
        ),

        // Error
        if (bluetooth.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            bluetooth.errorMessage!,
            style: GoogleFonts.inter(color: Colors.red, fontSize: 13),
          ),
        ],

        // Pairing / Connecting indicator
        if (bluetooth.isPairing) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Aguardando confirmação no dispositivo...',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Color(AppConstants.neonAccent),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Aceite o pareamento nas notificações do celular.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
          ),
        ] else if (bluetooth.isConnecting) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Conectando...',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
        ],

        // Device list (filtered to HR-capable devices only)
        if (bluetooth.filteredScanResults.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Dispositivos encontrados',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...bluetooth.filteredScanResults.map(
            (result) => _DeviceTile(
              result: result,
              onTap: () => bluetooth.connectToDevice(result.device),
            ),
          ),
        ] else if (!bluetooth.isScanning && bluetooth.errorMessage == null) ...[
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Nenhum dispositivo encontrado ainda.\nToque em "Buscar dispositivos" para iniciar.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final dynamic result; // ScanResult
  final VoidCallback onTap;

  const _DeviceTile({required this.result, required this.onTap});

  IconData _rssiIcon(int rssi) {
    if (rssi > -60) return Icons.signal_wifi_4_bar;
    if (rssi > -75) return Icons.network_wifi_3_bar;
    return Icons.network_wifi_1_bar;
  }

  Color _rssiColor(int rssi) {
    if (rssi > -60) return Colors.green;
    if (rssi > -75) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final name = (result.device.platformName as String).isNotEmpty
        ? result.device.platformName as String
        : 'Dispositivo desconhecido';
    final rssi = result.rssi as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.favorite, color: Colors.red),
        title: Text(
          name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          result.device.remoteId.toString(),
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_rssiIcon(rssi), color: _rssiColor(rssi), size: 18),
            const SizedBox(width: 4),
            Text(
              '$rssi dBm',
              style: GoogleFonts.inter(
                color: _rssiColor(rssi),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}
