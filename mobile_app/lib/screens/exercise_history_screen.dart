import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';

class ExerciseHistoryScreen extends StatefulWidget {
  final Exercise exercise;
  final WorkoutService workoutService;

  const ExerciseHistoryScreen({
    super.key,
    required this.exercise,
    required this.workoutService,
  });

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = widget.workoutService.getExerciseHistory(widget.exercise.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progresso',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(AppConstants.textSecondary)),
            ),
            Text(
              widget.exercise.name,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar histórico',
                style: GoogleFonts.inter(color: Colors.red),
              ),
            );
          }

          final records = snapshot.data ?? [];

          if (records.isEmpty) {
            return Center(
              child: Text(
                'Nenhum histórico disponível',
                style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary)),
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weight Progression Chart
                Text(
                  'Carga Máxima',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 250,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.cardDark),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildWeightChart(records),
                ),

                const SizedBox(height: 32),

                // History List
                Text(
                  'Histórico de Sessões',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._buildSessionsList(records),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeightChart(List<Map<String, dynamic>> records) {
    // Extract data for chart
    final spots = <FlSpot>[];
    for (int i = 0; i < records.length; i++) {
      final maxWeight = (records[i]['max_weight_kg'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), maxWeight));
    }

    if (spots.isEmpty || spots.every((s) => s.y == 0)) {
      return Center(
        child: Text(
          'Sem dados de carga',
          style: GoogleFonts.inter(color: Colors.grey),
        ),
      );
    }

    final maxWeight = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minWeight = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: (minWeight * 0.9).clamp(0, double.infinity),
        maxY: maxWeight * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(AppConstants.neonAccent),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: const Color(AppConstants.neonAccent),
                  strokeWidth: 2,
                  strokeColor: Colors.black,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(AppConstants.neonAccent).withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSessionsList(List<Map<String, dynamic>> records) {
    return records.map((record) {
      final date = record['date'] as String?;
      final workoutName = record['workout_name'] as String?;
      final sets = record['sets'] as List?;
      final maxWeight = (record['max_weight_kg'] as num?)?.toDouble() ?? 0.0;
      final totalVolume = (record['total_volume'] as num?)?.toDouble() ?? 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(AppConstants.cardDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(AppConstants.borderColor)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Date and Workout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(date),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        workoutName ?? 'Sem nome',
                        style: GoogleFonts.inter(
                          color: const Color(AppConstants.textSecondary),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${maxWeight.toStringAsFixed(1)}kg',
                        style: GoogleFonts.inter(
                          color: const Color(AppConstants.neonAccent),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Vol: ${totalVolume.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          color: const Color(AppConstants.textSecondary),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (sets != null && sets.isNotEmpty) ...[
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(1.5),
                  },
                  children: [
                    TableRow(
                      children: [
                        Text('Série', style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary), fontSize: 11)),
                        Text('Peso', style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary), fontSize: 11)),
                        Text('Reps', style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary), fontSize: 11)),
                      ],
                    ),
                    ...(sets.cast<Map<String, dynamic>>()).map((setData) {
                      final setNum = setData['set'] ?? 0;
                      final weight = setData['weight_kg'] ?? 0;
                      final reps = setData['reps_done'] ?? 0;
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('#$setNum', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('${weight}kg', style: GoogleFonts.inter(color: Colors.white, fontSize: 11)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('$reps', style: GoogleFonts.inter(color: Colors.white, fontSize: 11)),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }).toList();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy', 'pt_BR').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
