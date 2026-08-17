import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../widgets/error_retry_view.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  bool _loading = true;
  bool _hasError = false;
  bool _active = false;
  bool _completed = false;
  int _daysCompleted = 0;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final resp = await auth.dio.get('${AppConstants.baseUrl}/gamification/challenge/status');
      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _active = data['active'] as bool? ?? false;
          _completed = data['completed'] as bool? ?? false;
          _daysCompleted = data['days_completed'] as int? ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  Future<void> _startChallenge() async {
    setState(() => _starting = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.dio.post('${AppConstants.baseUrl}/gamification/challenge/start');
      await _fetchStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível iniciar o desafio. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.primaryDark),
        foregroundColor: Colors.white,
        title: Text('Desafio 7 Dias', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? ErrorRetryView(onRetry: _fetchStatus)
              : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildDayGrid(),
                  const SizedBox(height: 28),
                  _buildRules(),
                  const SizedBox(height: 32),
                  if (!_active && !_completed) _buildStartButton(),
                  if (_completed) _buildCompletedBanner(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(AppConstants.neonAccent).withOpacity(0.15),
            const Color(AppConstants.cardDark),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(AppConstants.neonAccent).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Desafio 7 Dias',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Treine 7 dias e prove seu comprometimento',
                      style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_active || _completed) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_daysCompleted / 7 dias',
                  style: GoogleFonts.inter(
                    color: const Color(AppConstants.neonAccent),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _completed ? 'Concluido!' : 'Em andamento',
                  style: GoogleFonts.inter(
                    color: _completed ? Colors.amber : Colors.grey[400],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _daysCompleted / 7,
                minHeight: 8,
                backgroundColor: const Color(AppConstants.borderColor),
                color: _completed ? Colors.amber : const Color(AppConstants.neonAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progresso',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final done = i < _daysCompleted;
            final isCurrent = i == _daysCompleted && _active;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 64,
                decoration: BoxDecoration(
                  color: done
                      ? const Color(AppConstants.neonAccent).withOpacity(0.2)
                      : isCurrent
                          ? const Color(AppConstants.cardDark)
                          : const Color(AppConstants.cardDark).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: done
                        ? const Color(AppConstants.neonAccent)
                        : isCurrent
                            ? const Color(AppConstants.neonAccent).withOpacity(0.4)
                            : const Color(AppConstants.borderColor),
                    width: done ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    done
                        ? const Icon(Icons.check_circle_rounded,
                            color: Color(AppConstants.neonAccent), size: 22)
                        : Icon(
                            isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isCurrent
                                ? const Color(AppConstants.neonAccent).withOpacity(0.6)
                                : Colors.grey[700],
                            size: 20,
                          ),
                    const SizedBox(height: 4),
                    Text(
                      'D${i + 1}',
                      style: GoogleFonts.inter(
                        color: done
                            ? const Color(AppConstants.neonAccent)
                            : isCurrent
                                ? Colors.white70
                                : Colors.grey[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRules() {
    final rules = [
      ('Treine qualquer dia da semana', Icons.calendar_today_outlined),
      ('Qualquer treino conta — curto ou longo', Icons.fitness_center_outlined),
      ('Complete 7 dias para ganhar o badge', Icons.emoji_events_outlined),
      ('Os 7 dias não precisam ser consecutivos', Icons.repeat_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como funciona',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ...rules.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(r.$2, color: const Color(AppConstants.neonAccent), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      r.$1,
                      style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _starting ? null : _startChallenge,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(AppConstants.neonAccent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _starting
            ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
            : Text(
                'Aceitar Desafio',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  Widget _buildCompletedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Desafio Concluido!',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Voce treinou 7 dias. Incrivel!',
                  style: GoogleFonts.inter(color: Colors.black87, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
