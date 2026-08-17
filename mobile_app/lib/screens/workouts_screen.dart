import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/workout_service.dart';
import '../models/workout.dart';
import '../models/workout_group.dart';
import '../core/constants.dart';
import 'workout_runner.dart';
import 'create_workout_screen.dart';
import 'workout_library_screen.dart';
import 'ai_workout_suggestion_screen.dart';
import 'workout_preview_screen.dart';

/// Electric lime — used SPARINGLY for energy / active accents.
const Color spark = Color(0xFFD4FF3F);

enum _WorkoutBadge { none, inProgress, lastDone }

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  List<Workout> _workouts = [];
  List<WorkoutGroup> _groups = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _expandedGroupId; // Track which folder is currently expanded

  // Getters to separate active and archived groups
  List<WorkoutGroup> get _activeGroups => _groups.where((g) => g.isActive).toList();
  List<WorkoutGroup> get _archivedGroups => _groups.where((g) => !g.isActive).toList();

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(authProvider.dio);

      final workouts = await workoutService.getWorkouts();
      final groups = await workoutService.getWorkoutGroups();

      if (mounted) {
        setState(() {
          _workouts = workouts;
          _groups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Falha ao carregar treinos';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openCreateWorkout() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateWorkoutScreen()),
    );
    if (result == true) _loadData();
  }

  /// Estimated minutes for a workout. Prefers explicit `estimatedDuration`,
  /// otherwise derives from exercises: sum(sets * (restSeconds + 40)) / 60.
  int? _estimatedMinutes(Workout workout) {
    if (workout.estimatedDuration != null && workout.estimatedDuration! > 0) {
      return workout.estimatedDuration;
    }
    if (workout.exercises.isEmpty) return null;
    var totalSeconds = 0;
    for (final ex in workout.exercises) {
      final rest = ex.restSeconds ?? 60;
      totalSeconds += ex.sets * (rest + 40);
    }
    final minutes = (totalSeconds / 60).round();
    return minutes > 0 ? minutes : null;
  }

  // ── Computed ────────────────────────────────────────────────────

  List<Workout> get _filteredWorkouts {
    if (_searchQuery.isEmpty) return _workouts;
    return _workouts
        .where((w) => w.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<Workout> get _activeWorkouts =>
      _filteredWorkouts.where((w) => w.isActive).toList();

  List<Workout> get _inactiveWorkouts =>
      _filteredWorkouts.where((w) => !w.isActive).toList();

  /// ID do treino com a session COMPLETED mais recente
  String? get _lastExecutedWorkoutId {
    DateTime? latest;
    String? id;
    for (final w in _activeWorkouts) {
      final completed = w.sessions
          .where((s) => s.status == 'COMPLETED' && s.endTime != null)
          .toList()
        ..sort((a, b) => b.endTime!.compareTo(a.endTime!));
      if (completed.isNotEmpty) {
        if (latest == null || completed.first.endTime!.isAfter(latest)) {
          latest = completed.first.endTime;
          id = w.id;
        }
      }
    }
    return id;
  }

  Map<String, List<Workout>> _groupByFolder(List<Workout> workouts) {
    final Map<String, List<Workout>> grouped = {};
    for (final workout in workouts) {
      final key = workout.groupId ?? 'ungrouped';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(workout);
    }
    return grouped;
  }

  Map<String, List<WorkoutGroup>> _groupByTrainer(List<WorkoutGroup> groups) {
    final map = <String, List<WorkoutGroup>>{};
    for (final g in groups) {
      final key = g.trainerId ?? 'unknown';
      map.putIfAbsent(key, () => []).add(g);
    }
    return map;
  }

  Widget _buildTrainerSectionHeader(String trainerName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(
            trainerName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.grey[800], height: 1)),
        ],
      ),
    );
  }

  Map<String, List<Workout>> _groupInactiveByMonth(List<Workout> inactive) {
    final Map<String, List<Workout>> byMonth = {};
    for (final workout in inactive) {
      final refDate = workout.endDate ?? workout.startDate;
      final String key = refDate != null
          ? '${_monthName(refDate.month)} ${refDate.year}'
          : 'Sem Data';
      byMonth.putIfAbsent(key, () => []);
      byMonth[key]!.add(workout);
    }
    // Ordenar decrescente (mais recente primeiro)
    final entries = byMonth.entries.toList()
      ..sort((a, b) {
        final aRef = a.value.first.endDate ??
            a.value.first.startDate ??
            DateTime(2000);
        final bRef = b.value.first.endDate ??
            b.value.first.startDate ??
            DateTime(2000);
        return bRef.compareTo(aRef);
      });
    return Map.fromEntries(entries);
  }

  String _monthName(int month) {
    const names = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return names[month - 1];
  }

  // ── Dialogs ─────────────────────────────────────────────────────

  Future<void> _showCreateGroupDialog({WorkoutGroup? groupToEdit}) async {
    final nameController = TextEditingController(text: groupToEdit?.name ?? '');
    DateTime? startDate = groupToEdit?.startDate;
    DateTime? endDate = groupToEdit?.endDate;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(AppConstants.cardDark),
          title: Text(
            groupToEdit == null ? 'Nova Pasta' : 'Editar Pasta',
            style: GoogleFonts.inter(color: const Color(AppConstants.textPrimary)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name field
                TextField(
                  controller: nameController,
                  autofocus: groupToEdit == null,
                  style: GoogleFonts.inter(color: const Color(AppConstants.textPrimary)),
                  decoration: InputDecoration(
                    labelText: 'Nome da pasta',
                    hintText: 'Ex: Novembro, Fase 1...',
                    hintStyle: GoogleFonts.inter(color: const Color(AppConstants.textSecondary)),
                    filled: true,
                    fillColor: const Color(AppConstants.primaryDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(AppConstants.borderColor)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Start date
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() => startDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.primaryDark),
                      border: Border.all(color: const Color(AppConstants.borderColor)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Início: ${startDate != null ? _formatDate(startDate!) : 'Sem data'}',
                          style: GoogleFonts.inter(color: const Color(AppConstants.textPrimary)),
                        ),
                        const Icon(Icons.calendar_today, color: Color(AppConstants.neonAccent), size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // End date
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: endDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() => endDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.primaryDark),
                      border: Border.all(color: const Color(AppConstants.borderColor)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fim: ${endDate != null ? _formatDate(endDate!) : 'Sem data'}',
                          style: GoogleFonts.inter(color: const Color(AppConstants.textPrimary)),
                        ),
                        const Icon(Icons.calendar_today, color: Color(AppConstants.neonAccent), size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar',
                  style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final workoutService = WorkoutService(authProvider.dio);

                  WorkoutGroup? newGroup;
                  if (groupToEdit == null) {
                    newGroup = await workoutService.createWorkoutGroup(
                      nameController.text.trim(),
                      startDate: startDate,
                      endDate: endDate,
                    );
                  } else {
                    newGroup = await workoutService.updateWorkoutGroup(
                      groupToEdit.id,
                      nameController.text.trim(),
                      startDate: startDate,
                      endDate: endDate,
                    );
                  }

                  if (newGroup != null) {
                    setState(() {
                      if (groupToEdit == null) {
                        _groups.add(newGroup!);
                      } else {
                        final index = _groups.indexWhere((g) => g.id == groupToEdit.id);
                        if (index >= 0) _groups[index] = newGroup!;
                      }
                    });
                    if (context.mounted) Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(AppConstants.neonAccent)),
              child: Text(groupToEdit == null ? 'Criar' : 'Salvar',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

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
          'O treino "${workout.name}" será removido permanentemente.',
          style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text('Excluir', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(authProvider.dio);
      await workoutService.deleteWorkout(workout.id);
      setState(() => _workouts.removeWhere((w) => w.id == workout.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Treino "${workout.name}" excluído')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir treino: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavoriteWorkout(Workout workout) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final workoutService = WorkoutService(authProvider.dio);
    final updated = await workoutService.toggleFavoriteWorkout(workout.id);
    if (updated != null && mounted) {
      setState(() {
        final idx = _workouts.indexWhere((w) => w.id == workout.id);
        if (idx != -1) _workouts[idx] = _workouts[idx].copyWith(isFavorite: updated.isFavorite);
      });
    }
  }

  Future<void> _showWorkoutOptionsSheet(Workout workout) async {
    await showModalBottomSheet(
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                workout.name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(AppConstants.textPrimary),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(color: Color(AppConstants.borderColor), height: 1),
            ListTile(
              leading: Icon(
                workout.isFavorite ? Icons.star : Icons.star_border,
                color: workout.isFavorite ? Colors.amber : Colors.grey,
              ),
              title: Text(
                workout.isFavorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
                style: GoogleFonts.inter(color: const Color(AppConstants.textPrimary)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggleFavoriteWorkout(workout);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: Color(AppConstants.neonAccent)),
              title: Text('Editar treino',
                  style: GoogleFonts.inter(color: const Color(AppConstants.textPrimary))),
              onTap: () async {
                Navigator.pop(ctx);
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateWorkoutScreen(workoutToEdit: workout),
                  ),
                );
                if (updated == true && mounted) _loadData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined,
                  color: Color(AppConstants.neonAccent)),
              title: Text('Mover para pasta',
                  style: GoogleFonts.inter(color: const Color(AppConstants.textPrimary))),
              onTap: () {
                Navigator.pop(ctx);
                _showMoveToGroupSheet(workout);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
              title: Text('Excluir treino',
                  style: GoogleFonts.inter(color: Colors.red.shade400)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteWorkout(workout);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoveToGroupSheet(Workout workout) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final workoutService = WorkoutService(authProvider.dio);

    await showModalBottomSheet(
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Mover "${workout.name}" para...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(AppConstants.textPrimary),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(color: Color(AppConstants.borderColor), height: 1),
            if (_activeGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nenhuma pasta criada ainda.\nToque no ícone de pasta no topo para criar uma.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: const Color(AppConstants.textSecondary),
                    fontSize: 13,
                  ),
                ),
              )
            else
              ..._activeGroups.map((group) {
                final isCurrent = workout.groupId == group.id;
                return ListTile(
                  leading: Icon(
                    isCurrent ? Icons.folder_open : Icons.folder_outlined,
                    color: const Color(AppConstants.neonAccent),
                  ),
                  title: Text(
                    group.name,
                    style: GoogleFonts.inter(
                        color: const Color(AppConstants.textPrimary)),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.check,
                          color: Color(AppConstants.neonAccent))
                      : null,
                  onTap: isCurrent
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            final updated = await workoutService
                                .moveWorkoutToGroup(workout.id, group.id);
                            if (updated != null && mounted) {
                              setState(() {
                                final idx = _workouts
                                    .indexWhere((w) => w.id == workout.id);
                                if (idx != -1) _workouts[idx] = updated;
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Erro ao mover treino: $e')),
                              );
                            }
                          }
                        },
                );
              }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        titleSpacing: 20,
        title: Text(
          'MEUS TREINOS',
          style: GoogleFonts.bebasNeue(
            fontSize: 28,
            letterSpacing: 1.5,
            color: const Color(AppConstants.textPrimary),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            color: const Color(AppConstants.textSecondary),
            onPressed: _showCreateGroupDialog,
            tooltip: 'Nova Pasta',
          ),
          IconButton(
            icon: const Icon(Icons.library_books_outlined),
            color: const Color(AppConstants.textSecondary),
            tooltip: 'Biblioteca de Treinos',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkoutLibraryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Treino por IA',
            color: const Color(AppConstants.neonAccent),
            onPressed: () async {
              final saved = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => const AiWorkoutSuggestionScreen()),
              );
              if (saved == true) _loadData();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateWorkout,
        backgroundColor: const Color(AppConstants.neonAccent),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: GoogleFonts.inter(
                  color: const Color(AppConstants.textPrimary)),
              decoration: InputDecoration(
                hintText: 'Buscar treinos...',
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
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _filteredWorkouts.isEmpty
                        ? _buildEmptyState()
                        : _buildMainList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (context, index) => _SkeletonCard(index: index),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade400),
            const SizedBox(height: 20),
            Text(
              'ALGO DEU ERRADO',
              style: GoogleFonts.bebasNeue(
                fontSize: 30,
                letterSpacing: 1.5,
                color: const Color(AppConstants.textPrimary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.archivo(
                fontSize: 14,
                color: const Color(AppConstants.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                'Tentar Novamente',
                style: GoogleFonts.archivo(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.cyanAccent),
                foregroundColor: const Color(AppConstants.primaryDark),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(AppConstants.cardDark),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(AppConstants.neonAccent)
                      .withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(
                isSearching ? Icons.search_off : Icons.fitness_center,
                size: 44,
                color: const Color(AppConstants.neonAccent),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearching ? 'NADA ENCONTRADO' : 'COMECE A TREINAR',
              style: GoogleFonts.bebasNeue(
                fontSize: 38,
                letterSpacing: 1.5,
                height: 1.0,
                color: const Color(AppConstants.textPrimary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isSearching
                  ? 'Nenhum treino corresponde à sua busca.'
                  : 'Crie seu primeiro treino e\ndê o primeiro passo.',
              textAlign: TextAlign.center,
              style: GoogleFonts.archivo(
                fontSize: 14,
                height: 1.4,
                color: const Color(AppConstants.textSecondary),
              ),
            ),
            if (!isSearching) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                child: ElevatedButton.icon(
                  onPressed: _openCreateWorkout,
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(
                    'Criar treino',
                    style: GoogleFonts.archivo(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConstants.cyanAccent),
                    foregroundColor: const Color(AppConstants.primaryDark),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () async {
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AiWorkoutSuggestionScreen()),
                  );
                  if (saved == true) _loadData();
                },
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text(
                  'Ou deixe a IA montar pra você',
                  style: GoogleFonts.archivo(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(AppConstants.neonAccent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainList() {
    final active = _activeWorkouts;
    final inactive = _inactiveWorkouts;
    final byFolder = _groupByFolder(active);
    final lastExecutedId = _lastExecutedWorkoutId;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // ── Treinos Ativos ──────────────────────────────────────
          if (active.isEmpty && inactive.isEmpty)
            _buildEmptyState()
          else ...[
            // Pastas com treinos ativos (agrupadas por trainer quando há múltiplos)
            ...() {
              final uniqueTrainerIds = _activeGroups
                  .map((g) => g.trainerId ?? 'unknown')
                  .toSet();

              if (uniqueTrainerIds.length <= 1) {
                // Comportamento original: lista plana sem cabeçalhos
                return _activeGroups.map((group) {
                  final groupWorkouts = byFolder[group.id] ?? [];
                  if (groupWorkouts.isEmpty) return const SizedBox.shrink();
                  return _buildFolderSection(
                    group,
                    groupWorkouts,
                    lastExecutedId: lastExecutedId,
                    isActive: true,
                  );
                }).toList();
              }

              // Múltiplos trainers: exibir cabeçalho de seção por trainer
              final byTrainer = _groupByTrainer(_activeGroups);
              final widgets = <Widget>[];

              for (final trainerId in byTrainer.keys) {
                final trainerGroups = byTrainer[trainerId]!;
                final trainerName = trainerGroups.first.trainerName ?? 'Personal';
                widgets.add(_buildTrainerSectionHeader(trainerName));

                for (final group in trainerGroups) {
                  final groupWorkouts = byFolder[group.id] ?? [];
                  if (groupWorkouts.isEmpty) continue;
                  widgets.add(_buildFolderSection(
                    group,
                    groupWorkouts,
                    lastExecutedId: lastExecutedId,
                    isActive: true,
                  ));
                }
              }

              return widgets;
            }(),

            // Treinos ativos sem pasta
            if (byFolder['ungrouped']?.isNotEmpty ?? false)
              _buildFolderSection(
                null,
                byFolder['ungrouped']!,
                lastExecutedId: lastExecutedId,
                isActive: true,
                isUngrouped: true,
              ),

            // ── Pastas Arquivadas ──────────────────────────────────
            if (_archivedGroups.isNotEmpty) _buildArchivedGroupsSection(),

            // ── Treinos Inativos ──────────────────────────────────
            if (inactive.isNotEmpty) _buildInactiveSection(inactive),

            const SizedBox(height: 80),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderSection(
    WorkoutGroup? group,
    List<Workout> workouts, {
    String? lastExecutedId,
    bool isActive = true,
    bool isUngrouped = false,
  }) {
    final title = isUngrouped ? 'Sem Pasta' : group?.name ?? 'Pasta';
    final workoutCount = '${workouts.length} ${workouts.length == 1 ? 'treino' : 'treinos'}';
    final endDateStr = group != null && group.endDate != null
        ? 'Fim: ${_formatDate(group.endDate!)}'
        : '';
    final trainerStr = group != null && group.trainerName != null
        ? 'Por: ${group.trainerName}'
        : '';

    // Build subtitle with all available info
    final parts = <String>[
      if (endDateStr.isNotEmpty) endDateStr,
      workoutCount,
      if (trainerStr.isNotEmpty) trainerStr,
    ];
    final subtitle = parts.join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _expandedGroupId == group?.id && isActive,
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedGroupId = expanded ? group?.id : null;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: Icon(
            isUngrouped ? Icons.folder_outlined : Icons.folder_open,
            color: isUngrouped
                ? const Color(AppConstants.textSecondary)
                : group?.isExpired == true
                    ? Colors.orange
                    : const Color(AppConstants.neonAccent),
          ),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(AppConstants.textPrimary),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: group?.isExpired == true
                  ? Colors.orange
                  : const Color(AppConstants.textSecondary),
            ),
          ),
          trailing: group != null && !isUngrouped
              ? PopupMenuButton(
                  color: const Color(AppConstants.cardDark),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Text('Editar',
                          style: GoogleFonts.inter(
                              color: const Color(AppConstants.textPrimary))),
                      onTap: () => _showCreateGroupDialog(groupToEdit: group),
                    ),
                    PopupMenuItem(
                      child: Text('Arquivar',
                          style: GoogleFonts.inter(color: Colors.orange)),
                      onTap: () => _archiveGroup(group),
                    ),
                  ],
                )
              : null,
          children: workouts
              .map((workout) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildWorkoutCard(
                      workout,
                      badge: _badgeForWithId(workout, lastExecutedId),
                      showStartButton: true,
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _archiveGroup(WorkoutGroup group) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(authProvider.dio);
      final updated = await workoutService.archiveWorkoutGroup(group.id);
      if (updated != null && mounted) {
        setState(() {
          final index = _groups.indexWhere((g) => g.id == group.id);
          if (index >= 0) _groups[index] = updated;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pasta arquivada com sucesso')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao arquivar: $e')),
        );
      }
    }
  }

  Widget _buildArchivedGroupsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: const Icon(
            Icons.archive_outlined,
            color: Color(AppConstants.textSecondary),
          ),
          title: Text(
            'Pastas Arquivadas',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(AppConstants.textSecondary),
            ),
          ),
          subtitle: Text(
            '${_archivedGroups.length} ${_archivedGroups.length == 1 ? 'pasta' : 'pastas'}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(AppConstants.textSecondary),
            ),
          ),
          children: _archivedGroups
              .map((group) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.primaryDark),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(AppConstants.borderColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(AppConstants.textPrimary),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (group.endDate != null)
                                  Text(
                                    'Fim: ${_formatDate(group.endDate!)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(AppConstants.textSecondary),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.restore, size: 18),
                            label: const Text('Restaurar'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(AppConstants.neonAccent),
                            ),
                            onPressed: () => _unarchiveGroup(group),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _unarchiveGroup(WorkoutGroup group) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(authProvider.dio);
      final updated = await workoutService.unarchiveWorkoutGroup(group.id);
      if (updated != null && mounted) {
        setState(() {
          final index = _groups.indexWhere((g) => g.id == group.id);
          if (index >= 0) _groups[index] = updated;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pasta restaurada com sucesso')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao restaurar: $e')),
        );
      }
    }
  }

  Widget _buildInactiveSection(List<Workout> inactive) {
    final byMonth = _groupInactiveByMonth(inactive);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: const Icon(
            Icons.archive_outlined,
            color: Color(AppConstants.textSecondary),
          ),
          title: Text(
            'Treinos Inativos',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(AppConstants.textSecondary),
            ),
          ),
          subtitle: Text(
            '${inactive.length} ${inactive.length == 1 ? 'treino' : 'treinos'}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(AppConstants.textSecondary),
            ),
          ),
          children: byMonth.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildMonthSubSection(entry.key, entry.value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthSubSection(String month, List<Workout> workouts) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(AppConstants.primaryDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 4),
          leading: const Icon(
            Icons.calendar_month_outlined,
            color: Color(AppConstants.textSecondary),
            size: 20,
          ),
          title: Text(
            month,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(AppConstants.textSecondary),
            ),
          ),
          subtitle: Text(
            '${workouts.length} ${workouts.length == 1 ? 'treino' : 'treinos'}',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(AppConstants.textSecondary),
            ),
          ),
          children: workouts
              .map((workout) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _buildWorkoutCard(
                      workout,
                      badge: _WorkoutBadge.none,
                      showStartButton: false,
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  _WorkoutBadge _badgeForWithId(Workout workout, String? lastExecutedId) {
    if (workout.hasActiveSession) return _WorkoutBadge.inProgress;
    if (workout.id == lastExecutedId) return _WorkoutBadge.lastDone;
    return _WorkoutBadge.none;
  }

  Widget _buildWorkoutCard(
    Workout workout, {
    required _WorkoutBadge badge,
    required bool showStartButton,
  }) {
    final bool inProgress = badge == _WorkoutBadge.inProgress;
    final bool dimmed = !showStartButton;
    final Color accent =
        inProgress ? Colors.orange.shade700 : const Color(AppConstants.cyanAccent);

    final int exCount = workout.exercises.length;
    final int? estMin = _estimatedMinutes(workout);

    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inProgress
              ? Colors.orange.shade700.withValues(alpha: 0.7)
              : const Color(AppConstants.borderColor),
          width: inProgress ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: title + favorite star (own breathing room) ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Slim accent rail for energy
              Container(
                width: 4,
                height: 34,
                margin: const EdgeInsets.only(top: 2, right: 12),
                decoration: BoxDecoration(
                  color: dimmed
                      ? const Color(AppConstants.textSecondary)
                          .withValues(alpha: 0.4)
                      : (inProgress ? Colors.orange.shade700 : spark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  workout.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.archivo(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.3,
                    color: dimmed
                        ? const Color(AppConstants.textSecondary)
                        : const Color(AppConstants.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Favorite star — top-right, generous tap target
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _toggleFavoriteWorkout(workout);
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 40, minHeight: 40),
                tooltip: workout.isFavorite
                    ? 'Remover dos favoritos'
                    : 'Favoritar',
                icon: Icon(
                  workout.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: workout.isFavorite
                      ? spark
                      : const Color(AppConstants.textSecondary),
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Meta chips: exercises + est duration ──
          Row(
            children: [
              _MetaChip(
                icon: Icons.format_list_numbered,
                label: '$exCount ${exCount == 1 ? 'exercício' : 'exercícios'}',
                dimmed: dimmed,
              ),
              if (estMin != null) ...[
                const SizedBox(width: 8),
                _MetaChip(
                  icon: Icons.schedule,
                  label: '~$estMin min',
                  dimmed: dimmed,
                ),
              ],
              const Spacer(),
              if (inProgress)
                _StatusBadge(
                  label: 'Em andamento',
                  color: Colors.orange.shade700,
                  icon: Icons.bolt,
                )
              else if (badge == _WorkoutBadge.lastDone)
                _StatusBadge(
                  label: 'Último',
                  color: spark,
                  icon: Icons.check_rounded,
                ),
            ],
          ),
          // Data de vencimento para inativos
          if (dimmed && workout.endDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_busy, size: 13, color: Colors.red.shade400),
                const SizedBox(width: 6),
                Text(
                  'Venceu em ${_formatDate(workout.endDate!)}',
                  style: GoogleFonts.archivo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ),
          ],
          // ── Actions: preview (secondary) + start (primary focal) ──
          if (showStartButton) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                // Preview — clear secondary action
                _PreviewButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkoutPreviewScreen(workout: workout),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                // Primary focal action
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkoutRunnerScreen(workout: workout),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(AppConstants.primaryDark),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow_rounded, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          inProgress ? 'Continuar treino' : 'Iniciar treino',
                          style: GoogleFonts.archivo(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Inactive cards: preview still reachable, de-emphasized
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _PreviewButton(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutPreviewScreen(workout: workout),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );

    return GestureDetector(
      onLongPress:
          showStartButton ? () => _showWorkoutOptionsSheet(workout) : null,
      // Inactive cards: clean de-emphasis via opacity, not a grey blob
      child: dimmed
          ? Opacity(opacity: 0.62, child: card)
          : card,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.archivo(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small meta chip (exercise count, est duration).
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dimmed;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = const Color(AppConstants.textSecondary)
        .withValues(alpha: dimmed ? 0.7 : 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(AppConstants.primaryDark),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.archivo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Secondary "preview" (eye) action with clear affordance.
class _PreviewButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PreviewButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: const Color(AppConstants.primaryDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(AppConstants.neonAccent)
                  .withValues(alpha: 0.45),
            ),
          ),
          child: const Icon(
            Icons.visibility_outlined,
            color: Color(AppConstants.neonAccent),
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Pulsing placeholder card for the loading state.
class _SkeletonCard extends StatefulWidget {
  final int index;
  const _SkeletonCard({required this.index});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> {
  double _opacity = 0.4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 0.85);
    });
  }

  Widget _bar(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(AppConstants.borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      opacity: _opacity,
      onEnd: () {
        if (mounted) {
          setState(() => _opacity = _opacity > 0.6 ? 0.4 : 0.85);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          color: const Color(AppConstants.cardDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(AppConstants.borderColor)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(180, 20),
            const SizedBox(height: 14),
            Row(
              children: [
                _bar(90, 26),
                const SizedBox(width: 8),
                _bar(70, 26),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _bar(46, 46),
                const SizedBox(width: 10),
                Expanded(child: _bar(double.infinity, 46)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
