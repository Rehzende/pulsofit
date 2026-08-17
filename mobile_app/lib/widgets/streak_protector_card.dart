import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

/// Fetches and shows the Streak Protector status card.
/// Can be embedded in the Home or Profile screen.
class StreakProtectorCard extends StatefulWidget {
  const StreakProtectorCard({super.key});

  @override
  State<StreakProtectorCard> createState() => _StreakProtectorCardState();
}

class _StreakProtectorCardState extends State<StreakProtectorCard> {
  bool _isLoading = true;
  bool _isActivating = false;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await authProvider.dio.get(
        '${AppConstants.baseUrl}/workout-sessions/streak-protector/status',
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _status = response.data as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching streak protector status: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _activateProtector() async {
    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;

    setState(() => _isActivating = true);
    HapticFeedback.heavyImpact();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await authProvider.dio.post(
        '${AppConstants.baseUrl}/workout-sessions/streak-protector/activate',
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        _showSuccessDialog(data['streak_maintained'] as int);
        await _fetchStatus();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao ativar Streak Protector',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: const Color(AppConstants.cardDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🛡️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    'Usar Streak Protector?',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Você tem 1 Streak Protector disponível este mês. Usá-lo vai manter sua sequência de treinos intacta mesmo que você perca um dia.',
                    style: GoogleFonts.inter(
                      color: const Color(AppConstants.textSecondary),
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancelar',
                            style: GoogleFonts.inter(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(AppConstants.neonAccent),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Ativar',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  void _showSuccessDialog(int streak) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(AppConstants.cardDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🛡️✅', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                'Sequência Protegida!',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sua sequência de $streak dias foi mantida.\nContinue firme amanhã! 💪',
                style: GoogleFonts.inter(
                  color: const Color(AppConstants.textSecondary),
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConstants.neonAccent),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Entendido!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(AppConstants.cardDark),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final available = _status?['available'] as int? ?? 0;
    final hasProtector = available > 0;
    final resetsOn = _status?['resets_on'] as String? ?? '--';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasProtector
              ? const Color(AppConstants.neonAccent).withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
        ),
        boxShadow: hasProtector
            ? [
                BoxShadow(
                  color: const Color(AppConstants.neonAccent).withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Shield icon with glow
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasProtector
                      ? const Color(AppConstants.neonAccent).withOpacity(0.1)
                      : Colors.grey.shade800.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  hasProtector ? '🛡️' : '🔒',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Streak Protector',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      hasProtector
                          ? '$available disponível este mês'
                          : 'Reabastecer em $resetsOn',
                      style: GoogleFonts.inter(
                        color: hasProtector
                            ? const Color(AppConstants.neonAccent)
                            : const Color(AppConstants.textSecondary),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasProtector
                      ? const Color(AppConstants.neonAccent).withOpacity(0.15)
                      : Colors.grey.shade800.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$available / 1',
                  style: GoogleFonts.inter(
                    color: hasProtector
                        ? const Color(AppConstants.neonAccent)
                        : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          if (hasProtector) ...[
            const SizedBox(height: 16),
            Text(
              'Perdeu um dia de treino? Ative agora para proteger sua sequência sem perder seus dias acumulados.',
              style: GoogleFonts.inter(
                color: const Color(AppConstants.textSecondary),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isActivating ? null : _activateProtector,
                icon: _isActivating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('🛡️', style: TextStyle(fontSize: 16)),
                label: Text(
                  _isActivating ? 'Ativando...' : 'Ativar Streak Protector',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConstants.neonAccent),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade800.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.refresh, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Você já usou seu protector este mês. Reabastece em $resetsOn',
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
