import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import 'main_navigation_screen.dart';

// Electric lime — used SPARINGLY for energy / achievement accents.
const Color spark = Color(0xFFD4FF3F);

class WorkoutSummaryScreen extends StatefulWidget {
  final String workoutName;
  final int durationSeconds;
  final int averageHeartRate;
  final int xpEarned;
  final num? caloriesBurned;
  final int currentStreak;
  final bool isNewStreakRecord;
  final String? trainerLogoUrl;
  final String? trainerInstagramHandle;

  const WorkoutSummaryScreen({
    super.key,
    required this.workoutName,
    required this.durationSeconds,
    required this.averageHeartRate,
    this.xpEarned = 0,
    this.caloriesBurned,
    this.currentStreak = 0,
    this.isNewStreakRecord = false,
    this.trainerLogoUrl,
    this.trainerInstagramHandle,
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen>
    with TickerProviderStateMixin {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  // Drives the staggered entrance reveal (slide-up + fade).
  bool _revealed = false;

  // Continuous pulse for the streak flame + record burst ring.
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Punctuate the moment of arrival.
    HapticFeedback.heavyImpact();

    // Trigger the orchestrated entrance on the next frame so the implicit
    // animations have an initial (hidden) state to animate FROM.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _getImageUrl(String url) {
    if (url.startsWith('http')) return url;
    var cleanUrl = url;
    while (cleanUrl.startsWith('/')) {
      cleanUrl = cleanUrl.substring(1);
    }
    return '${AppConstants.apiUrl}/$cleanUrl';
  }

  /// Deterministic PT-BR headline for the share card. Deterministic so the
  /// captured PNG is always stable for a given workout.
  String _shareHeadline() {
    if (widget.isNewStreakRecord) return 'RECORDE BATIDO';
    if (widget.currentStreak > 1) return 'DIA ${widget.currentStreak}';
    const options = [
      'SEM DESCULPAS',
      'MAIS UM',
      'FOCO TOTAL',
      'CONSTÂNCIA',
      'TREINO FEITO',
    ];
    return options[widget.durationSeconds % options.length];
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar imagem: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _shareToInstagram() async {
    setState(() {
      _isSharing = true;
    });

    try {
      // Capture the screenshot
      final imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 10),
        pixelRatio: 2.0, // Higher quality
      );

      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'workout_share_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File('${tempDir.path}/$fileName');

        await file.writeAsBytes(imageBytes);

        // Check if file exists before sharing
        if (await file.exists()) {
          await Share.shareXFiles(
            [XFile(file.path)],
            text: '💪 Treino concluído com sucesso! #PULSO',
          );
        } else {
          throw Exception('Erro ao salvar arquivo de imagem');
        }
      } else {
        throw Exception('Erro ao capturar imagem');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao compartilhar: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  // ── Staggered entrance helper ──────────────────────────────────────────
  // Wraps a child in a slide-up + fade that fires once on reveal.
  // ALL of these animations live on the SCREEN, never inside the Screenshot
  // capture subtree.
  Widget _staggered({required int delayMs, required Widget child}) {
    return AnimatedSlide(
      offset: _revealed ? Offset.zero : const Offset(0, 0.18),
      duration: Duration(milliseconds: 520 + delayMs),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _revealed ? 1.0 : 0.0,
        duration: Duration(milliseconds: 420 + delayMs),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(AppConstants.cardDark),
              const Color(AppConstants.primaryDark),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── CELEBRATION HEADER ──────────────────────────────
                _staggered(
                  delayMs: 0,
                  child: _buildCelebrationHeader(),
                ),

                const SizedBox(height: 24),

                // ── XP HERO ─────────────────────────────────────────
                _staggered(
                  delayMs: 90,
                  child: _buildXpHero(),
                ),

                const SizedBox(height: 20),

                // ── HERO STAT ROW ───────────────────────────────────
                _staggered(
                  delayMs: 160,
                  child: _buildHeroStatRow(),
                ),

                // ── STREAK CELEBRATION ──────────────────────────────
                if (widget.currentStreak > 0) ...[
                  const SizedBox(height: 20),
                  _staggered(
                    delayMs: 230,
                    child: _buildStreakCelebration(),
                  ),
                ],

                const SizedBox(height: 32),

                // ── SHARE SECTION ───────────────────────────────────
                _staggered(
                  delayMs: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: spark,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'COMPARTILHE SUA VITÓRIA',
                            style: GoogleFonts.archivo(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(AppConstants.textPrimary),
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // STATIC capture subtree — no animations inside.
                      Center(
                        child: Screenshot(
                          controller: _screenshotController,
                          child: _buildShareCard(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── BUTTONS ─────────────────────────────────────────
                _staggered(
                  delayMs: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _pickImage,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(AppConstants.textPrimary),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.25),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _selectedImage == null ? 'ADICIONAR FOTO' : 'ALTERAR FOTO',
                                  maxLines: 1,
                                  style: GoogleFonts.archivo(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSharing ? null : _shareToInstagram,
                              icon: _isSharing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.share, size: 20),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _isSharing ? 'COMPARTILHANDO' : 'COMPARTILHAR',
                                  maxLines: 1,
                                  style: GoogleFonts.archivo(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(AppConstants.cyanAccent),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 6,
                                shadowColor:
                                    const Color(AppConstants.cyanAccent).withOpacity(0.45),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const MainNavigationScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(AppConstants.neonAccent),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor:
                                const Color(AppConstants.neonAccent).withOpacity(0.5),
                          ),
                          child: Text(
                            'FINALIZAR',
                            style: GoogleFonts.archivo(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SCREEN-ONLY CELEBRATION WIDGETS (animated; OUTSIDE the capture subtree)
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildCelebrationHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(AppConstants.neonAccent).withOpacity(0.15),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(AppConstants.neonAccent).withOpacity(0.28),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.emoji_events,
            size: 58,
            color: spark,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'TREINO CONCLUÍDO',
          style: GoogleFonts.bebasNeue(
            fontSize: 46,
            color: const Color(AppConstants.textPrimary),
            letterSpacing: 2.0,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          widget.workoutName.toUpperCase(),
          style: GoogleFonts.archivo(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(AppConstants.textSecondary),
            letterSpacing: 2.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildXpHero() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(AppConstants.neonAccent).withOpacity(0.22),
            const Color(AppConstants.cardDark),
          ],
        ),
        border: Border.all(color: spark.withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, color: spark, size: 34),
              const SizedBox(width: 4),
              // XP count-up: 0 → xpEarned (screen-only animation).
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: widget.xpEarned),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutExpo,
                builder: (context, value, _) {
                  return Text(
                    '+$value',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 76,
                      color: spark,
                      letterSpacing: 1.0,
                      height: 1.0,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'XP CONQUISTADO',
            style: GoogleFonts.archivo(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(AppConstants.textPrimary),
              letterSpacing: 3.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatRow() {
    final stats = <Widget>[
      _buildScreenStat(
        label: 'DURAÇÃO',
        value: _formatDuration(widget.durationSeconds),
        icon: Icons.timer_outlined,
        iconColor: const Color(AppConstants.cyanAccent),
      ),
      _buildScreenStat(
        label: 'CALORIAS',
        value: widget.caloriesBurned != null
            ? widget.caloriesBurned!.toStringAsFixed(0)
            : '--',
        unit: 'KCAL',
        icon: Icons.local_fire_department_outlined,
        iconColor: const Color(0xFFFF6B00),
      ),
      if (widget.averageHeartRate > 0)
        _buildScreenStat(
          label: 'BPM MÉDIO',
          value: '${widget.averageHeartRate}',
          icon: Icons.favorite_border,
          iconColor: const Color(0xFFE53935),
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              Expanded(child: stats[i]),
              if (i != stats.length - 1)
                VerticalDivider(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                  thickness: 1,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScreenStat({
    required String label,
    required String value,
    String? unit,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: GoogleFonts.bebasNeue(
                color: const Color(AppConstants.textPrimary),
                fontSize: 32,
                height: 1.0,
                letterSpacing: 0.5,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: GoogleFonts.archivo(
                    color: const Color(AppConstants.textSecondary),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.archivo(
            color: const Color(AppConstants.textSecondary),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCelebration() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B00).withOpacity(0.18),
            const Color(AppConstants.cardDark),
          ],
        ),
        border: Border.all(
          color: widget.isNewStreakRecord
              ? spark.withOpacity(0.5)
              : const Color(0xFFFF6B00).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Pulsing flame, optionally with a celebratory burst ring on record.
          SizedBox(
            width: 56,
            height: 56,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final t = _pulseController.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.isNewStreakRecord)
                      CustomPaint(
                        size: const Size(56, 56),
                        painter: _BurstRingPainter(
                          progress: t,
                          color: spark,
                        ),
                      ),
                    Transform.scale(
                      scale: 1.0 + 0.12 * t,
                      child: Icon(
                        Icons.local_fire_department,
                        color: Color.lerp(
                          const Color(0xFFFF6B00),
                          const Color(0xFFFFB300),
                          t,
                        ),
                        size: 34,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'DIA ',
                      style: GoogleFonts.archivo(
                        color: const Color(AppConstants.textSecondary),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${widget.currentStreak}',
                      style: GoogleFonts.bebasNeue(
                        color: const Color(AppConstants.textPrimary),
                        fontSize: 34,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.isNewStreakRecord
                      ? 'NOVO RECORDE DE OFENSIVA!'
                      : 'OFENSIVA ATIVA — NÃO PARE',
                  style: GoogleFonts.archivo(
                    color: widget.isNewStreakRecord
                        ? spark
                        : const Color(AppConstants.textSecondary),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          if (widget.isNewStreakRecord)
            const Icon(Icons.emoji_events, color: spark, size: 26),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SHARE CARD — STATIC subtree captured to PNG. NO animations in here.
  // Athletic sport-editorial poster, ~9:16 (300x533).
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildShareCard() {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    final headline = _shareHeadline();

    return Container(
      width: 300,
      height: 533,
      decoration: BoxDecoration(
        color: const Color(AppConstants.primaryDark),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── LAYER 1: BACKGROUND (photo OR deliberate default mesh) ──
            if (_selectedImage != null)
              Image.file(_selectedImage!, fit: BoxFit.cover)
            else
              _buildDefaultBackground(),

            // ── LAYER 2: readability scrim (top + bottom) ──────────────
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.28, 0.6, 1.0],
                  colors: [
                    Colors.black.withOpacity(0.65),
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.88),
                  ],
                ),
              ),
            ),

            // ── LAYER 3: POSTER CONTENT ────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Masthead ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // FittedBox(scaleDown) shrinks a long name to fit the
                      // available width instead of truncating it, so the full
                      // workout name is always visible. Flexible (no Spacer)
                      // gives it all the room left over by the date.
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(color: spark, width: 1.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.workoutName.toUpperCase(),
                              maxLines: 1,
                              style: GoogleFonts.archivo(
                                color: spark,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        dateStr,
                        style: GoogleFonts.archivo(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── HERO HEADLINE ──
                  Text(
                    headline,
                    style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 58,
                      height: 0.92,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(width: 22, height: 2, color: spark),
                      const SizedBox(width: 8),
                      Text(
                        'POWERED BY PULSO',
                        style: GoogleFonts.archivo(
                          color: const Color(AppConstants.neonAccentLight),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── FROSTED STAT ROW ──
                  _buildFrostedStatRow(),

                  const SizedBox(height: 12),

                  // ── XP / STREAK + BRANDING (unified footer) ──
                  _buildPosterFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Deliberate, premium default background: violet → near-black mesh with a
  // single disciplined lime accent + faint diagonal line texture + vignette.
  Widget _buildDefaultBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base mesh: violet bleeding from top-left into near-black.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2A0E4F), // deep violet
                Color(AppConstants.primaryDark),
                Color(0xFF05040A),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        // Soft violet glow bloom (single, disciplined).
        Positioned(
          top: -80,
          right: -70,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(AppConstants.neonAccent).withOpacity(0.45),
                  const Color(AppConstants.neonAccent).withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // One disciplined lime spark glow, low and small.
        Positioned(
          bottom: 120,
          left: -50,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  spark.withOpacity(0.16),
                  spark.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // Faint diagonal line texture.
        CustomPaint(
          painter: _DiagonalLinesPainter(
            color: Colors.white.withOpacity(0.04),
          ),
        ),
        // Vignette to focus the center.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.1,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.45),
              ],
              stops: const [0.6, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrostedStatRow() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
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
                    value: _formatDuration(widget.durationSeconds),
                    icon: Icons.timer_outlined,
                  ),
                ),
                _frostedDivider(),
                Expanded(
                  child: _buildFrostedStat(
                    label: 'CALORIAS',
                    value: widget.caloriesBurned != null
                        ? widget.caloriesBurned!.toStringAsFixed(0)
                        : '--',
                    unit: 'KCAL',
                    icon: Icons.local_fire_department_outlined,
                    iconColor: const Color(0xFFFF6B00),
                  ),
                ),
                if (widget.averageHeartRate > 0) ...[
                  _frostedDivider(),
                  Expanded(
                    child: _buildFrostedStat(
                      label: 'BPM',
                      value: '${widget.averageHeartRate}',
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
    );
  }

  Widget _frostedDivider() => VerticalDivider(
        color: Colors.white.withOpacity(0.25),
        width: 1,
        thickness: 1,
      );

  // Unified footer: XP hero number on the left, streak + branding stacked
  // on the right. One composition, harmonized type & spacing.
  Widget _buildPosterFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: spark.withOpacity(0.25), width: 1),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // XP hero
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt, color: spark, size: 22),
                      const SizedBox(width: 2),
                      Text(
                        '+${widget.xpEarned}',
                        style: GoogleFonts.bebasNeue(
                          color: spark,
                          fontSize: 40,
                          height: 1.0,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'XP CONQUISTADO',
                    style: GoogleFonts.archivo(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Streak pills
              if (widget.currentStreak > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPill(
                      icon: Icons.local_fire_department,
                      iconColor: const Color(0xFFFF6B00),
                      text: 'DIA ${widget.currentStreak}',
                    ),
                    if (widget.isNewStreakRecord) ...[
                      const SizedBox(height: 6),
                      _buildPill(
                        text: 'RECORDE',
                        icon: Icons.emoji_events,
                        iconColor: spark,
                      ),
                    ],
                  ],
                ),
            ],
          ),
          // Branding divider + row
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Divider(
              color: Colors.white.withOpacity(0.1),
              height: 1,
              thickness: 1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.trainerInstagramHandle != null) ...[
                if (widget.trainerLogoUrl != null)
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                      image: DecorationImage(
                        image: NetworkImage(_getImageUrl(widget.trainerLogoUrl!)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Text(
                  '@${widget.trainerInstagramHandle}',
                  style: GoogleFonts.archivo(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.fitness_center,
                      color: Color(AppConstants.neonAccentLight), size: 11),
                  const SizedBox(width: 4),
                  Text(
                    '@pulsofit.app',
                    style: GoogleFonts.archivo(
                      color: const Color(AppConstants.neonAccentLight),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.archivo(
                  color: Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: GoogleFonts.bebasNeue(
                color: Colors.white,
                fontSize: 26,
                height: 1.0,
                letterSpacing: 0.5,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: GoogleFonts.archivo(
                    color: Colors.white60,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPill(
      {required String text, required IconData icon, required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.archivo(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Faint diagonal-line texture for the default share-card background.
class _DiagonalLinesPainter extends CustomPainter {
  final Color color;
  _DiagonalLinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    const gap = 22.0;
    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DiagonalLinesPainter old) => old.color != color;
}

// Celebratory burst ring used in the streak record celebration (SCREEN only).
class _BurstRingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  _BurstRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Expanding fading halo.
    final haloR = maxR * (0.55 + 0.45 * progress);
    final haloPaint = Paint()
      ..color = color.withOpacity((1.0 - progress) * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, haloR, haloPaint);

    // Radiating spokes.
    final spokePaint = Paint()
      ..color = color.withOpacity((1.0 - progress) * 0.5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const count = 8;
    final inner = maxR * 0.6;
    final outer = maxR * (0.7 + 0.3 * progress);
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi + progress * 0.4;
      final p1 = center + Offset(cos(angle), sin(angle)) * inner;
      final p2 = center + Offset(cos(angle), sin(angle)) * outer;
      canvas.drawLine(p1, p2, spokePaint);
    }
  }

  @override
  bool shouldRepaint(_BurstRingPainter old) =>
      old.progress != progress || old.color != color;
}
