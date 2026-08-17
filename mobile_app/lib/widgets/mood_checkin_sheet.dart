import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

/// Mood options with emoji, label, and color
const List<Map<String, dynamic>> _moods = [
  {'emoji': '😴', 'label': 'Exausto', 'value': 1, 'color': 0xFF6B7280},
  {'emoji': '😕', 'label': 'Cansado', 'value': 2, 'color': 0xFFF59E0B},
  {'emoji': '😐', 'label': 'Normal', 'value': 3, 'color': 0xFF3B82F6},
  {'emoji': '😄', 'label': 'Animado', 'value': 4, 'color': 0xFF10B981},
  {'emoji': '🔥', 'label': 'Na Vibe!', 'value': 5, 'color': AppConstants.neonAccent},
];

/// Shows a beautiful bottom sheet for mood check-in before or after a workout.
/// Returns the selected mood value (1-5) or null if dismissed.
Future<int?> showMoodCheckIn(
  BuildContext context, {
  required String phase, // 'before' or 'after'
  String? sessionId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MoodCheckInSheet(phase: phase, sessionId: sessionId),
  );
}

class MoodCheckInSheet extends StatefulWidget {
  final String phase;
  final String? sessionId;

  const MoodCheckInSheet({super.key, required this.phase, this.sessionId});

  @override
  State<MoodCheckInSheet> createState() => _MoodCheckInSheetState();
}

class _MoodCheckInSheetState extends State<MoodCheckInSheet>
    with SingleTickerProviderStateMixin {
  int? _selectedMood;
  bool _isSaving = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _saveMood() async {
    if (_selectedMood == null) return;
    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.dio.post(
        '${AppConstants.baseUrl}/workout-sessions/mood',
        data: {
          'mood': _selectedMood,
          'phase': widget.phase,
          if (widget.sessionId != null) 'session_id': widget.sessionId,
        },
      );
    } catch (e) {
      debugPrint('Error saving mood: $e');
      // Not critical — proceed anyway
    }

    if (mounted) {
      Navigator.of(context).pop(_selectedMood);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBefore = widget.phase == 'before';
    final title = isBefore ? 'Como você está agora?' : 'Como foi o treino?';
    final subtitle = isBefore
        ? 'Seu estado de espírito impacta a performance'
        : 'Rastrear seu humor ajuda a otimizar treinos futuros';

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic)),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(AppConstants.cardDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(
              color: const Color(AppConstants.neonAccent).withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(AppConstants.neonAccent).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                isBefore ? '🧠' : '🏅',
                style: const TextStyle(fontSize: 32),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: const Color(AppConstants.textSecondary),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Mood Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _moods.map((mood) {
                final isSelected = _selectedMood == mood['value'];
                final color = Color(mood['color'] as int);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedMood = mood['value'] as int);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.3 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            mood['emoji'] as String,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          mood['label'] as String,
                          style: GoogleFonts.inter(
                            color: isSelected ? color : const Color(AppConstants.textSecondary),
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // Confirm Button
            AnimatedOpacity(
              opacity: _selectedMood != null ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedMood != null && !_isSaving ? _saveMood : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConstants.neonAccent),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(AppConstants.neonAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          isBefore ? 'Iniciar Treino' : 'Salvar & Continuar',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),

            // Skip
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Pular',
                style: GoogleFonts.inter(
                  color: const Color(AppConstants.textSecondary),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
