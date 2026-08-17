import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/constants.dart';
import '../widgets/ai_terms_dialog.dart';
import '../widgets/error_retry_view.dart';

class WorkoutLibraryScreen extends StatefulWidget {
  const WorkoutLibraryScreen({super.key});

  @override
  State<WorkoutLibraryScreen> createState() => _WorkoutLibraryScreenState();
}

class _WorkoutLibraryScreenState extends State<WorkoutLibraryScreen> {
  Map<String, List<dynamic>> _programs = {};
  bool _isLoading = true;
  bool _hasError = false;
  bool _isImporting = false;
  String? _importingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final resp = await auth.dio.get(
        '${AppConstants.baseUrl}/workout-templates/by-program',
      );
      if (resp.statusCode == 200) {
        final data = resp.data as Map<String, dynamic>;
        setState(() {
          _programs = data.map((k, v) => MapEntry(k, List<dynamic>.from(v)));
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() { _isLoading = false; _hasError = true; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar biblioteca: $e')),
        );
      }
    }
  }

  Future<void> _importTemplate(String templateId, String name) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Check terms accepted
    if (!auth.acceptedAiTerms) {
      final accepted = await AiTermsDialog.show(context);
      if (!accepted || !mounted) return;
    }

    setState(() {
      _isImporting = true;
      _importingId = templateId;
    });

    try {
      final resp = await auth.dio.post(
        '${AppConstants.baseUrl}/workout-templates/$templateId/import',
      );

      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        final imported = data['exercises_imported'] ?? 0;
        final skipped = (data['exercises_skipped'] as List?)?.length ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.black),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"$name" adicionado! $imported exercícios importados${skipped > 0 ? " ($skipped não encontrados)" : ""}.',
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(AppConstants.neonAccent),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Biblioteca de Treinos',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(AppConstants.borderColor)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? ErrorRetryView(onRetry: _load)
              : _programs.isEmpty
                  ? _buildEmpty()
                  : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildBanner(),
                    const SizedBox(height: 20),
                    ..._programs.entries.map(
                      (entry) => _buildProgramSection(entry.key, entry.value),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1e3a5f), Color(0xFF0d1b2a)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(AppConstants.neonAccent).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(AppConstants.neonAccent).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.library_books_rounded,
              color: Color(AppConstants.neonAccent),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Programas Prontos',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Selecione um treino e importe com 1 toque. Gratuito.',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramSection(String programName, List<dynamic> templates) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.neonAccent),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  programName,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${templates.length} treinos',
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...templates.map((t) => _buildTemplateCard(t as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final id = template['id'] as String;
    final name = template['name'] as String;
    final level = template['level'] as String? ?? '';
    final goal = template['goal'] as String? ?? '';
    final duration = template['duration_minutes'] as int? ?? 0;
    final equipment = template['equipment'] as String? ?? '';
    final exercises = (template['exercises'] as List?)?.length ?? 0;
    final isImporting = _isImporting && _importingId == id;

    final levelColor = level == 'Iniciante'
        ? Colors.green[400]!
        : level == 'Intermediário'
            ? Colors.orange[400]!
            : Colors.red[400]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: levelColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: levelColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        level,
                        style: GoogleFonts.inter(
                          color: levelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Stats row
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _stat(Icons.timer_outlined, '$duration min'),
                    _stat(Icons.fitness_center_outlined, '$exercises exercícios'),
                    _stat(Icons.flag_outlined, goal),
                    _stat(Icons.sports_gymnastics_outlined, equipment),
                  ],
                ),
              ],
            ),
          ),

          // Exercises preview
          if (template['exercises'] != null) ...[
            const Divider(height: 1, color: Color(AppConstants.borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  for (final ex in (template['exercises'] as List).take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 6, color: Color(AppConstants.neonAccent)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${ex['name']}  •  ${ex['sets']}x${ex['reps_min'] != null ? "${ex['reps_min']}-${ex['reps_max']}" : "${ex['duration_seconds']}s"}',
                              style: GoogleFonts.inter(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if ((template['exercises'] as List).length > 3)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+ ${(template['exercises'] as List).length - 3} outros exercícios',
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Import button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isImporting ? null : () => _importTemplate(id, name),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConstants.neonAccent),
                  disabledBackgroundColor: const Color(AppConstants.neonAccent).withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download_rounded, color: Colors.black, size: 18),
                label: Text(
                  isImporting ? 'Importando...' : 'Adicionar aos Meus Treinos',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Biblioteca indisponível',
            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
