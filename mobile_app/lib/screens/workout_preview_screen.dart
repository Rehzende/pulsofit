import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/workout.dart';

class WorkoutPreviewScreen extends StatelessWidget {
  final Workout workout;

  const WorkoutPreviewScreen({super.key, required this.workout});

  String _getMethodologyDescription(String methodology) {
    switch (methodology.toUpperCase()) {
      case 'DROP_SET':
        return 'Drop Set';
      case 'REST_PAUSE':
        return 'Rest-Pause';
      case 'PIRAMIDE':
        return 'Pirâmide';
      case 'FST_7':
        return 'FST-7';
      case 'AMRAP':
        return 'AMRAP';
      case 'EMOM':
        return 'EMOM';
      default:
        return 'Normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        elevation: 0,
        title: Text(
          workout.name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Descrição
            if (workout.description != null && workout.description!.isNotEmpty) ...[
              Text(
                'Descrição',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.cardDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  workout.description!,
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade300,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Estatísticas gerais
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(AppConstants.cardDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatBadge('TOTAL', '${workout.exercises.length}', 'Exercícios'),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  _buildStatBadge(
                    'SÉRIES',
                    '${workout.exercises.fold<int>(0, (sum, ex) => sum + ex.sets)}',
                    'Séries',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Lista de Exercícios
            Text(
              'Exercícios',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (workout.exercises.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Nenhum exercício neste treino.',
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: workout.exercises.length,
                itemBuilder: (context, index) {
                  final exercise = workout.exercises[index];
                  final methodology = exercise.methodologyType ?? 'NORMAL';
                  final isSuperset = exercise.supersetId != null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.cardDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSuperset
                            ? const Color(AppConstants.cyanAccent).withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                        width: isSuperset ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: número + nome
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(AppConstants.neonAccent),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.inter(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exercise.name,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (isSuperset)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'BI-SET',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(AppConstants.cyanAccent),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Detalhes: séries, reps, descanso
                        Row(
                          children: [
                            Expanded(
                              child: _buildExerciseDetail(
                                'SÉRIES',
                                '${exercise.sets}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildExerciseDetail(
                                exercise.isTimeBased ? 'TEMPO' : 'REPS',
                                exercise.isTimeBased
                                    ? exercise.formattedDuration
                                    : '${exercise.reps ?? "-"}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildExerciseDetail(
                                'DESCANSO',
                                '${exercise.restSeconds ?? 60}s',
                              ),
                            ),
                          ],
                        ),

                        // Metodologia (se não for NORMAL)
                        if (methodology != 'NORMAL') ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(AppConstants.neonAccent).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(AppConstants.neonAccent).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _getMethodologyDescription(methodology),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(AppConstants.neonAccent),
                              ),
                            ),
                          ),
                        ],

                        // Notas (se houver)
                        if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb_outline,
                                size: 14,
                                color: Color(AppConstants.neonAccent),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  exercise.notes!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(AppConstants.textSecondary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(AppConstants.neonAccent),
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(AppConstants.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(AppConstants.textSecondary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
