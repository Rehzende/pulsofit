import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

// Maps quiz answers to template IDs to import
const Map<String, List<String>> _templateMap = {
  // goal_experience_equipment
  'hypertrophy_beginner_gym': ['fullbody-a', 'fullbody-b'],
  'hypertrophy_intermediate_gym': ['ppl-push', 'ppl-pull', 'ppl-legs'],
  'hypertrophy_advanced_gym': ['ppl-push', 'ppl-pull', 'ppl-legs'],
  'strength_beginner_gym': ['fullbody-a', 'fullbody-b'],
  'strength_intermediate_gym': ['stronglifts-a', 'stronglifts-b'],
  'strength_advanced_gym': ['stronglifts-a', 'stronglifts-b'],
  'cardio_beginner_gym': ['hiit-3x'],
  'cardio_intermediate_gym': ['hiit-3x'],
  'cardio_advanced_gym': ['hiit-3x'],
  // no equipment fallback
  'hypertrophy_beginner_home': ['home-noequip'],
  'hypertrophy_intermediate_home': ['home-noequip'],
  'strength_beginner_home': ['home-noequip'],
  'cardio_beginner_home': ['hiit-3x'],
};

List<String> _resolveTemplates(String goal, String experience, String equipment) {
  final key = '${goal}_${experience}_$equipment';
  return _templateMap[key] ?? (equipment == 'home' ? ['home-noequip'] : ['fullbody-a', 'fullbody-b']);
}

class OnboardingQuizScreen extends StatefulWidget {
  const OnboardingQuizScreen({super.key});

  @override
  State<OnboardingQuizScreen> createState() => _OnboardingQuizScreenState();
}

class _OnboardingQuizScreenState extends State<OnboardingQuizScreen> {
  int _step = 0;
  String? _goal;
  String? _experience;
  String? _equipment;
  bool _importing = false;

  static const _goals = [
    ('hypertrophy', 'Ganhar Massa', '💪', 'Hipertrofia e aumento de força'),
    ('strength', 'Ganhar Forca', '🏋️', 'Forca e performance'),
    ('cardio', 'Perder Peso / Condicionamento', '🏃', 'Queima de gordura e saude'),
  ];
  static const _experiences = [
    ('beginner', 'Iniciante', 'Menos de 6 meses de treino'),
    ('intermediate', 'Intermediario', '6 meses a 2 anos de treino'),
    ('advanced', 'Avancado', 'Mais de 2 anos de treino'),
  ];
  static const _equipments = [
    ('gym', 'Academia Completa', '🏋️', 'Acesso a maquinas e pesos livres'),
    ('home', 'Em Casa / Sem Equipamento', '🏠', 'Treino com peso corporal'),
  ];

  Future<void> _importAndFinish() async {
    setState(() => _importing = true);
    final templates = _resolveTemplates(_goal!, _experience!, _equipment!);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    int imported = 0;
    try {
      for (final tid in templates) {
        await auth.dio.post('${AppConstants.baseUrl}/workout-templates/$tid/import');
        imported++;
      }
      // Mark anamnesis completed
      auth.completeAnamnesis();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$imported treinos adicionados ao seu plano!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar treinos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.primaryDark),
        foregroundColor: Colors.white,
        title: Text(
          'Configure seu plano',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress bar
            Row(
              children: List.generate(3, (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 6.0 : 0.0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= _step
                        ? const Color(AppConstants.neonAccent)
                        : const Color(AppConstants.borderColor),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 32),
            if (_step == 0) _buildGoalStep(),
            if (_step == 1) _buildExperienceStep(),
            if (_step == 2) _buildEquipmentStep(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalStep() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Qual e seu objetivo?', style: _titleStyle()),
          Text('Isso define o tipo de programa ideal para voce.',
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(height: 24),
          ...(_goals.map((g) => _OptionCard(
                title: g.$2,
                subtitle: g.$4,
                emoji: g.$3,
                selected: _goal == g.$1,
                onTap: () {
                  setState(() {
                    _goal = g.$1;
                    _step = 1;
                  });
                },
              ))),
        ],
      ),
    );
  }

  Widget _buildExperienceStep() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Qual e seu nivel?', style: _titleStyle()),
          Text('Vamos ajustar a intensidade do programa.',
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(height: 24),
          ...(_experiences.map((e) => _OptionCard(
                title: e.$2,
                subtitle: e.$3,
                emoji: null,
                selected: _experience == e.$1,
                onTap: () {
                  setState(() {
                    _experience = e.$1;
                    _step = 2;
                  });
                },
              ))),
        ],
      ),
    );
  }

  Widget _buildEquipmentStep() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Voce tem acesso a academia?', style: _titleStyle()),
          Text('Isso define os exercicios do seu programa.',
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(height: 24),
          ...(_equipments.map((e) => _OptionCard(
                title: e.$2,
                subtitle: e.$4,
                emoji: e.$3,
                selected: _equipment == e.$1,
                onTap: () => setState(() => _equipment = e.$1),
              ))),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_equipment != null && !_importing) ? _importAndFinish : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.neonAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _importing
                  ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                  : Text(
                      'Montar meu programa',
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _titleStyle() => GoogleFonts.inter(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        height: 1.3,
      );
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? const Color(AppConstants.neonAccent).withOpacity(0.1)
              : const Color(AppConstants.cardDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(AppConstants.neonAccent)
                : const Color(AppConstants.borderColor),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(AppConstants.neonAccent)),
          ],
        ),
      ),
    );
  }
}
