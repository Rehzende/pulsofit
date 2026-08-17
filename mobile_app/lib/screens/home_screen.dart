import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/bluetooth_controller.dart';
import '../services/workout_service.dart';
import '../models/workout.dart';
import '../core/constants.dart';
import '../widgets/ui/premium_ui.dart';
import '../providers/workout_session_provider.dart';
import 'package:mobile_app/widgets/heatmap/body_heatmap.dart';
import 'workout_runner.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'anamnesis_screen.dart';
import 'history_screen.dart';
import 'workouts_screen.dart';
import 'coaches_screen.dart';
import 'monthly_wrapped_screen.dart';
import '../widgets/streak_protector_card.dart';
import '../core/utils.dart';
import 'challenge_screen.dart';


class HomeScreen extends StatefulWidget {
  final int unreadCount;
  final VoidCallback? onNotificationTap;

  const HomeScreen({super.key, this.unreadCount = 0, this.onNotificationTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Workout? _todayWorkout;
  bool _isLoadingWorkout = true;
  String? _errorMessage;
  
  // Weekly Status
  List<int> _completedDays = [];
  bool _todayCompleted = false;
  Workout? _nextWorkout;

  // Streak
  int _currentStreak = 0;

  // Challenge
  bool _challengeActive = false;
  bool _challengeCompleted = false;
  int _challengeDays = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingWorkout = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(authProvider.dio);
      
      await authProvider.fetchUserDetails();
      
      final weeklyStatus = await workoutService.getWeeklyStatus();

      if (weeklyStatus != null) {
        _completedDays = List<int>.from(weeklyStatus['completed_days'] ?? []);
        _todayCompleted = weeklyStatus['today_completed'] ?? false;

        if (weeklyStatus['next_workout'] != null) {
          _nextWorkout = Workout.fromJson(weeklyStatus['next_workout']);
        }
      }

      // Fetch student stats for streak data
      try {
        final statsResponse = await authProvider.dio.get('/student/stats');
        if (mounted) {
          setState(() {
            _currentStreak = (statsResponse.data['current_streak'] as num?)?.toInt() ?? 0;
          });
        }
      } catch (_) {}

      // Fetch challenge status
      try {
        final challengeResp = await authProvider.dio.get('${AppConstants.baseUrl}/gamification/challenge/status');
        if (mounted && challengeResp.statusCode == 200) {
          final cd = challengeResp.data as Map<String, dynamic>;
          setState(() {
            _challengeActive = cd['active'] as bool? ?? false;
            _challengeCompleted = cd['completed'] as bool? ?? false;
            _challengeDays = cd['days_completed'] as int? ?? 0;
          });
        }
      } catch (_) {}

      final workout = await workoutService.getTodayWorkout();

      if (mounted) {
        setState(() {
          _todayWorkout = workout;
          _isLoadingWorkout = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('404')) {
               _todayWorkout = null;
          } else {
               _errorMessage = 'Falha ao carregar treino';
          }
          _isLoadingWorkout = false;
        });
      }
    }
  }

  void _startWorkout() {
    if (_todayWorkout != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkoutRunnerScreen(workout: _todayWorkout!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.fullName ?? authProvider.userEmail?.split('@').first ?? 'User';
    final formattedName = userName.length > 15 && authProvider.fullName != null 
        ? userName.split(' ').first 
        : userName;
    final photoUrl = authProvider.getProfileImageUrl();

    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(AppConstants.neonAccent),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Compact greeting + coach access
                _buildHeader(formattedName, photoUrl),

                // Anamnesis Alert (gates training — keep prominent)
                if (!authProvider.anamnesisCompleted)
                  _buildAnamnesisAlert(context),

                const SizedBox(height: 4),

                // 2. HERO — Today's workout (action-first)
                FadeSlideIn(
                  delayMs: 40,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _buildTodayWorkoutCard(),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Compact stats strip (streak · level · recovery)
                FadeSlideIn(
                  delayMs: 110,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _buildStatStrip(),
                  ),
                ),

                const SizedBox(height: 28),

                // 4. Challenge (secondary)
                _buildChallengeBanner(),

                // 5. Quick Actions Grid
                _sectionLabel("ACESSO RÁPIDO"),
                const SizedBox(height: 16),
                FadeSlideIn(delayMs: 180, child: _buildQuickActionsGrid(context)),

                const SizedBox(height: 28),

                // 6. Body Status Preview
                FadeSlideIn(
                  delayMs: 240,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _buildBodyStatusPreview(context),
                  ),
                ),

                const SizedBox(height: 16),

                // 7. Streak Protector
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: StreakProtectorCard(),
                ),

                const SizedBox(height: 24),

                // 8. Monthly Wrapped Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MonthlyWrappedScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFF59E0B).withOpacity(0.15),
                            const Color(AppConstants.cardDark),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 32)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Seu Mês em Resumo',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Veja suas estatísticas e evolução do mês passado',
                                  style: GoogleFonts.inter(
                                    color: const Color(AppConstants.textSecondary),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFFF59E0B),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String userName, String? photoUrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(AppConstants.neonAccent).withOpacity(0.5), width: 2),
                  color: const Color(AppConstants.cardDark),
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                userName.substring(0, 1).toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(AppConstants.neonAccent),
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            userName.substring(0, 1).toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(AppConstants.neonAccent),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Olá, $userName 👋',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(AppConstants.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    toBeginningOfSentenceCase(
                          DateFormat('EEEE, d MMM', 'pt_BR').format(DateTime.now()),
                        ) ??
                        '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(AppConstants.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _NotificationBell(
                unreadCount: widget.unreadCount,
                onTap: widget.onNotificationTap ?? () {},
              ),
              const SizedBox(width: 8),
              _buildCoachAction(),
            ],
          ),
        ],
      ),
    );
  }

  /// Coach access on the header: trainer logo / WhatsApp, or "Achar Coach".
  Widget _buildCoachAction() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.hasTrainer) {
      final logo = authProvider.getTrainerLogoUrl();
      return GestureDetector(
        onTap: () => launchWhatsApp(
          context,
          authProvider.trainerWhatsappNumber,
          message: "Olá coach, tenho uma dúvida sobre o treino...",
        ),
        child: logo != null
            ? Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover),
                ),
              )
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(AppConstants.neonAccent).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline,
                    color: Color(AppConstants.neonAccent), size: 20),
              ),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CoachesScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(AppConstants.neonAccent).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(AppConstants.neonAccent).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, color: Color(AppConstants.neonAccent), size: 14),
            const SizedBox(width: 4),
            Text(
              "Achar Coach",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(AppConstants.neonAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: const Color(AppConstants.textSecondary),
        ),
      ),
    );
  }

  /// Compact strip merging streak + level + recovery into one row.
  Widget _buildStatStrip() {
    final authProvider = Provider.of<AuthProvider>(context);
    final level = authProvider.level;
    return Row(
      children: [
        Expanded(
          child: _statChip(
            emoji: '🔥',
            value: '$_currentStreak',
            label: _currentStreak == 1 ? 'dia' : 'dias',
            color: const Color(0xFFF97316),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statChip(
            emoji: '⭐',
            value: 'N$level',
            label: 'nível',
            color: const Color(AppConstants.neonAccent),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _fetchRecoveryPreview(),
            builder: (context, snapshot) {
              final pct = snapshot.data?['overall_percentage'] ?? 100;
              final color = pct >= 80
                  ? const Color(0xFF22C55E)
                  : pct >= 50
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444);
              return _statChip(
                emoji: '💪',
                value: '$pct%',
                label: 'recup.',
                color: color,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statChip({
    required String emoji,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(AppConstants.cardElevated), Color(AppConstants.cardDark)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(value, style: displayStyle(size: 22, weight: FontWeight.w800, color: color)),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(AppConstants.textSecondary),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeBanner() {
    if (!_challengeActive && !_challengeCompleted) {
      // Invite to start challenge
      return GestureDetector(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChallengeScreen()));
          _loadData();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(AppConstants.cardDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(AppConstants.neonAccent).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Desafio 7 Dias — Aceite o desafio!',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(AppConstants.neonAccent)),
            ],
          ),
        ),
      );
    }
    if (_challengeCompleted) return const SizedBox.shrink();
    // Active: show mini progress
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChallengeScreen()));
        _loadData();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(AppConstants.cardDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(AppConstants.neonAccent).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Desafio 7 Dias — $_challengeDays/7',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _challengeDays / 7,
                      minHeight: 4,
                      backgroundColor: const Color(AppConstants.borderColor),
                      color: const Color(AppConstants.neonAccent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(AppConstants.neonAccent)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnamnesisAlert(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade700),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Anamnese Pendente",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade100,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "Responda para liberar seu treino!",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.orange.shade200,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
               Navigator.of(context).push(
                 MaterialPageRoute(builder: (_) => const AnamnesisScreen()),
               );
            },
            child: const Text("Responder", style: TextStyle(color: Colors.orange)),
          )
        ],
      ),
    );
  }

  Widget _buildTodayWorkoutCard() {
    return Consumer<WorkoutSessionProvider>(
      builder: (context, sessionProvider, child) {
        if (sessionProvider.isSessionActive) {
          return _buildActiveSessionCard(sessionProvider);
        }

        if (_isLoadingWorkout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox(width: 120, height: 22, radius: 20),
              SizedBox(height: 18),
              SkeletonBox(width: 220, height: 28),
              SizedBox(height: 14),
              SkeletonBox(width: 160, height: 16),
              SizedBox(height: 22),
              SkeletonBox(height: 54, radius: AppRadius.card),
            ],
          );
        }

        if (_errorMessage != null) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(AppConstants.cardDark),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.shade900),
            ),
            child: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white))),
          );
        }

        // Check for completion first
        if (sessionProvider.isWorkoutCompletedToday || _todayCompleted) {
          return _buildCompletedCard();
        }

        if (_todayWorkout == null) {
          return _buildRestDayCard();
        }

        // Standard Workout Card — premium hero
        return PremiumCard(
          onTap: _startWorkout,
          radius: AppRadius.hero,
          padding: const EdgeInsets.all(22),
          glow: const Color(AppConstants.neonAccent),
          borderColor: const Color(AppConstants.neonAccent).withValues(alpha: 0.28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(AppConstants.neonAccent), Color(AppConstants.cyanAccent)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "TREINO DE HOJE",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const IconBadge(Icons.fitness_center_rounded, boxSize: 42, iconSize: 20),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _todayWorkout!.name,
                style: displayStyle(size: 26, weight: FontWeight.w800, height: 1.1),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildWorkoutMeta(Icons.schedule_rounded, "${_todayWorkout!.estimatedDuration ?? 45} min"),
                  const SizedBox(width: 16),
                  _buildWorkoutMeta(Icons.bolt_rounded, "${_todayWorkout!.exercises.length} exercícios"),
                ],
              ),
              const SizedBox(height: 22),
              GradientButton(
                label: "INICIAR TREINO",
                icon: Icons.play_arrow_rounded,
                onTap: _startWorkout,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkoutMeta(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(AppConstants.textSecondary)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(AppConstants.textSecondary),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSessionCard(WorkoutSessionProvider sessionProvider) {
     return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(AppConstants.neonAccent),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(AppConstants.neonAccent).withOpacity(0.1),
            blurRadius: 16,
          ),
        ],
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
                  color: Color(AppConstants.neonAccent),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "TREINO EM ANDAMENTO",
                style: GoogleFonts.inter(
                  color: const Color(AppConstants.neonAccent),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  fontSize: 10
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sessionProvider.activeWorkout?.name ?? 'Treino Atual',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WorkoutRunnerScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.neonAccent),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text("RETOMAR", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCompletedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(AppConstants.neonAccent).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(AppConstants.neonAccent).withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(AppConstants.neonAccent).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, size: 40, color: Color(AppConstants.neonAccent)),
          ),
          const SizedBox(height: 12),
          Text(
            "Missão Cumprida! 🔥",
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Mais um dia de evolução. Continue assim!",
            style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRestDayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade900.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bedtime_outlined, size: 40, color: Colors.blueGrey.shade400),
          ),
          const SizedBox(height: 12),
          Text(
            "Dia de Descanso",
            style: GoogleFonts.inter(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: Colors.white
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Recupere-se bem para o próximo treino.",
            style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        _buildActionCard(
          icon: Icons.monitor_heart_outlined,
          label: "Status Corpo",
          color: Colors.redAccent,
          onTap: () {
             showModalBottomSheet(
               context: context,
               isScrollControlled: true,
               backgroundColor: const Color(AppConstants.primaryDark),
               builder: (ctx) => SizedBox(
                 height: MediaQuery.of(context).size.height * 0.85,
                 child: const Padding(
                   padding: EdgeInsets.all(16.0),
                   child: Column(
                     children: [
                        SizedBox(height: 20),
                        Text("Mapa de Recuperação", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Expanded(child: HumanBodyHeatmap()),
                     ],
                   ),
                 ),
               ),
             );
          },
        ),
        _buildActionCard(
          icon: Icons.history,
          label: "Histórico",
          color: Colors.blueAccent,
          onTap: () {
             Navigator.of(context).push(
               MaterialPageRoute(builder: (_) => const HistoryScreen()),
             );
          },
        ),
        _buildActionCard(
          icon: Icons.fitness_center_outlined,
          label: "Meus Treinos",
          color: Colors.purpleAccent,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WorkoutsScreen()),
            );
          },
        ),
        _buildActionCard(
          icon: Icons.people_outline,
          label: "Coaches",
          color: Colors.tealAccent,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CoachesScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(AppConstants.cardElevated), Color(AppConstants.cardDark)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconBadge(icon, color: color, boxSize: 42, iconSize: 22),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyStatusPreview(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchRecoveryPreview(),
      builder: (context, snapshot) {
        final pct = snapshot.data?['overall_percentage'] ?? 85;
        final Color statusColor;
        final String statusLabel;
        if (pct >= 80) {
          statusColor = const Color(0xFF22C55E); // Green
          statusLabel = 'Pronto para treinar!';
        } else if (pct >= 50) {
          statusColor = const Color(0xFFF59E0B); // Amber
          statusLabel = 'Recuperação parcial.';
        } else {
          statusColor = const Color(0xFFEF4444); // Red
          statusLabel = 'Precisa de descanso.';
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(AppConstants.cardDark),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: statusColor.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              // Progress ring
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: pct / 100,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      strokeWidth: 5,
                    ),
                    Text(
                      '$pct%',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Recuperação Muscular",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seu corpo está $pct% recuperado. $statusLabel',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(AppConstants.textSecondary),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchRecoveryPreview() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dio = authProvider.dio;
      final response = await dio.get('/student/recovery');
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      return {'overall_percentage': 100};
    }
  }

}

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBell({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(AppConstants.cardDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(AppConstants.borderColor)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_outlined,
                color: Color(AppConstants.textPrimary), size: 20),
            if (unreadCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(AppConstants.neonAccent),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}