import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../services/workout_service.dart';
import '../../models/workout.dart';
import '../../models/workout_group.dart';
import '../../models/user.dart';
import '../../core/constants.dart';
import '../create_workout_screen.dart';
import './agent_chat_screen.dart';

/// Screen for managing a specific student's workouts and folders (trainer view)
class StudentWorkoutsDetailScreen extends StatefulWidget {
  final User student;

  const StudentWorkoutsDetailScreen({
    super.key,
    required this.student,
  });

  @override
  State<StudentWorkoutsDetailScreen> createState() =>
      _StudentWorkoutsDetailScreenState();
}

class _StudentWorkoutsDetailScreenState
    extends State<StudentWorkoutsDetailScreen> {
  List<WorkoutGroup> _groups = [];
  List<Workout> _workouts = [];
  bool _isLoading = true;
  String? _errorMessage;

  List<WorkoutGroup> get _activeGroups =>
      _groups.where((g) => g.isActive).toList();

  List<WorkoutGroup> get _archivedGroups =>
      _groups.where((g) => !g.isActive).toList();

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(auth.dio);

      final workouts =
          await workoutService.getWorkouts(studentId: widget.student.id);
      final groups = await workoutService.getWorkoutGroups(
          studentId: widget.student.id);

      if (mounted) {
        setState(() {
          _workouts = workouts;
          _groups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao carregar dados: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Workout> _getWorkoutsForGroup(String groupId) {
    return _workouts.where((w) => w.groupId == groupId).toList();
  }

  List<Workout> _getUngroupedWorkouts() {
    return _workouts.where((w) => w.groupId == null).toList();
  }

  void _showFabMenu() {
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
            ListTile(
              leading:
                  const Icon(Icons.fitness_center, color: Color(AppConstants.neonAccent)),
              title: Text('Novo Treino',
                  style: GoogleFonts.inter(
                    color: const Color(AppConstants.textPrimary),
                    fontWeight: FontWeight.w600,
                  )),
              onTap: () {
                Navigator.pop(ctx);
                _openCreateWorkout();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder,
                  color: Color(AppConstants.neonAccent)),
              title: Text('Nova Pasta',
                  style: GoogleFonts.inter(
                    color: const Color(AppConstants.textPrimary),
                    fontWeight: FontWeight.w600,
                  )),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateGroupDialog();
              },
            ),
            const Divider(color: Color(AppConstants.borderColor)),
            ListTile(
              leading:
                  const Icon(Icons.bolt, color: Color(AppConstants.neonAccent)),
              title: Text('Agente Pulso (IA)',
                  style: GoogleFonts.inter(
                    color: const Color(AppConstants.textPrimary),
                    fontWeight: FontWeight.bold,
                  )),
              subtitle: Text('Criar treino com IA para este aluno',
                  style: GoogleFonts.inter(
                    color: const Color(AppConstants.textSecondary),
                    fontSize: 12,
                  )),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        AgentChatScreen(studentId: widget.student.id),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog({WorkoutGroup? groupToEdit}) {
    final nameController =
        TextEditingController(text: groupToEdit?.name ?? '');
    DateTime? startDate = groupToEdit?.startDate;
    DateTime? endDate = groupToEdit?.endDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(AppConstants.cardDark),
          title: Text(
            groupToEdit == null ? 'Nova Pasta' : 'Editar Pasta',
            style: GoogleFonts.inter(
              color: const Color(AppConstants.textPrimary),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: groupToEdit == null,
                  style: GoogleFonts.inter(
                    color: const Color(AppConstants.textPrimary),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nome da pasta',
                    hintText: 'Ex: Novembro, Fase 1...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(AppConstants.textSecondary),
                    ),
                    filled: true,
                    fillColor: const Color(AppConstants.primaryDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(AppConstants.borderColor),
                      ),
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
                    if (date != null) setDialogState(() => startDate = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.primaryDark),
                      border: Border.all(
                        color: const Color(AppConstants.borderColor),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          startDate != null
                              ? 'Início: ${_formatDate(startDate!)}'
                              : 'Sem data de início',
                          style: GoogleFonts.inter(
                            color: const Color(AppConstants.textPrimary),
                          ),
                        ),
                        const Icon(Icons.calendar_today,
                            color: Color(AppConstants.neonAccent), size: 20),
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
                      initialDate:
                          endDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) setDialogState(() => endDate = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.primaryDark),
                      border: Border.all(
                        color: const Color(AppConstants.borderColor),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          endDate != null
                              ? 'Fim: ${_formatDate(endDate!)}'
                              : 'Sem data de término',
                          style: GoogleFonts.inter(
                            color: const Color(AppConstants.textPrimary),
                          ),
                        ),
                        const Icon(Icons.calendar_today,
                            color: Color(AppConstants.neonAccent), size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(
                  color: const Color(AppConstants.textSecondary),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nome obrigatório')),
                  );
                  return;
                }

                try {
                  final auth =
                      Provider.of<AuthProvider>(context, listen: false);
                  final workoutService = WorkoutService(auth.dio);

                  if (groupToEdit == null) {
                    await workoutService.createWorkoutGroup(
                      nameController.text.trim(),
                      studentId: widget.student.id,
                      startDate: startDate,
                      endDate: endDate,
                    );
                  } else {
                    await workoutService.updateWorkoutGroup(
                      groupToEdit.id,
                      nameController.text.trim(),
                      studentId: widget.student.id,
                      startDate: startDate,
                      endDate: endDate,
                    );
                  }

                  if (mounted) {
                    Navigator.pop(ctx);
                    // Update in-place
                    final newGroup = groupToEdit != null
                        ? groupToEdit
                        : null; // For create, just reload
                    setState(() {
                      if (newGroup != null) {
                        final idx =
                            _groups.indexWhere((g) => g.id == newGroup.id);
                        if (idx >= 0) _groups[idx] = newGroup;
                      }
                    });
                    _loadData(); // Reload to get new group
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.neonAccent),
              ),
              child: Text(
                groupToEdit == null ? 'Criar' : 'Salvar',
                style: const TextStyle(color: Color(AppConstants.primaryDark)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _archiveGroup(WorkoutGroup group) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(auth.dio);
      final updated = await workoutService.archiveWorkoutGroup(group.id);
      if (updated != null && mounted) {
        setState(() {
          final idx = _groups.indexWhere((g) => g.id == group.id);
          if (idx >= 0) _groups[idx] = updated;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao arquivar: $e')),
      );
    }
  }

  void _unarchiveGroup(WorkoutGroup group) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(auth.dio);
      final updated = await workoutService.unarchiveWorkoutGroup(group.id);
      if (updated != null && mounted) {
        setState(() {
          final idx = _groups.indexWhere((g) => g.id == group.id);
          if (idx >= 0) _groups[idx] = updated;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao restaurar: $e')),
      );
    }
  }

  void _showDeleteGroupDialog(WorkoutGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Excluir pasta?',
          style: GoogleFonts.inter(
            color: const Color(AppConstants.textPrimary),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'A pasta "${group.name}" será removida permanentemente. Os treinos dentro dela não serão deletados.',
          style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(color: const Color(AppConstants.textSecondary)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final workoutService = WorkoutService(auth.dio);
                await workoutService.deleteWorkoutGroup(group.id);
                if (mounted) {
                  setState(() {
                    _groups.removeWhere((g) => g.id == group.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pasta removida com sucesso')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao excluir pasta: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(
              'Excluir',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _openCreateWorkout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateWorkoutScreen(
          preSelectedStudentId: widget.student.id,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _showMoveToGroupSheet(Workout workout) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final workoutService = WorkoutService(auth.dio);

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
            const Divider(
              color: Color(AppConstants.borderColor),
              height: 1,
            ),
            if (_activeGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nenhuma pasta criada ainda.\nToque no ícone de pasta para criar uma.',
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
                      color: const Color(AppConstants.textPrimary),
                    ),
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
                            final updated =
                                await workoutService.moveWorkoutToGroup(
                                    workout.id, group.id);
                            if (updated != null && mounted) {
                              setState(() {
                                final idx = _workouts.indexWhere(
                                    (w) => w.id == workout.id);
                                if (idx >= 0) _workouts[idx] = updated;
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erro ao mover treino: $e'),
                              ),
                            );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Treinos de ${widget.student.fullName ?? widget.student.email}',
              style: GoogleFonts.inter(
                color: const Color(AppConstants.textPrimary),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(AppConstants.neonAccent),
        onPressed: _showFabMenu,
        child: const Icon(Icons.add, color: Color(AppConstants.primaryDark)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(color: Colors.red),
                      ),
                    ),
                  if (_activeGroups.isEmpty &&
                      _archivedGroups.isEmpty &&
                      _getUngroupedWorkouts().isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Nenhum treino ou pasta criada ainda',
                          style: GoogleFonts.inter(
                            color: const Color(AppConstants.textSecondary),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    // Treinos sem pasta
                    if (_getUngroupedWorkouts().isNotEmpty) ...[
                      _buildFolderSection(
                        null,
                        _getUngroupedWorkouts(),
                        isUngrouped: true,
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Active groups
                    ..._activeGroups.map((group) {
                      final groupWorkouts = _getWorkoutsForGroup(group.id);
                      return _buildFolderSection(group, groupWorkouts);
                    }).toList(),
                    // Archived groups
                    if (_archivedGroups.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildArchivedGroupsSection(),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildFolderSection(
    WorkoutGroup? group,
    List<Workout> workouts, {
    bool isUngrouped = false,
  }) {
    final title = isUngrouped ? 'Sem Pasta' : group?.name ?? 'Pasta';
    final workoutCount =
        '${workouts.length} ${workouts.length == 1 ? 'treino' : 'treinos'}';
    final endDateStr = group != null && group.endDate != null
        ? 'Fim: ${_formatDate(group.endDate!)}'
        : '';

    final parts = <String>[
      if (endDateStr.isNotEmpty) endDateStr,
      workoutCount,
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
          initiallyExpanded: true,
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
                      child: Text(
                        'Editar',
                        style: GoogleFonts.inter(
                          color: const Color(AppConstants.textPrimary),
                        ),
                      ),
                      onTap: () => _showCreateGroupDialog(groupToEdit: group),
                    ),
                    PopupMenuItem(
                      child: Text(
                        'Arquivar',
                        style: GoogleFonts.inter(color: Colors.orange),
                      ),
                      onTap: () => _archiveGroup(group),
                    ),
                    PopupMenuItem(
                      child: Text(
                        'Excluir',
                        style: GoogleFonts.inter(color: Colors.red),
                      ),
                      onTap: () => _showDeleteGroupDialog(group),
                    ),
                  ],
                )
              : null,
          children: workouts
              .map((workout) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildWorkoutTile(workout),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildWorkoutTile(Workout workout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(AppConstants.primaryDark),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(AppConstants.neonAccent).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.fitness_center,
              color: Color(AppConstants.neonAccent), size: 16),
        ),
        title: Text(
          workout.name,
          style: GoogleFonts.inter(
            color: const Color(AppConstants.textPrimary),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${workout.exercises.length} exercício${workout.exercises.length == 1 ? '' : 's'}',
          style: GoogleFonts.inter(
            color: const Color(AppConstants.textSecondary),
            fontSize: 11,
          ),
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Text(
                'Editar',
                style: GoogleFonts.inter(
                  color: const Color(AppConstants.textPrimary),
                  fontSize: 12,
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateWorkoutScreen(
                    workoutToEdit: workout,
                  ),
                ),
              ).then((_) => _loadData()),
            ),
            PopupMenuItem(
              child: Text(
                'Mover para pasta',
                style: GoogleFonts.inter(
                  color: const Color(AppConstants.neonAccent),
                  fontSize: 12,
                ),
              ),
              onTap: () => _showMoveToGroupSheet(workout),
            ),
            PopupMenuItem(
              child: Text(
                'Excluir',
                style: GoogleFonts.inter(
                  color: Colors.red.shade400,
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(AppConstants.cardDark),
                    title: Text(
                      'Excluir treino?',
                      style: GoogleFonts.inter(
                        color: const Color(AppConstants.textPrimary),
                      ),
                    ),
                    content: Text(
                      '"${workout.name}" será removido permanentemente.',
                      style: GoogleFonts.inter(
                        color: const Color(AppConstants.textSecondary),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          'Excluir',
                          style: GoogleFonts.inter(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  try {
                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);
                    await WorkoutService(auth.dio).deleteWorkout(workout.id);
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
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
          leading: const Icon(Icons.archive_outlined,
              color: Color(AppConstants.textSecondary)),
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
              .map(
                (group) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(AppConstants.primaryDark),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(AppConstants.borderColor)),
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
                                    fontSize: 11,
                                    color: const Color(
                                      AppConstants.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.restore, size: 16),
                          label: const Text('Restaurar'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                const Color(AppConstants.neonAccent),
                          ),
                          onPressed: () => _unarchiveGroup(group),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
