import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../services/workout_service.dart';
import '../../services/trainer_service.dart';
import '../../services/workout_template_service.dart';
import '../../models/workout.dart';
import '../../models/workout_template.dart';
import '../../models/user.dart';
import '../../core/constants.dart';
import '../../widgets/ui/app_dialog.dart';
import '../create_workout_screen.dart';
import 'student_workouts_detail_screen.dart';

/// BUG-7.1 — Dedicated Workouts screen for TRAINERS.
/// Lists workouts per student (workouts CREATED BY the trainer for their students).
/// Unlike WorkoutsScreen (for students), this shows each student's workouts
/// and allows create/edit per student context.
class TrainerWorkoutsScreen extends StatefulWidget {
  const TrainerWorkoutsScreen({super.key});

  @override
  State<TrainerWorkoutsScreen> createState() => _TrainerWorkoutsScreenState();
}

class _TrainerWorkoutsScreenState extends State<TrainerWorkoutsScreen> {
  List<User> _students = [];
  List<WorkoutTemplate> _templates = [];
  // student_id → workouts
  final Map<String, List<Workout>> _workoutsByStudent = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Expanded state per student card
  final Set<String> _expanded = {};

  int _lastSyncPulse = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    if (_lastSyncPulse != -1 && _lastSyncPulse != auth.syncPulse) {
      _lastSyncPulse = auth.syncPulse;
      _loadData(); // Reload background data
    } else if (_lastSyncPulse == -1) {
      _lastSyncPulse = auth.syncPulse;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final trainerService = TrainerService(auth.dio);
      final workoutService = WorkoutService(auth.dio);
      final templateService = WorkoutTemplateService(auth.dio);

      // 1. Fetch all students
      final students = await trainerService.getStudents();

      // 1.5 Fetch templates
      final templates = await templateService.getMyTemplates();

      // 2. For each student, fetch their workouts (created by this trainer)
      final Map<String, List<Workout>> byStudent = {};
      await Future.wait(
        students.map((s) async {
          final workouts = await workoutService.getWorkouts(studentId: s.id);
          byStudent[s.id] = workouts;
        }),
      );

      if (mounted) {
        setState(() {
          _students = students;
          _templates = templates;
          _workoutsByStudent.clear();
          _workoutsByStudent.addAll(byStudent);
          // Auto-expand first student
          if (students.isNotEmpty && _expanded.isEmpty) _expanded.add(students.first.id);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Falha ao carregar treinos';
          _isLoading = false;
        });
      }
    }
  }

  List<User> get _filteredStudents {
    if (_searchQuery.isEmpty) return _students;
    final q = _searchQuery.toLowerCase();
    return _students.where((s) {
      final name = (s.fullName ?? '').toLowerCase();
      // Also match students that have workouts matching the query
      final hasMatchingWorkout = (_workoutsByStudent[s.id] ?? [])
          .any((w) => w.name.toLowerCase().contains(q));
      return name.contains(q) || hasMatchingWorkout;
    }).toList();
  }

  int get _totalWorkouts =>
      _workoutsByStudent.values.fold(0, (sum, list) => sum + list.length);

  Future<void> _confirmDeleteWorkout(Workout workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Excluir treino?',
          style: GoogleFonts.inter(color: const Color(AppConstants.textPrimary)),
        ),
        content: Text(
          '"${workout.name}" será removido permanentemente.',
          style:
              GoogleFonts.inter(color: const Color(AppConstants.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: GoogleFonts.inter(
                    color: const Color(AppConstants.textSecondary))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text('Excluir',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(auth.dio);
      await workoutService.deleteWorkout(workout.id);

      // Remove locally
      setState(() {
        for (final list in _workoutsByStudent.values) {
          list.removeWhere((w) => w.id == workout.id);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${workout.name}" excluído')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Treinos e Templates',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // ── Search bar ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style:
                  GoogleFonts.inter(color: const Color(AppConstants.textPrimary)),
              decoration: InputDecoration(
                hintText: 'Buscar aluno ou treino…',
                hintStyle: GoogleFonts.inter(
                    color: const Color(AppConstants.textSecondary)),
                prefixIcon: const Icon(Icons.search,
                    color: Color(AppConstants.textSecondary)),
                filled: true,
                fillColor: const Color(AppConstants.cardDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(AppConstants.borderColor)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(AppConstants.borderColor)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(AppConstants.neonAccent)),
                ),
              ),
            ),
          ),

          // ── Summary header ───────────────────────────────────────
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildChip(
                    '${_students.length} alunos',
                    Icons.people_outline,
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildChip(
                    '$_totalWorkouts treinos',
                    Icons.fitness_center,
                    const Color(AppConstants.neonAccent),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // ── Templates Carousel ──────────────────────────────────
          if (!_isLoading) _buildTemplatesCarousel(),

          // ── Body ─────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(AppConstants.neonAccent)))
                : _errorMessage != null
                    ? _buildError()
                    : _filteredStudents.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            color: const Color(AppConstants.neonAccent),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                              itemCount: _filteredStudents.length,
                              itemBuilder: (context, i) {
                                final student = _filteredStudents[i];
                                return _buildStudentCard(student);
                              },
                            ),
                          ),
          ),
        ],
      ),

      // ── FAB — criar treino ou template ──────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: _showActionSheet,
        backgroundColor: const Color(AppConstants.neonAccent),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  // ── Student Card ───────────────────────────────────────────────────

  Widget _buildStudentCard(User student) {
    final workouts = _workoutsByStudent[student.id] ?? [];
    final initials =
        (student.fullName?.isNotEmpty == true) ? student.fullName![0] : 'A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentWorkoutsDetailScreen(student: student),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(AppConstants.neonAccent)
                    .withOpacity(0.15),
                backgroundImage: student.photoUrl != null
                    ? NetworkImage(_resolveUrl(student.photoUrl!))
                    : null,
                child: student.photoUrl == null
                    ? Text(initials,
                        style: GoogleFonts.inter(
                          color: const Color(AppConstants.neonAccent),
                          fontWeight: FontWeight.bold,
                        ))
                    : null,
              ),
              const SizedBox(width: 12),
              // Name + count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName ?? student.email,
                      style: GoogleFonts.inter(
                        color: const Color(AppConstants.textPrimary),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${workouts.length} ${workouts.length == 1 ? 'treino' : 'treinos'}',
                      style: GoogleFonts.inter(
                        color: const Color(AppConstants.textSecondary),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow icon
              const Icon(Icons.arrow_forward_ios,
                  color: Color(AppConstants.textSecondary), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutTile(Workout workout, User student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(AppConstants.primaryDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(AppConstants.neonAccent).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.fitness_center,
              color: Color(AppConstants.neonAccent), size: 18),
        ),
        title: Text(
          workout.name,
          style: GoogleFonts.inter(
            color: const Color(AppConstants.textPrimary),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${workout.exercises.length} exercício${workout.exercises.length == 1 ? '' : 's'}',
          style: GoogleFonts.inter(
            color: const Color(AppConstants.textSecondary),
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: Color(AppConstants.neonAccent)),
              onPressed: () => _openEditWorkout(workout),
              tooltip: 'Editar',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: Colors.red.shade400),
              onPressed: () => _confirmDeleteWorkout(workout),
              tooltip: 'Excluir',
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  Future<void> _openCreateWorkout(User student) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateWorkoutScreen(preSelectedStudentId: student.id),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _openEditWorkout(Workout workout) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateWorkoutScreen(workoutToEdit: workout),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _openEditTemplate(WorkoutTemplate template) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateWorkoutScreen(
          isTemplate: true,
          templateToEdit: template,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _confirmDeleteTemplate(WorkoutTemplate template) async {
    final bool? confirm = await AppDialog.show<bool>(
      context,
      title: 'Excluir Modelo',
      content: 'Tem certeza que deseja excluir o modelo "${template.name}"? Esta ação não pode ser desfeita.',
      primaryButtonText: 'Excluir',
      secondaryButtonText: 'Cancelar',
      onPrimaryButton: () => Navigator.of(context).pop(true),
      onSecondaryButton: () => Navigator.of(context).pop(false),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final templateService = WorkoutTemplateService(auth.dio);
        await templateService.deleteTemplate(template.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Modelo excluído com sucesso!')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir modelo: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showTemplateDetails(WorkoutTemplate template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(AppConstants.primaryDark),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(AppConstants.borderColor),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (template.description != null && template.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              template.description!,
                              style: GoogleFonts.inter(
                                color: const Color(AppConstants.textSecondary),
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(AppConstants.neonAccent), size: 22),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openEditTemplate(template);
                    },
                    tooltip: 'Editar Modelo',
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: Colors.red[400], size: 22),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDeleteTemplate(template);
                    },
                    tooltip: 'Excluir Modelo',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: template.items.length,
                itemBuilder: (ctx, i) {
                  final item = template.items[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.cardDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(AppConstants.borderColor)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.exerciseName,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.sets} x ${item.repsMin ?? 0}-${item.repsMax ?? 0} • ${item.restSeconds}s',
                                style: GoogleFonts.inter(
                                  color: const Color(AppConstants.textSecondary),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.methodologyType != 'NORMAL')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(AppConstants.neonAccent).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.methodologyType,
                              style: GoogleFonts.inter(
                                color: const Color(AppConstants.neonAccent),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(AppConstants.cardDark),
                border: Border(top: BorderSide(color: const Color(AppConstants.borderColor))),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showApplyTemplateToStudentDialog(template);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppConstants.neonAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Aplicar este Template a um Aluno',
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
  }

  void _showApplyTemplateToStudentDialog(WorkoutTemplate template) {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum aluno cadastrado ainda')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(AppConstants.cardDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Aplicar "${template.name}" para:',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final s = _students[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(AppConstants.neonAccent),
                      child: Text(
                        (s.fullName?.isNotEmpty == true) ? s.fullName![0] : 'A',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    title: Text(
                      s.fullName ?? s.email,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      _applyTemplate(template.id, s.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyTemplate(String templateId, String studentId) async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final templateService = WorkoutTemplateService(auth.dio);
      final workout = await templateService.applyTemplate(templateId, studentId);

      if (workout != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Treino copiado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aplicar template: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSelectStudentDialog() {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum aluno cadastrado ainda')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(AppConstants.cardDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(AppConstants.borderColor),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Criar treino para qual aluno?',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(AppConstants.textPrimary),
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(color: Color(AppConstants.borderColor), height: 1),
            ..._students.map((s) => ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        Color(AppConstants.neonAccent).withValues(alpha: 0.15),
                    child: Text(
                      (s.fullName?.isNotEmpty == true) ? s.fullName![0] : s.email[0],
                      style: GoogleFonts.inter(
                          color: const Color(AppConstants.neonAccent),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    s.fullName ?? s.email,
                    style: GoogleFonts.inter(
                        color: const Color(AppConstants.textPrimary)),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openCreateWorkout(s);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(AppConstants.cardDark),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.borderColor),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'O que deseja criar?',
                style: GoogleFonts.inter(
                  color: const Color(AppConstants.textPrimary),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildActionTile(
                icon: Icons.person_add_alt_1,
                title: 'Novo Treino para Aluno',
                subtitle: 'Crie um treino direto para alguém',
                onTap: () {
                  Navigator.pop(ctx);
                  _showSelectStudentDialog();
                },
              ),
              const SizedBox(height: 12),
              _buildActionTile(
                icon: Icons.save_as,
                title: 'Novo Modelo (Template)',
                subtitle: 'Crie um template reutilizável',
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateWorkoutScreen(isTemplate: true),
                    ),
                  );
                  if (result == true) _loadData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(AppConstants.primaryDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(AppConstants.borderColor)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(AppConstants.neonAccent).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(AppConstants.neonAccent)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: const Color(AppConstants.textPrimary),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(AppConstants.textSecondary),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(AppConstants.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesCarousel() {
    if (_templates.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meus Templates',
                style: GoogleFonts.inter(
                  color: const Color(AppConstants.textPrimary),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text('Ver Todos', style: GoogleFonts.inter(color: const Color(AppConstants.neonAccent), fontSize: 12)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _templates.length,
            itemBuilder: (ctx, i) {
              final t = _templates[i];
              return InkWell(
                onTap: () => _showTemplateDetails(t),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(AppConstants.cardDark), Color(AppConstants.primaryDark)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(AppConstants.borderColor)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(AppConstants.neonAccent).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.file_copy_outlined, color: Color(AppConstants.neonAccent), size: 20),
                      ),
                      const Spacer(),
                      Text(
                        t.name,
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.items.length} exercícios',
                        style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    var clean = url;
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    return '${AppConstants.apiUrl}/$clean';
  }

  Widget _buildChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
                color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 56, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(_errorMessage!,
              style: GoogleFonts.inter(
                  color: const Color(AppConstants.textSecondary))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(
            'Nenhum aluno encontrado',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: const Color(AppConstants.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Convide alunos pelo seu painel principal',
            style: GoogleFonts.inter(
              color: const Color(AppConstants.textSecondary),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

}
