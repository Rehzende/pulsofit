import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

/// Map muscle group enum to readable Portuguese name
const Map<String, String> _muscleGroupPt = {
  'CHEST': 'Peito',
  'BACK': 'Costas',
  'LEGS': 'Pernas',
  'ARMS': 'Braços',
  'SHOULDERS': 'Ombros',
  'CORE': 'Core',
  'CARDIO': 'Cardio',
};

const Map<String, String> _muscleGroupEmoji = {
  'CHEST': '💪',
  'BACK': '🔙',
  'LEGS': '🦵',
  'ARMS': '💪',
  'SHOULDERS': '🤷',
  'CORE': '🎯',
  'CARDIO': '❤️',
};

/// Screen showing the Monthly Wrapped stats
class MonthlyWrappedScreen extends StatefulWidget {
  final int? year;
  final int? month;

  const MonthlyWrappedScreen({super.key, this.year, this.month});

  @override
  State<MonthlyWrappedScreen> createState() => _MonthlyWrappedScreenState();
}

class _MonthlyWrappedScreenState extends State<MonthlyWrappedScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSharing = false;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic>? _stats;
  final ScreenshotController _screenshotController = ScreenshotController();

  late int _year;
  late int _month;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late List<AnimationController> _cardControllers;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default: previous month
    final lastMonth = DateTime(now.year, now.month - 1);
    _year = widget.year ?? lastMonth.year;
    _month = widget.month ?? lastMonth.month;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _cardControllers = List.generate(
      6,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    _loadStats();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    for (final c in _cardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await authProvider.dio.get(
        '${AppConstants.baseUrl}/workout-sessions/monthly-stats/$_year/$_month',
      );
      if (response.statusCode == 200) {
        setState(() {
          _stats = response.data as Map<String, dynamic>;
          _isLoading = false;
          _hasError = false;
        });
        // Staggered card entrance animations
        _fadeController.forward();
        for (int i = 0; i < _cardControllers.length; i++) {
          await Future.delayed(Duration(milliseconds: 80 * i));
          if (mounted) _cardControllers[i].forward();
        }
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Erro ao carregar dados. Status: ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint('Error loading monthly stats: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Erro ao conectar ao servidor. Tente novamente.';
      });
    }
  }

  Future<void> _shareWrapped() async {
    setState(() => _isSharing = true);
    HapticFeedback.mediumImpact();

    try {
      final Uint8List image = await _screenshotController.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 100),
      ) ?? Uint8List(0);

      if (image.isEmpty) return;

      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/pulso_wrapped_$_year${_month.toString().padLeft(2, '0')}.png')
          .create();
      await file.writeAsBytes(image);

      final monthName = DateFormat.MMMM('pt_BR').format(DateTime(_year, _month));

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Meu mês de $monthName no PULSO! 💪🔥 #PULSO #FitnessWrapped',
      );
    } catch (e) {
      debugPrint('Error sharing wrapped: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String get _monthName {
    return DateFormat.MMMM('pt_BR').format(DateTime(_year, _month)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Seu Mês em Resumo',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_stats != null && ((_stats!['total_sessions'] as num?) ?? 0) > 0)
            TextButton.icon(
              onPressed: _isSharing ? null : _shareWrapped,
              icon: _isSharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.share_outlined, color: Colors.white, size: 18),
              label: Text(
                'Compartilhar',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(AppConstants.neonAccent),
              ),
            )
          : _hasError
              ? _buildErrorView()
              : _buildBody(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar dados',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: GoogleFonts.inter(
              color: const Color(AppConstants.textSecondary),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
            label: Text(
              'Tentar Novamente',
              style: GoogleFonts.inter(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.neonAccent),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final totalSessions = _stats?['total_sessions'] as int? ?? 0;

    if (totalSessions == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📭', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Sem treinos em $_monthName',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete treinos no $_monthName de $_year\npara ver seu resumo aqui!',
              style: GoogleFonts.inter(
                color: const Color(AppConstants.textSecondary),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Screenshot(
      controller: _screenshotController,
      child: Container(
        color: const Color(AppConstants.primaryDark),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _fadeController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card (highlighted)
                _buildHeaderCard(),
                const SizedBox(height: 16),

                // Stats grid
                _buildStatsGrid(),
                const SizedBox(height: 16),

                // Highlights row
                Row(
                  children: [
                    Expanded(child: _buildHighlightCard(0)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildHighlightCard(1)),
                  ],
                ),
                const SizedBox(height: 16),

                // Mood insight card
                if (_stats?['mood_avg_before'] != null) _buildMoodCard(),

                const SizedBox(height: 16),

                // Footer watermark (for sharing)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.favorite,
                        size: 12,
                        color: Color(AppConstants.neonAccent),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Powered by PULSO',
                        style: GoogleFonts.inter(
                          color: const Color(AppConstants.textSecondary),
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final totalMinutes = _stats?['total_minutes'] as int? ?? 0;
    final totalSessions = _stats?['total_sessions'] as int? ?? 0;
    final totalHours = totalMinutes ~/ 60;
    final remainingMinutes = totalMinutes % 60;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(CurvedAnimation(parent: _cardControllers[0], curve: Curves.easeOutCubic)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(AppConstants.neonAccent).withOpacity(0.15),
              const Color(AppConstants.cardDark),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(AppConstants.neonAccent).withOpacity(0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.neonAccent).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_monthName $_year',
                    style: GoogleFonts.inter(
                      color: const Color(AppConstants.neonAccent),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const Spacer(),
                const Text('🏆', style: TextStyle(fontSize: 24)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$totalSessions treinos',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            Text(
              'concluídos com sucesso',
              style: GoogleFonts.inter(
                color: const Color(AppConstants.textSecondary),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            // Time bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTimeStat('${totalHours}h\n${remainingMinutes}min', 'Tempo Total'),
                  Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                  _buildTimeStat(
                    totalSessions > 0
                        ? '${(totalMinutes / totalSessions).round()}min'
                        : '--',
                    'Média/Treino',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(AppConstants.textSecondary),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final totalXp = _stats?['total_xp'] as int? ?? 0;
    final totalCalories = _stats?['total_calories'] as num? ?? 0;
    final maxBpm = _stats?['max_bpm'] as int? ?? 0;
    final avgBpm = _stats?['avg_bpm'] as int? ?? 0;

    final items = [
      {'icon': '⚡', 'value': '$totalXp XP', 'label': 'XP Ganhos', 'color': 0xFFF59E0B},
      {'icon': '🔥', 'value': '${totalCalories.toStringAsFixed(0)}kcal', 'label': 'Calorias', 'color': 0xFFEF4444},
      {'icon': '💓', 'value': '${maxBpm} bpm', 'label': 'BPM Máximo', 'color': 0xFFEC4899},
      {'icon': '❤️', 'value': '${avgBpm} bpm', 'label': 'BPM Médio', 'color': 0xFF8B5CF6},
    ];

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(CurvedAnimation(parent: _cardControllers[1], curve: Curves.easeOutCubic)),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final color = Color(item['color'] as int);
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(AppConstants.cardDark),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['icon'] as String, style: const TextStyle(fontSize: 24)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['value'] as String,
                      style: GoogleFonts.inter(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      item['label'] as String,
                      style: GoogleFonts.inter(
                        color: const Color(AppConstants.textSecondary),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHighlightCard(int idx) {
    final favoriteDay = _stats?['favorite_day'] as String?;
    final topMuscle = _stats?['top_muscle_group'] as String?;
    final topMusclePt = _muscleGroupPt[topMuscle] ?? topMuscle ?? '--';
    final topMuscleEmoji = _muscleGroupEmoji[topMuscle] ?? '💪';

    final cards = [
      {
        'emoji': '📅',
        'title': 'Dia Favorito',
        'value': favoriteDay ?? '--',
        'subtitle': 'é quando você treina mais',
      },
      {
        'emoji': topMuscleEmoji,
        'title': 'Músculo Top',
        'value': topMusclePt,
        'subtitle': 'grupo mais trabalhado',
      },
    ];

    final card = cards[idx];

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(CurvedAnimation(parent: _cardControllers[2 + idx], curve: Curves.easeOutCubic)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(AppConstants.cardDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card['emoji']!, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 12),
            Text(
              card['title']!,
              style: GoogleFonts.inter(
                color: const Color(AppConstants.textSecondary),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card['value']!,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card['subtitle']!,
              style: GoogleFonts.inter(
                color: const Color(AppConstants.textSecondary),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodCard() {
    final moodBefore = (_stats?['mood_avg_before'] as num?)?.toDouble();
    final moodAfter = (_stats?['mood_avg_after'] as num?)?.toDouble();

    // Mood labels
    final moodLabels = ['', 'Exausto', 'Cansado', 'Normal', 'Animado', 'Na Vibe!'];
    final moodEmojis = ['', '😴', '😕', '😐', '😄', '🔥'];

    int beforeIdx = moodBefore != null ? moodBefore.round().clamp(1, 5) : 0;
    int afterIdx = moodAfter != null ? moodAfter.round().clamp(1, 5) : 0;

    // If mood improves after workout, show positive insight
    final moodBoost = moodAfter != null && moodBefore != null
        ? (moodAfter - moodBefore).toStringAsFixed(1)
        : null;
    final moodImproved = moodAfter != null && moodBefore != null && moodAfter > moodBefore;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(CurvedAnimation(parent: _cardControllers[4], curve: Curves.easeOutCubic)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(AppConstants.cardDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: moodImproved
                ? const Color(0xFF10B981).withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  moodImproved ? '🧠✨' : '🧠',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Text(
                  'Check-in de Humor',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMoodStat(
                    'Pré-Treino',
                    beforeIdx > 0 ? moodEmojis[beforeIdx] : '?',
                    beforeIdx > 0 ? moodLabels[beforeIdx] : '--',
                    const Color(0xFF6B7280),
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Colors.white.withOpacity(0.1),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                Expanded(
                  child: _buildMoodStat(
                    'Pós-Treino',
                    afterIdx > 0 ? moodEmojis[afterIdx] : '?',
                    afterIdx > 0 ? moodLabels[afterIdx] : '--',
                    const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            if (moodBoost != null && moodImproved) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'O treino melhora seu humor em média +$moodBoost pontos. Continue! 🚀',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF10B981),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMoodStat(String phase, String emoji, String label, Color color) {
    return Column(
      children: [
        Text(phase,
            style: GoogleFonts.inter(
                color: const Color(AppConstants.textSecondary), fontSize: 11)),
        const SizedBox(height: 6),
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
