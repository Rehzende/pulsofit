import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

import '../core/constants.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/workout_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/error_retry_view.dart';
import 'workout_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<WorkoutSession> _sessions = [];
  Map<String, Workout> _workoutsMap = {};
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(authProvider.dio);
      
      // Fetch history directly from backend (filtered by COMPLETED)
      final sessions = await workoutService.getHistory();
      
      // Also fetch workouts to map names
      final workouts = await workoutService.getWorkouts();
      Map<String, Workout> workoutsMap = {};
      for (var workout in workouts) {
        workoutsMap[workout.id] = workout;
      }

      // Add pending sessions (offline)
      final pendingSessions = await workoutService.getPendingSessions();
      sessions.addAll(pendingSessions);

      // Sort by date descending
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));

      setState(() {
        _sessions = sessions;
        _workoutsMap = workoutsMap;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _shareSession(WorkoutSession session) async {
    final workout = _workoutsMap[session.workoutId];
    if (workout == null) return;

    try {
      final image = await _screenshotController.captureFromWidget(
        _buildShareCard(session, workout),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0,
      );

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/workout_share.png').create();
      await imagePath.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Acabei de completar o treino ${workout.name} no PULSO! 💪🔥 #PULSO #Fitness',
      );
    } catch (e) {
      debugPrint('Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao compartilhar treino')),
        );
      }
    }
  }



  Future<void> _confirmDelete(WorkoutSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text('Excluir Treino', style: GoogleFonts.inter(color: Colors.white)),
        content: Text(
          'Tem certeza que deseja excluir este treino do histórico?',
          style: GoogleFonts.inter(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteSession(session);
    }
  }

  Future<void> _deleteSession(WorkoutSession session) async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(authProvider.dio);

      final success = await workoutService.deleteSession(session.id);

      if (success) {
        if (mounted) {
          final message = session.status == 'pending'
              ? 'Treino pendente removido'
              : 'Treino excluído com sucesso';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          _loadHistory(); // Reload list
        }
      } else {
        if (mounted) {
          String errorMessage = 'Erro ao excluir treino';
          if (session.status != 'pending') {
            errorMessage = 'Você precisa estar online para excluir treinos sincronizados';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error deleting session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao excluir treino')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildShareCard(WorkoutSession session, Workout workout) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(AppConstants.primaryDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(AppConstants.neonAccent), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fitness_center, color: Color(AppConstants.neonAccent), size: 32),
              const SizedBox(width: 12),
              Text(
                'TREINO CONCLUÍDO',
                style: GoogleFonts.inter(
                  color: const Color(AppConstants.neonAccent),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            workout.name,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildShareStat('DURAÇÃO', _formatDuration(session.durationSeconds ?? 0)),
              Container(width: 1, height: 40, color: Colors.grey),
              _buildShareStat('BPM MÉDIO', '${session.averageHeartRate ?? "-"}'),
            ],
          ),
          if (session.caloriesBurned != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${session.caloriesBurned?.toStringAsFixed(0) ?? "-"} kcal',
                style: GoogleFonts.inter(
                  color: Colors.orange,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          if (session.xpEarned != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(AppConstants.neonAccent).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+${session.xpEarned} XP',
                style: GoogleFonts.inter(
                  color: const Color(AppConstants.neonAccent),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Column(
            children: [
              Text(
                DateFormat('dd/MM/yyyy').format(session.startTime),
                style: GoogleFonts.inter(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('HH:mm').format(session.startTime),
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Histórico de Treinos',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? ErrorRetryView(onRetry: _loadHistory)
              : _sessions.isEmpty
                  ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum treino registrado ainda.',
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final workout = _workoutsMap[session.workoutId];

                    // Derive workout name: prefer current workout, fallback to snapshot
                    final workoutName = workout?.name ??
                        (session.workoutSnapshot?.isNotEmpty == true
                            ? 'Treino (editado)'
                            : 'Treino removido');

                    // Skip only if we have truly no info at all
                    if (workout == null && (session.workoutSnapshot?.isEmpty ?? true)) {
                      return const SizedBox.shrink();
                    }

                    return GestureDetector(
                      onTap: () {
                        if (workout != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WorkoutDetailsScreen(
                                session: session,
                                workout: workout,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(AppConstants.cardDark),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(AppConstants.borderColor)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(
                                        DateFormat('dd/MM/yyyy • HH:mm').format(session.startTime),
                                        style: GoogleFonts.inter(
                                          color: const Color(AppConstants.textSecondary),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: session.status == 'pending' || session.status == 'IN_PROGRESS'
                                                ? Colors.orange.withOpacity(0.1) 
                                                : const Color(AppConstants.neonAccent).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            session.status == 'pending' ? 'Pendente' : 
                                            session.status == 'IN_PROGRESS' ? 'Em Andamento' : 'Concluído',
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              color: session.status == 'pending' || session.status == 'IN_PROGRESS' ? Colors.orange : const Color(AppConstants.neonAccent),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => _confirmDelete(session),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              workoutName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _buildStatItem(Icons.timer_outlined, _formatDuration(session.durationSeconds ?? 0)),
                                _buildStatItem(Icons.favorite_outline, '${session.averageHeartRate ?? "-"} BPM'),
                                _buildStatItem(Icons.local_fire_department_outlined, '${session.caloriesBurned?.toStringAsFixed(0) ?? "-"} Kcal'),
                                if (session.xpEarned != null)
                                  _buildStatItem(Icons.star_outline, '+${session.xpEarned} XP'),
                              ],
                            ),
                              ],
                            ),
                          ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildStatItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
