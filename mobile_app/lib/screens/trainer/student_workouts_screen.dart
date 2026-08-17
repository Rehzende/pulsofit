import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../providers/auth_provider.dart';
import '../../services/workout_service.dart';
import '../create_workout_screen.dart';
import '../workout_preview_screen.dart';
import '../../widgets/error_retry_view.dart';

class StudentWorkoutsScreen extends StatefulWidget {
  final User student;

  const StudentWorkoutsScreen({super.key, required this.student});

  @override
  State<StudentWorkoutsScreen> createState() => _StudentWorkoutsScreenState();
}

class _StudentWorkoutsScreenState extends State<StudentWorkoutsScreen> {
  List<Workout> _workouts = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchWorkouts();
  }

  Future<void> _fetchWorkouts() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final workoutService = WorkoutService(authProvider.dio);
      final workouts = await workoutService.getWorkouts(studentId: widget.student.id);
      
      if (mounted) {
        setState(() {
          _workouts = workouts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _hasError = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar treinos: $e')),
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
          'Treinos de ${widget.student.fullName?.split(' ').first ?? 'Aluno'}',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateWorkoutScreen(
                preSelectedStudentId: widget.student.id,
              ),
            ),
          );
          
          if (result == true) {
            _fetchWorkouts();
          }
        },
        backgroundColor: const Color(AppConstants.neonAccent),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError ? ErrorRetryView(onRetry: _fetchWorkouts)
          : _workouts.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum treino encontrado.',
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _workouts.length,
                  itemBuilder: (context, index) {
                    final workout = _workouts[index];
                    return _buildWorkoutCard(workout);
                  },
                ),
    );
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Remover Treino?',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Deseja remover "${workout.name}"? Esta ação não pode ser desfeita.',
          style: GoogleFonts.inter(color: Colors.grey[400], height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remover',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.dio.delete('${AppConstants.baseUrl}/workouts/${workout.id}');
      setState(() => _workouts.removeWhere((w) => w.id == workout.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${workout.name}" removido.',
                style: const TextStyle(color: Colors.black)),
            backgroundColor: const Color(AppConstants.neonAccent),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao remover: $e')));
      }
    }
  }

  Widget _buildWorkoutCard(Workout workout) {
    return Dismissible(
      key: Key(workout.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red[800],
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete, color: Colors.white),
            Text('Remover', style: GoogleFonts.inter(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _deleteWorkout(workout);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: const Color(AppConstants.cardDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Text(
            workout.name,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${workout.exercises.length} exercícios',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            color: const Color(AppConstants.cardDark),
            onSelected: (value) {
              if (value == 'delete') _deleteWorkout(workout);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Text('Remover treino',
                        style: GoogleFonts.inter(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
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
    );
  }
}
