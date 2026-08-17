import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';

/// Recovery status for muscle groups
enum RecoveryStatus {
  tired,      // < 24h - Red glow
  recovering, // 24-48h - Orange/Amber glow
  fresh,      // > 48h - Green / dim
}

/// Glow node position (relative 0..1 within the body area)
class GlowNode {
  final String label;
  final double relX; // 0.0 = left, 1.0 = right
  final double relY; // 0.0 = top, 1.0 = bottom
  final double radius; // glow radius factor

  const GlowNode(this.label, this.relX, this.relY, {this.radius = 0.08});
}

class HumanBodyHeatmap extends StatefulWidget {
  const HumanBodyHeatmap({super.key});

  @override
  State<HumanBodyHeatmap> createState() => _HumanBodyHeatmapState();
}

class _HumanBodyHeatmapState extends State<HumanBodyHeatmap>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _recoveryData;
  int _overallPct = 100;
  String? _error;
  bool _showFront = true;
  late AnimationController _pulseController;

  // Glow node maps — positions are relative to body container (0..1)
  static const Map<String, List<GlowNode>> _frontNodes = {
    'SHOULDERS': [
      GlowNode('Ombro E', 0.30, 0.22, radius: 0.06),
      GlowNode('Ombro D', 0.70, 0.22, radius: 0.06),
    ],
    'CHEST': [
      GlowNode('Peito', 0.50, 0.28, radius: 0.12),
    ],
    'ARMS': [
      GlowNode('Bíceps E', 0.22, 0.34, radius: 0.05),
      GlowNode('Bíceps D', 0.78, 0.34, radius: 0.05),
    ],
    'CORE': [
      GlowNode('Core', 0.50, 0.40, radius: 0.08),
    ],
    'LEGS': [
      GlowNode('Quad E', 0.40, 0.60, radius: 0.07),
      GlowNode('Quad D', 0.60, 0.60, radius: 0.07),
      GlowNode('Canela E', 0.40, 0.80, radius: 0.05),
      GlowNode('Canela D', 0.60, 0.80, radius: 0.05),
    ],
  };

  static const Map<String, List<GlowNode>> _backNodes = {
    'SHOULDERS': [
      GlowNode('Ombro E', 0.30, 0.22, radius: 0.06),
      GlowNode('Ombro D', 0.70, 0.22, radius: 0.06),
    ],
    'BACK': [
      GlowNode('Costas Alta', 0.50, 0.28, radius: 0.10),
      GlowNode('Lombar', 0.50, 0.40, radius: 0.08),
    ],
    'ARMS': [
      GlowNode('Tríceps E', 0.22, 0.34, radius: 0.05),
      GlowNode('Tríceps D', 0.78, 0.34, radius: 0.05),
    ],
    'LEGS': [
      GlowNode('Glúteo E', 0.42, 0.50, radius: 0.07),
      GlowNode('Glúteo D', 0.58, 0.50, radius: 0.07),
      GlowNode('Posterior E', 0.40, 0.65, radius: 0.06),
      GlowNode('Posterior D', 0.60, 0.65, radius: 0.06),
      GlowNode('Panturrilha E', 0.40, 0.82, radius: 0.04),
      GlowNode('Panturrilha D', 0.60, 0.82, radius: 0.04),
    ],
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadRecoveryStatus();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadRecoveryStatus() async {
    setState(() {
      _error = null;
      _recoveryData = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dio = authProvider.dio;

      final response = await dio.get('/student/recovery');

      if (mounted) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _overallPct = data['overall_percentage'] ?? 100;
          _recoveryData = Map<String, dynamic>.from(
            data['muscle_groups'] ?? {},
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível carregar os dados';
          _overallPct = 100;
          _recoveryData = {
            'CHEST': {'status': 'FRESH', 'recovery_percentage': 100},
            'BACK': {'status': 'FRESH', 'recovery_percentage': 100},
            'LEGS': {'status': 'FRESH', 'recovery_percentage': 100},
            'ARMS': {'status': 'FRESH', 'recovery_percentage': 100},
            'SHOULDERS': {'status': 'FRESH', 'recovery_percentage': 100},
            'CORE': {'status': 'FRESH', 'recovery_percentage': 100},
            'CARDIO': {'status': 'FRESH', 'recovery_percentage': 100},
          };
        });
      }
    }
  }

  RecoveryStatus _getStatus(String muscleGroup) {
    if (_recoveryData == null) return RecoveryStatus.fresh;
    final groupData = _recoveryData![muscleGroup];
    if (groupData == null) return RecoveryStatus.fresh;
    final status = groupData['status'] as String?;
    switch (status) {
      case 'TIRED':
        return RecoveryStatus.tired;
      case 'RECOVERING':
        return RecoveryStatus.recovering;
      case 'FRESH':
      default:
        return RecoveryStatus.fresh;
    }
  }

  int _getRecoveryPct(String muscleGroup) {
    if (_recoveryData == null) return 100;
    final groupData = _recoveryData![muscleGroup];
    if (groupData == null) return 100;
    return groupData['recovery_percentage'] ?? 100;
  }

  Color _getGlowColor(RecoveryStatus status) {
    switch (status) {
      case RecoveryStatus.tired:
        return const Color(0xFFFF4D4D); // Neon Red
      case RecoveryStatus.recovering:
        return const Color(0xFFFFA500); // Neon Orange
      case RecoveryStatus.fresh:
        return const Color(0xFF22C55E); // Neon Green
    }
  }

  Color _getBarColor(RecoveryStatus status) {
    switch (status) {
      case RecoveryStatus.tired:
        return const Color(0xFFEF4444);
      case RecoveryStatus.recovering:
        return const Color(0xFFF59E0B);
      case RecoveryStatus.fresh:
        return const Color(0xFF22C55E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isWoman = authProvider.gender?.toLowerCase() == 'female' ||
        authProvider.gender?.toLowerCase() == 'woman';
    final genderPath = isWoman ? 'woman' : 'man';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 8),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: GoogleFonts.inter(color: Colors.orange, fontSize: 11),
              ),
            ),

          // Overall Recovery Ring
          _buildOverallRing(),
          const SizedBox(height: 16),

          // Toggle
          _buildToggle(),
          const SizedBox(height: 16),

          // Body + Glow Nodes
          SizedBox(
            height: 360,
            width: double.infinity,
            child: _recoveryData == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(AppConstants.neonAccent),
                    ),
                  )
                : _buildBodyWithGlowNodes(isWoman, genderPath),
          ),

          const SizedBox(height: 20),

          // Recovery Bars Panel
          _buildRecoveryBars(),

          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(AppConstants.neonAccent).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.monitor_heart_outlined,
                color: Color(AppConstants.neonAccent),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Recuperação Muscular',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(AppConstants.textPrimary),
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          color: const Color(AppConstants.textSecondary),
          onPressed: _loadRecoveryStatus,
        ),
      ],
    );
  }

  Widget _buildOverallRing() {
    final Color ringColor;
    final String statusText;
    if (_overallPct >= 80) {
      ringColor = const Color(0xFF22C55E);
      statusText = 'Totalmente Recuperado';
    } else if (_overallPct >= 50) {
      ringColor = const Color(0xFFF59E0B);
      statusText = 'Parcialmente Recuperado';
    } else {
      ringColor = const Color(0xFFEF4444);
      statusText = 'Precisa Descansar';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ringColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ringColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _overallPct / 100,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                  strokeWidth: 5,
                ),
                Text(
                  '$_overallPct',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: ringColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(AppConstants.textPrimary),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_overallPct% de recuperação geral',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(AppConstants.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption('Frente', true),
          _buildToggleOption('Costas', false),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, bool isFront) {
    final isSelected = _showFront == isFront;
    return GestureDetector(
      onTap: () => setState(() => _showFront = isFront),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(AppConstants.neonAccent)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.black : Colors.white60,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildBodyWithGlowNodes(bool isWoman, String genderPath) {
    final basePath = 'assets/body/$genderPath/';
    final outlineFile = _showFront
        ? (isWoman ? 'woman_front_body_lines.svg' : 'man_front_body_lines.svg')
        : (isWoman ? 'woman_back_body_lines.svg' : 'man_back_body_lines.svg');

    final nodes = _showFront ? _frontNodes : _backNodes;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Base body outline
            Center(
              child: SizedBox(
                width: w * 0.65,
                height: h,
                child: SvgPicture.asset(
                  '$basePath$outlineFile',
                  colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(0.15),
                    BlendMode.srcIn,
                  ),
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Glow Nodes
            ...nodes.entries.expand((entry) {
              final muscleGroup = entry.key;
              final nodeList = entry.value;
              final status = _getStatus(muscleGroup);
              final color = _getGlowColor(status);

              return nodeList.map((node) {
                // Calculate pixel position relative to the body area
                final bodyLeft = (w - w * 0.65) / 2;
                final bodyWidth = w * 0.65;

                final cx = bodyLeft + node.relX * bodyWidth;
                final cy = node.relY * h;
                final glowSize = node.radius * w;

                return Positioned(
                  left: cx - glowSize,
                  top: cy - glowSize,
                  width: glowSize * 2,
                  height: glowSize * 2,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final pulse = status == RecoveryStatus.tired
                          ? 0.4 + _pulseController.value * 0.4
                          : status == RecoveryStatus.recovering
                              ? 0.2 + _pulseController.value * 0.2
                              : 0.1; // fresh = subtle

                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              color.withOpacity(pulse),
                              color.withOpacity(pulse * 0.3),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      );
                    },
                  ),
                );
              });
            }),
          ],
        );
      },
    );
  }

  Widget _buildRecoveryBars() {
    final groups = [
      ('CHEST', 'Peito', Icons.grid_view_rounded),
      ('BACK', 'Costas', Icons.airline_seat_flat_rounded),
      ('SHOULDERS', 'Ombros', Icons.expand_outlined),
      ('ARMS', 'Braços', Icons.fitness_center_rounded),
      ('CORE', 'Core', Icons.circle_outlined),
      ('LEGS', 'Pernas', Icons.directions_walk_rounded),
      ('CARDIO', 'Cardio', Icons.favorite_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'STATUS POR GRUPO',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: const Color(AppConstants.textSecondary),
            ),
          ),
        ),
        ...groups.map((g) {
          final key = g.$1;
          final label = g.$2;
          final icon = g.$3;
          final status = _getStatus(key);
          final pct = _getRecoveryPct(key);
          final barColor = _getBarColor(status);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: barColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: barColor),
                ),
                const SizedBox(width: 10),
                // Label
                SizedBox(
                  width: 60,
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(AppConstants.textPrimary),
                    ),
                  ),
                ),
                // Bar
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (pct / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [
                              barColor.withOpacity(0.8),
                              barColor,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: barColor.withOpacity(0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Percentage
                SizedBox(
                  width: 36,
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem('Cansado', const Color(0xFFEF4444)),
          _buildLegendItem('Recuperando', const Color(0xFFF59E0B)),
          _buildLegendItem('Descansado', const Color(0xFF22C55E)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.4), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(AppConstants.textSecondary),
          ),
        ),
      ],
    );
  }
}