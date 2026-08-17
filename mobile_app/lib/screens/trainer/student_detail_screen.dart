import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/trainer_service.dart';
import '../../core/constants.dart';
import '../../models/user.dart';
import 'student_workouts_screen.dart';
import '../history_screen.dart';
import '../../core/utils.dart';

class StudentDetailScreen extends StatelessWidget {
  final User student;

  const StudentDetailScreen({super.key, required this.student});

  Future<void> _launchWhatsApp(BuildContext context) async {
    if (student.whatsappNumber == null) return;
    
    // Use the utility function if available, or direct launch
    // Since we have launchWhatsApp in utils.dart, let's use it if imported
    // But here we are defining a local method. Let's use the utils one directly in UI or here.
    // The utils.dart import is present.
    await launchWhatsApp(context, student.whatsappNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Detalhes do Aluno',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: const Color(AppConstants.cardDark),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(AppConstants.primaryDark),
                    backgroundImage: student.photoUrl != null
                        ? NetworkImage(student.photoUrl!)
                        : null,
                    child: student.photoUrl == null
                        ? Text(
                            (student.fullName ?? student.email)[0].toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              color: const Color(AppConstants.neonAccent),
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    student.fullName ?? 'Sem nome',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    student.email,
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                    ),
                  ),


                  if (student.whatsappNumber != null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => launchWhatsApp(
                        context, 
                        student.whatsappNumber,
                        message: "Olá ${student.fullName?.split(' ').first ?? 'Aluno'}, vi seu progresso aqui...",
                      ),
                      icon: const Icon(Icons.chat),
                      label: const Text('Conversar no WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Grid Menu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildMenuCard(
                    context,
                    title: 'Fichas de Treino',
                    icon: Icons.fitness_center,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentWorkoutsScreen(student: student),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Histórico',
                    icon: Icons.history,
                    onTap: () {
                       Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HistoryScreen(), // Needs update to support studentId
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Avaliação Física',
                    icon: Icons.monitor_weight_outlined,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Em breve')),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Biofeedback',
                    icon: Icons.favorite_outline,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Em breve')),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Remove Student Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _confirmRemoveStudent(context),
                  icon: const Icon(Icons.person_remove, color: Colors.red),
                  label: Text(
                    'Remover Aluno',
                    style: GoogleFonts.inter(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.red.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(AppConstants.cardDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: const Color(AppConstants.neonAccent),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveStudent(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text('Remover Aluno?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Tem certeza que deseja remover este aluno da sua lista? Esta ação não pode ser desfeita.',
          style: GoogleFonts.inter(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeStudent(context);
            },
            child: const Text('Remover', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeStudent(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(AppConstants.neonAccent))),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final trainerService = TrainerService(authProvider.dio);
      await trainerService.removeStudent(student.id);
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Go back to list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aluno removido com sucesso.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover aluno: $e')),
        );
      }
    }
  }
}
