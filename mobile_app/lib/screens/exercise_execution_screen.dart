import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../core/constants.dart';
import '../models/workout.dart';
import '../providers/bluetooth_controller.dart';
import '../providers/workout_session_provider.dart';
import '../providers/auth_provider.dart';
import '../services/exercise_load_history_service.dart';
import '../services/workout_service.dart';

class ExerciseExecutionScreen extends StatefulWidget {
  final int exerciseIndex;
  final Workout workout;

  const ExerciseExecutionScreen({
    super.key,
    required this.exerciseIndex,
    required this.workout,
  });

  @override
  State<ExerciseExecutionScreen> createState() => _ExerciseExecutionScreenState();
}

class _ExerciseExecutionScreenState extends State<ExerciseExecutionScreen> {
  late Exercise _currentExercise;
  late List<TextEditingController> _weightControllers;
  late List<TextEditingController> _repsControllers;

  final Set<int> _completedSets = {}; // base-0 indices
  int _currentSet = 1; // base-1
  bool _isResting = false;
  Timer? _restTimer;
  int _restSecondsRemaining = 0;

  static const int _defaultRestSeconds = 60;

  @override
  void initState() {
    super.initState();
    _loadExercise();
  }

  @override
  void dispose() {
    _cancelTimer();
    for (var controller in _weightControllers) {
      controller.dispose();
    }
    for (var controller in _repsControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExercise() async {
    _currentExercise = widget.workout.exercises[widget.exerciseIndex];
    final numSets = _currentExercise.sets;

    // Initialize controllers
    _weightControllers = List.generate(numSets, (_) => TextEditingController());
    _repsControllers = List.generate(numSets, (_) => TextEditingController());

    // Pre-fill with historical data: try backend first, fallback to local cache.
    // We keep the weight of EACH set (e.g. [60, 50, 40] for a drop/pyramid),
    // not a single value applied to every set.
    List<double?> perSetLoads = [];
    double? lastLoad; // fallback for sets beyond the recorded history
    try {
      final authProvider = context.read<AuthProvider>();
      final workoutService = WorkoutService(authProvider.dio);
      final history = await workoutService.getExerciseHistory(_currentExercise.id);

      if (history.isNotEmpty) {
        final sets = history.first['sets'] as List?;
        if (sets != null && sets.isNotEmpty) {
          perSetLoads = _extractPerSetLoads(sets);
        }
      }
    } catch (e) {
      debugPrint('[LoadHistory] Failed to fetch from backend: $e');
    }

    // Fallback to local per-set cache if backend had nothing.
    if (perSetLoads.every((w) => w == null)) {
      final cachedSets =
          await ExerciseLoadHistoryService.getExerciseSets(_currentExercise.id);
      if (cachedSets.isNotEmpty) {
        perSetLoads = cachedSets
            .map((s) => (s.weightKg != null && s.weightKg! > 0) ? s.weightKg : null)
            .toList();
      }
    }

    // Last recorded non-zero weight — used for sets beyond the history length.
    for (int i = perSetLoads.length - 1; i >= 0; i--) {
      if (perSetLoads[i] != null) {
        lastLoad = perSetLoads[i];
        break;
      }
    }
    lastLoad ??= await ExerciseLoadHistoryService.getLoad(_currentExercise.id);

    for (int i = 0; i < numSets; i++) {
      final w = (i < perSetLoads.length && perSetLoads[i] != null)
          ? perSetLoads[i]
          : lastLoad;
      if (w != null && w > 0) {
        _weightControllers[i].text = w.toStringAsFixed(0);
      }
      // Per-set planned reps when available, otherwise the exercise's reps.
      final repsForSet = (i < _currentExercise.repsPerSet.length)
          ? _currentExercise.repsPerSet[i]
          : _currentExercise.reps;
      if (repsForSet != null) {
        _repsControllers[i].text = repsForSet.toString();
      }
    }

    _completedSets.clear();
    _currentSet = 1;
    _isResting = false;
    _cancelTimer();
    if (mounted) setState(() {});
  }

  /// Extracts the weight of each set from a history `sets` list, ordered by
  /// set_number. Returns null for sets without a recorded weight.
  List<double?> _extractPerSetLoads(List sets) {
    final ordered = List<dynamic>.from(sets);
    ordered.sort((a, b) {
      final an = (a is Map && a['set_number'] is num) ? a['set_number'] as num : 0;
      final bn = (b is Map && b['set_number'] is num) ? b['set_number'] as num : 0;
      return an.compareTo(bn);
    });
    return ordered.map<double?>((s) {
      final raw = (s is Map) ? s['weight_kg'] : null;
      final w = (raw is num) ? raw.toDouble() : null;
      return (w != null && w > 0) ? w : null;
    }).toList();
  }

  void _cancelTimer() {
    _restTimer?.cancel();
    _restTimer = null;
  }

  void _startRest() {
    setState(() {
      _isResting = true;
      _restSecondsRemaining = _currentExercise.restSeconds ?? _defaultRestSeconds;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_restSecondsRemaining > 0) {
          _restSecondsRemaining--;
        } else {
          _finishRest();
        }
      });
    });
  }

  void _finishRest() {
    _cancelTimer();
    setState(() {
      _isResting = false;
      _currentSet++;
    });
  }

  void _skipRest() {
    _finishRest();
  }

  void _completeSet(int setNumber) {
    final sessionProvider = context.read<WorkoutSessionProvider>();

    final weightText = _weightControllers[setNumber - 1].text.trim();
    final repsText = _repsControllers[setNumber - 1].text.trim();
    final weight = double.tryParse(weightText);
    final reps = int.tryParse(repsText);

    // Register in provider
    sessionProvider.recordSetData(
      widget.exerciseIndex,
      setNumber,
      weight,
      reps,
    );

    // Mark as completed
    _completedSets.add(setNumber - 1);

    // Check if all sets completed
    if (_completedSets.length == _currentExercise.sets) {
      _finishExercise();
    } else {
      // Start rest and move to next set
      if (setNumber < _currentExercise.sets) {
        _startRest();
      }
    }
  }

  void _finishExercise() {
    final sessionProvider = context.read<WorkoutSessionProvider>();
    sessionProvider.completeExercise(widget.exerciseIndex);

    if (widget.exerciseIndex < widget.workout.exercises.length - 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseExecutionScreen(
            exerciseIndex: widget.exerciseIndex + 1,
            workout: widget.workout,
          ),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _openVideo() {
    final url = _currentExercise.videoUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vídeo indisponível para este exercício.', style: GoogleFonts.inter()),
            backgroundColor: const Color(AppConstants.cardDark),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('URL do vídeo inválida.', style: GoogleFonts.inter()),
            backgroundColor: const Color(AppConstants.cardDark),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VideoBottomSheet(
        videoId: videoId,
        exerciseName: _currentExercise.name,
      ),
    );
  }

  void _showInstructions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(AppConstants.cardDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'INSTRUÇÕES',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  controller: scrollController,
                  children: _currentExercise.instructions!
                      .map((instruction) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6.0),
                                  child: Icon(Icons.circle,
                                      size: 6, color: Color(AppConstants.neonAccent)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    instruction,
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _openGifFullscreen(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Animated demonstration GIF shown at the top of the execution screen.
  /// Returns an empty box when the exercise has no GIF.
  Widget _buildGifBanner() {
    final url = _currentExercise.gifUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () => _openGifFullscreen(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 190,
            width: double.infinity,
            color: Colors.white,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(AppConstants.neonAccent),
                    strokeWidth: 2,
                  ),
                );
              },
              errorBuilder: (context, error, stack) => Center(
                child: Icon(
                  Icons.fitness_center,
                  color: Colors.black.withOpacity(0.2),
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSeriesTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  'SÉRIE',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(AppConstants.textSecondary),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'CARGA (KG)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(AppConstants.textSecondary),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'REPS',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(AppConstants.textSecondary),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 50),
            ],
          ),
        ),
        const Divider(color: Colors.white10),
        // Series Rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _currentExercise.sets,
          separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, index) {
            final setNumber = index + 1;
            final isCompleted = _completedSets.contains(index);
            final isActive = setNumber == _currentSet && !_isResting;
            final isFuture = setNumber > _currentSet;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: isActive
                  ? BoxDecoration(
                      color: const Color(AppConstants.neonAccent).withOpacity(0.1),
                      border: Border(
                        left: BorderSide(
                          color: const Color(AppConstants.neonAccent),
                          width: 3,
                        ),
                      ),
                    )
                  : null,
              child: Row(
                children: [
                  // Set Number
                  SizedBox(
                    width: 50,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? const Color(AppConstants.neonAccent)
                            : isActive
                                ? const Color(AppConstants.neonAccent).withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: isActive
                              ? const Color(AppConstants.neonAccent)
                              : Colors.white10,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.black, size: 18)
                            : Text(
                                setNumber.toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Weight Controls
                  Expanded(
                    flex: 1,
                    child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () {
                                  final current =
                                      double.tryParse(_weightControllers[index].text) ?? 0;
                                  _weightControllers[index].text =
                                      ((current - 1).clamp(0, 999)).toString();
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: const Icon(Icons.remove,
                                      size: 16, color: Colors.white70),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextFormField(
                                  controller: _weightControllers[index],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(AppConstants.cyanAccent),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isActive
                                            ? const Color(AppConstants.cyanAccent)
                                            : Colors.white10,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(AppConstants.cyanAccent),
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.03),
                                    hintText: '?',
                                    hintStyle: GoogleFonts.inter(
                                      color: Colors.white38,
                                    ),
                                  ),
                                  enabled: !isFuture,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  final current =
                                      double.tryParse(_weightControllers[index].text) ?? 0;
                                  _weightControllers[index].text =
                                      (current + 1).toString();
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: const Icon(Icons.add,
                                      size: 16, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  // Reps Controls
                  Expanded(
                    flex: 1,
                    child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () {
                                  final current =
                                      int.tryParse(_repsControllers[index].text) ?? 0;
                                  _repsControllers[index].text =
                                      ((current - 1).clamp(0, 999)).toString();
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: const Icon(Icons.remove,
                                      size: 16, color: Colors.white70),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextFormField(
                                  controller: _repsControllers[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(AppConstants.cyanAccent),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isActive
                                            ? const Color(AppConstants.cyanAccent)
                                            : Colors.white10,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(AppConstants.cyanAccent),
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.03),
                                    hintText: '?',
                                    hintStyle: GoogleFonts.inter(
                                      color: Colors.white38,
                                    ),
                                  ),
                                  enabled: !isFuture,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  final current =
                                      int.tryParse(_repsControllers[index].text) ?? 0;
                                  _repsControllers[index].text = (current + 1).toString();
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: const Icon(Icons.add,
                                      size: 16, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  // Checkmark Button
                  InkWell(
                    onTap: isCompleted || isFuture ? null : () => _completeSet(setNumber),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? const Color(AppConstants.neonAccent).withOpacity(0.2)
                            : isActive
                                ? const Color(AppConstants.neonAccent).withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: isActive
                              ? const Color(AppConstants.neonAccent)
                              : Colors.white10,
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(Icons.check_circle,
                              color: Color(AppConstants.neonAccent), size: 24)
                          : Icon(
                              Icons.check_circle_outline,
                              color: Colors.white.withOpacity(0.3),
                              size: 24,
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRestBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(AppConstants.cardDark),
        child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRÓXIMA: SÉRIE $_currentSet',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white60,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(_restSecondsRemaining),
                  style: GoogleFonts.robotoMono(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(AppConstants.neonAccent),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _skipRest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'PULAR',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothController>(
      builder: (context, bluetooth, child) {
        final int bpm = bluetooth.heartRate;

        return Scaffold(
          backgroundColor: const Color(AppConstants.primaryDark),
          appBar: AppBar(
            backgroundColor: const Color(AppConstants.cardDark),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              _currentExercise.name,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.play_circle_outline,
                  color: (_currentExercise.videoUrl != null && _currentExercise.videoUrl!.isNotEmpty)
                      ? const Color(AppConstants.neonAccent)
                      : Colors.white38,
                ),
                onPressed: _openVideo,
                tooltip: 'Ver vídeo',
              ),
              if (_currentExercise.instructions != null && _currentExercise.instructions!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.description_outlined, color: Color(AppConstants.neonAccent)),
                  onPressed: _showInstructions,
                  tooltip: 'Instruções',
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0, left: 8.0),
                  child: Text(
                    '${widget.exerciseIndex + 1}/${widget.workout.exercises.length}',
                    style: GoogleFonts.inter(
                      color: const Color(AppConstants.textSecondary),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: GestureDetector(
            onHorizontalDragEnd: (details) {
              // Swipe left: next exercise
              if (details.primaryVelocity! < -500) {
                _finishExercise();
              }
              // Swipe right: previous exercise
              else if (details.primaryVelocity! > 500 && widget.exerciseIndex > 0) {
                Navigator.pop(context);
              }
            },
            child: Column(
              children: [
                // Demonstration GIF (stick figure)
                _buildGifBanner(),
                // Exercise Info (compact)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _currentExercise.name,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Alvo: ${_currentExercise.sets}×${_currentExercise.reps ?? _currentExercise.formattedDuration}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_currentExercise.notes != null && _currentExercise.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _currentExercise.notes!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(AppConstants.neonAccent).withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                // Series Table
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildSeriesTable(),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _isResting ? _buildRestBottomBar() : null,
        );
      },
    );
  }
}

/// Bottom-sheet widget that shows the exercise YouTube video starting muted,
/// with a floating mute/unmute toggle button overlaid on the player.
class _VideoBottomSheet extends StatefulWidget {
  final String videoId;
  final String exerciseName;

  const _VideoBottomSheet({
    required this.videoId,
    required this.exerciseName,
  });

  @override
  State<_VideoBottomSheet> createState() => _VideoBottomSheetState();
}

class _VideoBottomSheetState extends State<_VideoBottomSheet> {
  late YoutubePlayerController _controller;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: true, // always start muted
        enableCaption: false,
        loop: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) {
        _controller.mute();
      } else {
        _controller.unMute();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(AppConstants.primaryDark),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.exerciseName,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Video player with mute button overlay
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                YoutubePlayerBuilder(
                  player: YoutubePlayer(
                    controller: _controller,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: const Color(AppConstants.neonAccent),
                    progressColors: const ProgressBarColors(
                      playedColor: Color(AppConstants.neonAccent),
                      handleColor: Color(AppConstants.cyanAccent),
                    ),
                  ),
                  builder: (context, player) => player,
                ),

                // Mute/Unmute floating pill button
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isMuted
                            ? Colors.black.withOpacity(0.7)
                            : const Color(AppConstants.neonAccent).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isMuted
                              ? Colors.white24
                              : const Color(AppConstants.neonAccent),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: _isMuted ? Colors.white70 : Colors.black,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isMuted ? 'SOM' : 'MUDO',
                            style: GoogleFonts.inter(
                              color: _isMuted ? Colors.white70 : Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
