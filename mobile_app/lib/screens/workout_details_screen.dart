import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/workout_service.dart';
import './exercise_history_screen.dart';

class WorkoutDetailsScreen extends StatefulWidget {
  final WorkoutSession session;
  final Workout workout;

  const WorkoutDetailsScreen({
    super.key,
    required this.session,
    required this.workout,
  });

  @override
  State<WorkoutDetailsScreen> createState() => _WorkoutDetailsScreenState();
}

class _WorkoutDetailsScreenState extends State<WorkoutDetailsScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  String _formatDuration(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Future<void> _shareSession() async {
    setState(() => _isSharing = true);
    try {
      final image = await _screenshotController.captureFromWidget(
        Theme(
          data: ThemeData.dark(),
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: Material(
              color: Colors.transparent,
              child: _buildShareCard(),
            ),
          ),
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0,
      );

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/workout_share_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await imagePath.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Confira meu treino ${widget.workout.name} no PULSO! 💪🔥',
      );
    } catch (e) {
      debugPrint('Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao compartilhar treino')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          widget.workout.name,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _isSharing ? null : _shareSession,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Text(
              DateFormat('EEEE, d MMMM y', 'pt_BR').format(widget.session.startTime),
              style: GoogleFonts.inter(
                color: const Color(AppConstants.textSecondary),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Main Stats Grid
            Row(
              children: [
                Expanded(child: _buildStatCard(Icons.timer_outlined, 'Duração', _formatDuration(widget.session.durationSeconds ?? 0))),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard(Icons.favorite_outline, 'BPM Médio', '${widget.session.averageHeartRate ?? "-"}')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatCard(Icons.local_fire_department_outlined, 'Calorias', widget.session.caloriesBurned?.toStringAsFixed(0) ?? '-')),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard(Icons.star_outline, 'XP Ganho', '+${widget.session.xpEarned ?? "-"}')),
              ],
            ),

            const SizedBox(height: 32),

            // Heart Rate Graph
            Text(
              'Frequência Cardíaca',
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
              child: widget.session.heartRateData.isEmpty
                  ? Center(
                      child: Text(
                        'Sem dados de frequência cardíaca',
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: widget.session.heartRateData.length.toDouble() - 1,
                        minY: 0,
                        maxY: 200,
                        lineBarsData: [
                          LineChartBarData(
                            spots: widget.session.heartRateData.asMap().entries.map((e) {
                              return FlSpot(e.key.toDouble(), (e.value['bpm'] as int).toDouble());
                            }).toList(),
                            isCurved: true,
                            color: const Color(AppConstants.neonAccent),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(AppConstants.neonAccent).withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Exercises section (if progress data available)
            if (widget.session.progressData != null && widget.session.progressData!.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                'Exercícios',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._buildExercisesSection(),
            ],
            // Show snapshot-only exercises (no progress data but snapshot available)
            if ((widget.session.progressData == null || widget.session.progressData!.isEmpty) &&
                (widget.session.workoutSnapshot?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 32),
              Text(
                'Exercícios do Treino',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._buildSnapshotOnlySection(),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildExercisesSection() {
    final progressData = widget.session.progressData ?? {};

    // Prefer snapshot (historical freeze) over current workout exercises
    final snapshot = widget.session.workoutSnapshot;
    final exercises = widget.workout.exercises;

    // Build a list of (exerciseId, exerciseName) pairs from snapshot or fallback
    final List<Map<String, dynamic>> exerciseList = snapshot != null && snapshot.isNotEmpty
        ? snapshot
        : exercises.map((e) => {'exercise_id': e.exerciseId, 'exercise_name': e.name}).toList();

    return exerciseList.map((exerciseEntry) {
      final exerciseIdStr = exerciseEntry['exercise_id']?.toString() ?? '';
      final exerciseName = (exerciseEntry['exercise_name'] as String?)?.isNotEmpty == true
          ? exerciseEntry['exercise_name'] as String
          : 'Exercício';

      final exerciseData = progressData[exerciseIdStr];
      if (exerciseData == null) return const SizedBox.shrink();

      final sets = exerciseData['sets'] as List?;
      if (sets == null || sets.isEmpty) return const SizedBox.shrink();

      // Find the corresponding exercise for navigation (if available in current workout)
      final matchingExercise = exercises.isNotEmpty
          ? exercises.where((e) => e.exerciseId == exerciseIdStr).firstOrNull
          : null;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: matchingExercise != null
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ExerciseHistoryScreen(
                        exercise: matchingExercise,
                        workoutService: WorkoutService(Dio()),
                      ),
                    ),
                  );
                }
              : null,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      exerciseName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (matchingExercise != null)
                      const Icon(Icons.arrow_forward_ios, color: Color(AppConstants.neonAccent), size: 16),
                  ],
                ),
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      children: [
                        Text('Série', style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary), fontSize: 12)),
                        Text('Peso (kg)', style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary), fontSize: 12)),
                        Text('Reps', style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary), fontSize: 12)),
                      ],
                    ),
                    ...sets.map((setData) {
                      final setNum = setData['set'] ?? 0;
                      final weight = setData['weight_kg'] ?? 0;
                      final reps = setData['reps_done'] ?? 0;
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('#$setNum', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('${weight}kg', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('$reps', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Shows exercise list from snapshot when no per-set progress data is available
  List<Widget> _buildSnapshotOnlySection() {
    final snapshot = widget.session.workoutSnapshot ?? [];

    return snapshot.map((item) {
      final exerciseName = (item['exercise_name'] as String?)?.isNotEmpty == true
          ? item['exercise_name'] as String
          : 'Exercício';
      final sets = item['sets'] ?? '-';
      final repsMin = item['reps_min'];
      final repsMax = item['reps_max'];
      final repsStr = repsMin != null
          ? (repsMax != null && repsMax != repsMin ? '$repsMin–$repsMax reps' : '$repsMin reps')
          : '-';

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(AppConstants.cardDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(AppConstants.borderColor)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.fitness_center, color: Color(AppConstants.neonAccent), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  exerciseName,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '$sets séries • $repsStr',
                style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }


  Widget _buildStatCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(AppConstants.neonAccent), size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(AppConstants.textSecondary),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareCard() {
    final dateStr = DateFormat('dd/MM', 'pt_BR').format(widget.session.startTime);

    return Container(
      width: 300,
      height: 533,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // ── TOP HEADER ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black,
              child: Row(
                children: [
                  // Workout name box
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.workout.name.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Date pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      dateStr,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // PULSO logo
                  Row(
                    children: [
                      const Icon(Icons.fitness_center, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'PULSO',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── IMAGE AREA (default background) ─────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Abstract background
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1a1a1a), Color(0xFF000000)],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -50,
                          right: -50,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(AppConstants.neonAccent).withValues(alpha: 0.08),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(AppConstants.neonAccent).withValues(alpha: 0.15),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 100,
                          left: -30,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.purple.withValues(alpha: 0.08),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withValues(alpha: 0.15),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(bottom: 80),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.08),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.fitness_center,
                                  size: 64,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'NO EXCUSES.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'POWERED BY PULSO',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: const Color(AppConstants.neonAccent).withValues(alpha: 0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Frosted glass stats overlay
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildFrostedStat(
                                    label: 'DURAÇÃO',
                                    value: _formatDuration(widget.session.durationSeconds ?? 0),
                                    icon: Icons.timer_outlined,
                                  ),
                                ),
                                VerticalDivider(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                  thickness: 1,
                                ),
                                Expanded(
                                  child: _buildFrostedStat(
                                    label: 'CALORIAS',
                                    value: widget.session.caloriesBurned != null
                                        ? widget.session.caloriesBurned!.toStringAsFixed(0)
                                        : '--',
                                    unit: 'KCAL',
                                    icon: Icons.local_fire_department_outlined,
                                    iconColor: const Color(0xFFFF6B00),
                                  ),
                                ),
                                if ((widget.session.averageHeartRate ?? 0) > 0) ...[
                                  VerticalDivider(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                    thickness: 1,
                                  ),
                                  Expanded(
                                    child: _buildFrostedStat(
                                      label: 'FREQUÊNCIA\nCARDÍACA',
                                      value: '${widget.session.averageHeartRate}',
                                      unit: 'BPM',
                                      icon: Icons.favorite_border,
                                      iconColor: const Color(0xFFE53935),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── FOOTER: @pulsofit.app ────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFF151515),
              alignment: Alignment.centerRight,
              child: Text(
                '@pulsofit.app',
                style: GoogleFonts.inter(
                  color: const Color(AppConstants.neonAccent).withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // ── XP PANEL ────────────────────────────────────────
            if ((widget.session.xpEarned ?? 0) > 0)
              Container(
                color: const Color(0xFF1A1A1A),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_upward, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '+${widget.session.xpEarned}',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'XP GANHO',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrostedStat({
    required String label,
    required String value,
    String? unit,
    required IconData icon,
    Color iconColor = Colors.white,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 11),
            const SizedBox(width: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
