import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/constants.dart';
import '../widgets/ai_terms_dialog.dart';
import '../widgets/ui/app_dialog.dart';

/// Screen for AI-powered workout suggestion based on user anamnesis.
class AiWorkoutSuggestionScreen extends StatefulWidget {
  const AiWorkoutSuggestionScreen({super.key});

  @override
  State<AiWorkoutSuggestionScreen> createState() =>
      _AiWorkoutSuggestionScreenState();
}

class _AiWorkoutSuggestionScreenState
    extends State<AiWorkoutSuggestionScreen> {
  // ─── Form fields ──────────────────────────────────────────
  String _goal = 'Hipertrofia';
  String _level = 'Iniciante';
  String _frequency = '3x por semana';
  String _duration = '60 minutos';
  String _equipment = 'Academia completa';
  String _activityLevel = 'Moderadamente Ativo';
  String _injuries = '';
  String _medicalConditions = '';

  final _goals = ['Hipertrofia', 'Emagrecimento', 'Condicionamento', 'Força', 'Saúde Geral', 'Reabilitação'];
  final _levels = ['Iniciante', 'Intermediário', 'Avançado'];
  final _frequencies = ['2x por semana', '3x por semana', '4x por semana', '5x por semana', '6x ou mais'];
  final _durations = ['30 minutos', '45 minutos', '60 minutos', '90 minutos'];
  final _equipments = ['Academia completa', 'Halteres em casa', 'Elásticos / bandas', 'Sem equipamento'];
  final _activityLevels = ['Sedentário', 'Levemente Ativo', 'Moderadamente Ativo', 'Muito Ativo'];

  // ─── State ────────────────────────────────────────────────
  bool _isLoading = false;
  bool _isSaving = false;
  Map<String, dynamic>? _result;
  String? _jobId;          // async job id for polling
  Timer? _pollTimer;
  String _statusLabel = 'Gerando seu programa...';

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Require terms
    if (!auth.acceptedAiTerms) {
      final accepted = await AiTermsDialog.show(context);
      if (!accepted || !mounted) return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
      _jobId = null;
      _statusLabel = 'Gerando seu programa...';
    });

    try {
      final resp = await auth.dio.post(
        '${AppConstants.baseUrl}/ai-workouts/suggest-from-anamnesis',
        data: {
          'goal': _goal,
          'experience_level': _level,
          'weekly_frequency': _frequency,
          'session_duration': _duration,
          'equipment': _equipment,
          'activity_level': _activityLevel,
          'injuries': _injuries,
          'medical_conditions': _medicalConditions,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      // Decrement credits on success
      auth.fetchUserDetails();

      final respData = resp.data as Map<String, dynamic>;
      final status = respData['status'] as String? ?? '';

      // ── Cache hit — instant result ──────────────────────────
      if (status == 'ready' && mounted) {
        setState(() {
          _result = respData['result'] as Map<String, dynamic>?;
          _isLoading = false;
        });
        return;
      }

      // ── Job queued — start polling ─────────────────────────
      if (status == 'pending') {
        final jobId = respData['job_id'] as String?;
        if (jobId == null) throw Exception('job_id não retornado');
        setState(() {
          _jobId = jobId;
          _statusLabel = 'IA está montando seu programa... ⚡';
        });
        _startPolling(auth, jobId);
        return;
      }

      throw Exception('Resposta inesperada: $status');
    } on DioException catch (e) {
      if (mounted) {
        // Handle rate limit
        if (e.response?.statusCode == 429) {
          await AppDialog.show(
            context,
            title: 'Limite de IA Atingido',
            content: 'Você atingiu o limite de ${auth.subscriptionPlanName ?? 'seu plano'} para este mês. Faça upgrade para continuar criando treinos com a IA.',
            primaryButtonText: 'Ver Planos',
            secondaryButtonText: 'Ok',
            onPrimaryButton: () => Navigator.pop(context),
          );
        } else {
          final detail = e.response?.data?['detail'] ?? e.message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $detail')),
          );
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _startPolling(AuthProvider auth, String jobId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) {
        _pollTimer?.cancel();
        return;
      }
      try {
        final resp = await auth.dio.get(
          '${AppConstants.baseUrl}/ai-workouts/jobs/$jobId',
          options: Options(
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        final data = resp.data as Map<String, dynamic>;
        final jobStatus = data['status'] as String? ?? '';

        if (jobStatus == 'done') {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() {
              _result = data['result'] as Map<String, dynamic>?;
              _isLoading = false;
              _jobId = null;
            });
          }
        } else if (jobStatus == 'failed') {
          _pollTimer?.cancel();
          if (mounted) {
            final err = data['error'] as String? ?? 'Falha desconhecida';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('IA falhou: $err')),
            );
            setState(() => _isLoading = false);
          }
        } else {
          // Still processing — update label
          if (mounted) {
            setState(() {
              _statusLabel = jobStatus == 'processing'
                  ? 'Finalizando a periodização... 🧠'
                  : 'Na fila, aguardando... ⏳';
            });
          }
        }
      } catch (_) {
        // Network hiccup — retry on next tick
      }
    });
  }

  Future<void> _saveProgram() async {
    if (_result == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final workouts = (_result!['workouts'] as List?) ?? [];
    final programName = _result!['program_name'] as String? ?? 'Programa IA';
    if (workouts.isEmpty) return;

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      // Build the payload matching SaveAiProgramInput schema
      final days = workouts.map((w) {
        final wMap = w as Map<String, dynamic>;
        final exercises = (wMap['exercises'] as List? ?? []).map((ex) {
          final e = ex as Map<String, dynamic>;
          return {
            'exercise_name': e['exercise_name'] as String? ?? '',
            'sets': e['sets'] ?? 3,
            'reps_min': e['reps_min'],
            'reps_max': e['reps_max'],
            'duration_seconds': e['duration_seconds'],
            'rest_seconds': e['rest_seconds'] ?? 60,
            'notes': e['notes'],
          };
        }).toList();

        return {
          'name': wMap['name'] ?? 'Treino',
          'notes': wMap['notes'],
          'exercises': exercises,
        };
      }).toList();

      final resp = await auth.dio.post(
        '${AppConstants.baseUrl}/ai-workouts/save-program',
        data: {
          'program_name': programName,
          'workouts': days,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final saved = resp.data['saved'] as int? ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$saved treino${saved != 1 ? 's' : ''} salvo${saved != 1 ? 's' : ''} com sucesso! 🎉',
                style: const TextStyle(color: Colors.black),
              ),
              backgroundColor: const Color(AppConstants.neonAccent),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          // Small delay to allow transition to start rendering
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Row(
          children: [
            Icon(Icons.auto_awesome,
                color: const Color(AppConstants.neonAccent), size: 20),
            const SizedBox(width: 8),
            Text(
              'IA — Sugestão de Treino',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: _result != null ? _buildResult() : _buildForm(),
    );
  }

  // ─── FORM ─────────────────────────────────────────────────
  Widget _buildForm() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (auth.isTrainer) _AiCreditsBanner(
              credits: auth.aiRequestsRemaining,
              planName: auth.subscriptionPlanName,
            ),
            _buildInfoBanner(),
            const SizedBox(height: 20),
            _sectionTitle('🎯 Seu objetivo'),
            _buildChips(_goals, _goal, (v) => setState(() => _goal = v)),
            const SizedBox(height: 20),
            _sectionTitle('📊 Nível de Experiência'),
            _buildChips(_levels, _level, (v) => setState(() => _level = v)),
            const SizedBox(height: 20),
            _sectionTitle('📅 Frequência Semanal'),
            _buildChips(_frequencies, _frequency, (v) => setState(() => _frequency = v)),
            const SizedBox(height: 20),
            _sectionTitle('⏱ Duração por Sessão'),
            _buildChips(_durations, _duration, (v) => setState(() => _duration = v)),
            const SizedBox(height: 20),
            _sectionTitle('🏋️ Equipamentos'),
            _buildChips(_equipments, _equipment, (v) => setState(() => _equipment = v)),
            const SizedBox(height: 20),
            _sectionTitle('⚡ Nível de Atividade Atual'),
            _buildChips(_activityLevels, _activityLevel, (v) => setState(() => _activityLevel = v)),
            const SizedBox(height: 20),
            _sectionTitle('⚠️ Lesões ou Restrições (opcional)'),
            _buildTextField(
              'Ex: Dor no joelho direito, hérnia de disco...',
              (v) => _injuries = v,
            ),
            const SizedBox(height: 16),
            _sectionTitle('🏥 Condições Médicas (opcional)'),
            _buildTextField(
              'Ex: Hipertensão, diabetes...',
              (v) => _medicalConditions = v,
            ),
            const SizedBox(height: 32),
            _buildGenerateButton(),
            const SizedBox(height: 40),
          ],
        );
      }
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(AppConstants.neonAccent).withOpacity(0.08),
            Colors.purple.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(AppConstants.neonAccent).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(AppConstants.neonAccent), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'A IA criará um programa personalizado baseado no seu perfil completo, incluindo adaptações para lesões e restrições.',
              style: GoogleFonts.inter(
                color: Colors.grey[300],
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildChips(List<String> options, String selected, ValueChanged<String> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onTap(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(AppConstants.neonAccent).withOpacity(0.15)
                  : const Color(AppConstants.cardDark),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(AppConstants.neonAccent)
                    : const Color(AppConstants.borderColor),
              ),
            ),
            child: Text(
              opt,
              style: GoogleFonts.inter(
                color: isSelected
                    ? const Color(AppConstants.neonAccent)
                    : Colors.grey[400],
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(String hint, ValueChanged<String> onChanged) {
    return TextField(
      maxLines: 2,
      onChanged: onChanged,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
        filled: true,
        fillColor: const Color(AppConstants.cardDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(AppConstants.borderColor)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(AppConstants.borderColor)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(AppConstants.neonAccent).withOpacity(0.6)),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _generate,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(AppConstants.neonAccent),
          disabledBackgroundColor: const Color(AppConstants.neonAccent).withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome, color: Colors.black),
        label: Text(
          _isLoading ? _statusLabel : 'Gerar Programa com IA',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // ─── RESULT ───────────────────────────────────────────────
  Widget _buildResult() {
    final workouts = (_result!['workouts'] as List?) ?? [];
    final summary = _result!['summary'] as String? ?? '';
    final programName = _result!['program_name'] as String? ?? 'Meu Programa';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(AppConstants.neonAccent).withOpacity(0.1),
                Colors.purple.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(AppConstants.neonAccent).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Color(AppConstants.neonAccent), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    programName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                summary,
                style: GoogleFonts.inter(
                  color: Colors.grey[300],
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estes treinos são sugestões da IA. Consulte um profissional antes de iniciar.',
                        style: GoogleFonts.inter(
                          color: Colors.amber[300],
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Workouts
        ...workouts.asMap().entries.map((entry) {
          final i = entry.key;
          final w = entry.value as Map<String, dynamic>;
          return _buildWorkoutCard(i + 1, w);
        }),

        const SizedBox(height: 16),

        // Save button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveProgram,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.neonAccent),
              disabledBackgroundColor: const Color(AppConstants.neonAccent).withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt, color: Colors.black),
            label: Text(
              _isSaving ? 'Salvando...' : 'Salvar Programa',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Try again button
        OutlinedButton.icon(
          onPressed: _isSaving ? null : () => setState(() => _result = null),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey[700]!),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: Icon(Icons.refresh, color: Colors.grey[400]),
          label: Text(
            'Gerar novamente',
            style: GoogleFonts.inter(color: Colors.grey[400]),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildWorkoutCard(int dayNum, Map<String, dynamic> workout) {
    final name = workout['name'] as String? ?? 'Dia $dayNum';
    final notes = workout['notes'] as String?;
    final exercises = (workout['exercises'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(AppConstants.neonAccent)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (notes != null && notes.isNotEmpty)
                        Text(
                          notes,
                          style: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${exercises.length} exerc.',
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Exercises
          ...exercises.asMap().entries.map((e) {
            final ex = e.value as Map<String, dynamic>;
            final vol = ex['duration_seconds'] != null
                ? '${ex['sets']}x ${ex['duration_seconds']}s'
                : '${ex['sets']}x${ex['reps_min']}-${ex['reps_max']}';
            final rest = ex['rest_seconds'] as int? ?? 60;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: const Color(AppConstants.borderColor)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Color(AppConstants.neonAccent)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex['exercise_name'] as String? ?? '',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (ex['notes'] != null && (ex['notes'] as String).isNotEmpty)
                          Text(
                            ex['notes'] as String,
                            style: GoogleFonts.inter(
                              color: Colors.amber[400],
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        vol,
                        style: GoogleFonts.inter(
                          color: const Color(AppConstants.neonAccent),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${rest}s descanso',
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}


class _AiCreditsBanner extends StatelessWidget {
  final int? credits;
  final String? planName;

  const _AiCreditsBanner({this.credits, this.planName});

  @override
  Widget build(BuildContext context) {
    if (credits == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber[400], size: 18),
              const SizedBox(width: 8),
              Text(
                'Créditos de IA restantes:',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[300]),
              ),
            ],
          ),
          Text(
            '$credits',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
