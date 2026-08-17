import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../core/constants.dart';
import '../widgets/ui/premium_ui.dart';
import '../widgets/live_students_carousel.dart';
import '../services/trainer_service.dart';
import '../models/trainer_stats.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../models/hiring_request.dart';
import '../models/live_session.dart';
import '../models/student_engagement.dart';
import 'trainer_service_registration_screen.dart';
import 'trainer/trainer_students_screen.dart';
import 'trainer/student_detail_screen.dart';
import 'trainer/agent_chat_screen.dart';
import 'workouts_screen.dart';
import 'create_workout_screen.dart';
import '../services/websocket_service.dart';

class TrainerHomeScreen extends StatefulWidget {
  final int unreadCount;
  final VoidCallback? onNotificationTap;

  const TrainerHomeScreen({super.key, this.unreadCount = 0, this.onNotificationTap});

  @override
  State<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerHomeScreenState extends State<TrainerHomeScreen> {
  TrainerStats? _stats;
  List<User> _recentStudents = [];
  List<Workout> _recentWorkouts = [];
  List<HiringRequest> _requests = [];
  List<StudentEngagement> _engagement = [];
  bool _isLoading = true;

  final WebSocketService _wsService = WebSocketService();
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  List<LiveSession> _liveSessions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _initWebSocket();
  }

  Future<void> _initWebSocket() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      await _wsService.connect(authProvider.token!);
      _wsSubscription?.cancel();
      _wsSubscription = _wsService.events.listen((event) {
        if (event['event'] == 'START_SESSION' || event['event'] == 'HEART_RATE') {
          _handleLiveEvent(event);
        }
      });
    }
  }

  void _handleLiveEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    
    final studentId = event['student_id'];
    final studentName = event['student_name'];
    final data = event['data'];
    
    setState(() {
      final index = _liveSessions.indexWhere((s) => s.studentId == studentId);
      
      if (index != -1) {
        // Update existing session
        final oldSession = _liveSessions[index];
        _liveSessions[index] = LiveSession(
          sessionId: oldSession.sessionId,
          studentId: oldSession.studentId,
          studentName: oldSession.studentName,
          studentAvatar: oldSession.studentAvatar,
          studentPhone: oldSession.studentPhone,
          workoutName: oldSession.workoutName,
          startTime: oldSession.startTime,
          currentHeartRate: data?['bpm'] ?? oldSession.currentHeartRate,
        );
      } else if (event['event'] == 'START_SESSION') {
        // Try to find student photo from recent students
        String? avatarUrl;
        try {
          final student = _recentStudents.firstWhere((s) => s.id == studentId);
          avatarUrl = student.photoUrl;
        } catch (_) {}

        _liveSessions.add(LiveSession(
          sessionId: 'live_${DateTime.now().millisecondsSinceEpoch}', // Temp ID
          studentId: studentId,
          studentName: studentName,
          studentAvatar: avatarUrl,
          workoutName: data?['workout_name'] ?? 'Treino',
          startTime: DateTime.now(),
          currentHeartRate: 0,
        ));
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    // Only disconnect — never dispose() the singleton's shared StreamController.
    _wsService.disconnect();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final trainerService = TrainerService(authProvider.dio);

    try {
      final results = await Future.wait([
        trainerService.getStats(),
        trainerService.getStudents(),
        trainerService.getRecentWorkouts(),
        trainerService.getHiringRequests(),
        trainerService.getLiveSessions(),
        trainerService.getStudentEngagement(),
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as TrainerStats?;
          _recentStudents = results[1] as List<User>;
          _recentWorkouts = results[2] as List<Workout>;
          _requests = results[3] as List<HiringRequest>;
          _liveSessions = results[4] as List<LiveSession>;
          _engagement = results[5] as List<StudentEngagement>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('Error loading trainer dashboard data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.fullName ?? authProvider.userEmail?.split('@').first ?? 'Trainer';
    final photoUrl = authProvider.getProfileImageUrl();

    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(AppConstants.neonAccent),
          backgroundColor: const Color(AppConstants.cardDark),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(userName, photoUrl),

                const SizedBox(height: 4),

                // 1. Foco de hoje — actionable snapshot
                FadeSlideIn(
                  delayMs: 40,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _buildTodayFocus(),
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Live now (most time-sensitive)
                LiveStudentsCarousel(liveSessions: _liveSessions),

                const SizedBox(height: 24),

                // 3. Students needing attention
                _buildEngagementAlerts(),

                // 4. Hiring requests
                _buildRequestsSection(),

                // 5. Quick Actions (create content)
                FadeSlideIn(delayMs: 120, child: _buildQuickActions()),

                const SizedBox(height: 32),

                // 6. Stats Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "VISÃO GERAL",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: const Color(AppConstants.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatsGrid(),

                const SizedBox(height: 32),

                // 7. Recent Students
                _buildRecentStudents(),

                const SizedBox(height: 32),

                // 8. Recent Workouts
                _buildRecentWorkouts(),
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
                          _getImageUrl(photoUrl),
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
          _NotificationBell(
            unreadCount: widget.unreadCount,
            onTap: widget.onNotificationTap ?? () {},
          ),
        ],
      ),
    );
  }

  /// Action snapshot: who's training now, who's at risk, how many students.
  Widget _buildTodayFocus() {
    final liveCount = _liveSessions.length;
    final atRisk = _engagement.where((s) => s.riskLevel == 'AT_RISK').length;
    final students = _stats?.activeStudents ?? _engagement.length;

    return Row(
      children: [
        Expanded(
          child: _focusChip(
            icon: Icons.sensors,
            value: '$liveCount',
            label: 'ao vivo',
            color: const Color(0xFF22C55E),
            highlight: liveCount > 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _focusChip(
            icon: Icons.warning_amber_rounded,
            value: '$atRisk',
            label: 'em risco',
            color: const Color(0xFFEF4444),
            highlight: atRisk > 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _focusChip(
            icon: Icons.people_outline,
            value: '$students',
            label: 'alunos',
            color: const Color(AppConstants.neonAccent),
          ),
        ),
      ],
    );
  }

  Widget _focusChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        gradient: highlight
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(AppConstants.cardElevated), Color(AppConstants.cardDark)],
              ),
        color: highlight ? color.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: highlight ? color.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          IconBadge(icon, color: color, boxSize: 40, iconSize: 20),
          const SizedBox(height: 8),
          Text(value, style: displayStyle(size: 22, weight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(AppConstants.textSecondary),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Center(child: CircularProgressIndicator(color: Color(AppConstants.neonAccent))),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          _buildStatCard("Total de Alunos", "${_stats?.activeStudents ?? 0}", Icons.people_outline, Colors.blue),
          _buildStatCard("Treinos Criados", "${_stats?.totalWorkouts ?? 0}", Icons.fitness_center, Colors.orange),
          _buildStatCard("Frequência Média", "${_stats?.avgAttendance ?? 0}%", Icons.trending_up, Colors.green),
          _buildStatCard("Sequências Ativas", "${_stats?.activeStreaks ?? 0}", Icons.local_fire_department, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          IconBadge(icon, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: displayStyle(size: 24, weight: FontWeight.w800)),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(AppConstants.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildActionButton(
                    "Novo Aluno",
                    Icons.person_add,
                    const Color(AppConstants.neonAccent),
                    _showInviteDialog,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    "Serviços",
                    Icons.work_outline,
                    Colors.purpleAccent,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TrainerServiceRegistrationScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildAiActionCard(),
        ],
      ),
    );
  }

  Widget _buildAiActionCard() {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AgentChatScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(AppConstants.neonAccent).withOpacity(0.15),
              Colors.blue.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(AppConstants.neonAccent).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(AppConstants.neonAccent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Agente Pulso IA",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Converse para criar treinos, templates e pastas",
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog() {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text('Convidar Aluno', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Digite o e-mail do aluno para enviar um convite.',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'E-mail do aluno',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  errorStyle: const TextStyle(color: Colors.redAccent),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, digite um e-mail';
                  }
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Digite um e-mail válido';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final email = emailController.text.trim();
                Navigator.pop(context); // Close input dialog
                _sendInvite(email);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(AppConstants.neonAccent)),
            child: const Text('Gerar Convite', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInvite(String email) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(AppConstants.neonAccent))),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final trainerService = TrainerService(authProvider.dio);
      final link = await trainerService.createInvite(email);
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        if (link != null) {
          _showShareDialog(link);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao criar convite: $e')));
      }
    }
  }

  void _showShareDialog(String link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text('Convite Criado!', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            Text(
              'O convite foi enviado por e-mail. Você também pode compartilhar o link abaixo:',
              style: GoogleFonts.inter(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                link,
                style: GoogleFonts.inter(color: const Color(AppConstants.neonAccent), fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Share.share('Olá! Aqui está o link para se cadastrar no meu time: $link');
              Navigator.pop(context);
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Compartilhar Link'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.neonAccent),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(AppConstants.cardElevated), Color(AppConstants.cardDark)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconBadge(icon, color: color, boxSize: 48, iconSize: 24),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
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

  String _getImageUrl(String url) {
    if (url.startsWith('http')) return url;
    var cleanUrl = url;
    while (cleanUrl.startsWith('/')) {
      cleanUrl = cleanUrl.substring(1);
    }
    return '${AppConstants.apiUrl}/$cleanUrl';
  }

  Widget _buildRecentStudents() {
    if (_recentStudents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ALUNOS RECENTES",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: const Color(AppConstants.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TrainerStudentsScreen()),
                  );
                },
                child: Text(
                  "Ver Todos",
                  style: GoogleFonts.inter(
                    color: const Color(AppConstants.neonAccent),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: _recentStudents.length,
            itemBuilder: (context, index) {
              final student = _recentStudents[index];
              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: student.photoUrl != null ? NetworkImage(_getImageUrl(student.photoUrl!)) : null,
                      backgroundColor: const Color(AppConstants.cardDark),
                      child: student.photoUrl == null
                          ? Text(student.fullName?[0] ?? 'A', style: const TextStyle(color: Colors.white))
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      student.fullName?.split(' ').first ?? 'Aluno',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentWorkouts() {
    if (_recentWorkouts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TREINOS RECENTES",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: const Color(AppConstants.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WorkoutsScreen()),
                  );
                },
                child: Text(
                  "Ver Todos",
                  style: GoogleFonts.inter(
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentWorkouts.length,
          itemBuilder: (context, index) {
            final workout = _recentWorkouts[index];
            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateWorkoutScreen(workoutToEdit: workout),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.cardDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.fitness_center, color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workout.name,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${workout.exercises.length} exercícios • ${workout.scheduledFor != null ? DateFormat('dd/MM').format(workout.scheduledFor!) : 'Rascunho'}",
                            style: GoogleFonts.inter(
                              color: const Color(AppConstants.textSecondary),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRequestsSection() {
    if (_requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "SOLICITAÇÕES PENDENTES",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: const Color(AppConstants.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final request = _requests[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(AppConstants.cardDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(AppConstants.neonAccent).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: request.studentPhoto != null ? NetworkImage(_getImageUrl(request.studentPhoto!)) : null,
                        child: request.studentPhoto == null ? Text(request.studentName?[0] ?? 'A') : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.studentName ?? 'Novo Aluno',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              'Solicitou acompanhamento',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rejectRequest(request.id),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Rejeitar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptRequest(request.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(AppConstants.neonAccent),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Aceitar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _acceptRequest(String requestId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(AppConstants.neonAccent))),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final trainerService = TrainerService(authProvider.dio);
      await trainerService.acceptHiringRequest(requestId);
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        authProvider.triggerSync();
        _loadData(); // Reload to update lists
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitação aceita!')));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(AppConstants.neonAccent))),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final trainerService = TrainerService(authProvider.dio);
      await trainerService.rejectHiringRequest(requestId);
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        authProvider.triggerSync();
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitação rejeitada.')));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
      }
    }
  }

  Widget _buildEngagementAlerts() {
    final atRisk = _engagement.where((s) => s.riskLevel == 'AT_RISK').toList();
    final irregular = _engagement.where((s) => s.riskLevel == 'IRREGULAR').toList();
    final missingWorkouts = _engagement.where((s) => s.upcomingWorkoutsCount == 0).toList();

    if (atRisk.isEmpty && irregular.isEmpty && missingWorkouts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        if (atRisk.isNotEmpty)
          _buildAlertCard(
            '${atRisk.length} aluno${atRisk.length > 1 ? 's' : ''} sem treinar há 5+ dias',
            atRisk.map((s) => s.studentName).join(', '),
            Colors.redAccent,
            Icons.warning_amber_rounded,
            () {
               // Navigation could go to a filtered list or first student
               if (atRisk.length == 1) {
                 _navigateToStudent(atRisk.first.studentId);
               }
            }
          ),
        
        if (missingWorkouts.isNotEmpty)
          _buildAlertCard(
            '${missingWorkouts.length} aluno${missingWorkouts.length > 1 ? 's' : ''} sem treinos agendados',
            missingWorkouts.map((s) => s.studentName).join(', '),
            Colors.orangeAccent,
            Icons.calendar_today_outlined,
            () {
              if (missingWorkouts.length == 1) {
                 _navigateToStudent(missingWorkouts.first.studentId);
               }
            }
          ),
          
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAlertCard(String title, String subtitle, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: color.withOpacity(0.8),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  void _navigateToStudent(String studentId) {
     // We need to fetch the User object or modify StudentDetailScreen to accept ID
     // For now, let's try to find in _recentStudents or just navigate if possible
     try {
       final student = _recentStudents.firstWhere((s) => s.id == studentId);
       Navigator.push(
         context,
         MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
       );
     } catch (_) {
       // If not in recent, we might need to fetch it first. 
       // Simplification: just show message or navigate to list
       Navigator.push(
         context,
         MaterialPageRoute(builder: (_) => const TrainerStudentsScreen()),
       );
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
