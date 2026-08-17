import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/workout.dart';
import '../providers/bluetooth_controller.dart';
import '../providers/workout_session_provider.dart';
import 'workout_summary_screen.dart';
import 'exercise_execution_screen.dart';
import '../services/websocket_service.dart';
import '../services/chat_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/mood_checkin_sheet.dart';
import '../services/exercise_load_history_service.dart';

class WorkoutRunnerScreen extends StatefulWidget {
  final Workout? workout;

  const WorkoutRunnerScreen({
    super.key,
    this.workout,
  });

  @override
  State<WorkoutRunnerScreen> createState() => _WorkoutRunnerScreenState();
}

class _WorkoutRunnerScreenState extends State<WorkoutRunnerScreen> {
  late BluetoothController _bluetoothController;
  bool _deviceTipShown = false;
  bool _sessionInitialized = false;  // Prevent duplicate startSession calls
  Timer? _heartbeatTimer;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  Timer? _messagePollingTimer;
  DateTime? _workoutStartedAt;
  // conversationId → lastMessageAt seen so far
  final Map<String, DateTime> _lastSeenMessageAt = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_sessionInitialized) return;  // Prevent duplicate calls

      final sessionProvider = context.read<WorkoutSessionProvider>();
      if (!sessionProvider.isSessionActive && widget.workout != null) {
        _sessionInitialized = true;  // Mark as initialized

        // 🧠 Mood Check-in PRÉ-TREINO
        final moodBefore = await showMoodCheckIn(context, phase: 'before');

        sessionProvider.startSession(widget.workout!);

        // Start Heartbeat Timer
        _startHeartbeatTimer();

        // Save mood once session starts (session ID may not be ready yet — backend handles it)
        if (moodBefore != null) {
          final authProvider = context.read<AuthProvider>();
          try {
            await authProvider.dio.post(
              '${AppConstants.baseUrl}/workout-sessions/mood',
              data: {'mood': moodBefore, 'phase': 'before'},
            );
          } catch (e) {
            debugPrint('Mood save error (non-critical): $e');
          }
        }
      }
    });

    // Listen to Bluetooth updates
    _bluetoothController = context.read<BluetoothController>();
    _bluetoothController.addListener(_onBluetoothUpdate);

    // Initialize WebSocket
    _initWebSocket();
    _listenToTrainerMessages();

    // Polling fallback: catch trainer messages even if WS fails
    _workoutStartedAt = DateTime.now().toUtc();
    _startMessagePolling();
  }

  Future<void> _initWebSocket() async {
    final authProvider = context.read<AuthProvider>();
    final wsService = WebSocketService();
    
    if (authProvider.token != null) {
      await wsService.connect(authProvider.token!);
      await Future.delayed(const Duration(seconds: 5));
      wsService.sendEvent('START_SESSION', {
        'workout_id': widget.workout?.id,
        'workout_name': widget.workout?.name,
      });
    }
  }

  void _startMessagePolling() {
    final authProvider = context.read<AuthProvider>();
    final chatService = ChatService(authProvider.dio);

    _messagePollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try {
        final conversations = await chatService.fetchConversations();
        for (final conv in conversations) {
          // Only conversations where the other user is a trainer
          if (!conv.isFromTrainer) continue;
          final msgAt = conv.lastMessageAt;
          if (msgAt == null) continue;
          // Only messages that arrived after workout started
          if (_workoutStartedAt != null && msgAt.isBefore(_workoutStartedAt!)) continue;
          // Only if newer than what we've already shown
          final lastSeen = _lastSeenMessageAt[conv.id];
          if (lastSeen != null && !msgAt.isAfter(lastSeen)) continue;

          _lastSeenMessageAt[conv.id] = msgAt;
          if (conv.lastMessageBody != null && mounted) {
            _showTrainerMessageBanner(conv.otherUserName, conv.lastMessageBody!);
          }
        }
      } catch (_) {}
    });
  }

  void _listenToTrainerMessages() {
    _wsSubscription = WebSocketService().events.listen((data) {
      if (!mounted) return;
      if (data['event'] == 'CHAT_MESSAGE') {
        final senderName = data['sender_name'] ?? 'Personal';
        final body = data['body'] ?? '';
        _showTrainerMessageBanner(senderName, body);
      }
    });
  }

  void _showTrainerMessageBanner(String senderName, String body) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        backgroundColor: const Color(AppConstants.cardDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(AppConstants.neonAccent).withOpacity(0.5)),
        ),
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: Color(AppConstants.neonAccent), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(AppConstants.neonAccent),
                    ),
                  ),
                  Text(
                    body,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Color(AppConstants.textPrimary),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _wsSubscription?.cancel();
    _messagePollingTimer?.cancel();
    _bluetoothController.removeListener(_onBluetoothUpdate);
    // Only disconnect the channel — never dispose() the singleton's shared
    // StreamController, or every later live-session feature breaks for the
    // rest of the app session ("Cannot add event after closing").
    WebSocketService().disconnect();
    super.dispose();
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      final sessionProvider = context.read<WorkoutSessionProvider>();
      if (sessionProvider.isSessionActive && sessionProvider.sessionId != null) {
        _sendHeartbeat(sessionProvider.sessionId!);
      }
    });
  }

  Future<void> _sendHeartbeat(String sessionId) async {
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.dio.post('${AppConstants.baseUrl}/workout-sessions/$sessionId/heartbeat');
      debugPrint('Heartbeat sent for session $sessionId');
    } catch (e) {
      debugPrint('Failed to send heartbeat: $e');
    }
  }

  void _onBluetoothUpdate() {
    if (!mounted) return;
    final bluetooth = context.read<BluetoothController>();
    final session = context.read<WorkoutSessionProvider>();

    if (bluetooth.heartRate > 0 && session.isSessionActive) {
      session.updateHeartRate(bluetooth.heartRate);
      
      // Send WebSocket update (throttled by Bluetooth update rate usually, but good to throttle more)
      // For simplicity, we send every update for now. In prod, use a timer.
      final wsService = WebSocketService();
      if (wsService.isConnected) {
        wsService.sendEvent('HEART_RATE', {
          'bpm': bluetooth.heartRate,
          'calories': session.caloriesBurned,
        });
      }
    }
  }

  void _showDeviceSheet() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(AppConstants.cardDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _DeviceConnectionSheet(),
    );
  }

  void _showExercisesPreview() {
    if (!mounted) return;
    final sessionProvider = context.read<WorkoutSessionProvider>();
    final workout = sessionProvider.activeWorkout!;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(AppConstants.cardDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
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
                  const SizedBox(height: 16),
                  Text(
                    'Visualizar Exercícios',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Exercise List
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: workout.exercises.length,
                itemBuilder: (context, index) {
                  final exercise = workout.exercises[index];
                  final methodologyType = exercise.methodologyType ?? 'NORMAL';
                  final isSuperset = exercise.supersetId != null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.primaryDark),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Exercise number and name
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (isSuperset)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'BI-SET',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(AppConstants.cyanAccent),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (exercise.gifUrl != null &&
                                  exercise.gifUrl!.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                _GifThumb(
                                  url: exercise.gifUrl!,
                                  name: exercise.name,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Exercise details
                          Row(
                            children: [
                              Expanded(
                                child: _buildPreviewBadge(
                                  'SÉRIES',
                                  '${exercise.sets}',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildPreviewBadge(
                                  exercise.isTimeBased ? 'TEMPO' : 'REPS',
                                  exercise.isTimeBased
                                      ? exercise.formattedDuration
                                      : '${exercise.reps ?? "-"}',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildPreviewBadge(
                                  'DESCANSO',
                                  '${exercise.restSeconds ?? 60}s',
                                ),
                              ),
                            ],
                          ),
                          // Methodology badge
                          if (methodologyType != 'NORMAL') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(AppConstants.neonAccent)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(AppConstants.neonAccent)
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                methodologyType,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(AppConstants.neonAccent),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Bottom padding
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewBadge(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
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

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _finishWorkout(WorkoutSessionProvider sessionProvider) async {
    _heartbeatTimer?.cancel();
    // Capture up front: finishWorkout() ends the session and clears
    // activeWorkout, so reading the name afterwards falls back to 'Treino'.
    final workoutName =
        sessionProvider.activeWorkout?.name ?? widget.workout?.name ?? 'Treino';
    // 🧠 Mood Check-in PÓS-TREINO (before showing loading)
    final moodAfter = await showMoodCheckIn(context, phase: 'after');

    // User may have backed out during the mood sheet — don't touch a dead context.
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Save post-workout mood
    if (moodAfter != null) {
      final authProvider = context.read<AuthProvider>();
      try {
        await authProvider.dio.post(
          '${AppConstants.baseUrl}/workout-sessions/mood',
          data: {'mood': moodAfter, 'phase': 'after'},
        );
      } catch (e) {
        debugPrint('Post-workout mood save error (non-critical): $e');
      }
    }
    final response = await sessionProvider.finishWorkout(null);

    if (!mounted) return;
    
    // Pop the loading dialog
    Navigator.pop(context);

    if (response != null) {
      final xpEarned = (response['xp_earned'] as num?)?.toInt() ?? 0;
      final caloriesBurned = response['calories_burned'] as num?;
      final currentStreak = (response['current_streak'] as num?)?.toInt() ?? 0;
      final isNewStreakRecord = response['is_new_streak_record'] as bool? ?? false;
      final isOffline = response['offline'] == true;

      final shareContext = response['share_context'] as Map<String, dynamic>?;
      final trainerLogo = shareContext?['brand_logo_url'];
      final trainerInsta = shareContext?['trainer_instagram_handle'];

      if (isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treino salvo offline — sincroniza ao reconectar.'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryScreen(
            workoutName: workoutName,
            durationSeconds: sessionProvider.elapsedSeconds,
            averageHeartRate: (response['average_heart_rate'] as num?)?.toInt() ?? 0,
            xpEarned: xpEarned,
            caloriesBurned: caloriesBurned,
            currentStreak: currentStreak,
            isNewStreakRecord: isNewStreakRecord,
            trainerLogoUrl: trainerLogo,
            trainerInstagramHandle: trainerInsta,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro ao salvar treino. Tente novamente.')),
      );
    }
  }

  void _navigateToExercise(int index, Exercise exercise) {
    final sessionProvider = context.read<WorkoutSessionProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseExecutionScreen(
          exerciseIndex: index,
          workout: sessionProvider.activeWorkout!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WorkoutSessionProvider, BluetoothController>(
      builder: (context, sessionProvider, bluetooth, child) {
        if (!sessionProvider.isSessionActive) {
          return const Scaffold(
            backgroundColor: Color(AppConstants.primaryDark),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final int bpm = bluetooth.heartRate;
        final workout = sessionProvider.activeWorkout!;
        final allExercisesCompleted =
            sessionProvider.completedExercises.length ==
                workout.exercises.length;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final elapsed = sessionProvider.elapsedSeconds;
            
            final action = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(AppConstants.cardDark),
                title: Text(
                  'Sair do Treino?',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'Você treinou por ${elapsed ~/ 60}min ${elapsed % 60}s. O que deseja fazer?',
                  style: GoogleFonts.inter(
                      color: Colors.grey[400], height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'cancel'),
                    child: Text('Continuar treino',
                        style: GoogleFonts.inter(
                            color: const Color(AppConstants.neonAccent))),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'discard'),
                    child: Text('Descartar',
                        style: GoogleFonts.inter(color: Colors.redAccent)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppConstants.neonAccent)),
                    onPressed: () => Navigator.pop(ctx, 'save'),
                    child: Text('Salvar assim',
                        style: GoogleFonts.inter(
                            color: Colors.black,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );

            if (!mounted) return;
            if (action == 'discard') {
              _heartbeatTimer?.cancel();
              sessionProvider.endSession();
              Navigator.of(context).pop();
            } else if (action == 'save') {
              await _finishWorkout(sessionProvider);
            }
            // 'cancel' or null → do nothing
          },
          child: Scaffold(
            backgroundColor: const Color(AppConstants.primaryDark),
            appBar: AppBar(

              backgroundColor: const Color(AppConstants.cardDark),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatDuration(sessionProvider.elapsedSeconds),
                    style: GoogleFonts.robotoMono(
                      color: const Color(AppConstants.textSecondary),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              actions: [
                // Preview exercises icon
                Tooltip(
                  message: 'Ver exercícios',
                  child: IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: Colors.white),
                    onPressed: _showExercisesPreview,
                  ),
                ),
                // Heart Rate Indicator — tappable
                Tooltip(
                  message: bluetooth.isConnected
                      ? '${bluetooth.deviceName} — toque para gerenciar'
                      : 'Toque para conectar um monitor cardíaco',
                  child: GestureDetector(
                    onTap: _showDeviceSheet,
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: bpm > 0
                            ? const Color(AppConstants.neonAccent).withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: !bluetooth.isConnected
                            ? Border.all(
                                color: Colors.grey.withOpacity(0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            bpm > 0 ? Icons.favorite : Icons.bluetooth,
                            color: bpm > 0
                                ? const Color(AppConstants.neonAccent)
                                : Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            bpm > 0 ? '$bpm' : '--',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                // Exercise List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: workout.exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = workout.exercises[index];
                      final isCompleted =
                          sessionProvider.completedExercises.contains(index);

                      final bool isInSuperset = exercise.supersetId != null;
                      final bool isSupersetStart = isInSuperset &&
                          (index == 0 ||
                              workout.exercises[index - 1].supersetId !=
                                  exercise.supersetId);
                      final bool isSupersetEnd = isInSuperset &&
                          (index == workout.exercises.length - 1 ||
                              workout.exercises[index + 1].supersetId !=
                                  exercise.supersetId);

                      const bisetColor = Color(AppConstants.cyanAccent);

                      // Exercises outside a biset: render normally
                      if (!isInSuperset) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ExerciseCard(
                            exercise: exercise,
                            index: index,
                            isCompleted: isCompleted,
                            isInSuperset: false,
                            sessionProvider: sessionProvider,
                            onTap: () => _navigateToExercise(index, exercise),
                          ),
                        );
                      }

                      // Se for um item de BI-SET que não é o primeiro, ignora (já renderizado no grupo anterior)
                      if (!isSupersetStart) {
                        return const SizedBox.shrink();
                      }

                      // Agrupa todos os exercícios que pertencem a este superset
                      final supersetExercises = <Map<String, dynamic>>[];
                      int currIndex = index;
                      while (currIndex < workout.exercises.length &&
                          workout.exercises[currIndex].supersetId ==
                              exercise.supersetId) {
                        supersetExercises.add({
                          'exercise': workout.exercises[currIndex],
                          'index': currIndex,
                        });
                        currIndex++;
                      }

                      // Exercises inside a biset: wrapped in grouped container
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: bisetColor.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: bisetColor.withOpacity(0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // BI-SET badge — only on the first exercise of the group
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: bisetColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: bisetColor.withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.link_rounded,
                                            size: 12, color: bisetColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          'BI-SET',
                                          style: GoogleFonts.inter(
                                            color: bisetColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Render All exercises in this BI-SET
                            ...supersetExercises.map((data) {
                              final ex = data['exercise'] as Exercise;
                              final exIndex = data['index'] as int;
                              final isExCompleted = sessionProvider
                                  .completedExercises
                                  .contains(exIndex);
                              final isLastInGroup =
                                  exIndex == supersetExercises.last['index'];

                              return Column(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      8,
                                      0,
                                      8,
                                      isLastInGroup ? 8 : 0,
                                    ),
                                    child: _ExerciseCard(
                                      exercise: ex,
                                      index: exIndex,
                                      isCompleted: isExCompleted,
                                      isInSuperset: true,
                                      sessionProvider: sessionProvider,
                                      onTap: () =>
                                          _navigateToExercise(exIndex, ex),
                                    ),
                                  ),
                                  // Connector between exercises in the same biset
                                  if (!isLastInGroup)
                                    Center(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        width: 2,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: bisetColor.withOpacity(0.5),
                                          borderRadius:
                                              BorderRadius.circular(1),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Action Area
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.cardDark),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          if (allExercisesCompleted) {
                            _finishWorkout(sessionProvider);
                          } else {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(AppConstants.cardDark),
                                title: Text(
                                  'Encerrar Treino?',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: Text(
                                  'Você ainda não completou todos os exercícios. Deseja encerrar mesmo assim?',
                                  style: GoogleFonts.inter(
                                    color: const Color(AppConstants.textSecondary),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'Cancelar',
                                      style: GoogleFonts.inter(
                                        color: const Color(AppConstants.textSecondary),
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _finishWorkout(sessionProvider);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade800,
                                    ),
                                    child: Text(
                                      'Encerrar',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: allExercisesCompleted
                              ? const Color(AppConstants.neonAccent)
                              : Colors.orange.shade800, // Neutral amber for early-end action
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          allExercisesCompleted
                              ? 'FINALIZAR TREINO'
                              : 'ENCERRAR TREINO',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final int index;
  final bool isCompleted;
  final bool isInSuperset;
  final WorkoutSessionProvider sessionProvider;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exercise,
    required this.index,
    required this.isCompleted,
    required this.isInSuperset,
    required this.sessionProvider,
    required this.onTap,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  double? _previousLoad;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final load = await ExerciseLoadHistoryService.getLoad(widget.exercise.id);
    if (mounted && load != null && load > 0) {
      setState(() => _previousLoad = load);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLoad = widget.sessionProvider.getExerciseLoad(widget.index);
    final sets = widget.sessionProvider.getExerciseSets(widget.index);

    return Container(
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isCompleted
              ? const Color(AppConstants.neonAccent).withOpacity(0.5)
              : widget.isInSuperset
                  ? const Color(AppConstants.neonAccent).withOpacity(0.3)
                  : Colors.transparent,
          width: widget.isInSuperset ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox
                    InkWell(
                      onTap: () {
                        if (!widget.isCompleted) {
                          widget.sessionProvider.completeExercise(widget.index);
                        } else {
                          widget.sessionProvider.uncompleteExercise(widget.index);
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isCompleted
                              ? const Color(AppConstants.neonAccent)
                              : Colors.transparent,
                          border: Border.all(
                            color: widget.isCompleted
                                ? const Color(AppConstants.neonAccent)
                                : const Color(AppConstants.textSecondary),
                            width: 2,
                          ),
                        ),
                        child: widget.isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.exercise.name,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              decoration: widget.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor:
                                  const Color(AppConstants.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _InfoBadge(
                                icon: Icons.repeat,
                                text: '${widget.exercise.sets} séries',
                              ),
                              const SizedBox(width: 12),
                              _InfoBadge(
                                icon: widget.exercise.isTimeBased
                                    ? Icons.timer
                                    : Icons.fitness_center,
                                text: widget.exercise.isTimeBased
                                    ? widget.exercise.formattedDuration
                                    : '${widget.exercise.reps ?? 0} reps',
                              ),
                            ],
                          ),
                          // Methodology Badge
                          if (widget.exercise.methodologyType != 'NORMAL') ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getMethodologyColor(widget.exercise.methodologyType).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getMethodologyColor(widget.exercise.methodologyType).withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getMethodologyColor(widget.exercise.methodologyType),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatMethodologyType(widget.exercise.methodologyType),
                                    style: GoogleFonts.inter(
                                      color: _getMethodologyColor(widget.exercise.methodologyType),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // 🏋️ Previous Load Badge
                          if (_previousLoad != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(AppConstants.cyanAccent).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(AppConstants.cyanAccent).withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.history_rounded,
                                    size: 13,
                                    color: Color(AppConstants.cyanAccent),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Último: ${_previousLoad!.toStringAsFixed(_previousLoad! % 1 == 0 ? 0 : 1)} kg',
                                    style: GoogleFonts.inter(
                                      color: const Color(AppConstants.cyanAccent),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (widget.exercise.notes != null &&
                              widget.exercise.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.exercise.notes!,
                              style: GoogleFonts.inter(
                                color: const Color(AppConstants.neonAccent)
                                    .withOpacity(0.8),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.exercise.gifUrl != null &&
                        widget.exercise.gifUrl!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      _GifThumb(
                        url: widget.exercise.gifUrl!,
                        name: widget.exercise.name,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                // Load Display: Per-set summary or fallback editable field
                if (sets.isNotEmpty)
                  // Show per-set weight summary (read-only)
                  Row(
                    children: [
                      Text(
                        'Cargas:',
                        style: GoogleFonts.inter(
                          color: const Color(AppConstants.textSecondary),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sets
                              .asMap()
                              .entries
                              .map((e) {
                                final setNum = e.key + 1;
                                final weight = e.value.weightKg;
                                return weight != null && weight > 0
                                    ? 'S$setNum: ${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)}kg'
                                    : null;
                              })
                              .where((s) => s != null)
                              .join(' · '),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  // Fallback: editable field for exercises without set data
                  Row(
                    children: [
                      Text(
                        'Carga usada:',
                        style: GoogleFonts.inter(
                          color: const Color(AppConstants.textSecondary),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          initialValue: currentLoad > 0 ? currentLoad.toString() : '',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: _previousLoad != null
                                ? '${_previousLoad!.toStringAsFixed(0)} kg'
                                : '0 kg',
                            hintStyle: GoogleFonts.inter(
                              color: _previousLoad != null
                                  ? const Color(AppConstants.cyanAccent).withOpacity(0.4)
                                  : Colors.white24,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            suffixText: 'kg',
                            suffixStyle: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          onChanged: (value) {
                            final load = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
                            widget.sessionProvider.updateExerciseLoad(widget.index, load);
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getMethodologyColor(String type) {
    switch (type) {
      case 'DROP_SET':
        return Colors.red;
      case 'REST_PAUSE':
        return Colors.orange;
      case 'PIRAMIDE':
        return Colors.purple;
      case 'FST_7':
        return Colors.blue;
      case 'AMRAP':
        return Colors.green;
      case 'EMOM':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  String _formatMethodologyType(String type) {
    switch (type) {
      case 'DROP_SET':
        return 'Drop Set';
      case 'REST_PAUSE':
        return 'Rest Pause';
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
}

class _DeviceConnectionSheet extends StatefulWidget {
  @override
  State<_DeviceConnectionSheet> createState() => _DeviceConnectionSheetState();
}

class _DeviceConnectionSheetState extends State<_DeviceConnectionSheet> {
  List<dynamic>? _pairedDevices;

  @override
  void initState() {
    super.initState();
    _loadPairedDevices();
  }

  Future<void> _loadPairedDevices() async {
    final bluetooth = context.read<BluetoothController>();
    final paired = await bluetooth.getPairedDevices();
    if (mounted) {
      setState(() => _pairedDevices = paired);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothController>(
      builder: (context, bluetooth, child) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monitor Cardíaco',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Icon(
                      Icons.favorite,
                      color: bluetooth.isConnected ? Colors.red : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Connected state
                if (bluetooth.isConnected) ...[
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
                      Text(
                        bluetooth.deviceName,
                        style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '${bluetooth.heartRate} BPM',
                      style: GoogleFonts.inter(
                        fontSize: 40,
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
                ] else ...[
                  // Scan / Stop button
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bluetooth_searching),
                      label: Text(
                        bluetooth.isScanning ? 'Parar busca' : 'Buscar dispositivos',
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
                    const SizedBox(height: 10),
                    Text(
                      bluetooth.errorMessage!,
                      style: GoogleFonts.inter(color: Colors.red, fontSize: 12),
                    ),
                  ],

                  // Pairing / Connecting indicator
                  if (bluetooth.isPairing) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Aguardando confirmação no dispositivo...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Color(AppConstants.neonAccent),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Aceite o pareamento nas notificações do celular.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                  ] else if (bluetooth.isConnecting) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Conectando...',
                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ],

                  // Paired devices (if no scan results yet)
                  if (bluetooth.filteredScanResults.isEmpty && _pairedDevices != null && _pairedDevices!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Dispositivos pareados',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._pairedDevices!.map((device) {
                      final name = (device.platformName as String).isNotEmpty
                          ? device.platformName as String
                          : 'Dispositivo desconhecido';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(AppConstants.primaryDark),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ListTile(
                          onTap: () => bluetooth.connectToDevice(device),
                          leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          title: Text(
                            name,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Pareado',
                            style: GoogleFonts.inter(color: Colors.green, fontSize: 11),
                          ),
                        ),
                      );
                    }).toList(),
                  ],

                  // Device list from scan (filtered to HR-capable devices only)
                  if (bluetooth.filteredScanResults.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Dispositivos encontrados',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...bluetooth.filteredScanResults.map((result) {
                      final name = (result.device.platformName as String).isNotEmpty
                          ? result.device.platformName as String
                          : 'Dispositivo desconhecido';
                      final rssi = result.rssi as int;
                      final signalColor = rssi > -60
                          ? Colors.green
                          : rssi > -75
                              ? Colors.orange
                              : Colors.red;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(AppConstants.primaryDark),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ListTile(
                          onTap: () => bluetooth.connectToDevice(result.device),
                          leading: const Icon(Icons.favorite, color: Colors.red, size: 20),
                          title: Text(
                            name,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.signal_wifi_4_bar, color: signalColor, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '$rssi',
                                style: GoogleFonts.inter(color: signalColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(AppConstants.textSecondary)),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(AppConstants.textSecondary),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// GIF thumbnail shown on the exercise card. Tap to maximize (fullscreen).
class _GifThumb extends StatelessWidget {
  final String url;
  final String name;

  const _GifThumb({required this.url, required this.name});

  void _maximize(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.white,
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _maximize(context),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 64,
              height: 64,
              color: Colors.white,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(AppConstants.neonAccent),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stack) => Icon(
                  Icons.fitness_center,
                  color: Colors.black.withOpacity(0.2),
                  size: 24,
                ),
              ),
            ),
          ),
          // Maximize hint badge
          Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.fullscreen, color: Colors.white, size: 14),
          ),
        ],
      ),
    );
  }
}
